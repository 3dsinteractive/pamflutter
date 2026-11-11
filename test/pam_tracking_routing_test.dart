import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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
    if (body['event'] == 'allow_consent') {
      response
        ..consentID = 'consent-record-id'
        ..consentMessageID = fields['_consent_message_id'] as String?;
    }
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

class _ContactNotFoundTrackerAPI extends TrackerAPI {
  final List<Map<String, dynamic>> requests = [];

  _ContactNotFoundTrackerAPI() : super('https://example.invalid');

  @override
  Future<PamResponse?> postTracker(Map<String, dynamic> body) async {
    requests.add(body);
    if (requests.length == 1) {
      return PamResponse.createErrorResponse(
        code: 'CONTACT_NOT_FOUND',
        errorMessage: 'Contact not found',
      );
    }

    final fields = body['form_fields'] as Map<String, dynamic>;
    return PamResponse()
      ..database = fields['_database'] as String
      ..contactID = 'recovered-contact';
  }
}

class _ThrowingRemovePreference extends UserPreference {
  @override
  Future<void> remove(SaveKey key) {
    throw StateError('Secure storage is unavailable.');
  }
}

class _DelayedContactPreference extends UserPreference {
  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<String?> getString(SaveKey key) async {
    if (key == SaveKey.contactID) {
      if (!readStarted.isCompleted) readStarted.complete();
      await releaseRead.future;
    }
    return super.getString(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pam_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Pam pam;
  late _RecordingTrackerAPI tracker;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getTrackingAppInfo');
      return {
        'osVersion': 'Android: 15 (SDK 35)',
        'appName': 'PAM Test',
        'appVersion': '1.0.0',
        'buildNumber': '1',
      };
    });

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

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'reset forgets user state and keeps configuration ready for the next event',
    () async {
      final config = pam.config!;
      pam.isEnableLog = true;
      for (final key in SaveKey.values) {
        if (key == SaveKey.allowTracking) {
          await pam.setAllowTracking(true);
        } else {
          await pam.pref.saveString('old-value', key);
        }
      }
      pam
        ..loginContact = 'old-login-contact'
        ..custID = 'old-customer'
        ..pushToken = 'old-token';
      Pam.contactID = 'old-contact';
      Pam.customerID = 'old-customer';
      Pam.databaseAlias = 'login-db';
      final oldSession = pam.getSessionID();
      String? callbackToken;
      Pam.onToken((token) => callbackToken = token);

      await Pam.reset();

      expect(pam.config, same(config));
      expect(pam.trackerAPI, same(tracker));
      expect(pam.isEnableLog, isTrue);
      expect(Pam.contactID, isEmpty);
      expect(Pam.customerID, isEmpty);
      expect(Pam.databaseAlias, isEmpty);
      expect(pam.publicContact, isNull);
      expect(pam.loginContact, isNull);
      expect(pam.deviceUDID, isNull);
      expect(await pam.isUserLogin(), isFalse);
      expect(await pam.getPushToken(), isNull);
      expect(pam.allowTracking, isFalse);
      expect(pam.sessionID, isEmpty);
      expect(pam.getSessionID(), isNot(oldSession));
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await Pam.methodsHandler(const MethodCall('onToken', 'new-token'));
      expect(callbackToken, 'new-token');
      expect(tracker.requests, isEmpty);

      expect(await pam.getDatabaseAlias(), 'public-db');
      expect(await pam.getContactID(), isNull);
      expect(pam.allowTracking, isFalse);
      pam.deviceUDID = 'device-id';
      await Pam.track('first-event');
      expect(fieldsAt(0).containsKey('_contact_id'), isFalse);
      expect(fieldsAt(0).containsKey('customer'), isFalse);
      expect(fieldsAt(0)['_database'], 'public-db');

      await Pam.reset();
      await Pam.reset();
      expect(await pam.getContactID(), isNull);
    },
  );

  test(
    'reset waits for queued tracking and clears its saved contact',
    () async {
      final gate = Completer<void>();
      final pending = pam.queue.add(() => gate.future);
      final tracking = Pam.track('pending-event');
      var resetFinished = false;
      final reset = Pam.reset().then((_) => resetFinished = true);
      await Future<void>.delayed(Duration.zero);
      expect(resetFinished, isFalse);
      gate.complete();
      await pending;
      await tracking;
      await reset;

      expect(tracker.requests, hasLength(1));
      expect(await pam.getContactID(), isNull);
      expect(await pam.pref.getString(SaveKey.contactID), isNull);
    },
  );

  test('reset clears memory and reports storage failures', () async {
    final config = pam.config;
    pam.pref = _ThrowingRemovePreference();
    pam.custID = 'old-customer';
    await expectLater(Pam.reset(), throwsStateError);
    expect(pam.custID, isNull);
    expect(pam.publicContact, isNull);
    expect(pam.config, same(config));
  });

  test('reset waits for background consent sync without blocking initialize',
      () async {
    final preference = _DelayedContactPreference();
    final config = pam.config;
    pam.pref = preference;
    pam.publicContact = null;
    await Pam.initialize(pam.config!);
    await preference.readStarted.future;

    var resetFinished = false;
    final reset = Pam.reset().then((_) => resetFinished = true);
    await Future<void>.delayed(Duration.zero);
    expect(resetFinished, isFalse);
    preference.releaseRead.complete();
    await reset;

    expect(pam.config, same(config));
    expect(pam.allowTracking, isFalse);
    expect(await pam.pref.getBool(SaveKey.allowTracking), isNull);
  });

  test('reset after queued consent leaves tracking disabled', () async {
    final consent = Pam.allowAllTrackingConsent('consent-message');
    final reset = Pam.reset();
    await consent;
    await reset;
    expect(pam.allowTracking, isFalse);
    expect(await pam.pref.getBool(SaveKey.allowTracking), isNull);
  });

  test('session ID is a UUID v4 and is reused within the session', () {
    final sessionId = pam.getSessionID();

    expect(
      sessionId,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ),
    );
    expect(pam.getSessionID(), sessionId);
  });

  void expectAllowAllConsentFields(
    Map<String, dynamic> fields,
    String consentMessageId,
  ) {
    expect(
      fields,
      containsPair('_consent_message_id', consentMessageId),
    );
    expect(fields, containsPair('_version', 'latest'));

    const allowFields = [
      '_allow_terms_and_conditions',
      '_allow_privacy_overview',
      '_allow_necessary_cookies',
      '_allow_preferences_cookies',
      '_allow_analytics_cookies',
      '_allow_marketing_cookies',
      '_allow_social_media_cookies',
      '_allow_email',
      '_allow_sms',
      '_allow_line',
      '_allow_facebook_messenger',
      '_allow_push_notification',
    ];
    for (final field in allowFields) {
      expect(fields, containsPair(field, true));
    }
  }

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

  test(
    'public-only tracks login once and stays in public DB after logout',
    () async {
      pam.config!.loginDBAlias = '';
      await Pam.track('before');
      await Pam.userLogin('customer-a');
      await Pam.track('during');
      await Pam.userLogout();
      await Pam.track('after');

      expect(tracker.requests.map((body) => body['event']), [
        'before',
        'login',
        'during',
        'logout',
        'after',
      ]);
      for (var i = 0; i < tracker.requests.length; i++) {
        expect(fieldsAt(i)['_database'], 'public-db');
      }
      expect(fieldsAt(1)['customer'], 'customer-a');
      expect(fieldsAt(2)['customer'], 'customer-a');
      expect(fieldsAt(4).containsKey('customer'), isFalse);
      expect(await pam.isUserLogin(), isFalse);
    },
  );

  test(
    'login-only skips anonymous events and resumes after each login',
    () async {
      pam.config!.publicDBAlias = '';
      final skipped = await Pam.track('before');
      expect(skipped?.error?.code, 'TRACKING_DISABLED');
      expect(tracker.requests, isEmpty);
      await Pam.userLogin('customer-a');
      await Pam.track('during');
      await Pam.userLogout();
      final countAfterLogout = tracker.requests.length;
      await Pam.track('after');
      expect(tracker.requests.length, countAfterLogout);
      await Pam.userLogin('customer-b');
      await Pam.track('again');

      expect(tracker.requests.map((body) => body['event']), [
        'login',
        'during',
        'delete_media',
        'logout',
        'login',
        'again',
      ]);
      for (var i = 0; i < tracker.requests.length; i++) {
        expect(fieldsAt(i)['_database'], 'login-db');
      }
      expect(fieldsAt(5)['customer'], 'customer-b');
    },
  );

  test(
    'empty aliases never submit requests even across login and logout',
    () async {
      pam.config!.publicDBAlias = '';
      pam.config!.loginDBAlias = '';
      await Pam.track('before');
      await Pam.userLogin('customer-a');
      await Pam.track('during');
      await Pam.userLogout();
      await Pam.track('after');
      expect(tracker.requests, isEmpty);
      expect(await pam.isUserLogin(), isFalse);
    },
  );

  test(
    'login deletes media from the previous destination before switching',
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
      expect(fieldsAt(0), containsPair('os_version', 'Android: 15 (SDK 35)'));
      expect(fieldsAt(0), containsPair('app_version', '1.0.0'));
      expect(
        tracker.requests[0]['platform'],
        'Android: 15 (SDK 35),  PAM Test: 1.0.0(1)',
      );
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
    },
  );

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
    useIdentityMatcher(PamIdentityMatcher.primary(PamPrimaryIdentityKey.sms));

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

  test(
    'logout targets the logged-in contact before routing back to public',
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
    },
  );

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

  test(
    'login is enqueued before a track call even when neither is awaited',
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
    },
  );

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

  test('new response contract parses error_code and _database', () {
    final response = PamResponse.parse(jsonEncode({
      'contact_id': '',
      '_database': '',
      'consent_id': 'consent-record-id',
      'consent_message_id': 'consent-message-id',
      'error': 'Contact not found',
      'error_code': 'CONTACT_NOT_FOUND',
    }));

    expect(response?.error?.code, 'CONTACT_NOT_FOUND');
    expect(response?.error?.errorMessage, 'Contact not found');
    expect(response?.database, '');
    expect(response?.contactID, '');
    expect(response?.consentID, 'consent-record-id');
    expect(response?.consentMessageID, 'consent-message-id');
  });

  test(
    'contact-not-found response pauses normal tracking temporarily',
    () async {
      final contactNotFoundTracker = _ContactNotFoundTrackerAPI();
      pam.trackerAPI = contactNotFoundTracker;

      final firstResponse = await Pam.track('open_home');
      final secondResponse = await Pam.track('purchase');

      expect(firstResponse?.error?.code, 'CONTACT_NOT_FOUND');
      expect(secondResponse?.error?.code, 'TRACKING_PAUSED');
      expect(contactNotFoundTracker.requests.map((body) => body['event']), [
        'open_home',
      ]);
    },
  );

  test('whitelisted events can pass while normal tracking is paused', () async {
    final contactNotFoundTracker = _ContactNotFoundTrackerAPI();
    pam.trackerAPI = contactNotFoundTracker;

    await Pam.track('open_home');
    final testResponse = await Pam.track('test');
    final normalResponse = await Pam.track('purchase');

    expect(testResponse?.error, isNull);
    expect(normalResponse?.error?.code, 'TRACKING_PAUSED');
    expect(contactNotFoundTracker.requests.map((body) => body['event']), [
      'open_home',
      'test',
    ]);
  });

  test('successful consent event unpauses normal tracking', () async {
    final contactNotFoundTracker = _ContactNotFoundTrackerAPI();
    pam.trackerAPI = contactNotFoundTracker;

    await Pam.track('open_home');
    final consentResponse = await Pam.track('allow_consent');
    final normalResponse = await Pam.track('purchase');

    expect(consentResponse?.error, isNull);
    expect(normalResponse?.error, isNull);
    expect(contactNotFoundTracker.requests.map((body) => body['event']), [
      'open_home',
      'allow_consent',
      'purchase',
    ]);
  });

  test(
    'allowAllTrackingConsent submits latest version and allows tracking',
    () async {
      pam.config = PamConfig(
        pam.config!.pamServer,
        pam.config!.publicDBAlias,
        pam.config!.loginDBAlias,
        'tracking-consent-message',
        pam.config!.enableLog,
        identityMatcher: pam.config!.identityMatcher,
        blockEventsIfNoConsent: true,
        identityProvider: pam.config!.identityProvider,
        onIdentityMismatch: pam.config!.onIdentityMismatch,
      );

      final result = await Pam.allowAllTrackingConsent(
        'tracking-consent-message',
      );
      final normalResponse = await Pam.track('purchase');

      expect(result, isNotNull);
      expect(result?.result.keys, ['tracking-consent-message']);
      expect(
        result?.result['tracking-consent-message']?.consentMessageID,
        'tracking-consent-message',
      );
      expect(
        result?.result['tracking-consent-message']?.consentID,
        'consent-record-id',
      );
      expect(pam.allowTracking, isTrue);
      expect(normalResponse?.error, isNull);
      expect(tracker.requests.map((body) => body['event']), [
        'allow_consent',
        'purchase',
      ]);

      final consentFields = fieldsAt(0);
      expect(consentFields, containsPair('_database', 'public-db'));
      expectAllowAllConsentFields(consentFields, 'tracking-consent-message');
    },
  );

  test('allowAllContactingConsent does not allow tracking', () async {
    pam.config = PamConfig(
      pam.config!.pamServer,
      pam.config!.publicDBAlias,
      pam.config!.loginDBAlias,
      'tracking-consent-message',
      pam.config!.enableLog,
      identityMatcher: pam.config!.identityMatcher,
      blockEventsIfNoConsent: true,
      identityProvider: pam.config!.identityProvider,
      onIdentityMismatch: pam.config!.onIdentityMismatch,
    );

    final result =
        await Pam.allowAllContactingConsent('contacting-consent-message');
    final normalResponse = await Pam.track('purchase');

    expect(result, isNotNull);
    expect(result?.result.keys, ['contacting-consent-message']);
    expect(
      result?.result['contacting-consent-message']?.consentMessageID,
      'contacting-consent-message',
    );
    expect(
      result?.result['contacting-consent-message']?.consentID,
      'consent-record-id',
    );
    expect(pam.allowTracking, isFalse);
    expect(normalResponse, isNull);
    expect(tracker.requests.map((body) => body['event']), ['allow_consent']);

    final consentFields = fieldsAt(0);
    expect(consentFields, containsPair('_database', 'public-db'));
    expectAllowAllConsentFields(consentFields, 'contacting-consent-message');
  });

  test('allowAllTrackingConsent does not allow tracking after server error',
      () async {
    final contactNotFoundTracker = _ContactNotFoundTrackerAPI();
    pam.trackerAPI = contactNotFoundTracker;
    pam.config = PamConfig(
      pam.config!.pamServer,
      pam.config!.publicDBAlias,
      pam.config!.loginDBAlias,
      'tracking-consent-message',
      pam.config!.enableLog,
      identityMatcher: pam.config!.identityMatcher,
      blockEventsIfNoConsent: true,
      identityProvider: pam.config!.identityProvider,
      onIdentityMismatch: pam.config!.onIdentityMismatch,
    );

    final result =
        await Pam.allowAllTrackingConsent('tracking-consent-message');

    expect(result, isNull);
    expect(pam.allowTracking, isFalse);
    expect(
      contactNotFoundTracker.requests.map((body) => body['event']),
      ['allow_consent'],
    );
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

  test(
    'initialize does not automatically send a persisted push token',
    () async {
      pam.publicContact = null;
      await pam.pref.saveString('persisted-token', SaveKey.pushKey);

      await pam.init(pam.config!, false);
      await Future<void>.delayed(Duration.zero);

      expect(pam.pushToken, isNull);
      expect(await pam.pref.getString(SaveKey.pushKey), 'persisted-token');
    },
  );

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

  test(
    'central mismatch handler can resolve identity for the next event',
    () async {
      final resolved = Completer<void>();
      pam.config!.identityProvider =
          () => PamUserState.identified('0818888888');
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
    },
  );

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

  test(
    'platform token callback does not register the token automatically',
    () async {
      String? receivedToken;
      Pam.onToken((token) {
        receivedToken = token;
      });

      await Pam.methodsHandler(const MethodCall('onToken', 'developer-token'));

      expect(receivedToken, 'developer-token');
      expect(pam.pushToken, isNull);
      expect(tracker.requests, isEmpty);
    },
  );

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
