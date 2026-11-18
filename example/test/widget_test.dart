import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pam_flutter/api/tracker_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/preferences.dart';
import 'package:pam_flutter/response/pam_response.dart';
import 'package:pam_flutter_example/demo_auth_api.dart';
import 'package:pam_flutter_example/demo_auth_controller.dart';
import 'package:pam_flutter_example/pam_config.dart';
import 'package:pam_flutter_example/sdk_demo_page.dart';

class _Preference extends UserPreference {
  int clears = 0;
  @override
  Future<void> clear() async {
    clears++;
  }

  @override
  Future<String?> getString(SaveKey key) async => null;
}

class _DemoPam extends Pam {
  final requests = <Map<String, dynamic>>[];
  final lifecycle = <String>[];
  bool failTrack = false;

  _DemoPam() {
    pref = _Preference();
  }

  @override
  Future<void> init(PamConfig config, bool debug) async {
    this.config = config;
    isEnableLog = false;
  }

  @override
  Future<PamResponse> trackUserLogin(String customerId) async {
    custID = customerId;
    lifecycle.add('login');
    return PamResponse()..contactID = 'demo-contact';
  }

  @override
  Future<void> trackUserLogout({Map<String, dynamic>? payload}) async {
    custID = null;
    lifecycle.add('logout');
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
    requests.add({'event': event, 'customer': custID, ...?payload});
    if (failTrack) {
      return PamResponse.createErrorResponse(
        code: 'TEST_FAILURE',
        errorMessage: 'Failed',
      );
    }
    return PamResponse()
      ..contactID = 'demo-contact'
      ..consentID = event == 'allow_consent' ? 'consent-record' : null;
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

  tearDown(() {
    expect(auth.busy, isFalse);
    auth.dispose();
    Pam.shared = original;
  });

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> reveal(WidgetTester tester, String value) async {
    final scroll = tester.widget<ListView>(key('demo-scroll')).controller;
    final position =
        scroll?.position ??
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    final target = find.byKey(ValueKey(value), skipOffstage: false);
    // Dialog focus restoration can scroll after the initial jump. Cached
    // children are still usable by ensureVisible even when outside the viewport.
    position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
      position.jumpTo(
        math.min(position.pixels + 300, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }
    expect(target, findsOneWidget);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(key(value), findsOneWidget);
  }

  Future<void> press(WidgetTester tester, String value) async {
    await reveal(tester, value);
    await tester.tap(key(value));
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
    await tester.pumpWidget(MaterialApp(home: SdkDemoPage(auth: auth)));
    await tester.pumpAndSettle();
  }

  String notice(WidgetTester tester) =>
      tester.widget<Text>(key('demo-result')).data!;

  testWidgets(
    'guest can browse before consent and login; events use current identity',
    (tester) async {
      await configure(tester);
      expect(auth.identityProvider().type, PamUserStateType.anonymous);
      await press(tester, 'browse-product');
      expect(
        find.text('กระเป๋าสำหรับทุกวัน น้ำหนักเบา พกของจำเป็นได้ครบ'),
        findsOneWidget,
      );
      await press(tester, 'favorite-product');
      expect(find.text('อยู่ในรายการที่ชอบแล้ว'), findsOneWidget);
      expect(sdk.requests.map((request) => request['event']), [
        'view_product',
        'favorite_product',
      ]);
      expect(sdk.requests.last['is_favorite'], isTrue);
      await press(tester, 'favorite-product');
      expect(sdk.requests.last['event'], 'favorite_product');
      expect(sdk.requests.last['is_favorite'], isFalse);
      expect(
        sdk.requests.every((request) => request['customer'] == null),
        isTrue,
      );
      await press(tester, 'action-track-guest');
      expect(sdk.requests.last['event'], 'view_product');
      expect(sdk.requests.last['customer'], isNull);
      expect(sdk.requests.last['demo_stage'], 'guest');
      expect(sdk.requests.last['sku'], 'DEMO-SKU-001');
      await reveal(tester, 'action-track-member');
      expect(
        tester.widget<OutlinedButton>(key('action-track-member')).onPressed,
        isNull,
      );
      await reveal(tester, 'field-customer');
      await tester.enterText(key('field-customer'), 'CUSTOMER-FROM-UI');
      await press(tester, 'action-login');
      expect(auth.session!.customerId, 'CUSTOMER-FROM-UI');
      await press(tester, 'action-track-member');
      expect(sdk.requests.last['customer'], 'CUSTOMER-FROM-UI');
      expect(sdk.requests.last['demo_stage'], 'member');
      await reveal(tester, 'action-track-guest');
      expect(
        tester.widget<OutlinedButton>(key('action-track-guest')).onPressed,
        isNull,
      );
      expect(find.byType(SelectableText), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'purchase batch requires login and sends an order and its items in one request',
    (tester) async {
      final batches = <Map<String, dynamic>>[];
      const channel = MethodChannel('pam_flutter');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => <String, String>{},
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await http.runWithClient(
        () async {
          await configure(tester);
          await reveal(tester, 'action-purchase-order');
          expect(
            tester
                .widget<OutlinedButton>(key('action-purchase-order'))
                .onPressed,
            isNull,
          );
          await press(tester, 'action-login');
          sdk.trackerAPI = TrackerAPI('https://example.invalid');
          sdk.publicContact = 'demo-contact';
          sdk.deviceUDID = 'demo-device';
          await press(tester, 'action-purchase-order');
          expect(batches, hasLength(1));
          final events = batches.single['events'] as List;
          expect(events.map((event) => event['event']), [
            'purchase_order',
            'purchase_order_item',
            'purchase_order_item',
          ]);
          final fields = events
              .map((event) => event['form_fields'] as Map)
              .toList();
          expect(
            fields.map((field) => field['order_id']).toSet(),
            hasLength(1),
          );
          expect(
            fields.every((field) => field['customer'] == 'DEMO-CUSTOMER-001'),
            isTrue,
          );
          expect(fields.first['total_amount'], 1090);
          expect(
            fields
                .skip(1)
                .fold<int>(
                  0,
                  (total, field) =>
                      total +
                      (field['price'] as int) * (field['quantity'] as int),
                ),
            1090,
          );
          expect(
            key('action-result-purchase-order').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.widget<Text>(key('action-result-purchase-order')).data,
            contains('ส่งคำขอซื้อสินค้า'),
          );
          sdk.config!.blockEventsIfNoConsent = true;
          sdk.allowTracking = false;
          await press(tester, 'action-purchase-order');
          expect(batches, hasLength(1));
          expect(
            tester.widget<Text>(key('action-result-purchase-order')).data,
            contains('ยังไม่ได้ส่งคำสั่งซื้อ'),
          );
        },
        () => MockClient((request) async {
          batches.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', 200);
        }),
      );
    },
  );

  testWidgets(
    'consent works as guest, login invalidates status, member can edit, closing never saves',
    (tester) async {
      await http.runWithClient(
        () async {
          await configure(tester);
          await press(tester, 'action-show-guest-tracking');
          expect(find.text('Demo consent title'), findsOneWidget);
          await tester.tap(key('pam-consent-save'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(key('pam-consent-save-error'), findsNothing);
          expect(key('pam-consent-save'), findsNothing);
          expect(sdk.requests.single['event'], 'allow_consent');
          expect(sdk.requests.single['customer'], isNull);
          final saved = key('consent-result-guest-tracking');
          expect(saved.hitTestable(), findsOneWidget);
          expect(
            tester.widget<Text>(saved).data,
            contains('บันทึก Consent แล้ว'),
          );
          await press(tester, 'action-login');
          await reveal(tester, 'action-status-member-tracking');
          expect(key('consent-status-member-tracking'), findsNothing);
          await press(tester, 'action-status-member-tracking');
          await reveal(tester, 'consent-status-member-tracking');
          expect(
            find.textContaining('มี Consent ที่บันทึกไว้แล้ว'),
            findsOneWidget,
          );
          await press(tester, 'action-show-member-tracking');
          await tester.tap(key('pam-consent-close'));
          await tester.pumpAndSettle();
          expect(sdk.requests, hasLength(1));
          final dismissed = key('consent-result-member-tracking');
          expect(dismissed.hitTestable(), findsOneWidget);
          expect(
            tester.widget<Text>(dismissed).data,
            contains('ยังไม่ได้เปลี่ยน Consent'),
          );
          await press(tester, 'action-show-member-tracking');
          await tester.tap(key('pam-consent-save'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
          expect(key('pam-consent-save-error'), findsNothing);
          expect(key('pam-consent-save'), findsNothing);
          expect(sdk.requests.last['customer'], 'DEMO-CUSTOMER-001');
          expect(sdk.requests, hasLength(2));
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.startsWith('/contacts/')
                  ? {
                      'consent_id': 'previous-record',
                      'consent_message_id': 'tracking-test',
                      'consent_message_type': 'tracking_type',
                      'need_consent_review': false,
                      'tracking_permission': {'analytics_cookies': true},
                    }
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
    },
  );

  testWidgets(
    'logout resets SDK and local UI and starts a fresh guest journey',
    (tester) async {
      await configure(tester);
      await press(tester, 'favorite-product');
      await press(tester, 'action-login');
      sdk.publicContact = 'old-guest';
      sdk.loginContact = 'old-member';
      sdk.pushToken = 'old-token';
      sdk.allowTracking = true;
      await press(tester, 'action-logout-reset');
      expect(auth.session, isNull);
      expect(await auth.api.loadSession(), isNull);
      expect(await Pam.getCustID(), isNull);
      expect(sdk.lifecycle, ['login', 'logout']);
      expect((sdk.pref as _Preference).clears, 1);
      expect(sdk.publicContact, isNull);
      expect(sdk.loginContact, isNull);
      expect(sdk.pushToken, isNull);
      expect(sdk.allowTracking, isFalse);
      expect(auth.canUsePam, isTrue);
      await reveal(tester, 'favorite-product');
      expect(find.text('เก็บไว้ในรายการที่ชอบ'), findsOneWidget);
      await press(tester, 'action-track-guest');
      expect(sdk.requests.last['customer'], isNull);
      expect(sdk.requests.last['demo_stage'], 'guest');
    },
  );

  testWidgets('blocked tracking does not claim an event was sent', (
    tester,
  ) async {
    await configure(tester);
    sdk.config!.blockEventsIfNoConsent = true;
    sdk.allowTracking = false;
    await press(tester, 'action-track-guest');
    expect(sdk.requests, isEmpty);
    await reveal(tester, 'demo-result');
    expect(notice(tester), contains('ยังไม่ได้ส่ง Event'));
  });

  testWidgets('failed event shows a readable failure without response JSON', (
    tester,
  ) async {
    await configure(tester);
    sdk.failTrack = true;
    await press(tester, 'action-track-guest');
    await reveal(tester, 'demo-result');
    expect(notice(tester), contains('ทำรายการไม่สำเร็จ'));
    await reveal(tester, 'demo-result');
    expect(notice(tester), isNot(contains('contact_id')));
  });

  testWidgets('journey remains usable on a narrow phone with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(() async {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.binding.setSurfaceSize(null);
    });
    await configure(tester);
    await press(tester, 'browse-product');
    await press(tester, 'action-login');
    await press(tester, 'action-track-member');
    await press(tester, 'action-logout-reset');
    expect(tester.takeException(), isNull);
  });

  testWidgets('resume reconciles an expired server session', (tester) async {
    await configure(tester);
    await auth.login('CUSTOMER-A');
    await auth.expireOnServer();
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
  });
}
