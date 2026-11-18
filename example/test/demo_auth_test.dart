import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pam_flutter/api/tracker_api.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/preferences.dart';
import 'package:pam_flutter/response/pam_response.dart';
import 'package:pam_flutter_example/demo_auth_api.dart';
import 'package:pam_flutter_example/demo_auth_controller.dart';

class _MemoryPreference extends UserPreference {
  final values = <SaveKey, Object>{};
  bool failClear = false;
  int clearAttempts = 0;
  @override
  Future<void> clear() async {
    clearAttempts++;
    if (failClear) throw StateError('Storage unavailable');
    values.clear();
  }

  @override
  Future<String?> getString(SaveKey key) async => values[key] as String?;
  @override
  Future<void> saveString(String value, SaveKey key) async {
    values[key] = value;
  }

  @override
  Future<void> saveBool(bool value, SaveKey key) async {
    values[key] = value;
  }

  @override
  Future<void> remove(SaveKey key) async {
    values.remove(key);
  }
}

class _Tracker extends TrackerAPI {
  final requests = <Map<String, dynamic>>[];
  bool failLogin = false;
  _Tracker() : super('https://example.invalid');
  @override
  Future<PamResponse?> postTracker(Map<String, dynamic> body) async {
    requests.add(body);
    if (failLogin && body['event'] == 'login') {
      return PamResponse.createErrorResponse(
        code: 'TEST_PAM_ERROR',
        errorMessage: 'Unavailable',
      );
    }
    return PamResponse()
      ..contactID = 'pam-contact'
      ..database = 'public-db';
  }
}

class _AuthServer extends SimulatedAuthServer {
  String? failPath;
  Completer<void>? sessionGate;
  _AuthServer() : super(latency: Duration.zero);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/auth/session' && sessionGate != null) {
      await sessionGate!.future;
    }
    if (request.url.path == failPath) {
      await request.finalize().drain<void>();
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"message":"Unavailable"}')),
        500,
        headers: {'content-type': 'application/json'},
      );
    }
    return super.send(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pam_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Pam original;
  late _Tracker tracker;
  late _AuthServer server;
  late DemoAuthController auth;

  setUp(() {
    original = Pam.shared;
    tracker = _Tracker();
    server = _AuthServer();
    auth = DemoAuthController(
      api: DemoAuthApi(
        client: server,
        onRequest: (event) => auth.record(event),
      ),
    );
    Pam.shared = Pam()
      ..pref = _MemoryPreference()
      ..deviceUDID = 'device-id'
      ..publicContact = 'pam-contact'
      ..config = PamConfig(
        'https://example.invalid',
        'public-db',
        '',
        'tracking-id',
        false,
        identityMatcher: PamIdentityMatcher.primary(
          PamPrimaryIdentityKey.customer,
        ),
        identityProvider: auth.identityProvider,
        onIdentityMismatch: auth.onIdentityMismatch,
      )
      ..trackerAPI = tracker;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, String>{},
    );
  });
  tearDown(() async {
    await auth.whenIdle;
    auth.dispose();
    Pam.shared = original;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'cold start restores guest and provider only reads cached auth state',
    () async {
      expect(auth.identityProvider().type, PamUserStateType.unknown);
      await auth.refreshSession();
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      expect(auth.canUsePam, isTrue);
      expect(tracker.requests, isEmpty);
      final count = auth.events.length;
      auth.identityProvider();
      auth.identityProvider();
      expect(auth.events, hasLength(count));
      expect(
        auth.events.any((e) => e.contains('GET /auth/session → 401')),
        isTrue,
      );
    },
  );

  test(
    'provider returns unknown during an in-flight refresh and restores the cached user afterwards',
    () async {
      await auth.login('CUST-A');
      server.sessionGate = Completer<void>();
      final pending = auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.identityProvider().type, PamUserStateType.unknown);
      expect(auth.canUsePam, isFalse);
      server.sessionGate!.complete();
      await pending;
      expect(auth.identityProvider().identity!.value, 'CUST-A');
    },
  );

  test(
    'cold start reconciles a persisted SDK identity with a guest auth session',
    () async {
      Pam.shared.custID = 'OLD-PAM-USER';
      await auth.refreshSession();
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      expect(await Pam.getCustID(), isNull);
      expect(tracker.requests.single['event'], 'logout');
    },
  );

  test(
    'REST login publishes the entered customer before PAM, then REST logout clears both',
    () async {
      await auth.refreshSession();
      await auth.login('CUST-123');
      expect(auth.identityProvider().identity!.value, 'CUST-123');
      expect(await Pam.getCustID(), 'CUST-123');
      expect(tracker.requests.single['event'], 'login');
      expect(tracker.requests.single['form_fields']['customer'], 'CUST-123');
      expect(
        auth.events.indexWhere((e) => e.contains('App session → CUST-123')),
        lessThan(
          auth.events.indexWhere((e) => e.contains('Pam.userLogin(CUST-123)')),
        ),
      );
      await auth.logout();
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      expect(await Pam.getCustID(), isNull);
      expect(tracker.requests.last['event'], 'logout');
    },
  );

  test(
    'real resume path discovers expired REST session and logs out PAM',
    () async {
      await auth.login('CUST-A');
      await auth.expireOnServer();
      expect(auth.identityProvider().identity!.value, 'CUST-A');
      final a = auth.refreshSession();
      final b = auth.refreshSession();
      expect(identical(a, b), isTrue);
      await a;
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      expect(await Pam.getCustID(), isNull);
    },
  );

  test(
    'resume discovers a server-side account switch and synchronizes current identity',
    () async {
      await auth.login('CUST-A');
      await auth.switchCustomerOnServer('CUST-B');
      await auth.refreshSession();
      expect(auth.identityProvider().identity!.value, 'CUST-B');
      expect(await Pam.getCustID(), 'CUST-B');
      expect(tracker.requests.last['form_fields']['customer'], 'CUST-B');
    },
  );

  test(
    'actual SDK mismatch callback repairs logout without replaying the dropped event',
    () async {
      await auth.login('CUST-A');
      await auth.expireOnServer();
      await auth.loadSessionWithoutPamForDemo();
      expect(await Pam.getCustID(), 'CUST-A');
      expect(auth.requiresPamSync, isTrue);
      final dropped = await Pam.track('test');
      expect(dropped!.error!.code, 'IDENTITY_STATE_MISMATCH');
      await Future<void>.delayed(Duration.zero);
      await auth.whenIdle;
      expect(await Pam.getCustID(), isNull);
      expect(
        auth.events.any((e) => e.contains('onIdentityMismatch: CUST-A → null')),
        isTrue,
      );
      expect(tracker.requests.where((r) => r['event'] == 'test'), isEmpty);
      await Pam.track('test');
      expect(tracker.requests.where((r) => r['event'] == 'test'), hasLength(1));
    },
  );

  test('actual SDK mismatch callback repairs an account switch', () async {
    await auth.login('CUST-A');
    await auth.switchCustomerOnServer('CUST-B');
    await auth.loadSessionWithoutPamForDemo();
    final dropped = await Pam.track('test');
    expect(dropped!.error!.code, 'IDENTITY_STATE_MISMATCH');
    await Future<void>.delayed(Duration.zero);
    await auth.whenIdle;
    expect(await Pam.getCustID(), 'CUST-B');
    expect(auth.canUsePam, isTrue);
    expect(tracker.requests.where((r) => r['event'] == 'test'), isEmpty);
  });

  test(
    'callback queued behind a newer login uses the current session, not its stale identity',
    () async {
      await auth.login('CUST-A');
      final login = auth.login('CUST-C');
      final callback = auth.onIdentityMismatch(
        const PamIdentityMismatch(
          type: PamIdentityMismatchType.accountSwitchRequired,
          oldIdentity: PamUserIdentity('CUST-A'),
          newIdentity: PamUserIdentity('CUST-B'),
          event: 'test',
        ),
      );
      await Future.wait([login, callback]);
      expect(await Pam.getCustID(), 'CUST-C');
      expect(
        tracker.requests.any((r) => r['form_fields']['customer'] == 'CUST-B'),
        isFalse,
      );
    },
  );

  test(
    'logout and reset clears storage and SDK identity without restoring the member',
    () async {
      await auth.login('CUST-A');
      final storage = Pam.shared.pref as _MemoryPreference;
      storage.values[SaveKey.pushKey] = 'token';
      await auth.logoutAndReset();
      expect(auth.session, isNull);
      expect(await auth.api.loadSession(), isNull);
      expect(await Pam.getCustID(), isNull);
      expect(storage.values, isEmpty);
      expect(storage.clearAttempts, 1);
      expect(Pam.shared.allowTracking, isFalse);
      expect(auth.canUsePam, isTrue);
      expect(
        tracker.requests.where((r) => r['event'] == 'login'),
        hasLength(1),
      );
    },
  );

  test(
    'failed reset remains pending and sync retries storage cleanup',
    () async {
      await auth.login('CUST-A');
      final storage = Pam.shared.pref as _MemoryPreference;
      storage.failClear = true;
      await expectLater(auth.logoutAndReset(), throwsStateError);
      expect(auth.session, isNull);
      expect(auth.requiresPamSync, isTrue);
      expect(auth.canUsePam, isFalse);
      storage.failClear = false;
      await auth.synchronizePam();
      expect(storage.clearAttempts, 2);
      expect(auth.canUsePam, isTrue);
      expect(await Pam.getCustID(), isNull);
    },
  );

  test('REST 500 is unknown rather than logout, and recovery works', () async {
    await auth.login('CUST-A');
    server.failPath = '/auth/session';
    await expectLater(auth.refreshSession(), throwsA(isA<DemoAuthException>()));
    expect(auth.identityProvider().type, PamUserStateType.unknown);
    expect(await Pam.getCustID(), 'CUST-A');
    expect(tracker.requests.where((r) => r['event'] == 'logout'), isEmpty);
    server.failPath = null;
    await auth.refreshSession();
    expect(auth.identityProvider().identity!.value, 'CUST-A');
  });

  test(
    'failed REST login/logout does not change app or PAM identity',
    () async {
      await auth.login('CUST-A');
      final count = tracker.requests.length;
      server.failPath = '/auth/login';
      await expectLater(
        auth.login('CUST-B'),
        throwsA(isA<DemoAuthException>()),
      );
      expect(auth.session!.customerId, 'CUST-A');
      server.failPath = '/auth/logout';
      await expectLater(auth.logout(), throwsA(isA<DemoAuthException>()));
      expect(auth.session!.customerId, 'CUST-A');
      expect(await Pam.getCustID(), 'CUST-A');
      expect(tracker.requests, hasLength(count));
    },
  );

  test(
    'PAM failure retains successful REST login and retry sends login again even if local SDK changed',
    () async {
      tracker.failLogin = true;
      await expectLater(auth.login('CUST-A'), throwsStateError);
      expect(auth.session!.customerId, 'CUST-A');
      expect((await auth.api.loadSession())!.customerId, 'CUST-A');
      expect(auth.requiresPamSync, isTrue);
      tracker.failLogin = false;
      await auth.synchronizePam();
      expect(auth.canUsePam, isTrue);
      expect(
        tracker.requests.where((r) => r['event'] == 'login'),
        hasLength(2),
      );
    },
  );
}
