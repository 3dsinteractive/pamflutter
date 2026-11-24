import 'customer_consent_status.dart';

/// Version to record. Direct selections default to the latest server version.
final class ConsentVersion {
  final int? number;

  const ConsentVersion._latest() : number = null;
  const ConsentVersion.number(int value) : number = value;

  static const latest = ConsentVersion._latest();

  Object get value => number ?? 'latest';
}

/// The stored consent must be reviewed before its choices can be reused.
final class ConsentReviewRequiredException implements Exception {
  const ConsentReviewRequiredException();

  @override
  String toString() =>
      'Consent must be reviewed before reusing stored choices.';
}

/// A save failed; local tracking permission has not been updated.
final class ConsentSaveException implements Exception {
  final String? code;
  final String? message;

  const ConsentSaveException(this.code, this.message);

  @override
  String toString() => 'ConsentSaveException($code): $message';
}

/// An immutable, complete selection for one consent message.
sealed class ConsentSelection {
  final String messageId;
  final ConsentVersion version;
  final bool termsAndConditions;
  final bool privacyOverview;
  final String? _sourceContactId;

  const ConsentSelection({
    required this.messageId,
    required this.termsAndConditions,
    required this.privacyOverview,
    this.version = ConsentVersion.latest,
    String? sourceContactId,
  }) : _sourceContactId = sourceContactId;

  /// Checks required permissions without making a network request.
  void validate() {
    if (messageId.trim().isEmpty) {
      throw ArgumentError.value(messageId, 'messageId', 'Must not be empty');
    }
    if (version.number != null && version.number! <= 0) {
      throw ArgumentError.value(version.number, 'version', 'Must be positive');
    }
    if (!termsAndConditions || !privacyOverview) {
      throw ArgumentError(
        'Terms and conditions and privacy overview are required',
      );
    }
  }

  /// Prevents reusing a stored selection after changing the active contact.
  void validateForContact(String? contactId) {
    if (_sourceContactId != null && _sourceContactId != contactId) {
      throw StateError(
        'The active contact has changed. Reload consent status.',
      );
    }
  }

  /// Includes every permission belonging to this selection's consent type.
  Map<String, dynamic> toFormFields();
}

void _validateStatus(CustomerConsentStatus status, String type) {
  if (status.error != null ||
      status.consentMessageId == null ||
      status.consentMessageId!.trim().isEmpty ||
      status.consentId == null ||
      status.consentId!.trim().isEmpty ||
      status.contactId == null ||
      status.contactId!.trim().isEmpty) {
    throw StateError('No valid stored consent is available.');
  }
  if (status.consentMessageType != type) {
    throw ArgumentError('The stored consent has the wrong consent type.');
  }
  if (status.needConsentReview) {
    throw const ConsentReviewRequiredException();
  }
}

/// Choices for a tracking consent message.
final class TrackingConsent extends ConsentSelection {
  final bool necessaryCookies;
  final bool preferencesCookies;
  final bool analyticsCookies;
  final bool marketingCookies;
  final bool socialMediaCookies;

  const TrackingConsent({
    required super.messageId,
    required super.termsAndConditions,
    required super.privacyOverview,
    super.version,
    required this.necessaryCookies,
    this.preferencesCookies = false,
    this.analyticsCookies = false,
    this.marketingCookies = false,
    this.socialMediaCookies = false,
  });

  const TrackingConsent._({
    required super.messageId,
    required super.termsAndConditions,
    required super.privacyOverview,
    super.version,
    super.sourceContactId,
    required this.necessaryCookies,
    this.preferencesCookies = false,
    this.analyticsCookies = false,
    this.marketingCookies = false,
    this.socialMediaCookies = false,
  });

  /// Reuses a valid stored selection, targeting the latest version by default.
  /// Throws when review is needed or the status is missing/has the wrong type.
  factory TrackingConsent.fromStatus(CustomerConsentStatus status) {
    _validateStatus(status, 'tracking_type');
    final permission = status.trackingPermission;
    if (permission == null) {
      throw StateError('The stored consent has no permission data.');
    }
    return TrackingConsent._(
      messageId: status.consentMessageId!,
      sourceContactId: status.contactId,
      termsAndConditions: permission.termsAndConditions,
      privacyOverview: permission.privacyOverview,
      necessaryCookies: permission.necessaryCookies,
      preferencesCookies: permission.preferencesCookies,
      analyticsCookies: permission.analyticsCookies,
      marketingCookies: permission.marketingCookies,
      socialMediaCookies: permission.socialMediaCookies,
    );
  }

  /// Omitted values retain their previous choice, including explicit false.
  TrackingConsent copyWith({
    ConsentVersion? version,
    bool? termsAndConditions,
    bool? privacyOverview,
    bool? necessaryCookies,
    bool? preferencesCookies,
    bool? analyticsCookies,
    bool? marketingCookies,
    bool? socialMediaCookies,
  }) => TrackingConsent._(
    messageId: messageId,
    sourceContactId: _sourceContactId,
    version: version ?? this.version,
    termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    privacyOverview: privacyOverview ?? this.privacyOverview,
    necessaryCookies: necessaryCookies ?? this.necessaryCookies,
    preferencesCookies: preferencesCookies ?? this.preferencesCookies,
    analyticsCookies: analyticsCookies ?? this.analyticsCookies,
    marketingCookies: marketingCookies ?? this.marketingCookies,
    socialMediaCookies: socialMediaCookies ?? this.socialMediaCookies,
  );

  @override
  void validate() {
    super.validate();
    if (!necessaryCookies) {
      throw ArgumentError('Necessary cookies permission is required');
    }
  }

  @override
  Map<String, dynamic> toFormFields() => {
    '_consent_message_id': messageId,
    '_version': version.value,
    '_allow_terms_and_conditions': termsAndConditions,
    '_allow_privacy_overview': privacyOverview,
    '_allow_necessary_cookies': necessaryCookies,
    '_allow_preferences_cookies': preferencesCookies,
    '_allow_analytics_cookies': analyticsCookies,
    '_allow_marketing_cookies': marketingCookies,
    '_allow_social_media_cookies': socialMediaCookies,
  };
}

/// Choices for a contacting consent message.
final class ContactingConsent extends ConsentSelection {
  final bool email;
  final bool sms;
  final bool line;
  final bool facebookMessenger;
  final bool pushNotification;

  const ContactingConsent({
    required super.messageId,
    required super.termsAndConditions,
    required super.privacyOverview,
    super.version,
    this.email = false,
    this.sms = false,
    this.line = false,
    this.facebookMessenger = false,
    this.pushNotification = false,
  });

  const ContactingConsent._({
    required super.messageId,
    required super.termsAndConditions,
    required super.privacyOverview,
    super.version,
    super.sourceContactId,
    this.email = false,
    this.sms = false,
    this.line = false,
    this.facebookMessenger = false,
    this.pushNotification = false,
  });

  /// Reuses a valid stored selection, targeting the latest version by default.
  /// Throws when review is needed or the status is missing/has the wrong type.
  factory ContactingConsent.fromStatus(CustomerConsentStatus status) {
    _validateStatus(status, 'contacting_type');
    final permission = status.contactingPermission;
    if (permission == null) {
      throw StateError('The stored consent has no permission data.');
    }
    return ContactingConsent._(
      messageId: status.consentMessageId!,
      sourceContactId: status.contactId,
      termsAndConditions: permission.termsAndConditions,
      privacyOverview: permission.privacyOverview,
      email: permission.email,
      sms: permission.sms,
      line: permission.line,
      facebookMessenger: permission.facebookMessenger,
      pushNotification: permission.webPush,
    );
  }

  /// Omitted values retain their previous choice, including explicit false.
  ContactingConsent copyWith({
    ConsentVersion? version,
    bool? termsAndConditions,
    bool? privacyOverview,
    bool? email,
    bool? sms,
    bool? line,
    bool? facebookMessenger,
    bool? pushNotification,
  }) => ContactingConsent._(
    messageId: messageId,
    sourceContactId: _sourceContactId,
    version: version ?? this.version,
    termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    privacyOverview: privacyOverview ?? this.privacyOverview,
    email: email ?? this.email,
    sms: sms ?? this.sms,
    line: line ?? this.line,
    facebookMessenger: facebookMessenger ?? this.facebookMessenger,
    pushNotification: pushNotification ?? this.pushNotification,
  );

  @override
  Map<String, dynamic> toFormFields() => {
    '_consent_message_id': messageId,
    '_version': version.value,
    '_allow_terms_and_conditions': termsAndConditions,
    '_allow_privacy_overview': privacyOverview,
    '_allow_email': email,
    '_allow_sms': sms,
    '_allow_line': line,
    '_allow_facebook_messenger': facebookMessenger,
    '_allow_push_notification': pushNotification,
  };
}
