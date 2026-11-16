import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pam_flutter/api/tracker_api.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/pam_response.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BatchAPI extends TrackerAPI {
  final requests = <Map<String, dynamic>>[];
  final started = Completer<void>();
  Completer<PamBatchResponse>? pending;
  PamBatchResponse response = PamBatchResponse();

  _BatchAPI() : super('https://example.invalid');

  @override
  Future<PamBatchResponse> postTrackerBatch(Map<String, dynamic> body) async {
    requests.add(body);
    if (!started.isCompleted) started.complete();
    return pending == null ? response : pending!.future;
  }
}

PamResponse contact(String id, {String database = 'public-db'}) => PamResponse()
  ..contactID = id
  ..database = database;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pam_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Pam pam;
  late _BatchAPI api;
  const events = [
    PamTrackEvent(event: 'purchase', payload: {'order_id': 'order-1'}),
    PamTrackEvent(event: 'purchase_item', payload: {'sku': 'sku-1'}),
  ];

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'osVersion': 'Android',
        'appName': 'Test',
        'appVersion': '1',
        'buildNumber': '1',
      },
    );
    api = _BatchAPI();
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
      ..deviceUDID = 'device-1'
      ..publicContact = 'contact-1'
      ..trackerAPI = api;
    Pam.shared = pam;
    Pam.contactID = 'contact-1';
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'sends one request with the same stored contact and database on each event',
    () async {
      api.response = PamBatchResponse(results: [contact('contact-1')]);
      var callbacks = 0;
      final result = await Pam.trackBatch(events, callback: (_) => callbacks++);
      expect(result!.error, isNull);
      expect(result.results, hasLength(1));
      expect(callbacks, 1);
      expect(api.requests, hasLength(1));
      final body = api.requests.single;
      expect(body['_use_first_contact_id_for_all_events'], isNull);
      expect(body['form_fields'], {'_database': 'public-db'});
      for (final event in body['events'] as List) {
        expect(event['form_fields']['_contact_id'], 'contact-1');
        expect(event['form_fields']['_database'], 'public-db');
        expect(event['form_fields']['uuid'], 'device-1');
      }
      expect(pam.publicContact, 'contact-1');
    },
  );

  test(
    'missing contact enables first-contact mode and saves a consistent response ID',
    () async {
      pam.publicContact = null;
      api.response = PamBatchResponse(
        results: [contact('new-contact'), contact('new-contact')],
      );
      await Pam.trackBatch(events);
      expect(
        api.requests.single['_use_first_contact_id_for_all_events'],
        isTrue,
      );
      for (final event in api.requests.single['events'] as List) {
        expect(event['form_fields'].containsKey('_contact_id'), isFalse);
      }
      expect(pam.publicContact, 'new-contact');
      expect(Pam.contactID, 'new-contact');
    },
  );

  test(
    'queued batches reuse the contact established by the preceding batch',
    () async {
      pam.publicContact = null;
      api.pending = Completer<PamBatchResponse>();
      final first = Pam.trackBatch(events);
      final second = Pam.trackBatch(events);
      await api.started.future;
      expect(api.requests, hasLength(1));
      api.pending!.complete(
        PamBatchResponse(results: [contact('created-contact')]),
      );
      await Future.wait([first, second]);
      expect(api.requests, hasLength(2));
      expect(
        api.requests.first['_use_first_contact_id_for_all_events'],
        isTrue,
      );
      expect(api.requests.last['_use_first_contact_id_for_all_events'], isNull);
      for (final event in api.requests.last['events'] as List) {
        expect(event['form_fields']['_contact_id'], 'created-contact');
      }
    },
  );

  test(
    'logged-in batch keeps database, contact and configured identity together',
    () async {
      pam.custID = 'customer-1';
      pam.loginContact = 'login-contact';
      api.response = PamBatchResponse(
        results: [contact('login-contact', database: 'login-db')],
      );
      final result = await Pam.trackBatch(events);
      expect(result!.error, isNull);
      for (final event in api.requests.single['events'] as List) {
        expect(event['form_fields']['_contact_id'], 'login-contact');
        expect(event['form_fields']['_database'], 'login-db');
        expect(event['form_fields']['customer'], 'customer-1');
      }
      expect(pam.publicContact, 'contact-1');
      expect(pam.loginContact, 'login-contact');
    },
  );

  test(
    'a partial error pauses subsequent normal events without retrying',
    () async {
      api.response = PamBatchResponse(
        results: [
          contact('contact-1'),
          PamResponse.createErrorResponse(
            code: 'TRACKING_IS_NOT_ALLOWED',
            errorMessage: 'Consent required',
          ),
        ],
      );
      final first = await Pam.trackBatch(events);
      expect(first!.results.last.error!.code, 'TRACKING_IS_NOT_ALLOWED');
      final second = await Pam.trackBatch(events);
      expect(second!.error!.code, 'TRACKING_PAUSED');
      expect(api.requests, hasLength(1));
      expect(pam.publicContact, 'contact-1');
    },
  );

  test('empty response does not invent or replace a contact', () async {
    pam.publicContact = null;
    final result = await Pam.trackBatch(events);
    expect(result!.results, isEmpty);
    expect(pam.publicContact, isNull);
  });

  test(
    'rejects payloads that try to switch contact, database or identity before sending',
    () async {
      for (final payload in [
        {'_contact_id': 'other'},
        {'_database': 'other'},
        {'customer': 'other'},
        {'email': 'other@example.com'},
        {'_key_name': 'other'},
        {'_force_create': true},
      ]) {
        final result = await Pam.trackBatch([
          PamTrackEvent(event: 'purchase', payload: payload),
        ]);
        expect(result!.error!.code, 'BATCH_IDENTITY_CONFLICT');
      }
      expect(api.requests, isEmpty);
      expect(pam.publicContact, 'contact-1');
    },
  );

  test(
    'conflicting IDs or database in server results never overwrite contact',
    () async {
      for (final results in [
        [contact('contact-1'), contact('other')],
        [contact('other')],
        [contact('contact-1', database: 'other-db')],
      ]) {
        api.response = PamBatchResponse(results: results);
        final result = await Pam.trackBatch(events);
        expect(result!.error!.code, 'BATCH_IDENTITY_CONFLICT');
        expect(pam.publicContact, 'contact-1');
        expect(Pam.contactID, 'contact-1');
      }
    },
  );

  test(
    'multiple returned IDs do not seed an initially missing contact',
    () async {
      pam.publicContact = null;
      api.response = PamBatchResponse(results: [contact('a'), contact('b')]);
      final result = await Pam.trackBatch(events);
      expect(result!.error!.code, 'BATCH_IDENTITY_CONFLICT');
      expect(pam.publicContact, isNull);
    },
  );

  test(
    'late response cannot replace a contact changed while request was pending',
    () async {
      pam.publicContact = null;
      api.pending = Completer<PamBatchResponse>();
      final request = Pam.trackBatch(events);
      await api.started.future;
      pam.publicContact = 'newer-contact';
      Pam.contactID = 'newer-contact';
      api.pending!.complete(
        PamBatchResponse(results: [contact('late-contact')]),
      );
      await request;
      expect(pam.publicContact, 'newer-contact');
      expect(Pam.contactID, 'newer-contact');
    },
  );

  test(
    'consent filters individual events and does not send a blocked batch',
    () async {
      pam.config!.blockEventsIfNoConsent = true;
      final result = await Pam.trackBatch(events);
      expect(result, isNull);
      expect(api.requests, isEmpty);
      await Pam.trackBatch([...events, const PamTrackEvent(event: 'test')]);
      expect((api.requests.single['events'] as List).single['event'], 'test');
    },
  );

  test('rejects empty input and empty event names', () async {
    await expectLater(Pam.trackBatch([]), throwsArgumentError);
    await expectLater(
      Pam.trackBatch([const PamTrackEvent(event: ' ')]),
      throwsArgumentError,
    );
    expect(api.requests, isEmpty);
  });

  test('batch parser accepts single, multiple, empty and error responses', () {
    expect(PamBatchResponse.parse('{}').results, isEmpty);
    expect(
      PamBatchResponse.parse('{"contact_id":"a"}').results.single.contactID,
      'a',
    );
    final partial = PamBatchResponse.parse(
      '{"results":[{"contact_id":"a"},{"error_code":"INVALID_EVENT","error":"invalid"}]}',
    );
    expect(partial.results, hasLength(2));
    expect(partial.results.last.error!.code, 'INVALID_EVENT');
    expect(
      PamBatchResponse.parse('{"error_code":"UNAUTHORIZED"}').error!.code,
      'UNAUTHORIZED',
    );
    expect(PamBatchResponse.parse('not json').error!.code, 'INVALID_RESPONSE');
    expect(
      PamBatchResponse.parse('{"results":null}').error!.code,
      'INVALID_RESPONSE',
    );
  });
}
