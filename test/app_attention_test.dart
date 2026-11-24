import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/pam_flutter_platform_interface.dart';
import 'package:pam_flutter/preferences.dart';

class _Preference extends UserPreference {
  bool fail = false;

  @override
  Future<String?> getString(SaveKey key) async {
    if (fail) throw PlatformException(code: 'STORAGE_UNAVAILABLE');
    return null;
  }

  @override
  Future<void> clear() async {}
}

class _PopupPlatform extends PamFlutterPlatform {
  final requests = <Map<String, dynamic>>[];
  final pending = <Completer<Map<String, dynamic>?>>[];

  @override
  Future<Map<String, dynamic>?> appAttentionPopup(Map<String, dynamic> params) {
    requests.add(params);
    final completer = Completer<Map<String, dynamic>?>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  late Pam previousPam;
  late PamFlutterPlatform previousPlatform;
  late _PopupPlatform platform;
  late _Preference preference;
  late BuildContext context;
  late NavigatorState navigator;

  setUp(() {
    previousPam = Pam.shared;
    previousPlatform = PamFlutterPlatform.instance;
    platform = _PopupPlatform();
    preference = _Preference();
    PamFlutterPlatform.instance = platform;
    Pam.shared = Pam()
      ..pref = preference
      ..publicContact = 'public-contact'
      ..config = PamConfig(
        'https://example.invalid',
        'public-db',
        'login-db',
        '',
        false,
        identityMatcher: PamIdentityMatcher.primary(
          PamPrimaryIdentityKey.customer,
        ),
      );
  });

  tearDown(() {
    Pam.shared = previousPam;
    PamFlutterPlatform.instance = previousPlatform;
  });

  Future<void> mount(WidgetTester tester, {Widget? body}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            navigator = Navigator.of(value);
            return Scaffold(body: body);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> withResponse(
    Future<void> Function() body, {
    String response = '{"title":"offer"}',
  }) {
    return http.runWithClient(
      body,
      () => MockClient((_) async => http.Response(response, 200)),
    );
  }

  for (final completion in ['dismiss', 'action', 'error']) {
    testWidgets(
      'blocks background taps and scrolling until popup completes with $completion',
      (tester) async {
        var taps = 0;
        var clicks = 0;
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await mount(
          tester,
          body: Column(
            children: [
              TextButton(
                onPressed: () => taps++,
                child: const Text('Background button'),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemExtent: 50,
                  itemBuilder: (_, index) => Text('Item $index'),
                ),
              ),
            ],
          ),
        );
        final buttonPosition = tester.getCenter(find.text('Background button'));
        final listPosition = tester.getCenter(find.byType(ListView));
        final response = Completer<http.Response>();
        await http.runWithClient(() async {
          final call = Pam.appAttention(
            context,
            onBannerClick: (_) {
              clicks++;
              return true;
            },
          );
          await flush(tester);
          // Fetching an offer should leave the page interactive.
          await tester.tapAt(buttonPosition);
          expect(taps, 1);

          response.complete(http.Response('{"title":"offer"}', 200));
          await flush(tester);
          expect(platform.requests, hasLength(1));
          await tester.tapAt(buttonPosition);
          await tester.dragFrom(listPosition, const Offset(0, -200));
          await tester.pumpAndSettle();
          expect(taps, 1);
          expect(scrollController.offset, 0);
          expect(platform.pending.single.isCompleted, isFalse);

          if (completion == 'error') {
            platform.pending.single.completeError(
              PlatformException(code: 'POPUP_FAILED'),
            );
          } else {
            platform.pending.single.complete(
              completion == 'action'
                  ? {'url': 'https://example.invalid'}
                  : null,
            );
          }
          await call;
          await flush(tester);
          await tester.tapAt(buttonPosition);
          await tester.dragFrom(listPosition, const Offset(0, -200));
          await tester.pumpAndSettle();
          expect(taps, 2);
          expect(scrollController.offset, greaterThan(0));
          expect(clicks, completion == 'action' ? 1 : 0);
        }, () => MockClient((_) => response.future));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('blocks outside a nested navigator too', (tester) async {
    var taps = 0;
    late BuildContext nestedContext;
    await mount(
      tester,
      body: Row(
        children: [
          TextButton(
            onPressed: () => taps++,
            child: const Text('Outside navigator'),
          ),
          Expanded(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (value) {
                  nestedContext = value;
                  return const Scaffold();
                },
              ),
            ),
          ),
        ],
      ),
    );
    final position = tester.getCenter(find.text('Outside navigator'));
    await withResponse(() async {
      final call = Pam.appAttention(nestedContext);
      await flush(tester);
      expect(platform.requests, hasLength(1));
      await tester.tapAt(position);
      expect(taps, 0);
      platform.pending.single.complete(null);
      await call;
      await flush(tester);
      await tester.tapAt(position);
      expect(taps, 1);
    });
  });

  testWidgets('cleans up when the app unmounts while the popup is open', (
    tester,
  ) async {
    await mount(tester);
    await withResponse(() async {
      final call = Pam.appAttention(context);
      await flush(tester);
      expect(platform.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      platform.pending.single.complete(null);
      await call;
      await flush(tester);
      expect(tester.takeException(), isNull);

      await mount(tester);
      final next = Pam.appAttention(context);
      await flush(tester);
      expect(platform.requests, hasLength(2));
      platform.pending.last.complete(null);
      await next;
      await flush(tester);
    });
  });

  testWidgets(
    'skips all concurrent page names while loading and showing; no queue',
    (tester) async {
      await mount(tester);
      final response = Completer<http.Response>();
      var requestCount = 0;
      await http.runWithClient(
        () async {
          final first = Pam.appAttention(context, pageName: 'home');
          await Pam.appAttention(context, pageName: 'home');
          await Pam.appAttention(context, pageName: 'other');
          await flush(tester);
          expect(requestCount, 1);
          response.complete(http.Response('{"title":"offer"}', 200));
          await flush(tester);
          expect(platform.requests, hasLength(1));
          await Pam.appAttention(context, pageName: 'other');
          platform.pending[0].complete(null);
          await first;
          await flush(tester);
          expect(requestCount, 1);
          expect(platform.requests, hasLength(1));
        },
        () => MockClient((_) {
          requestCount++;
          return response.future;
        }),
      );

      await withResponse(() async {
        final next = Pam.appAttention(context, pageName: 'home');
        await flush(tester);
        expect(platform.requests, hasLength(2));
        platform.pending[1].complete(null);
        await next;
      });
    },
  );

  testWidgets(
    'default timeout allows an attention response slower than five seconds',
    (tester) async {
      await mount(tester);
      await http.runWithClient(
        () async {
          final call = Pam.appAttention(context, pageName: 'home');
          await flush(tester);
          await tester.pump(const Duration(seconds: 6));
          await flush(tester);
          expect(platform.requests, hasLength(1));
          platform.pending.single.complete(null);
          await call;
        },
        () => MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 6));
          return http.Response('{"title":"slow offer"}', 200);
        }),
      );
    },
  );

  testWidgets(
    'custom request timeout ignores a late response and releases the popup lock',
    (tester) async {
      await mount(tester);
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        final call = Pam.appAttention(
          context,
          requestTimeout: const Duration(seconds: 2),
        );
        await flush(tester);
        await tester.pump(const Duration(seconds: 2));
        await call;
        expect(platform.requests, isEmpty);
        response.complete(http.Response('{"title":"too late"}', 200));
        await flush(tester);
        expect(platform.requests, isEmpty);
      }, () => MockClient((_) => response.future));
      await withResponse(() async {
        final retry = Pam.appAttention(context);
        await flush(tester);
        expect(platform.requests, hasLength(1));
        platform.pending.single.complete(null);
        await retry;
      });
    },
  );

  for (final response in ['', '{}', 'null', '[]', '{invalid']) {
    testWidgets('releases lock after empty/invalid response: $response', (
      tester,
    ) async {
      await mount(tester);
      await withResponse(() => Pam.appAttention(context), response: response);
      await withResponse(() async {
        final call = Pam.appAttention(context);
        await flush(tester);
        expect(platform.requests, hasLength(1));
        platform.pending.single.complete(null);
        await call;
      });
    });
  }

  testWidgets('storage failures are contained and allow retry', (tester) async {
    await mount(tester);
    preference.fail = true;
    await Pam.appAttention(context);
    preference.fail = false;
    await withResponse(() async {
      final call = Pam.appAttention(context);
      await flush(tester);
      expect(platform.requests, hasLength(1));
      platform.pending.single.complete(null);
      await call;
    });
  });

  for (final change in ['unmount', 'cover', 'cover-and-return', 'reset']) {
    testWidgets('drops pending response after $change', (tester) async {
      await mount(tester);
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        final call = Pam.appAttention(context);
        await flush(tester);
        if (change == 'unmount') {
          await tester.pumpWidget(const SizedBox());
        } else if (change == 'reset') {
          await Pam.reset();
        } else {
          unawaited(
            navigator.push(
              MaterialPageRoute<void>(builder: (_) => const Scaffold()),
            ),
          );
          await tester.pumpAndSettle();
          if (change == 'cover-and-return') {
            navigator.pop();
            await tester.pumpAndSettle();
          }
        }
        response.complete(http.Response('{"title":"stale"}', 200));
        await call;
        expect(platform.requests, isEmpty);
      }, () => MockClient((_) => response.future));
    });
  }

  testWidgets(
    'native errors release lock; click callback runs once with overrides',
    (tester) async {
      await mount(tester);
      await withResponse(() async {
        final first = Pam.appAttention(context);
        await flush(tester);
        platform.pending[0].completeError(
          PlatformException(code: 'NO_PRESENTER'),
        );
        await first;
        var clicks = 0;
        final second = Pam.appAttention(
          context,
          actionButtonLabel: 'Offer',
          actionButtonColor: '#123456',
          actionButtonTextColor: '#FFFFFF',
          onBannerClick: (_) {
            clicks++;
            return true;
          },
        );
        await flush(tester);
        expect(platform.requests.last['action_button_label'], 'Offer');
        expect(platform.requests.last['action_button_color'], '#123456');
        expect(platform.requests.last['action_button_text_color'], '#FFFFFF');
        platform.pending[1].complete({'url': 'https://example.invalid'});
        await second;
        expect(clicks, 1);
      });
    },
  );

  testWidgets('API button settings take priority over code per field', (
    tester,
  ) async {
    await mount(tester);
    final apiSettings = {
      'title': 'Offer',
      'action_button_label': 'API label',
      'action_button_color': '#AABBCC',
      'action_button_text_color': '#112233',
    };
    await withResponse(() async {
      final call = Pam.appAttention(
        context,
        actionButtonLabel: 'Code label',
        actionButtonColor: '#000000',
        actionButtonTextColor: '#FFFFFF',
      );
      await flush(tester);
      expect(platform.requests.single, apiSettings);
      platform.pending.single.complete(null);
      await call;
    }, response: jsonEncode(apiSettings));
  });

  for (final blank in [null, '', '  \t\n']) {
    testWidgets('blank API settings ($blank) use code or native defaults', (
      tester,
    ) async {
      await mount(tester);
      final response = jsonEncode({
        'title': 'Offer',
        'action_button_label': blank,
        'action_button_color': blank,
        'action_button_text_color': blank,
      });
      await withResponse(() async {
        final first = Pam.appAttention(
          context,
          actionButtonLabel: 'Code label',
          actionButtonColor: '#0066FF',
          actionButtonTextColor: '#FFFFFF',
        );
        await flush(tester);
        expect(platform.requests[0]['action_button_label'], 'Code label');
        expect(platform.requests[0]['action_button_color'], '#0066FF');
        expect(platform.requests[0]['action_button_text_color'], '#FFFFFF');
        platform.pending[0].complete(null);
        await first;
        final second = Pam.appAttention(context);
        await flush(tester);
        expect(platform.requests[1], {'title': 'Offer'});
        platform.pending[1].complete(null);
        await second;
      }, response: response);
    });
  }

  testWidgets('mixed API settings use fallback independently', (tester) async {
    await mount(tester);
    await withResponse(
      () async {
        final call = Pam.appAttention(
          context,
          actionButtonLabel: 'Code label',
          actionButtonColor: '#0066FF',
          actionButtonTextColor: '#FFFFFF',
        );
        await flush(tester);
        expect(platform.requests.single, {
          'title': 'Offer',
          'action_button_label': 'API label',
          'action_button_color': '#0066FF',
          'action_button_text_color': '#FFFFFF',
        });
        platform.pending.single.complete(null);
        await call;
      },
      response:
          '{"title":"Offer","action_button_label":"API label","action_button_color":""}',
    );
  });

  testWidgets('ignores clicks from an old session', (tester) async {
    await mount(tester);
    await withResponse(() async {
      var clicks = 0;
      final call = Pam.appAttention(
        context,
        onBannerClick: (_) {
          clicks++;
          return true;
        },
      );
      await flush(tester);
      await Pam.reset();
      platform.pending.single.complete({'url': 'https://example.invalid'});
      await call;
      expect(clicks, 0);
    });
  });

  testWidgets('an explicit call from a click handler can open the next popup', (
    tester,
  ) async {
    await mount(tester);
    await withResponse(() async {
      Future<void>? next;
      final first = Pam.appAttention(
        context,
        onBannerClick: (_) {
          next = Pam.appAttention(context, pageName: 'next');
          return true;
        },
      );
      await flush(tester);
      platform.pending[0].complete({'url': 'https://example.invalid'});
      await first;
      await flush(tester);
      expect(platform.requests, hasLength(2));
      // Finishing the first call must not unlock the second popup.
      await Pam.appAttention(context, pageName: 'third');
      expect(platform.requests, hasLength(2));
      platform.pending[1].complete(null);
      await next;
    });
  });

  testWidgets('transport failures and thrown click callbacks allow retry', (
    tester,
  ) async {
    await mount(tester);
    await http.runWithClient(
      () => Pam.appAttention(context),
      () => MockClient((_) async => throw http.ClientException('Offline')),
    );
    await withResponse(() async {
      final first = Pam.appAttention(
        context,
        onBannerClick: (_) => throw StateError('Callback failed'),
      );
      await flush(tester);
      platform.pending[0].complete({'url': 'https://example.invalid'});
      await first;
      final second = Pam.appAttention(context);
      await flush(tester);
      expect(platform.requests, hasLength(2));
      platform.pending[1].complete(null);
      await second;
    });
  });
}
