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
    final customer = fields['customer'] as String?;
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
}
