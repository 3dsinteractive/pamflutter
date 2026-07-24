import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pam_flutter/api/tracker_api.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/preferences.dart';
import 'package:pam_flutter/response/pam_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingTrackerAPI extends TrackerAPI {
  final List<Map<String, dynamic>> requests = [];
  final bool failFirstRequest;

  _RecordingTrackerAPI({this.failFirstRequest = false})
      : super('https://example.invalid');

  @override
  Future<PamResponse?> postTracker(Map<String, dynamic> body) async {
    requests.add(body);
    if (failFirstRequest && requests.length == 1) {
      return PamResponse.createErrorResponse(
        code: 'TIMEOUT',
        errorMessage: 'The server did not respond.',
      );
    }

    final fields = body['form_fields'] as Map<String, dynamic>;
    final database = fields['_database'] as String;
    final customer = (fields['customer'] ??
        fields['email'] ??
        fields['sms'] ??
        fields['_key_value']) as String?;
    final response = PamResponse()
      ..database = database
      ..contactID = database == 'public-db'
          ? 'public-contact'
          : 'login-contact-$customer';
    return response;
  }
}

class _DelayedFailureTrackerAPI extends TrackerAPI {
  var requestCount = 0;

  _DelayedFailureTrackerAPI() : super('https://example.invalid');

  @override
  Future<PamResponse?> postTracker(Map<String, dynamic> body) async {
    requestCount++;
    if (requestCount == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      return PamResponse.createErrorResponse(
        code: 'EXCEPTION',
        errorMessage: 'TimeoutException',
      );
    }

    return PamResponse()
      ..database = 'public-db'
      ..contactID = 'public-contact-2';
  }
}

class _ThrowingRemovePreference extends UserPreference {
  @override
  Future<void> remove(SaveKey key) {
    throw StateError('Secure storage is unavailable.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Pam pam;
  late _RecordingTrackerAPI tracker;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PAM Test',
      packageName: 'ai.pams.test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    pam = Pam()
      ..config = PamConfig(
        'https://example.invalid',
        'public-db',
        'login-db',
        'consent-message',
        false,
        identityMatcher: PamIdentityMatcher.primary(
          PamPrimaryIdentityKey.customer,
        ),
      )
      ..deviceUDID = 'device-id'
      ..publicContact = 'anonymous-contact';
    tracker = _RecordingTrackerAPI();
    pam.trackerAPI = tracker;
    Pam.shared = pam;
    Pam.contactID = '';
    Pam.customerID = '';
    Pam.databaseAlias = '';
  });

  Map<String, dynamic> fieldsAt(int index) =>
      tracker.requests[index]['form_fields'] as Map<String, dynamic>;

  void useIdentityMatcher(PamIdentityMatcher matcher) {
    final currentConfig = pam.config!;
    pam.config = PamConfig(
      currentConfig.pamServer,
      currentConfig.publicDBAlias,
      currentConfig.loginDBAlias,
      currentConfig.trackingConsentMessageID,
      currentConfig.enableLog,
      identityMatcher: matcher,
      blockEventsIfNoConsent: currentConfig.blockEventsIfNoConsent,
      identityProvider: currentConfig.identityProvider,
      onIdentityMismatch: currentConfig.onIdentityMismatch,
    );
  }

  test('login deletes media from the previous destination before switching',
      () async {
    await Pam.userLogin('customer-a');
    await Pam.track('purchase');

    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'login',
      'login',
      'purchase',
    ]);

    expect(fieldsAt(0), containsPair('_database', 'public-db'));
    expect(fieldsAt(0), containsPair('_contact_id', 'anonymous-contact'));
    expect(fieldsAt(0).containsKey('customer'), isFalse);
    expect(
      fieldsAt(0)['_delete_media'],
      anyOf(
        equals({'ios_notification': ''}),
        equals({'android_notification': ''}),
      ),
    );

    expect(fieldsAt(1), containsPair('_database', 'public-db'));
    expect(fieldsAt(1), containsPair('customer', 'customer-a'));
    expect(fieldsAt(1).containsKey('_contact_id'), isFalse);

    expect(fieldsAt(2), containsPair('_database', 'login-db'));
    expect(fieldsAt(2), containsPair('customer', 'customer-a'));

    expect(fieldsAt(3), containsPair('_database', 'login-db'));
    expect(
      fieldsAt(3),
      containsPair('_contact_id', 'login-contact-customer-a'),
    );
    expect(fieldsAt(3), containsPair('customer', 'customer-a'));
  });

  test('account switch deletes media from the old logged-in contact', () async {
    await Pam.userLogin('customer-a');
    tracker.requests.clear();

    await Pam.userLogin('customer-b');
    await Pam.track('open_home');

    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'login',
      'open_home',
    ]);
    expect(fieldsAt(0), containsPair('_database', 'login-db'));
    expect(
      fieldsAt(0),
      containsPair('_contact_id', 'login-contact-customer-a'),
    );
    expect(fieldsAt(0), containsPair('customer', 'customer-a'));

    expect(fieldsAt(1), containsPair('customer', 'customer-b'));
    expect(fieldsAt(1).containsKey('_contact_id'), isFalse);
    expect(
      fieldsAt(2),
      containsPair('_contact_id', 'login-contact-customer-b'),
    );
  });

  test('primary matcher sends its configured CDP field', () async {
    useIdentityMatcher(
      PamIdentityMatcher.primary(PamPrimaryIdentityKey.sms),
    );

    await Pam.userLogin('0811111111');
    await Pam.track('open_home');

    expect(fieldsAt(1), containsPair('sms', '0811111111'));
    expect(fieldsAt(1).containsKey('customer'), isFalse);
    expect(fieldsAt(2), containsPair('sms', '0811111111'));
    expect(fieldsAt(3), containsPair('sms', '0811111111'));
  });

  test('secondary matcher sends the fixed alternate-key protocol', () async {
    useIdentityMatcher(PamIdentityMatcher.secondary('line'));

    await Pam.userLogin('LINE_ID');
    await Pam.track('open_home');

    for (final index in [1, 2, 3]) {
      expect(fieldsAt(index), containsPair('_key_name', 'line'));
      expect(fieldsAt(index), containsPair('_key_value', 'LINE_ID'));
      expect(fieldsAt(index), containsPair('line', 'LINE_ID'));
      expect(fieldsAt(index), containsPair('_force_create', false));
    }
  });

  test('logout targets the logged-in contact before routing back to public',
      () async {
    await Pam.userLogin('customer-a');
    tracker.requests.clear();

    await Pam.userLogout();
    await Pam.track('anonymous_event');

    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'logout',
      'anonymous_event',
    ]);
    expect(fieldsAt(0), containsPair('_database', 'login-db'));
    expect(
      fieldsAt(0),
      containsPair('_contact_id', 'login-contact-customer-a'),
    );
    expect(fieldsAt(1), containsPair('_database', 'login-db'));
    expect(fieldsAt(2), containsPair('_database', 'public-db'));
    expect(fieldsAt(2), containsPair('_contact_id', 'public-contact'));
    expect(fieldsAt(2).containsKey('customer'), isFalse);
  });

  test('logout does not re-register a saved push token', () async {
    await Pam.userLogin('customer-a');
    await pam.pref.saveString('persisted-token', SaveKey.pushKey);
    tracker.requests.clear();

    await Pam.userLogout();

    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'logout',
    ]);
  });

  test('login is enqueued before a track call even when neither is awaited',
      () async {
    final loginFuture = Pam.userLogin('customer-a');
    final trackFuture = Pam.track('open_home');

    await Future.wait([loginFuture, trackFuture]);

    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'login',
      'login',
      'open_home',
    ]);
    expect(fieldsAt(3), containsPair('_database', 'login-db'));
    expect(
      fieldsAt(3),
      containsPair('_contact_id', 'login-contact-customer-a'),
    );
  });

  test('a timeout error lets the next queued event continue', () async {
    final delayedTracker = _DelayedFailureTrackerAPI();
    pam.trackerAPI = delayedTracker;

    final slowEvent = Pam.track('slow_event');
    final nextEvent = Pam.track('next_event');
    final results = await Future.wait([slowEvent, nextEvent]);

    expect(results[0]?.error?.code, 'EXCEPTION');
    expect(results[1]?.error, isNull);
    expect(results[1]?.contactID, 'public-contact-2');
    expect(delayedTracker.requestCount, 2);
  });

  test('login fails fast after delete_media fails but commits local routing',
      () async {
    tracker = _RecordingTrackerAPI(failFirstRequest: true);
    pam.trackerAPI = tracker;

    final loginResponse = await Pam.userLogin('customer-a');

    expect(loginResponse.error?.code, 'TIMEOUT');
    expect(tracker.requests.map((body) => body['event']), ['delete_media']);

    final trackResponse = await Pam.track('open_home');

    expect(trackResponse?.error, isNull);
    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'open_home',
    ]);
    final trackedFields = fieldsAt(1);
    expect(trackedFields, containsPair('_database', 'login-db'));
    expect(trackedFields, containsPair('customer', 'customer-a'));
  });

  test('initialize does not automatically send a persisted push token',
      () async {
    pam.publicContact = null;
    await pam.pref.saveString('persisted-token', SaveKey.pushKey);

    await pam.init(pam.config!, false);
    await Future<void>.delayed(Duration.zero);

    expect(pam.pushToken, isNull);
    expect(
      await pam.pref.getString(SaveKey.pushKey),
      'persisted-token',
    );
  });

  test('identity provider unknown state does not block tracking', () async {
    pam.config!.identityProvider = () => const PamUserState.unknown();

    final response = await Pam.track('open_home');

    expect(response?.error, isNull);
    expect(tracker.requests.map((body) => body['event']), ['open_home']);
  });

  test('matching identity allows tracking', () async {
    await Pam.userLogin('customer-a');
    tracker.requests.clear();
    pam.config!.identityProvider = () => PamUserState.identified('customer-a');

    final response = await Pam.track('open_home');

    expect(response?.error, isNull);
    expect(tracker.requests.map((body) => body['event']), ['open_home']);
  });

  test('identity mismatch drops events and notifies only once', () async {
    var mismatchCount = 0;
    PamIdentityMismatch? reportedMismatch;
    pam.config!.identityProvider = () => PamUserState.identified('customer-a');
    pam.config!.onIdentityMismatch = (mismatch) {
      mismatchCount++;
      reportedMismatch = mismatch;
    };

    final firstResponse = await Pam.track('first_event');
    final secondResponse = await Pam.track('second_event');
    await Future<void>.delayed(Duration.zero);

    expect(firstResponse?.error?.code, 'IDENTITY_STATE_MISMATCH');
    expect(secondResponse?.error?.code, 'IDENTITY_STATE_MISMATCH');
    expect(tracker.requests, isEmpty);
    expect(mismatchCount, 1);
    expect(reportedMismatch?.type, PamIdentityMismatchType.loginRequired);
    expect(reportedMismatch?.oldIdentity, isNull);
    expect(reportedMismatch?.newIdentity?.value, 'customer-a');
    expect(reportedMismatch?.event, 'first_event');
  });

  test('different identity value is treated as an account switch', () async {
    await Pam.userLogin('customer-a');
    tracker.requests.clear();
    PamIdentityMismatch? reportedMismatch;
    pam.config!.identityProvider = () => PamUserState.identified('customer-b');
    pam.config!.onIdentityMismatch = (mismatch) {
      reportedMismatch = mismatch;
    };

    final response = await Pam.track('open_home');
    await Future<void>.delayed(Duration.zero);

    expect(response?.error?.code, 'IDENTITY_STATE_MISMATCH');
    expect(tracker.requests, isEmpty);
    expect(
      reportedMismatch?.type,
      PamIdentityMismatchType.accountSwitchRequired,
    );
  });

  test('central mismatch handler can resolve identity for the next event',
      () async {
    final resolved = Completer<void>();
    pam.config!.identityProvider = () => PamUserState.identified('0818888888');
    pam.config!.onIdentityMismatch = (mismatch) async {
      await Pam.userLogin(mismatch.newIdentity!.value);
      resolved.complete();
    };

    final mismatchedResponse = await Pam.track('before_login');
    await resolved.future;
    tracker.requests.clear();
    final nextResponse = await Pam.track('after_login');

    expect(mismatchedResponse?.error?.code, 'IDENTITY_STATE_MISMATCH');
    expect(nextResponse?.error, isNull);
    expect(tracker.requests.map((body) => body['event']), ['after_login']);
  });

  test('identity provider errors drop the event without throwing', () async {
    pam.config!.identityProvider = () => throw StateError('Auth not ready');

    final response = await Pam.track('open_home');

    expect(response?.error?.code, 'IDENTITY_PROVIDER_ERROR');
    expect(tracker.requests, isEmpty);
  });

  test('setAllowTracking false updates the in-memory state', () async {
    pam.allowTracking = true;

    await pam.setAllowTracking(false);

    expect(pam.allowTracking, isFalse);
  });

  test('storage cleanup errors do not prevent logout media deletion', () async {
    await Pam.userLogin('customer-a');
    tracker.requests.clear();
    pam.pref = _ThrowingRemovePreference();

    await Pam.userLogout();

    expect(tracker.requests.map((body) => body['event']), [
      'delete_media',
      'logout',
    ]);
  });

  test('platform token callback does not register the token automatically',
      () async {
    String? receivedToken;
    Pam.onToken((token) {
      receivedToken = token;
    });

    await Pam.methodsHandler(
      const MethodCall('onToken', 'developer-token'),
    );

    expect(receivedToken, 'developer-token');
    expect(pam.pushToken, isNull);
    expect(tracker.requests, isEmpty);
  });

  test('push helpers accept a PAM data map without Firebase types', () {
    final data = <String, dynamic>{
      'pam': jsonEncode({
        'flex': '<img src="https://example.invalid/banner.png">',
        'pixel': 'https://example.invalid/read',
        'popup_type': 'banner',
        'url': 'https://example.invalid/content',
        'click_tracking_url': 'https://example.invalid/click',
        'redirect_id': 'redirect-id',
      }),
    };

    expect(Pam.isPushNotiFromPam(data), isTrue);

    final message = Pam.convertToPamPushMessage(data);

    expect(message, isNotNull);
    expect(message?.title, isEmpty);
    expect(message?.description, isEmpty);
    expect(message?.thumbnailUrl, 'https://example.invalid/banner.png');
    expect(message?.data['redirect_id'], 'redirect-id');
  });
}
