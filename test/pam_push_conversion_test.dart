import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pam_flutter/pam.dart';

void main() {
  group('Pam.convertToPamPushMessage', () {
    const metadata = <String, dynamic>{
      'pixel': 'https://example.invalid/read',
      'popup_type': 'banner',
      'url': 'https://example.invalid/content',
      'click_tracking_url': 'https://example.invalid/click',
      'redirect_id': 'redirect-id',
      'custom_data': {'campaign': 'text-only'},
    };

    final cases = <String, Map<String, dynamic>>{
      'missing flex': {},
      'null flex': {'flex': null},
      'empty flex': {'flex': ''},
      'whitespace flex': {'flex': '   '},
      'text without an image': {'flex': '<p>Text-only notification</p>'},
      'empty image source': {'flex': '<img src="">'},
    };
    const expectedFlex = <String, String>{
      'missing flex': '',
      'null flex': '',
      'empty flex': '',
      'whitespace flex': '   ',
      'text without an image': '<p>Text-only notification</p>',
      'empty image source': '<img src="">',
    };

    for (final entry in cases.entries) {
      test('accepts ${entry.key} and preserves message data', () {
        final payload = {...metadata, ...entry.value};
        final message = Pam.convertToPamPushMessage({
          'pam': jsonEncode(payload),
        });

        expect(message, isNotNull);
        expect(message!.flex, expectedFlex[entry.key]);
        expect(message.thumbnailUrl, isEmpty);
        expect(message.pixel, metadata['pixel']);
        expect(message.popupType, metadata['popup_type']);
        expect(message.url, metadata['url']);
        expect(message.clickTrackingUrl, metadata['click_tracking_url']);
        expect(message.redirectId, metadata['redirect_id']);
        expect(message.isOpen, isFalse);
        expect(message.data, payload);
      });
    }

    test('still extracts the image URL from a non-empty flex', () {
      const flex = '<img src="https://example.invalid/banner.png">';
      final payload = {...metadata, 'flex': flex};
      final message = Pam.convertToPamPushMessage({'pam': jsonEncode(payload)});

      expect(message, isNotNull);
      expect(message!.flex, flex);
      expect(message.thumbnailUrl, 'https://example.invalid/banner.png');
      expect(message.data, payload);
    });
  });
}
