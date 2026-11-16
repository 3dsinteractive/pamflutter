import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/pam_response.dart';
import 'package:pam_flutter/preferences.dart';
import 'package:pam_flutter_example/main.dart' as app;
import 'package:pam_flutter_example/demo_auth_api.dart';
import 'package:pam_flutter_example/demo_auth_controller.dart';
import 'package:pam_flutter_example/pam_config.dart';
import 'package:pam_flutter_example/sdk_demo_page.dart';

class _Preference extends UserPreference {
  @override
  Future<String?> getString(SaveKey key) async => null;
}

class _DemoPam extends Pam {
  final initializations = <PamConfig>[];
  final requests = <Map<String, dynamic>>[];
  bool failSave = false;
  _DemoPam() {
    pref = _Preference();
  }

  @override
  Future<PamResponse> trackUserLogin(String customerId) async {
    custID = customerId;
    requests.add({'event': 'login', 'customer': customerId});
    return PamResponse()..contactID = 'demo-contact';
  }

  @override
  Future<void> trackUserLogout({Map<String, dynamic>? payload}) async {
    custID = null;
    requests.add({'event': 'logout'});
  }

  @override
  Future<void> init(PamConfig config, bool debug) async {
    this.config = config;
    isEnableLog = false;
    initializations.add(config);
  }

  @override
  Future<String?> getContactID() async => 'demo-contact';

  @override
  Future<void> setAllowTracking(bool allow) async {
    allowTracking = allow;
  }

  @override
  Future<PamResponse> postTracker(
    String? event,
    Map<String, dynamic>? payload,
  ) async {
    requests.add({'event': event, ...?payload});
    if (failSave) {
      return PamResponse.createErrorResponse(
        code: 'TEST_FAILURE',
        errorMessage: 'Save failed',
      );
    }
    return PamResponse()
      ..contactID = 'demo-contact'
      ..database = 'test-db'
      ..consentID = event == 'allow_consent' ? 'consent-record' : null
      ..consentMessageID = payload?['_consent_message_id'] as String?;
  }
}

void main() {
  late Pam original;
  late _DemoPam sdk;
  late DemoAuthController auth;
  setUp(() {
    original = Pam.shared;
    sdk = _DemoPam();
    Pam.shared = sdk;
    auth = DemoAuthController(
      api: DemoAuthApi(
        client: SimulatedAuthServer(latency: Duration.zero),
        onRequest: (event) => auth.record(event),
      ),
    );
  });
  tearDown(() async {
    if (!auth.busy) auth.dispose();
    Pam.shared = original;
  });

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> reveal(WidgetTester tester, String value) async {
    final controller = tester.widget<ListView>(key('demo-scroll')).controller!;
    for (var i = 0; i < 100 && key(value).evaluate().isEmpty; i++) {
      controller.jumpTo(
        math.min(controller.offset + 300, controller.position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }
    expect(
      key(value),
      findsOneWidget,
      reason: 'Demo control $value must be reachable',
    );
    await tester.ensureVisible(key(value));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String value) async {
    await reveal(tester, value);
    await tester.tap(key(value));
    await tester.pumpAndSettle();
  }

  Future<void> section(WidgetTester tester, String name) async {
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(key('demo-section'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> configure(WidgetTester tester) async {
    final config =
        PamConfigProvider.getDevelopConfig(
            auth.identityProvider,
            auth.onIdentityMismatch,
          )
          ..pamServer = 'https://example.invalid'
          ..trackingConsentMessageID = 'tracking-test';
    await Pam.initialize(config);
    await tester.pumpWidget(
      MaterialApp(
        home: SdkDemoPage(auth: auth, contactingMessageId: 'contacting-test'),
      ),
    );
    await tester.pumpAndSettle();
    expect(sdk.initializations, hasLength(1));
    expect(find.text('พร้อมทดสอบ API'), findsOneWidget);
  }

  String result(WidgetTester tester) =>
      tester.widget<SelectableText>(key('demo-result')).data!;

  testWidgets(
    'main initializes with getDevelopConfig and restores session without a config form',
    (tester) async {
      await app.main();
      await tester.pump();
      final startupAuth = tester
          .widget<SdkDemoPage>(find.byType(SdkDemoPage))
          .auth;
      auth.dispose();
      auth = startupAuth;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(sdk.initializations, hasLength(1));
      final config = sdk.initializations.single;
      expect(config.pamServer, PamConfigProvider.endpoint);
      expect(config.identityProvider, isNotNull);
      expect(config.onIdentityMismatch, isNotNull);
      expect(config.identityProvider!().type, PamUserStateType.anonymous);
      expect(find.byType(TextField), findsNothing);
      expect(key('action-initialize'), findsNothing);
      expect(find.text('พร้อมทดสอบ API'), findsOneWidget);
      expect(sdk.requests, isEmpty);
    },
  );

  testWidgets(
    'entered customer ID logs in through REST and SDK logout clears both states',
    (tester) async {
      await configure(tester);
      await section(tester, 'ตัวตนผู้ใช้');
      await reveal(tester, 'field-customer');
      await tester.enterText(key('field-customer'), 'CUSTOMER-FROM-UI');
      await press(tester, 'action-login');
      expect(auth.session!.customerId, 'CUSTOMER-FROM-UI');
      expect(await Pam.getCustID(), 'CUSTOMER-FROM-UI');
      expect(
        sdk.config!.identityProvider!().identity!.value,
        'CUSTOMER-FROM-UI',
      );
      await press(tester, 'action-logout');
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      expect(await Pam.getCustID(), isNull);
    },
  );

  testWidgets(
    'real resumed lifecycle refreshes expired auth and synchronizes PAM',
    (tester) async {
      await configure(tester);
      await auth.login('CUSTOMER-A');
      await auth.expireOnServer();
      expect(await Pam.getCustID(), 'CUSTOMER-A');
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      expect(await Pam.getCustID(), isNull);
      expect(auth.canUsePam, isTrue);
    },
  );

  testWidgets(
    'custom tracking choices save only the toggles explicitly selected',
    (tester) async {
      await configure(tester);
      expect(sdk.config!.identityProvider, isNotNull);
      await section(tester, 'Consent');
      await reveal(tester, 'choice-tracking-terms_and_conditions');
      expect(
        tester
            .widget<SwitchListTile>(key('choice-tracking-terms_and_conditions'))
            .onChanged,
        isNull,
      );
      await press(tester, 'choice-tracking-analytics_cookies');
      await press(tester, 'action-save-tracking');
      expect(sdk.requests.single['_allow_analytics_cookies'], isTrue);
      expect(sdk.requests.single['_allow_preferences_cookies'], isFalse);
      expect(sdk.requests.single['_allow_marketing_cookies'], isFalse);
      expect(sdk.requests.single['_version'], 'latest');
      expect(result(tester), contains('consent-record'));
      expect(result(tester), isNot(contains('Instance of')));
    },
  );

  testWidgets('fromStatus populates channels before copyWith submits an edit', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await configure(tester);
        await section(tester, 'Consent');
        await press(tester, 'action-edit-contacting');
        expect(result(tester), contains('copyWith'));
        await reveal(tester, 'choice-contacting-email');
        expect(
          tester.widget<SwitchListTile>(key('choice-contacting-email')).value,
          isTrue,
        );
        await press(tester, 'choice-contacting-sms');
        await press(tester, 'action-save-contacting');
        expect(sdk.requests.single['_allow_email'], isTrue);
        expect(sdk.requests.single['_allow_sms'], isTrue);
        expect(sdk.requests.single['_allow_line'], isTrue);
        expect(sdk.requests.single['_allow_push_notification'], isTrue);
        expect(
          sdk.requests.single.containsKey('_allow_analytics_cookies'),
          isFalse,
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'consent_id': 'previous-record',
            'contact_id': 'demo-contact',
            'consent_message_id': 'contacting-test',
            'consent_message_type': 'contacting_type',
            'need_consent_review': false,
            'contacting_permission': {
              'terms_and_conditions': true,
              'privacy_overview': true,
              'email': true,
              'sms': false,
              'line': true,
              'push_notification': true,
            },
          }),
          200,
        ),
      ),
    );
  });

  testWidgets('built-in UI loads content and closing it submits nothing', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await configure(tester);
        await section(tester, 'Consent');
        await press(tester, 'action-show-tracking');
        expect(find.text('Demo consent title'), findsOneWidget);
        await tester.tap(key('pam-consent-close'));
        await tester.pumpAndSettle();
        expect(result(tester), contains('dismissed'));
        expect(sdk.requests, isEmpty);
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.startsWith('/contacts/')
                ? {}
                : {
                    'consent_message_id': 'tracking-test',
                    'consent_message_type': 'tracking_type',
                    'setting': {
                      'version': 1,
                      'available_languages': ['en'],
                      'consent_detail_title': {'en': 'Demo consent title'},
                      'display_text': {'en': 'Demo consent details'},
                    },
                  },
          ),
          200,
        ),
      ),
    );
  });

  testWidgets('a new auth session clears the previous custom consent draft', (
    tester,
  ) async {
    await configure(tester);
    await section(tester, 'Consent');
    await press(tester, 'choice-tracking-analytics_cookies');
    await section(tester, 'ตัวตนผู้ใช้');
    await press(tester, 'action-login');
    await section(tester, 'Consent');
    await press(tester, 'action-save-tracking');
    expect(sdk.requests.last['_consent_message_id'], 'tracking-test');
    expect(sdk.requests.last['_allow_analytics_cookies'], isFalse);
  });

  testWidgets('built-in UI saved choices are reflected in the custom form', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await configure(tester);
        await section(tester, 'Consent');
        await press(tester, 'action-show-tracking');
        final analytics = key('pam-consent-analytics_cookies');
        await tester.ensureVisible(analytics);
        await tester.tap(analytics);
        await tester.tap(key('pam-consent-save'));
        await tester.pumpAndSettle();
        expect(result(tester), contains('saved'));
        await reveal(tester, 'choice-tracking-analytics_cookies');
        expect(
          tester
              .widget<SwitchListTile>(key('choice-tracking-analytics_cookies'))
              .value,
          isTrue,
        );
        expect(sdk.requests.single['_version'], 1);
      },
      () => MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.startsWith('/contacts/')
                ? {}
                : {
                    'consent_message_id': 'tracking-test',
                    'consent_message_type': 'tracking_type',
                    'setting': {
                      'version': 1,
                      'available_languages': ['en'],
                      'display_text': {'en': 'Choose your permissions'},
                      'analytics_cookies': {
                        'is_enabled': true,
                        'brief_description': {'en': 'Analytics'},
                      },
                    },
                  },
          ),
          200,
        ),
      ),
    );
  });

  testWidgets('all API categories fit a narrow phone screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await configure(tester);
    for (final name in [
      'Consent',
      'ตัวตนผู้ใช้',
      'Tracking',
      'Push',
      'App Attention / อุปกรณ์',
      'การเริ่มต้น / Session',
    ]) {
      await section(tester, name);
      expect(tester.takeException(), isNull);
    }
    expect(sdk.requests, isEmpty);
  });

  testWidgets('save rejection displays the backend error code', (tester) async {
    await configure(tester);
    sdk.failSave = true;
    await section(tester, 'Consent');
    await press(tester, 'action-save-tracking');
    expect(result(tester), contains('ไม่สำเร็จ'));
    expect(result(tester), contains('TEST_FAILURE'));
  });

  testWidgets('malformed event JSON never reaches the SDK request', (
    tester,
  ) async {
    await configure(tester);
    await section(tester, 'Tracking');
    await reveal(tester, 'field-payload');
    await tester.enterText(key('field-payload'), '[]');
    await press(tester, 'action-track');
    expect(result(tester), contains('JSON object'));
    expect(sdk.requests, isEmpty);
  });

  testWidgets('push payload utilities do not send PAM tracking requests', (
    tester,
  ) async {
    await configure(tester);
    await section(tester, 'Push');
    await press(tester, 'action-is-pam-push');
    expect(result(tester), 'true');
    await press(tester, 'action-convert-push');
    expect(result(tester), contains('Demo notification'));
    expect(sdk.initializations, hasLength(1));
    expect(sdk.requests, isEmpty);
  });
}
