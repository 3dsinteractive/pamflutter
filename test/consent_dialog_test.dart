import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/api/tracker_api.dart';
import 'package:pam_flutter/preferences.dart';

class _MemoryPreference extends UserPreference {
  final values = <SaveKey, Object>{};
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
}

Map<String, dynamic> message({bool contacting = false, int version = 3}) {
  Map<String, dynamic> permission(String name) => {
    'is_enabled': true,
    'brief_description': {'en': 'About $name', 'th': 'รายละเอียด $name'},
    'is_full_description_enabled': true,
    'full_description': {
      'en':
          '<h1>Full $name</h1><p>Read these <strong>important</strong> details.</p>',
      'th': '<h1>รายละเอียดฉบับเต็ม</h1><p>โปรดอ่านรายละเอียด</p>',
    },
  };
  return {
    'data': {
      'consent_message_id': 'message',
      'consent_message_type': contacting ? 'contacting_type' : 'tracking_type',
      'style_configuration': {
        'bar_background_color': '#FFFFFF',
        'consent_detail': {
          'popup_main_icon': contacting ? 'gdpr' : 'pdpa',
          'primary_color': '#14203D',
          'secondary_color': '#336699',
          'button_text_color': '#E5C09F',
          'text_color': '#000000',
        },
      },
      'setting': {
        'version': version,
        'available_languages': ['en', 'th'],
        'default_language': 'th',
        'display_text': {
          'en': 'Choose how we use your data.',
          'th': 'เลือกการใช้ข้อมูลของคุณ',
        },
        'consent_detail_title': {
          'en': 'Privacy settings',
          'th': 'การตั้งค่าความเป็นส่วนตัว',
        },
        'accept_button_text': {'en': 'Save choices', 'th': 'บันทึกตัวเลือก'},
        // Required rows intentionally omitted: the UI must still show the lock.
        if (contacting) ...{
          'email': permission('Email'),
          'sms': permission('SMS'),
          'line': permission('LINE'),
          'push_notification': permission('Push'),
        } else ...{
          'preferences_cookies': permission('Preferences'),
          'analytics_cookies': permission('Analytics'),
          'marketing_cookies': {'is_enabled': false},
        },
      },
    },
  };
}

Map<String, dynamic> status({bool contacting = false, bool review = false}) => {
  'consent_id': 'old-consent',
  'consent_message_id': 'message',
  'contact_id': 'contact',
  'consent_message_type': contacting ? 'contacting_type' : 'tracking_type',
  'version': review ? 2 : 3,
  'need_consent_review': review,
  if (contacting)
    'contacting_permission': {
      'terms_and_conditions': true,
      'privacy_overview': true,
      'email': true,
      'sms': false,
      'line': true,
      'push_notification': true,
    }
  else
    'tracking_permission': {
      'terms_and_conditions': false,
      'privacy_overview': true,
      'necessary_cookies': false,
      'preferences_cookies': true,
      'analytics_cookies': false,
    },
};

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pam_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Pam original;
  late Pam pam;
  late BuildContext context;
  late Future<PamConsentResult> result;
  late MockClient client;
  late List<http.Request> requests;
  late List<Map<String, dynamic>> submissions;
  late Map<String, dynamic> detail;
  late Map<String, dynamic> stored;
  late String messageId;
  late int statusCode;
  late int detailCode;
  late int failSaves;
  String? nextSaveError;
  Completer<http.Response>? pendingSave;

  setUp(() {
    original = Pam.shared;
    pam = Pam()
      ..pref = _MemoryPreference()
      ..deviceUDID = 'device'
      ..publicContact = 'contact'
      ..config = PamConfig(
        'https://example.invalid',
        'public-db',
        'login-db',
        'message',
        false,
        identityMatcher: PamIdentityMatcher.primary(
          PamPrimaryIdentityKey.customer,
        ),
      );
    Pam.shared = pam;
    // Use the real TrackerAPI so the tests cover form fields and HTTP errors.
    requests = [];
    submissions = [];
    detail = message();
    stored = status();
    messageId = 'message';
    statusCode = 200;
    detailCode = 200;
    failSaves = 0;
    nextSaveError = null;
    pendingSave = null;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => <String, String>{},
    );
    client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        submissions.add(body['form_fields'] as Map<String, dynamic>);
        if (pendingSave != null) return pendingSave!.future;
        if (nextSaveError != null) {
          final code = nextSaveError;
          nextSaveError = null;
          return http.Response(jsonEncode({'code': code}), 400);
        }
        if (failSaves-- > 0) {
          return http.Response(
            jsonEncode({'code': 'TEMPORARY_ERROR', 'message': 'Try again'}),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'consent_id': 'saved-consent',
            'consent_message_id': 'message',
            'contact_id': 'contact',
            '_database': 'public-db',
          }),
          200,
        );
      }
      if (request.url.path.startsWith('/contacts/')) {
        return http.Response(jsonEncode(stored), statusCode);
      }
      return http.Response(
        jsonEncode(detail),
        detailCode,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    pam.trackerAPI = TrackerAPI('https://example.invalid');
  });

  tearDown(() {
    Pam.shared = original;
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> open(
    WidgetTester tester, {
    Locale? locale,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: Text('App'));
          },
        ),
      ),
    );
    result = Pam.showConsent(context, messageId: messageId, locale: locale);
    await tester.pumpAndSettle();
  }

  Finder control(String key) => find.byKey(ValueKey('pam-consent-$key'));
  Switch toggle(WidgetTester tester, String key) =>
      tester.widget<Switch>(control(key));

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tap(control('close'));
    await tester.pumpAndSettle();
    expect((await result).outcome, PamConsentOutcome.dismissed);
  }

  Iterable<String> htmlShown(WidgetTester tester) => tester
      .widgetList<HtmlWidget>(find.byType(HtmlWidget))
      .map((widget) => widget.html);

  for (final contacting in [false, true]) {
    testWidgets(
      'renders actual ${contacting ? "contacting" : "tracking"} response and replaces brief with full text',
      (tester) async {
        detail =
            jsonDecode(
                  File(
                    'test/fixtures/consent_${contacting ? "contacting" : "tracking"}.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        messageId = detail['consent_message_id'] as String;
        pam.publicContact = null;
        await http.runWithClient(() async {
          await open(tester, locale: const Locale('en'));
          expect(control('language'), findsNothing);
          expect(
            control(contacting ? 'email' : 'necessary_cookies'),
            findsOneWidget,
          );
          expect(
            control(contacting ? 'necessary_cookies' : 'email'),
            findsNothing,
          );
          final permission =
              detail['setting']['terms_and_conditions'] as Map<String, dynamic>;
          final brief = permission['brief_description']['th'] as String;
          final full = permission['full_description']['th'] as String;
          expect(htmlShown(tester), contains(brief));
          expect(htmlShown(tester), isNot(contains(full)));
          await scrollTo(tester, control('detail-terms_and_conditions'));
          await tester.tap(control('detail-terms_and_conditions'));
          await tester.pumpAndSettle();
          expect(htmlShown(tester), [full]);
          expect(control('save'), findsNothing);
          await tester.tap(control('detail-back'));
          await tester.pumpAndSettle();
          expect(htmlShown(tester), contains(brief));
          expect(tester.takeException(), isNull);
          await close(tester);
        }, () => client);
      },
    );
  }

  testWidgets(
    'Japanese locale uses jp keys and changing language retains choices',
    (tester) async {
      final settings = detail['data']['setting'] as Map<String, dynamic>;
      settings['available_languages'] = ['th', 'en', 'jp'];
      settings['default_language'] = 'jp';
      settings['display_text'] = {'jp': '日本語の説明'};
      settings['consent_detail_title'] = {
        'jp': '同意の設定',
        'en': 'Consent settings',
      };
      settings['accept_button_text'] = {'jp': '選択内容を保存'};
      settings['analytics_cookies']['brief_description'] = {
        'th': 'คำอธิบายย่อ',
        'en': 'Short summary',
        'jp': '短い説明',
      };
      settings['analytics_cookies']['full_description'] = {
        'th': '<p>ฉบับเต็ม</p>',
        'en': '<p>Full text</p>',
        'jp': '<p>全文の説明</p>',
      };
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('ja'));
        expect(find.text('同意の設定'), findsOneWidget);
        expect(
          tester.widget<DropdownButton<String>>(control('language')).value,
          'jp',
        );
        expect(htmlShown(tester), contains('日本語の説明'));
        expect(htmlShown(tester), contains('短い説明'));
        expect(htmlShown(tester), isNot(contains('<p>全文の説明</p>')));
        expect(toggle(tester, 'terms_and_conditions').onChanged, isNull);
        await scrollTo(tester, control('analytics_cookies'));
        await tester.tap(control('analytics_cookies'));
        await scrollTo(tester, control('detail-analytics_cookies'));
        await tester.tap(control('detail-analytics_cookies'));
        await tester.pumpAndSettle();
        expect(htmlShown(tester), ['<p>全文の説明</p>']);
        await tester.tap(control('language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('English').last);
        await tester.pumpAndSettle();
        expect(htmlShown(tester), ['<p>Full text</p>']);
        await tester.tap(control('detail-back'));
        await tester.pumpAndSettle();
        expect(toggle(tester, 'analytics_cookies').value, isTrue);
        // Missing translations use th/en/jp priority; only jp text exists here.
        expect(htmlShown(tester), contains('日本語の説明'));
        expect(htmlShown(tester), contains('Short summary'));
        expect(requests.where((r) => r.method == 'GET'), hasLength(2));
        await close(tester);
      }, () => client);
    },
  );

  for (final entry in <String, List<String>>{
    'th': ['jp', 'en', 'th'],
    'en': ['jp', 'en'],
    'jp': ['jp'],
  }.entries) {
    testWidgets('omitted locale selects ${entry.key} by th-en-jp priority', (
      tester,
    ) async {
      final settings = detail['data']['setting'] as Map<String, dynamic>;
      settings['available_languages'] = entry.value;
      settings['default_language'] = 'jp';
      settings['consent_detail_title'] = {
        'th': 'ชื่อไทย',
        'en': 'English title',
        'jp': '日本語タイトル',
      };
      // The app locale is English; it must not override the SDK priority.
      await http.runWithClient(() async {
        await open(tester);
        expect(
          find.text(
            {
              'th': 'ชื่อไทย',
              'en': 'English title',
              'jp': '日本語タイトル',
            }[entry.key]!,
          ),
          findsOneWidget,
        );
        await close(tester);
      }, () => client);
    });
  }

  testWidgets(
    'omitted locale falls back from missing Thai text to English before Japanese',
    (tester) async {
      final settings = detail['data']['setting'] as Map<String, dynamic>;
      settings['available_languages'] = ['jp', 'en', 'th'];
      settings['default_language'] = 'jp';
      settings['display_text'] = {'en': 'English fallback', 'jp': '日本語の代替'};
      await http.runWithClient(() async {
        await open(tester);
        expect(htmlShown(tester), contains('English fallback'));
        expect(htmlShown(tester), isNot(contains('日本語の代替')));
        await close(tester);
      }, () => client);
    },
  );

  testWidgets('explicit locale still overrides the th-en-jp priority', (
    tester,
  ) async {
    final settings = detail['data']['setting'] as Map<String, dynamic>;
    settings['available_languages'] = ['th', 'en', 'jp'];
    await http.runWithClient(() async {
      await open(tester, locale: const Locale('en'));
      expect(find.text('Privacy settings'), findsOneWidget);
      await close(tester);
    }, () => client);
  });

  testWidgets('unsupported locale ignores server default and JSON ordering', (
    tester,
  ) async {
    final settings = detail['data']['setting'] as Map<String, dynamic>;
    settings['available_languages'] = ['jp', 'en', 'th'];
    settings['default_language'] = 'jp';
    settings['consent_detail_title']['jp'] = '日本語タイトル';
    await http.runWithClient(() async {
      await open(tester, locale: const Locale('fr'));
      expect(find.text('การตั้งค่าความเป็นส่วนตัว'), findsOneWidget);
      expect(
        tester.widget<DropdownButton<String>>(control('language')).value,
        'th',
      );
      await close(tester);
    }, () => client);
  });

  testWidgets(
    'advertised language without any actual text falls back to Thai',
    (tester) async {
      final settings = detail['data']['setting'] as Map<String, dynamic>;
      settings['available_languages'] = ['jp', 'en', 'th'];
      settings['default_language'] = 'en';
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('ja'));
        expect(find.text('การตั้งค่าความเป็นส่วนตัว'), findsOneWidget);
        final picker = tester.widget<DropdownButton<String>>(
          control('language'),
        );
        expect(picker.value, 'th');
        expect(picker.items!.map((item) => item.value), ['en', 'th']);
        await close(tester);
      }, () => client);
    },
  );

  for (final missing in [null, '', '   ']) {
    testWidgets(
      'selected Japanese with missing text ($missing) uses Thai before English',
      (tester) async {
        final settings = detail['data']['setting'] as Map<String, dynamic>;
        settings['available_languages'] = ['jp', 'en', 'th'];
        settings['default_language'] = 'en';
        settings['consent_detail_title'] = {'jp': '日本語タイトル'};
        settings['display_text'] = {
          'jp': missing,
          'th': 'Thai fallback',
          'en': 'English fallback',
        };
        settings['analytics_cookies']['brief_description'] = {
          'th': 'Thai brief',
          'en': 'English brief',
        };
        settings['analytics_cookies']['full_description'] = {
          'th': '<p>Thai full</p>',
          'en': '<p>English full</p>',
        };
        settings['accept_button_text'] = {
          'th': 'Thai save',
          'en': 'English save',
        };
        await http.runWithClient(() async {
          await open(tester, locale: const Locale('ja'));
          expect(find.text('日本語タイトル'), findsOneWidget);
          expect(htmlShown(tester), contains('Thai fallback'));
          expect(htmlShown(tester), contains('Thai brief'));
          expect(find.text('Thai save'), findsOneWidget);
          await scrollTo(tester, control('detail-analytics_cookies'));
          await tester.tap(control('detail-analytics_cookies'));
          await tester.pumpAndSettle();
          expect(htmlShown(tester), ['<p>Thai full</p>']);
          await tester.tap(control('detail-back'));
          await tester.pumpAndSettle();
          await close(tester);
        }, () => client);
      },
    );
  }

  testWidgets(
    'missing Thai and Japanese text falls back to English after UI language change',
    (tester) async {
      final settings = detail['data']['setting'] as Map<String, dynamic>;
      settings['available_languages'] = ['th', 'en', 'jp'];
      settings['consent_detail_title']['jp'] = '日本語タイトル';
      settings['display_text'] = {'en': 'English fallback'};
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('th'));
        await tester.tap(control('language'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('日本語').last);
        await tester.pumpAndSettle();
        expect(find.text('日本語タイトル'), findsOneWidget);
        expect(htmlShown(tester), contains('English fallback'));
        await close(tester);
      }, () => client);
    },
  );

  testWidgets(
    'missing all language content uses Thai UI without rendering null',
    (tester) async {
      final settings = detail['data']['setting'] as Map<String, dynamic>;
      settings.remove('available_languages');
      settings['default_language'] = 'jp';
      for (final key in [
        'display_text',
        'consent_detail_title',
        'accept_button_text',
      ]) {
        settings.remove(key);
      }
      for (final key in ['preferences_cookies', 'analytics_cookies']) {
        settings[key]['brief_description'] = {};
        settings[key]['full_description'] = {};
      }
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('ja'));
        expect(find.text('การตั้งค่าความเป็นส่วนตัว'), findsOneWidget);
        expect(find.text('ยอมรับและบันทึกตัวเลือก'), findsOneWidget);
        expect(control('language'), findsNothing);
        expect(htmlShown(tester).every((text) => text != 'null'), isTrue);
        await close(tester);
      }, () => client);
    },
  );

  for (final advertised in [true, false]) {
    testWidgets(
      'jp-only content works with locale jp and language list present=$advertised',
      (tester) async {
        final settings = detail['data']['setting'] as Map<String, dynamic>;
        if (advertised) {
          settings['available_languages'] = ['jp'];
        } else {
          settings.remove('available_languages');
        }
        settings['default_language'] = 'jp';
        settings['display_text'] = {'jp': '日本語だけの本文'};
        settings['consent_detail_title'] = {'jp': '日本語だけのタイトル'};
        settings['accept_button_text'] = {'jp': '保存する'};
        for (final permission in ['preferences_cookies', 'analytics_cookies']) {
          settings[permission]['brief_description'] = {'jp': '日本語だけの要約'};
          settings[permission]['full_description'] = {'jp': '<p>日本語だけの全文</p>'};
        }
        await http.runWithClient(() async {
          await open(tester, locale: const Locale('jp'));
          expect(find.text('日本語だけのタイトル'), findsOneWidget);
          expect(htmlShown(tester), contains('日本語だけの本文'));
          expect(control('language'), findsNothing);
          await scrollTo(tester, control('detail-analytics_cookies'));
          await tester.tap(control('detail-analytics_cookies'));
          await tester.pumpAndSettle();
          expect(htmlShown(tester), ['<p>日本語だけの全文</p>']);
          await tester.tap(control('detail-back'));
          await tester.pumpAndSettle();
          await close(tester);
        }, () => client);
      },
    );
  }

  testWidgets(
    'full-description flag hides full text even when a translation exists',
    (tester) async {
      detail['data']['setting']['analytics_cookies']['is_full_description_enabled'] =
          false;
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('en'));
        expect(htmlShown(tester), contains('About Analytics'));
        expect(control('detail-analytics_cookies'), findsNothing);
        expect(
          htmlShown(tester).where((html) => html.startsWith('<h1>')),
          isEmpty,
        );
        await close(tester);
      }, () => client);
    },
  );

  testWidgets(
    'loads previous choices, locks required rows, and saves the shown version',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('en'));
        expect(requests.first.url.path, '/contacts/contact/consents/message');
        expect(toggle(tester, 'terms_and_conditions').value, isTrue);
        expect(toggle(tester, 'terms_and_conditions').onChanged, isNull);
        expect(toggle(tester, 'privacy_overview').onChanged, isNull);
        expect(toggle(tester, 'necessary_cookies').value, isTrue);
        expect(toggle(tester, 'necessary_cookies').onChanged, isNull);
        expect(toggle(tester, 'preferences_cookies').value, isTrue);
        expect(toggle(tester, 'analytics_cookies').value, isFalse);
        expect(control('marketing_cookies'), findsNothing);
        await scrollTo(tester, control('analytics_cookies'));
        await tester.tap(control('analytics_cookies'));
        await tester.tap(control('save'));
        await tester.pumpAndSettle();
        final saved = await result;
        expect(saved.outcome, PamConsentOutcome.saved);
        expect(saved.submission!.consentID, 'saved-consent');
        expect(saved.selection, isA<TrackingConsent>());
        expect(submissions.single['_version'], 3);
        expect(submissions.single['_allow_preferences_cookies'], isTrue);
        expect(submissions.single['_allow_analytics_cookies'], isTrue);
        expect(submissions.single['_allow_necessary_cookies'], isTrue);
        expect(submissions.single['_database'], 'public-db');
        expect(pam.allowTracking, isTrue);
      }, () => client);
    },
  );

  for (final code in [404, 500]) {
    testWidgets(
      'status HTTP $code starts a new selection even with a valid-looking body',
      (tester) async {
        statusCode = code;
        await http.runWithClient(() async {
          await open(tester);
          expect(toggle(tester, 'preferences_cookies').value, isFalse);
          expect(submissions, isEmpty);
          await close(tester);
          expect(submissions, isEmpty);
        }, () => client);
      },
    );
  }

  testWidgets('malformed status is treated as first consent', (tester) async {
    stored['version'] = 'invalid-version';
    await http.runWithClient(() async {
      await open(tester);
      expect(toggle(tester, 'preferences_cookies').value, isFalse);
      expect(control('save'), findsOneWidget);
      await close(tester);
    }, () => client);
  });

  testWidgets('status for another message is not reused', (tester) async {
    stored['consent_message_id'] = 'another-message';
    await http.runWithClient(() async {
      await open(tester);
      expect(toggle(tester, 'preferences_cookies').value, isFalse);
      await close(tester);
    }, () => client);
  });

  testWidgets(
    'unsupported locale uses priority; single language hides selector',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('ja'));
        expect(find.text('การตั้งค่าความเป็นส่วนตัว'), findsOneWidget);
        await close(tester);
        (detail['data']['setting']
            as Map<String, dynamic>)['available_languages'] = [
          'en',
        ];
        await open(tester, locale: const Locale('th'));
        expect(find.text('Privacy settings'), findsOneWidget);
        expect(control('language'), findsNothing);
        await close(tester);
      }, () => client);
    },
  );

  testWidgets('system back dismisses without submitting and allows reopening', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect((await result).outcome, PamConsentOutcome.dismissed);
      expect(submissions, isEmpty);
      await open(tester);
      await close(tester);
    }, () => client);
  });

  testWidgets(
    'server review response reloads latest details and waits for confirmation',
    (tester) async {
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('en'));
        detail = message(version: 4);
        nextSaveError = 'NEED_CONSENT_REVIEW';
        await tester.tap(control('save'));
        await tester.pumpAndSettle();
        expect(submissions, hasLength(1));
        expect(submissions.first['_version'], 3);
        expect(
          find.text(
            'Consent details have changed. Please review your choices.',
          ),
          findsOneWidget,
        );
        await tester.tap(control('save'));
        await tester.pumpAndSettle();
        expect(submissions.last['_version'], 4);
        expect((await result).outcome, PamConsentOutcome.saved);
      }, () => client);
    },
  );

  testWidgets('no contact skips status lookup', (tester) async {
    pam.publicContact = null;
    await http.runWithClient(() async {
      await open(tester);
      expect(
        requests.where((r) => r.url.path.startsWith('/contacts/')),
        isEmpty,
      );
      expect(toggle(tester, 'preferences_cookies').value, isFalse);
      await close(tester);
    }, () => client);
  });

  testWidgets('language changes preserve choices and translate HTML details', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await open(tester, locale: const Locale('en'));
      expect(find.text('Privacy settings'), findsOneWidget);
      await scrollTo(tester, control('analytics_cookies'));
      await tester.tap(control('analytics_cookies'));
      await scrollTo(tester, control('detail-analytics_cookies'));
      await tester.tap(control('detail-analytics_cookies'));
      await tester.pumpAndSettle();
      expect(find.text('Full Analytics', findRichText: true), findsOneWidget);
      await tester.tap(control('language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ไทย').last);
      await tester.pumpAndSettle();
      expect(
        find.text('รายละเอียดฉบับเต็ม', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(control('detail-back'));
      await tester.pumpAndSettle();
      expect(toggle(tester, 'analytics_cookies').value, isTrue);
      expect(requests.where((r) => r.method == 'GET'), hasLength(2));
      await close(tester);
    }, () => client);
  });

  testWidgets('invalid detail is retryable and cannot submit', (tester) async {
    detailCode = 500;
    await http.runWithClient(() async {
      await open(tester);
      expect(control('save'), findsNothing);
      expect(control('retry'), findsOneWidget);
      detailCode = 200;
      await tester.tap(control('retry'));
      await tester.pumpAndSettle();
      expect(control('save'), findsOneWidget);
      await close(tester);
    }, () => client);
  });

  testWidgets(
    'contacting consent retains previous channels and does not enable tracking',
    (tester) async {
      detail = message(contacting: true);
      stored = status(contacting: true, review: true);
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('en'));
        expect(
          find.text(
            'Consent details have changed. Please review your choices.',
          ),
          findsOneWidget,
        );
        expect(control('necessary_cookies'), findsNothing);
        expect(toggle(tester, 'email').value, isTrue);
        expect(toggle(tester, 'sms').value, isFalse);
        await scrollTo(tester, control('sms'));
        await tester.tap(control('sms'));
        await tester.tap(control('save'));
        await tester.pumpAndSettle();
        expect((await result).selection, isA<ContactingConsent>());
        expect(submissions.single['_allow_email'], isTrue);
        expect(submissions.single['_allow_sms'], isTrue);
        expect(submissions.single['_allow_line'], isTrue);
        expect(submissions.single['_allow_push_notification'], isTrue);
        expect(
          submissions.single.containsKey('_allow_necessary_cookies'),
          isFalse,
        );
        expect(pam.allowTracking, isFalse);
      }, () => client);
    },
  );

  testWidgets('failed save stays open and retries the same selection', (
    tester,
  ) async {
    failSaves = 1;
    await http.runWithClient(() async {
      await open(tester);
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect(control('save-error'), findsOneWidget);
      expect(toggle(tester, 'preferences_cookies').value, isTrue);
      expect(pam.allowTracking, isFalse);
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect((await result).outcome, PamConsentOutcome.saved);
      expect(submissions, hasLength(2));
      expect(
        submissions[0]['_allow_preferences_cookies'],
        submissions[1]['_allow_preferences_cookies'],
      );
    }, () => client);
  });

  testWidgets('saving disables close, switches, and duplicate submit', (
    tester,
  ) async {
    pendingSave = Completer<http.Response>();
    await http.runWithClient(() async {
      await open(tester);
      await tester.tap(control('save'));
      await tester.pump();
      expect(tester.widget<FilledButton>(control('save')).onPressed, isNull);
      expect(tester.widget<IconButton>(control('close')).onPressed, isNull);
      expect(toggle(tester, 'preferences_cookies').onChanged, isNull);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(control('save'), findsOneWidget);
      pendingSave!.complete(
        http.Response(
          jsonEncode({'consent_id': 'saved-consent', 'contact_id': 'contact'}),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect((await result).outcome, PamConsentOutcome.saved);
      expect(submissions, hasLength(1));
    }, () => client);
  });

  testWidgets('changed SDK session cannot save previous choices', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await open(tester);
      Pam.shared = Pam()..config = pam.config;
      await tester.tap(control('save'));
      await tester.pumpAndSettle();
      expect(submissions, isEmpty);
      expect(control('save'), findsNothing);
      await close(tester);
    }, () => client);
  });

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('fits $size with large text and preserves choices on resize', (
      tester,
    ) async {
      await binding.setSurfaceSize(size);
      addTearDown(() => binding.setSurfaceSize(null));
      await http.runWithClient(() async {
        await open(tester, locale: const Locale('th'), scale: 2);
        expect(
          control(size.width < 600 ? 'fullscreen' : 'dialog'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(control('save'), findsOneWidget);
        final value = toggle(tester, 'preferences_cookies').value;
        await binding.setSurfaceSize(const Size(480, 800));
        await tester.pumpAndSettle();
        expect(toggle(tester, 'preferences_cookies').value, value);
        expect(requests.where((r) => r.method == 'GET'), hasLength(2));
        expect(tester.takeException(), isNull);
        await close(tester);
      }, () => client);
    });
  }
}
