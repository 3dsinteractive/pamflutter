import 'dart:convert';
import './pam_response.dart' show PamErrorResponse;

class CustomerConsentStatus {
  String? consentId;
  String? consentMessageId;
  String? contactId;
  String? consentMessageType;
  int? version;
  TrackingPermission? trackingPermission;
  ContactingPermission? contactingPermission;
  int? lastConsentVersion;
  String? latestVersion;
  String? lastConsentAt;
  bool needConsentReview = true;
  String? createdAt;
  String? updatedAt;
  PamErrorResponse? error;

  static bool _getBool(Map<String, dynamic> map, String key) {
    return map[key] ?? false;
  }

  static CustomerConsentStatus parse(String jsonString) {
    Map<String, dynamic> map = jsonDecode(jsonString);

    var model = CustomerConsentStatus();

    final code = map['code'];
    final errorMessage = map["message"];

    if (code != null) {
      model.error = PamErrorResponse(code: code, errorMessage: errorMessage);
    }

    model.consentId = map['consent_id'];
    model.consentMessageId = map['consent_message_id'];
    model.contactId = map['contact_id'];
    model.consentMessageType = map['consent_message_type'];
    model.version = map['version'];
    model.createdAt = map['created_at'];
    model.updatedAt = map['updated_at'];
    model.lastConsentVersion = map['last_consent_version'];
    model.lastConsentVersion = map['latest_version'];
    model.lastConsentAt = map['last_consent_at'];
    model.needConsentReview = map['need_consent_review'] ?? true;

    if (map.containsKey("tracking_permission")) {
      if (map["tracking_permission"] != null) {
        var perms = map["tracking_permission"] ?? <String, dynamic>{};
        bool termsAndConditions = _getBool(perms, "terms_and_conditions");
        bool privacyOverview = _getBool(perms, "privacy_overview");
        bool necessaryCookies = _getBool(perms, "necessary_cookies");
        bool preferencesCookies = _getBool(perms, "preferences_cookies");
        bool analyticsCookies = _getBool(perms, "analytics_cookies");
        bool marketingCookies = _getBool(perms, "marketing_cookies");
        bool socialMediaCookies = _getBool(perms, "social_media_cookies");
        model.trackingPermission = TrackingPermission(
            termsAndConditions: termsAndConditions,
            privacyOverview: privacyOverview,
            necessaryCookies: necessaryCookies,
            preferencesCookies: preferencesCookies,
            analyticsCookies: analyticsCookies,
            marketingCookies: marketingCookies,
            socialMediaCookies: socialMediaCookies);
      }
    }

    if (map.containsKey("contacting_permission")) {
      if (map["contacting_permission"] != null) {
        var perms = map["contacting_permission"] ?? <String, dynamic>{};

        bool termsAndConditions = _getBool(perms, "terms_and_conditions");
        bool privacyOverview = _getBool(perms, "privacy_overview");
        bool email = _getBool(perms, "email");
        bool sms = _getBool(perms, "sms");
        bool line = _getBool(perms, "line");
        bool facebookMessenger = _getBool(perms, "facebook_messenger");
        bool webPush = _getBool(perms, "web_push");

        model.contactingPermission = ContactingPermission(
            termsAndConditions: termsAndConditions,
            privacyOverview: privacyOverview,
            email: email,
            sms: sms,
            line: line,
            facebookMessenger: facebookMessenger,
            webPush: webPush);
      }
    }

    return model;
  }
}

class TrackingPermission {
  bool termsAndConditions;
  bool privacyOverview;
  bool necessaryCookies;
  bool preferencesCookies;
  bool analyticsCookies;
  bool marketingCookies;
  bool socialMediaCookies;

  TrackingPermission({
    required this.termsAndConditions,
    required this.privacyOverview,
    required this.necessaryCookies,
    required this.preferencesCookies,
    required this.analyticsCookies,
    required this.marketingCookies,
    required this.socialMediaCookies,
  });
}

class ContactingPermission {
  bool termsAndConditions;
  bool privacyOverview;
  bool email;
  bool sms;
  bool line;
  bool facebookMessenger;
  bool webPush;

  ContactingPermission({
    required this.termsAndConditions,
    required this.privacyOverview,
    required this.email,
    required this.sms,
    required this.line,
    required this.facebookMessenger,
    required this.webPush,
  });
}
