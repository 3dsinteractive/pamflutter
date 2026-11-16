import 'dart:convert';

import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/consent_message.dart';
import 'package:pam_flutter/response/customer_consent_status.dart';
import 'package:pam_flutter/response/pam_push_message.dart';
import 'package:pam_flutter/response/pam_response.dart';

/// Display real response fields instead of "Instance of ..." in the demo.
Object? demoValue(Object? value) {
  if (value is PamConsentResult) {
    return {
      'outcome': value.outcome.name,
      'selection': value.selection?.toFormFields(),
      'submission': demoValue(value.submission),
    };
  }
  if (value is SubmitConsentResult) {
    return {
      'consent_id': value.consentID,
      'messages': value.result.map(
        (id, result) => MapEntry(id, {
          'consent_id': result.consentID,
          'consent_message_id': result.consentMessageID,
          'contact_id': result.contactID,
          'database': result.database,
        }),
      ),
    };
  }
  if (value is ConsentMessage) {
    return {
      'consent_message_id': value.id,
      'type': value.type?.name,
      'version': value.version,
      'available_languages': value.availableLanguages,
      'default_language': value.defaultLanguage,
      'display_text': {
        'th': value.displayText?.th,
        'en': value.displayText?.en,
        'jp': value.displayText?.jp,
      },
      'permissions': [
        for (final p in value.permission)
          {
            'name': p.name.key,
            'required': p.require,
            'allow': p.allow,
            'full_description_enabled': p.fullDescriptionEnabled,
          },
      ],
    };
  }
  if (value is CustomerConsentStatus) {
    final tracking = value.trackingPermission;
    final contacting = value.contactingPermission;
    return {
      'consent_id': value.consentId,
      'consent_message_id': value.consentMessageId,
      'contact_id': value.contactId,
      'consent_message_type': value.consentMessageType,
      'version': value.version,
      'latest_version': value.latestVersion,
      'need_consent_review': value.needConsentReview,
      'error': value.error == null
          ? null
          : {'code': value.error!.code, 'message': value.error!.errorMessage},
      if (tracking != null)
        'tracking_permission': {
          'terms_and_conditions': tracking.termsAndConditions,
          'privacy_overview': tracking.privacyOverview,
          'necessary_cookies': tracking.necessaryCookies,
          'preferences_cookies': tracking.preferencesCookies,
          'analytics_cookies': tracking.analyticsCookies,
          'marketing_cookies': tracking.marketingCookies,
          'social_media_cookies': tracking.socialMediaCookies,
        },
      if (contacting != null)
        'contacting_permission': {
          'terms_and_conditions': contacting.termsAndConditions,
          'privacy_overview': contacting.privacyOverview,
          'email': contacting.email,
          'sms': contacting.sms,
          'line': contacting.line,
          'facebook_messenger': contacting.facebookMessenger,
          'push_notification': contacting.webPush,
        },
    };
  }
  if (value is PamResponse) {
    return {
      'contact_id': value.contactID,
      'database': value.database,
      'consent_id': value.consentID,
      'error': value.error == null
          ? null
          : {'code': value.error!.code, 'message': value.error!.errorMessage},
    };
  }
  if (value is PamPushMessage) {
    return {
      'deliver_id': value.deliverID,
      'title': value.title,
      'description': value.description,
      'date': value.date.toIso8601String(),
      'is_open': value.isOpen,
      'url': value.url,
      'data': value.data,
    };
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), demoValue(item)));
  }
  if (value is Iterable) return value.map(demoValue).toList();
  if (value is Enum) return value.name;
  return value;
}

String formatDemoResult(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(demoValue(value));
