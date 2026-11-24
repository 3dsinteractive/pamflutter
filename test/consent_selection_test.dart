import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/customer_consent_status.dart';
import 'package:pam_flutter/response/pam_response.dart';

CustomerConsentStatus storedStatus({bool tracking = false}) =>
    CustomerConsentStatus.parse(
      jsonEncode({
        'consent_id': 'record',
        'consent_message_id': 'message',
        'contact_id': 'contact',
        'consent_message_type': tracking ? 'tracking_type' : 'contacting_type',
        'version': 2,
        'last_consent_version': 2,
        'latest_version': 3,
        'need_consent_review': false,
        if (tracking)
          'tracking_permission': {
            'terms_and_conditions': true,
            'privacy_overview': true,
            'necessary_cookies': true,
            'preferences_cookies': true,
            'analytics_cookies': false,
            'marketing_cookies': true,
            'social_media_cookies': false,
          }
        else
          'contacting_permission': {
            'terms_and_conditions': true,
            'privacy_overview': true,
            'email': true,
            'sms': false,
            'line': true,
            'facebook_messenger': false,
            'push_notification': true,
          },
      }),
    )!;

void main() {
  test(
    'new selections default optional choices to false and version to latest',
    () {
      const consent = ContactingConsent(
        messageId: 'message',
        termsAndConditions: true,
        privacyOverview: true,
        email: true,
      );
      expect(consent.toFormFields(), {
        '_consent_message_id': 'message',
        '_version': 'latest',
        '_allow_terms_and_conditions': true,
        '_allow_privacy_overview': true,
        '_allow_email': true,
        '_allow_sms': false,
        '_allow_line': false,
        '_allow_facebook_messenger': false,
        '_allow_push_notification': false,
      });
    },
  );

  test(
    'editing contacting status preserves all other choices and explicit false',
    () {
      final original = ContactingConsent.fromStatus(storedStatus());
      final updated = original.copyWith(sms: true, email: false);
      expect(updated.sms, isTrue);
      expect(updated.email, isFalse);
      expect(updated.line, isTrue);
      expect(updated.pushNotification, isTrue);
      expect(original.sms, isFalse);
      expect(original.email, isTrue);
      expect(updated.version.value, 'latest');
      expect(
        () => updated.validateForContact('someone-else'),
        throwsStateError,
      );
      updated.validateForContact('contact');
    },
  );

  test(
    'tracking edits preserve required choices and support explicit version',
    () {
      final original = TrackingConsent.fromStatus(storedStatus(tracking: true));
      final updated = original.copyWith(
        preferencesCookies: false,
        version: const ConsentVersion.number(2),
      );
      expect(updated.necessaryCookies, isTrue);
      expect(updated.preferencesCookies, isFalse);
      expect(updated.marketingCookies, isTrue);
      expect(updated.analyticsCookies, isFalse);
      expect(updated.toFormFields()['_version'], 2);
      expect(updated.toFormFields(), isNot(contains('_allow_email')));
      expect(original.preferencesCookies, isTrue);
    },
  );

  test('fromStatus rejects review, missing data, errors, and wrong types', () {
    final status = storedStatus()..needConsentReview = true;
    expect(
      () => ContactingConsent.fromStatus(status),
      throwsA(isA<ConsentReviewRequiredException>()),
    );
    expect(
      () => TrackingConsent.fromStatus(storedStatus()),
      throwsArgumentError,
    );
    expect(
      () => ContactingConsent.fromStatus(storedStatus(tracking: true)),
      throwsArgumentError,
    );
    expect(
      () => ContactingConsent.fromStatus(CustomerConsentStatus()),
      throwsStateError,
    );
    status
      ..needConsentReview = false
      ..error = PamErrorResponse(code: 'FAIL', errorMessage: 'Failed');
    expect(() => ContactingConsent.fromStatus(status), throwsStateError);
    expect(
      () => ContactingConsent.fromStatus(
        storedStatus()..contactingPermission = null,
      ),
      throwsStateError,
    );
  });

  test('required choices, empty IDs and invalid versions fail validation', () {
    const consent = TrackingConsent(
      messageId: 'message',
      termsAndConditions: true,
      privacyOverview: true,
      necessaryCookies: true,
    );
    expect(
      () => consent.copyWith(necessaryCookies: false).validate(),
      throwsArgumentError,
    );
    expect(
      () => consent.copyWith(termsAndConditions: false).validate(),
      throwsArgumentError,
    );
    expect(
      () => consent.copyWith(privacyOverview: false).validate(),
      throwsArgumentError,
    );
    expect(
      () =>
          consent.copyWith(version: const ConsentVersion.number(0)).validate(),
      throwsArgumentError,
    );
    expect(
      () => const ContactingConsent(
        messageId: '',
        termsAndConditions: true,
        privacyOverview: true,
      ).validate(),
      throwsArgumentError,
    );
  });

  test(
    'status keeps both versions and accepts legacy and current push keys',
    () {
      final status = storedStatus();
      expect(status.lastConsentVersion, 2);
      expect(status.latestVersion, '3');
      expect(status.contactingPermission!.webPush, isTrue);
      final legacy = CustomerConsentStatus.parse(
        jsonEncode({
          'contacting_permission': {'web_push': true},
        }),
      )!;
      expect(legacy.contactingPermission!.webPush, isTrue);
      final current = CustomerConsentStatus.parse(
        jsonEncode({
          'contacting_permission': {
            'web_push': true,
            'push_notification': false,
          },
        }),
      )!;
      expect(current.contactingPermission!.webPush, isFalse);
    },
  );
}
