import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pam_flutter/api/crm_api.dart';
import 'package:pam_flutter/api/tracker_api.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/preferences.dart';
import 'package:pam_flutter/response/pam_response.dart';
import 'package:pam_flutter/src/pam_log_writer.dart';

class _Unprintable {
  @override
  String toString() => throw StateError('Cannot print');
}

class _EmptyPreference extends UserPreference {
  @override
  Future<String?> getString(SaveKey key) async => null;
}

class _ErrorTracker extends TrackerAPI {
  _ErrorTracker() : super('https://example.invalid');

  @override
  Future<PamResponse?> postTracker(Map<String, dynamic> body) async =>
      PamResponse.createErrorResponse(
        code: 'DENIED',
        errorMessage: 'Event rejected',
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pam_flutter/logging');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Pam previousPam;
  late DebugPrintCallback previousPrint;
  late List<MethodCall> calls;
  late List<String?> printed;

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  List<Map<dynamic, dynamic>> entries() => calls
      .where((call) => call.method == 'log')
      .map((call) => call.arguments as Map<dynamic, dynamic>)
      .toList();

  setUp(() {
    previousPam = Pam.shared;
    Pam.shared = Pam()..isEnableLog = true;
    previousPrint = debugPrint;
    printed = [];
    calls = [];
    debugPrint = (String? message, {int? wrapWidth}) {
      printed.add(message);
    };
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() async {
    await flush();
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    debugPrint = previousPrint;
    Pam.shared = previousPam;
  });

  test(
    'legacy call defaults to General / INFO and does not duplicate output',
    () async {
      Pam.log(['Ready', 42, null]);
      await flush();
      expect(entries().single, {
        'category': 'General',
        'level': 'info',
        'lines': ['Ready', '42', '<null>'],
      });
      expect(printed, isEmpty);
    },
  );

  test(
    'all enum categories and severities are sent on Android and iOS',
    () async {
      for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = target;
        for (final category in PamLogCategory.values) {
          for (final level in PamLogLevel.values) {
            Pam.log(['Entry'], category: category, level: level);
            await flush();
            expect(entries().last['category'], category.label);
            expect(entries().last['level'], level.name);
          }
        }
      }
      expect(printed, isEmpty);
    },
  );

  test(
    'enableLog=false suppresses every level and configuration supports disable',
    () async {
      Pam.shared.isEnableLog = false;
      for (final level in PamLogLevel.values) {
        Pam.log([_Unprintable()], level: level);
      }
      await flush();
      expect(calls, isEmpty);
      expect(printed, isEmpty);
      await PamLogWriter.configureNative(true);
      await PamLogWriter.configureNative(false);
      expect(calls.map((call) => call.arguments), [
        {'enabled': true},
        {'enabled': false},
      ]);
    },
  );

  test(
    'splits multiline Unicode payloads without losing data or metadata',
    () async {
      final text = List.filled(2000, 'ก🦄').join();
      Pam.log(
        ['first\r\nsecond\rthird\n$text'],
        category: PamLogCategory.storage,
        level: PamLogLevel.error,
      );
      await flush();
      final entry = entries().single;
      final lines = (entry['lines'] as List).cast<String>();
      expect(lines.take(3), ['first', 'second', 'third']);
      expect(lines.skip(3).join(), text);
      expect(lines.every((line) => utf8.encode(line).length <= 800), isTrue);
      expect(entry['category'], 'Storage');
      expect(entry['level'], 'error');
    },
  );

  for (final error in [
    MissingPluginException(),
    PlatformException(code: 'LOG_FAILED'),
  ]) {
    test(
      'native failure $error falls back once with a prefix on every line',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw error;
        });
        Pam.log(
          ['First\nSecond'],
          category: PamLogCategory.consent,
          level: PamLogLevel.warning,
        );
        await flush();
        expect(calls, hasLength(1));
        expect(printed, [
          '[PAM][Consent][WARN] First',
          '[PAM][Consent][WARN] Second',
        ]);
      },
    );
  }

  test(
    'desktop fallback and unprintable values do not fail the application',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      Pam.log([_Unprintable()]);
      await flush();
      expect(calls, isEmpty);
      expect(printed, ['[PAM][General][INFO] <unprintable>']);
    },
  );

  test(
    'API requests have matching IDs, status, duration, and DEBUG bodies',
    () async {
      await http.runWithClient(
        () async {
          await TrackerAPI(
            'https://example.invalid',
          ).postTracker({'event': 'page_view', 'detail': List.filled(1000, 'ก🦄').join()});
        },
        () => MockClient(
          (_) async => http.Response('{"contact_id":"contact"}', 200),
        ),
      );
      await flush();
      final logs = entries();
      expect(logs.every((entry) => entry['category'] == 'Tracking'), isTrue);
      final messages = logs
          .map((entry) => (entry['lines'] as List).join('\n'))
          .toList();
      final requestID = RegExp(
        r'request_id=(r\d+)',
      ).firstMatch(messages.first)!.group(1)!;
      expect(
        messages.every((message) => message.contains('request_id=$requestID')),
        isTrue,
      );
      expect(
        logs.expand((entry) => entry['lines'] as List).every(
            (line) => line.toString().contains('request_id=$requestID')),
        isTrue,
      );
      final summary = logs.singleWhere((entry) => entry['level'] == 'info');
      expect(summary['lines'].toString(), contains('status=200 duration_ms='));
      expect(
        logs
            .where(
              (entry) => entry['lines'].toString().contains('response_body'),
            )
            .single['level'],
        'debug',
      );
    },
  );

  test(
    'HTTP failures are ERROR even if a response body can be parsed',
    () async {
      await http.runWithClient(
        () async {
          await TrackerAPI(
            'https://example.invalid',
          ).postTracker({'event': 'login'});
        },
        () => MockClient(
          (_) async => http.Response('{"error_code":"DENIED"}', 403),
        ),
      );
      await flush();
      expect(
        entries()
            .singleWhere((entry) => entry['level'] == 'error')['lines']
            .toString(),
        contains('status=403'),
      );
    },
  );

  test(
    'request exceptions include operation, request ID, and duration at ERROR',
    () async {
      await http.runWithClient(() async {
        await TrackerAPI(
          'https://example.invalid',
        ).postTracker({'event': 'page_view'});
      }, () => MockClient((_) async => throw http.ClientException('Offline')));
      await flush();
      final error = entries().singleWhere((entry) => entry['level'] == 'error');
      final message = error['lines'].toString();
      expect(message, contains('POST /trackers/events request_id='));
      expect(message, contains('failed duration_ms='));
      expect(message, contains('Offline'));
    },
  );

  test(
    'attention with no contact explains why it skipped the request',
    () async {
      Pam.shared.pref = _EmptyPreference();
      Pam.shared.config = PamConfig(
        'https://example.invalid',
        '',
        '',
        '',
        true,
        identityMatcher: PamIdentityMatcher.primary(
          PamPrimaryIdentityKey.customer,
        ),
      );
      // No configured destination has a contact; the request must not be sent.
      await CRMAPI('https://example.invalid').getAppAttention('home');
      await flush();
      final logs = entries();
      expect(logs.every((entry) => entry['category'] == 'Attention'), isTrue);
      expect(
        logs.any(
          (entry) => entry['lines'].toString().contains('reason=no_contact'),
        ),
        isTrue,
      );
      expect(logs.any((entry) => entry['level'] == 'error'), isFalse);
    },
  );

  test(
    'server error codes include event and destination in an ERROR summary',
    () async {
      const platformChannel = MethodChannel('pam_flutter');
      messenger.setMockMethodCallHandler(
        platformChannel,
        (_) async => <String, String>{},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(platformChannel, null),
      );
      Pam.shared
        ..pref = _EmptyPreference()
        ..trackerAPI = _ErrorTracker()
        ..publicContact = 'contact'
        ..config = PamConfig(
          'https://example.invalid',
          'public-db',
          '',
          '',
          true,
          identityMatcher: PamIdentityMatcher.primary(
            PamPrimaryIdentityKey.customer,
          ),
        );
      await Pam.shared.postTracker('page_view', null);
      await flush();
      final error = entries().singleWhere((entry) => entry['level'] == 'error');
      expect(error['category'], 'Tracking');
      expect(
        error['lines'].toString(),
        contains('event=page_view database=public-db session=public'),
      );
      expect(
        error['lines'].toString(),
        contains('error_code=DENIED error_message=Event rejected'),
      );
    },
  );
}
