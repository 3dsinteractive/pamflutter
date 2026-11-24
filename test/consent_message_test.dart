import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pam_flutter/response/consent_message.dart';

void main() {
  final payload = <String, dynamic>{
    'consent_message_id': 'message',
    'consent_message_type': 'tracking_type',
    'style_configuration': {
      'bar_background_color': '#FFFFFF',
      'bar_text_color': '#14203D',
      'bar_background_opacity_percentage': 50,
      'button_background_color': '#123456',
      'button_text_color': '#E5C09F',
      'consent_detail': {
        'popup_main_icon': 'gdpr',
        'primary_color': '#14203D',
        'secondary_color': '#336699',
        'button_text_color': '#E5C09F',
        'text_color': '#000000',
      },
    },
    'setting': {
      'version': 1,
      'display_text': {'en': 'Description', 'th': 'คำอธิบาย'},
      'available_languages': ['en', 'th'],
      'default_language': 'th',
      'analytics_cookies': {
        'is_enabled': true,
        'brief_description': {'en': 'Analytics'},
        'is_full_description_enabled': true,
        'full_description': {'en': '<h1>Analytics</h1><p>Details</p>'},
      },
      'marketing_cookies': {'is_enabled': false},
    },
  };

  test(
    'localized text supports sparse language keys and the original constructor',
    () {
      final onlyJapanese = LocalizeText.fromJson({'jp': '日本語のみ'});
      expect(onlyJapanese.en, isNull);
      expect(onlyJapanese.th, isNull);
      expect(onlyJapanese.jp, '日本語のみ');
      expect(onlyJapanese.get(Lang.jp), '日本語のみ');
      expect(onlyJapanese.get(Lang.en), '日本語のみ');
      expect(onlyJapanese.forLanguage('ja'), '日本語のみ');
      expect(onlyJapanese.availableLanguages, ['jp']);
      final original = LocalizeText('English', 'ไทย');
      expect(original.get(Lang.en), 'English');
      expect(original.get(Lang.th), 'ไทย');
      expect(original.jp, isNull);
      expect(LocalizeText.fromJson({}).get(Lang.jp), isNull);
    },
  );

  test(
    'missing selected language consistently falls back to Thai then English then Japanese',
    () {
      expect(LocalizeText('English', 'ไทย').get(Lang.jp), 'ไทย');
      expect(LocalizeText('English', null).get(Lang.jp), 'English');
      expect(LocalizeText(null, null, '日本語').get(Lang.th), '日本語');
      expect(LocalizeText('', 'ไทย', '   ').get(Lang.jp), 'ไทย');
      expect(LocalizeText('English', 'ไทย', '日本語').get(Lang.jp), '日本語');
    },
  );

  for (final contacting in [false, true]) {
    for (final enveloped in [false, true]) {
      test(
        'reads actual ${contacting ? "contacting" : "tracking"} sample, envelope=$enveloped',
        () {
          final json =
              jsonDecode(
                    File(
                      'test/fixtures/consent_${contacting ? "contacting" : "tracking"}.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>;
          final message = ConsentMessage.fromJson(
            enveloped ? {'data': json} : json,
          );
          expect(
            message.type,
            contacting ? ConsentType.contacting : ConsentType.tracking,
          );
          expect(message.permission, hasLength(7));
          expect(message.availableLanguages, ['th']);
          expect(message.displayText!.en, isNull);
          expect(message.displayText!.jp, isNull);
          expect(message.displayText!.th, isNotEmpty);
          expect(
            message.permission.map((p) => p.name),
            contacting
                ? [
                    ConsentPermissionName.termsAndConditions,
                    ConsentPermissionName.privacyOverview,
                    ConsentPermissionName.email,
                    ConsentPermissionName.sms,
                    ConsentPermissionName.line,
                    ConsentPermissionName.facebookMessenger,
                    ConsentPermissionName.pushNotification,
                  ]
                : ConsentPermissionName.values.take(7).toList(),
          );
          for (final permission in message.permission) {
            expect(permission.fullDescriptionEnabled, isTrue);
            expect(permission.shortDescription!.availableLanguages, ['th']);
            expect(permission.fullDescription!.th, startsWith('<p>'));
          }
        },
      );
    }
  }

  for (final enveloped in [false, true]) {
    test(
      'reads ${enveloped ? "enveloped" : "legacy"} consent with optional fields omitted',
      () {
        final message = ConsentMessage.parse(
          jsonEncode(enveloped ? {'data': payload} : payload),
        )!;
        expect(message.id, 'message');
        expect(message.version, 1);
        expect(message.type, ConsentType.tracking);
        expect(message.style!.barBackgroundOpacity, 0.5);
        expect(message.style!.buttonBackgroundColor, const Color(0xFF123456));
        expect(message.style!.dialogStyle!.icon, 'gdpr');
        expect(
          message.style!.dialogStyle!.secondaryColor,
          const Color(0xFF336699),
        );
        expect(message.permission, hasLength(1));
        expect(message.permission.single.shortDescription!.th, isNull);
        expect(message.permission.single.fullDescription!.en, contains('<h1>'));
        expect(message.moreInfoButtonText, isNull);
      },
    );
  }

  test(
    'invalid colors and missing dialog configuration use fallback colors',
    () {
      final style = ConsentStyleConfiguration.parse({
        'bar_background_color': '#garbage',
        'button_text_color': '',
        'bar_background_opacity_percentage': 150,
      })!;
      expect(style.backgroundColor, const Color(0xFFFFFFFF));
      expect(style.buttonTextColor, const Color(0xFFFFFFFF));
      expect(style.barBackgroundOpacity, 1);
      expect(style.dialogStyle!.primaryColor, const Color(0xFF14203D));
    },
  );
}
