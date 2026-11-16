library;

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import './api/consent_api.dart';
import './api/crm_api.dart';
import './response/allow_consent.dart';
import './response/consent_message.dart';
import './response/consent_selection.dart';
import './response/pam_consent_result.dart';
import './ui/pam_consent_dialog.dart';
export './response/pam_consent_result.dart';
export './response/consent_selection.dart';
import './response/customer_consent_status.dart';
import './response/pam_response.dart';
import './api/push_notification_api.dart';
import './response/pam_push_message.dart';

import 'preferences.dart';
import 'dart:io' show Platform;
import './api/tracker_api.dart';
import 'package:flutter/services.dart';
import 'package:queue/queue.dart';
import 'dart:convert';
import 'pam_flutter_platform_interface.dart';
import 'pam_logging.dart';
import 'src/pam_log_writer.dart';
export 'pam_logging.dart' show PamLogCategory, PamLogLevel;
import 'package:url_launcher/url_launcher.dart';

import 'pam_track_event.dart';
import 'response/pam_batch_response.dart';
export 'pam_track_event.dart';
export 'response/pam_batch_response.dart';

typedef TrackerCallBack = Function(PamResponse);
typedef PamIdentityProvider = PamUserState Function();
typedef PamIdentityMismatchHandler =
    FutureOr<void> Function(PamIdentityMismatch mismatch);

class PamUserIdentity {
  final String value;

  const PamUserIdentity(this.value);
}

enum PamUserStateType { unknown, anonymous, identified }

class PamUserState {
  final PamUserStateType type;
  final PamUserIdentity? identity;

  const PamUserState._(this.type, this.identity);

  const PamUserState.unknown() : this._(PamUserStateType.unknown, null);

  const PamUserState.anonymous() : this._(PamUserStateType.anonymous, null);

  PamUserState.identified(String value)
    : this._(PamUserStateType.identified, PamUserIdentity(value));
}

enum PamIdentityMismatchType {
  loginRequired,
  logoutRequired,
  accountSwitchRequired,
}

class PamIdentityMismatch {
  final PamIdentityMismatchType type;
  final PamUserIdentity? oldIdentity;
  final PamUserIdentity? newIdentity;
  final String event;

  const PamIdentityMismatch({
    required this.type,
    required this.oldIdentity,
    required this.newIdentity,
    required this.event,
  });
}

enum PamPrimaryIdentityKey { customer, email, sms }

enum PamIdentityMatcherType { primary, secondary }

class PamIdentityMatcher {
  final PamIdentityMatcherType type;
  final String key;

  PamIdentityMatcher.primary(PamPrimaryIdentityKey key)
    : type = PamIdentityMatcherType.primary,
      key = key.name;

  PamIdentityMatcher.secondary(String key)
    : type = PamIdentityMatcherType.secondary,
      key = key {
    if (key.isEmpty) {
      throw ArgumentError.value(key, "key", "Secondary key cannot be empty.");
    }
  }

  bool get isSecondary => type == PamIdentityMatcherType.secondary;
}

class PamConfig {
  String pamServer, publicDBAlias, loginDBAlias, trackingConsentMessageID;
  bool enableLog, blockEventsIfNoConsent;
  final PamIdentityMatcher identityMatcher;
  PamIdentityProvider? identityProvider;
  PamIdentityMismatchHandler? onIdentityMismatch;

  PamConfig(
    this.pamServer,
    this.publicDBAlias,
    this.loginDBAlias,
    this.trackingConsentMessageID,
    this.enableLog, {
    required this.identityMatcher,
    this.blockEventsIfNoConsent = false,
    this.identityProvider,
    this.onIdentityMismatch,
  });
}

class SubmitConsentResult {
  Map<String, AllowConsentResult> result;
  String consentID;
  SubmitConsentResult(this.result, this.consentID);
}

enum TrackingStatus {
  /// The user has not yet received an authorization request dialog
  notDetermined,

  /// The device is restricted, tracking is disabled and the system can't show a request dialog
  restricted,

  /// The user denies authorization for tracking
  denied,

  /// The user authorizes access to tracking
  authorized,

  /// The platform is not iOS or the iOS version is below 14.0
  notSupported,
}

enum _TrackingSessionType { public, login }

class _TrackingDestination {
  final _TrackingSessionType sessionType;
  final String databaseAlias;
  final String? contactID;
  final String? customerID;
  final int sessionVersion;

  const _TrackingDestination({
    required this.sessionType,
    required this.databaseAlias,
    required this.contactID,
    required this.customerID,
    required this.sessionVersion,
  });
}

class Pam {
  //--STATIC --
  static var contactID = "";
  static var databaseAlias = "";
  static var customerID = "";

  static var shared = Pam();

  static Future<CustomerConsentStatus> loadConsentStatus(
    String consentMessageID,
  ) => shared._loadConsentStatus(consentMessageID);

  static Future<String?> getCustID() => shared._getCustID();

  static Future<void> initialize(PamConfig config) =>
      shared.init(config, config.enableLog);

  /// Forgets local user data while keeping the current app configuration.
  ///
  /// Waits for queued operations before clearing storage and memory. Does not
  /// send logout or delete server data. PAM remains ready to use with the same
  /// configuration and callbacks; initialize is not required again. Storage
  /// failures are thrown; in-memory user state is still cleared.
  static Future<void> reset() => shared._reset();

  /// Writes SDK logs with optional category and native severity.
  /// Existing calls default to General / INFO. Disabled by enableLog=false.
  static void log(
    List<Object?> args, {
    PamLogCategory category = PamLogCategory.general,
    PamLogLevel level = PamLogLevel.info,
  }) {
    if (!shared.isEnableLog) return;
    unawaited(PamLogWriter.write(args, category, level));
  }

  static Future<String?> getPlatformVersion() {
    return PamFlutterPlatform.instance.getPlatformVersion();
  }

  //iOS App Tracking Transparencyx
  static Future<TrackingStatus> get trackingAuthorizationStatus async {
    if (Platform.isIOS) {
      final int status = await PamFlutterPlatform.instance
          .getTrackingAuthorizationStatus();
      return TrackingStatus.values[status];
    }
    return TrackingStatus.notSupported;
  }

  static Future<TrackingStatus> requestTrackingAuthorization() async {
    if (Platform.isIOS) {
      final int status = await PamFlutterPlatform.instance
          .requestTrackingAuthorization();
      return TrackingStatus.values[status];
    }
    return TrackingStatus.notSupported;
  }

  static Future<String?> identifierForVendor() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return await PamFlutterPlatform.instance.identifierForVendor();
    }
    return "";
  }

  static bool isPushNotiFromPam(Map<String, dynamic> data) {
    return data.containsKey('pam');
  }

  static PamPushMessage? convertToPamPushMessage(Map<String, dynamic> data) {
    if (isPushNotiFromPam(data)) {
      final String pam = data["pam"];

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(pam);
      } catch (e) {
        Pam.log([e], category: PamLogCategory.push, level: PamLogLevel.error);
        return null;
      }

      final String flex = payload['flex'];
      RegExp regExp = RegExp(r'src="(.*?)"');
      String? match = regExp.firstMatch(flex)?.group(1);
      String banner = match?.toString() ?? "";
      String pixel = payload['pixel'] ?? "";
      String popupType = payload['popup_type'] ?? "";
      String url = payload['url'] ?? "";
      String? clickTrackingUrl = payload["click_tracking_url"];
      String? redirectId = payload["redirect_id"];

      var item = PamPushMessage(
        deliverID: "",
        pixel: pixel,
        title: "",
        description: "",
        thumbnailUrl: banner,
        flex: flex,
        url: url,
        popupType: popupType,
        date: DateTime.now(),
        isOpen: false,
        data: payload,
        clickTrackingUrl: clickTrackingUrl,
        redirectId: redirectId,
      );

      return item;
    }
    return null;
  }

  bool _consentScreenOpen = false;

  /// Opens the SDK's adaptive consent UI and saves only after confirmation.
  /// Status errors are treated as first consent; detail errors allow retry.
  /// Requires a Material app with a Navigator. Existing APIs are unchanged.
  static Future<PamConsentResult> showConsent(
    BuildContext context, {
    required String messageId,
    Locale? locale,
  }) async {
    final owner = shared;
    final config = owner.config;
    if (config == null) {
      throw StateError('Initialize PAM before showing consent.');
    }
    if (messageId.trim().isEmpty) {
      throw ArgumentError.value(messageId, 'messageId');
    }
    if (!context.mounted) throw StateError('The page is no longer mounted.');
    if (owner._consentScreenOpen) {
      throw StateError('A consent screen is already open.');
    }
    final sessionVersion = owner._sessionVersion;
    bool isCurrent() =>
        identical(shared, owner) &&
        identical(owner.config, config) &&
        owner._sessionVersion == sessionVersion;
    owner._consentScreenOpen = true;
    try {
      return await presentPamConsent(
        context,
        messageId: messageId,
        locale: locale,
        getContactId: owner.getContactID,
        loadStatus: () => owner._loadConsentStatus(messageId),
        loadMessage: () =>
            ConsentAPI(config.pamServer).loadConsentMessage(messageId),
        isSessionCurrent: isCurrent,
        save: (selection, sourceContactId) => owner._saveConsentSelection(
          selection,
          isSessionCurrent: isCurrent,
          sourceContactId: sourceContactId,
        ),
      );
    } finally {
      owner._consentScreenOpen = false;
    }
  }

  /// Saves selected permissions without loading the consent message first.
  /// Existing allow/submit APIs retain their original behavior.
  /// Throws on invalid choices, stale contact state, or a rejected request.
  static Future<SubmitConsentResult> saveConsent(ConsentSelection consent) =>
      shared._saveConsentSelection(consent);

  Future<SubmitConsentResult> _saveConsentSelection(
    ConsentSelection consent, {
    bool Function()? isSessionCurrent,
    String? sourceContactId,
  }) {
    final pam = this;
    return pam.queue.add(() async {
      void checkSession() {
        if (isSessionCurrent != null && !isSessionCurrent()) {
          throw const ConsentSaveException(
            'SESSION_CHANGED',
            'The active user has changed.',
          );
        }
      }

      // Initialization synchronizes consent in the background. Finish it before
      // saving so a late startup response cannot overwrite the new permission.
      await pam._consentSync;
      checkSession();
      if (pam.config == null) {
        throw StateError('Initialize PAM before saving consent.');
      }
      consent.validate();
      final contactId = await pam.getContactID();
      consent.validateForContact(contactId);
      if (sourceContactId != null && sourceContactId != contactId) {
        throw const ConsentSaveException(
          'SESSION_CHANGED',
          'The active contact has changed.',
        );
      }
      checkSession();
      final response = await pam.postTracker(
        'allow_consent',
        consent.toFormFields(),
      );
      checkSession();
      if (response.error != null) {
        throw ConsentSaveException(
          response.error!.code,
          response.error!.errorMessage,
        );
      }
      if (response.consentID == null || response.consentID!.isEmpty) {
        throw const ConsentSaveException(
          'MISSING_CONSENT_ID',
          'PAM did not return a consent record ID.',
        );
      }
      if (consent is TrackingConsent &&
          consent.messageId == pam.config!.trackingConsentMessageID) {
        await pam.setAllowTracking(consent.preferencesCookies);
      }
      final result = AllowConsentResult(
        response.contactID,
        response.database,
        response.consentID,
        response.consentMessageID,
      );
      return SubmitConsentResult({
        consent.messageId: result,
      }, response.consentID!);
    });
  }

  static Future<SubmitConsentResult?> allowConsent(
    String consentMessageId,
  ) async {
    var consentMessage = await loadConsentMessage(consentMessageId);
    consentMessage?.allowAll();
    if (consentMessage != null) {
      final result = await submitConsent(consentMessage);
      return result;
    }
    return null;
  }

  static Future<SubmitConsentResult?> allowAllTrackingConsent(
    String consentMessageId,
  ) async {
    return _submitAllConsent(consentMessageId, allowTrackingOnSuccess: true);
  }

  static Future<SubmitConsentResult?> allowAllContactingConsent(
    String consentMessageId,
  ) async {
    return _submitAllConsent(consentMessageId);
  }

  static Future<SubmitConsentResult?> _submitAllConsent(
    String consentMessageId, {
    bool allowTrackingOnSuccess = false,
  }) {
    return shared.queue.add(() async {
      var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
      Map<String, AllowConsentResult> consentResult = {};
      String ids = "";
      var result = await consentAPI.allowAllConsent(consentMessageId);
      if (result == null) {
        return null;
      }

      if (allowTrackingOnSuccess) {
        await shared.setAllowTracking(true);
      }

      consentResult = {consentMessageId: result};
      ids = result.consentID ?? "";
      return SubmitConsentResult(consentResult, ids);
    });
  }

  //iOS App Tracking Transparency

  static Future<List<PamPushMessage>?> loadPushNotificationsFromMobile(
    String mobileNumber,
  ) async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotificationsFromMobile(mobileNumber);
  }

  static Future<List<PamPushMessage>?> loadPushNotificationsFromEmail(
    String email,
  ) async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotificationsFromEmail(email);
  }

  static Future<List<PamPushMessage>?> loadPushNotificationsFromCustomerID(
    String customer,
  ) async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotificationsFromCustomerID(customer);
  }

  static Future<List<PamPushMessage>?> loadPushNotifications() async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotifications();
  }

  static bool _isWhitelistEvent(String? event) {
    return event == "login" ||
        event == "register" ||
        event == "register_success" ||
        event == "logout" ||
        event == "save_push" ||
        event == "test" ||
        event == "allow_consent";
  }

  static Future<PamResponse?> track(
    String event, {
    Map<String, dynamic>? payload,
    TrackerCallBack? callback,
  }) async {
    if (Pam.shared.config?.blockEventsIfNoConsent == true) {
      var isAllowTracking = shared.allowTracking || _isWhitelistEvent(event);
      if (!isAllowTracking) {
        Pam.log(
          [
            "No Track Event $event with Payload $payload. Because of usr not yet allow Preferences cookies.",
          ],
          category: PamLogCategory.tracking,
          level: PamLogLevel.warning,
        );
        return null;
      }
    }

    return await shared.queue.add(() async {
      var result = await _track(event, payload: payload, callback: callback);
      return result;
    });
  }

  /// Sends events for one current user in one request, without automatic retry.
  /// Returned results may be incomplete and must not be matched by index.
  /// Identity and database fields cannot override the current SDK destination.
  static Future<PamBatchResponse?> trackBatch(
    List<PamTrackEvent> events, {
    void Function(PamBatchResponse response)? callback,
  }) async {
    if (events.isEmpty) {
      throw ArgumentError.value(events, 'events', 'Cannot be empty.');
    }
    final snapshot = events
        .map(
          (entry) => PamTrackEvent(
            event: entry.event,
            payload: entry.payload == null
                ? null
                : Map<String, dynamic>.from(entry.payload!),
          ),
        )
        .toList();
    if (snapshot.any((entry) => entry.event.trim().isEmpty)) {
      throw ArgumentError('Event names cannot be empty.');
    }
    return shared.queue.add(() async {
      final pam = shared;
      final allowed = snapshot
          .where(
            (entry) =>
                pam.config?.blockEventsIfNoConsent != true ||
                pam.allowTracking ||
                _isWhitelistEvent(entry.event),
          )
          .toList();
      if (allowed.isEmpty) return null;
      final result = await pam._trackBatch(allowed);
      callback?.call(result);
      return result;
    });
  }

  Future<PamBatchResponse> _trackBatch(List<PamTrackEvent> events) async {
    try {
      for (final entry in events) {
        final failure =
            _createPausedTrackingResponse(entry.event) ??
            await _validateIdentityForTrack(entry.event);
        if (failure != null) return PamBatchResponse(error: failure.error);
      }
      final destination = await _createTrackingDestination();
      if (!isNotEmpty(destination.databaseAlias)) {
        return PamBatchResponse.failure(
          'TRACKING_DISABLED',
          'No database alias configured for the current session.',
        );
      }
      Future<bool> destinationIsCurrent() async {
        final current = await _createTrackingDestination();
        return current.sessionVersion == destination.sessionVersion &&
            current.sessionType == destination.sessionType &&
            current.customerID == destination.customerID &&
            current.databaseAlias == destination.databaseAlias &&
            current.contactID == destination.contactID;
      }

      final bodies = <Map<String, dynamic>>[];
      final identityFields = <String, dynamic>{
        '_database': destination.databaseAlias,
        if (isNotEmpty(destination.contactID))
          '_contact_id': destination.contactID,
        if (isNotEmpty(destination.customerID))
          ..._createIdentityPayload(destination.customerID!),
      };
      final protectedKeys = {
        '_contact_id',
        '_database',
        'customer',
        'email',
        'sms',
        '_key_name',
        '_key_value',
        '_force_create',
        config!.identityMatcher.key,
      };
      for (final entry in events) {
        for (final key in protectedKeys) {
          if (entry.payload?.containsKey(key) == true &&
              (!identityFields.containsKey(key) ||
                  entry.payload![key] != identityFields[key])) {
            return PamBatchResponse.failure(
              'BATCH_IDENTITY_CONFLICT',
              'Batch payload cannot override $key. Use the current SDK user.',
            );
          }
        }
        final body = await _createTrackingBodyForDestination(
          entry.event,
          entry.payload,
          destination,
        );
        (body['form_fields'] as Map<String, dynamic>).addAll(identityFields);
        bodies.add(body);
      }
      if (!await destinationIsCurrent()) {
        return PamBatchResponse.failure(
          'IDENTITY_STATE_MISMATCH',
          'The SDK user changed while preparing the batch.',
        );
      }
      final response =
          await trackerAPI?.postTrackerBatch({
            'form_fields': {'_database': destination.databaseAlias},
            if (!isNotEmpty(destination.contactID))
              '_use_first_contact_id_for_all_events': true,
            'events': bodies,
          }) ??
          PamBatchResponse.failure(
            'EMPTY_RESPONSE',
            'PAM return empty response.',
          );

      // A partial response must never make the SDK switch between contacts.
      final ids = response.results
          .map((result) => result.contactID)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final databaseConflict = response.results.any(
        (result) =>
            isNotEmpty(result.database) &&
            result.database != destination.databaseAlias,
      );
      if (databaseConflict ||
          ids.length > 1 ||
          (isNotEmpty(destination.contactID) &&
              ids.any((id) => id != destination.contactID))) {
        return PamBatchResponse(
          results: response.results,
          error: PamErrorResponse(
            code: 'BATCH_IDENTITY_CONFLICT',
            errorMessage:
                'Server returned conflicting contacts or databases. SDK contact was preserved.',
          ),
        );
      }
      // Late responses must not alter either identity or pause state of a new user.
      if (!await destinationIsCurrent()) return response;
      final failures = [
        if (response.error != null) response.error!,
        ...response.results
            .where((result) => result.error != null)
            .map((result) => result.error!),
      ];
      // Apply errors last so a partial success cannot clear a tracking pause.
      for (final result in response.results.where(
        (result) => result.error == null,
      )) {
        _applyTrackingResponsePolicy('batch', result);
      }
      for (final failure in failures) {
        _applyTrackingResponsePolicy('batch', PamResponse()..error = failure);
      }
      if (response.error == null &&
          ids.length == 1 &&
          response.results.any(
            (result) => result.error == null && result.contactID == ids.single,
          )) {
        await _saveContactID(ids.single, destination);
      }
      return response;
    } catch (error, stackTrace) {
      final failure = _createInternalErrorResponse(
        'BATCH TRACKING ERROR',
        error,
        stackTrace,
      );
      return PamBatchResponse(error: failure.error);
    }
  }

  static Future<PamResponse> _track(
    String event, {
    Map<String, dynamic>? payload,
    TrackerCallBack? callback,
  }) async {
    final pauseError = shared._createPausedTrackingResponse(event);
    if (pauseError != null) {
      callback?.call(pauseError);
      return pauseError;
    }

    final identityError = await shared._validateIdentityForTrack(event);
    if (identityError != null) {
      callback?.call(identityError);
      return identityError;
    }

    final res = await shared.postTracker(event, payload);
    callback?.call(res);
    return res;
  }

  static Future<PamResponse> setPushNotificationToken(
    String deviceToken,
  ) async {
    return await shared.setDeviceToken(deviceToken);
  }

  static Future<PamResponse> userLogin(String loginId) async {
    return await shared.trackUserLogin(loginId);
  }

  static Future<void> userLogout({Map<String, dynamic>? payload}) async {
    await shared.trackUserLogout(payload: payload);
  }

  static Future<ConsentMessage?> loadConsentMessage(
    String consentMessageID,
  ) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    return await consentAPI.loadConsentMessage(consentMessageID);
  }

  static Future<Map<String, ConsentMessage>> loadConsentMessages(
    List<String> consentMessageIDs,
  ) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    Map<String, ConsentMessage> result = {};

    await Future.wait(
      consentMessageIDs.map((id) async {
        var consentMessage = await consentAPI.loadConsentMessage(id);
        if (consentMessage != null) {
          result[id] = consentMessage;
        }
      }),
    );

    return result;
  }

  static Future<SubmitConsentResult> submitConsents(
    Map<String, ConsentMessage> consentMessages,
  ) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");

    return shared.queue.add(() async {
      Map<String, AllowConsentResult> consentResult = {};
      List<String> ids = [];

      await Future.wait(
        consentMessages.keys.map((aKey) async {
          var item = consentMessages[aKey];
          if (item != null) {
            var result = await consentAPI.submitConsent(item);
            if (result != null) {
              consentResult = {item.id ?? "x": result};
              ids.add(result.consentID ?? "");
            }
          }
        }),
      );

      return SubmitConsentResult(consentResult, ids.join(","));
    });
  }

  static Future<SubmitConsentResult> submitConsent(
    ConsentMessage consentMessage,
  ) async {
    return shared.queue.add(() async {
      var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
      Map<String, AllowConsentResult> consentResult = {};
      String ids = "";
      var result = await consentAPI.submitConsent(consentMessage);
      if (result != null) {
        consentResult = {consentMessage.id ?? "x": result};
        ids = result.consentID ?? "";
      }
      return SubmitConsentResult(consentResult, ids);
    });
  }

  static void onToken(Function(String)? onToken) {
    Pam.shared._onToken = onToken;
  }

  static bool _appAttentionBusy = false;

  /// Displays one App Attention at a time; concurrent calls are skipped.
  /// Closing never queues another popup: call this method again to try again.
  /// Results are ignored if the calling page or user session is no longer current.
  ///
  /// Button colors accept `#RRGGBB` (case insensitive). Invalid colors keep
  /// the native default. Non-empty API strings take priority over code values.
  /// Missing, null, or blank API fields fall back to code, then native defaults.
  static Future<void> appAttention(
    BuildContext context, {
    String pageName = "",
    String? actionButtonLabel,
    String? actionButtonColor,
    String? actionButtonTextColor,
    bool Function(Map<String, dynamic>? bannerData)? onBannerClick,
  }) async {
    void attentionLog(String message, {PamLogLevel level = PamLogLevel.debug}) {
      Pam.log(
        ['page=$pageName $message'],
        category: PamLogCategory.attention,
        level: level,
      );
    }

    if (_appAttentionBusy) {
      attentionLog('Request skipped reason=popup_busy');
      return;
    }
    if (!context.mounted) {
      attentionLog('Request skipped reason=page_unmounted');
      return;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      attentionLog('Request skipped reason=page_not_current');
      return;
    }
    _appAttentionBusy = true;
    var ownsLock = true;
    void releaseLock() {
      if (ownsLock) {
        ownsLock = false;
        _appAttentionBusy = false;
      }
    }

    final owner = shared;
    final version = owner._sessionVersion;
    final config = owner.config;
    var pageInvalidated = false;
    final secondaryAnimation = route?.secondaryAnimation;
    void onRouteCovered(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) pageInvalidated = true;
    }

    secondaryAnimation?.addStatusListener(onRouteCovered);
    bool isCurrent() =>
        context.mounted &&
        !pageInvalidated &&
        (route == null || route.isCurrent) &&
        identical(shared, owner) &&
        identical(owner.config, config) &&
        owner._sessionVersion == version;

    try {
      final api = CRMAPI(config?.pamServer ?? "");
      final attention = await api.getAppAttention(pageName);
      if (!isCurrent()) {
        attentionLog('Response ignored reason=stale_page_or_session');
        return;
      }
      if (attention == null || attention.isEmpty) {
        attentionLog('No popup reason=no_response');
        return;
      }
      final decoded = jsonDecode(attention);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        attentionLog('No popup reason=empty_or_non_object_response');
        return;
      }
      final json = Map<String, dynamic>.from(decoded);
      final buttonSources = <String, String>{};
      void applyButtonFallback(String key, String? fallback) {
        final apiValue = json[key];
        if (apiValue is String && apiValue.trim().isNotEmpty) {
          buttonSources[key] = 'api';
          return;
        }
        if (fallback != null) {
          buttonSources[key] = 'code';
          json[key] = fallback;
        } else {
          buttonSources[key] = 'default';
          json.remove(key);
        }
      }

      applyButtonFallback('action_button_label', actionButtonLabel);
      applyButtonFallback('action_button_color', actionButtonColor);
      applyButtonFallback('action_button_text_color', actionButtonTextColor);
      attentionLog(
        'Opening popup size=${json['size']} button_sources=$buttonSources',
      );
      final result = await PamFlutterPlatform.instance.appAttentionPopup(json);
      // Native completes only once the popup is gone. A click handler may
      // explicitly request a new popup without the old call unlocking it later.
      releaseLock();
      attentionLog(
        'Popup completed action=${result == null ? 'dismiss' : 'button'}',
        level: PamLogLevel.info,
      );
      if (!isCurrent()) {
        attentionLog('Click ignored reason=stale_page_or_session');
        return;
      }
      if (result == null) return;
      if (onBannerClick == null || !onBannerClick(result)) {
        final url = result["url"];
        if (url is! String || url.isEmpty) {
          attentionLog('Action skipped reason=no_url');
          return;
        }
        final uri = Uri.tryParse(url);
        if (uri == null) return;
        if (await canLaunchUrl(uri)) {
          if (isCurrent()) {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            attentionLog(
              'External action scheme=${uri.scheme} launched=$launched',
              level: launched ? PamLogLevel.info : PamLogLevel.warning,
            );
          }
        } else {
          attentionLog(
            'Action skipped reason=cannot_launch scheme=${uri.scheme}',
            level: PamLogLevel.warning,
          );
        }
      } else {
        attentionLog('Action handled_by=app', level: PamLogLevel.info);
      }
    } catch (error, stackTrace) {
      Pam.log(
        ["App Attention Error", stackTrace, error],
        category: PamLogCategory.attention,
        level: PamLogLevel.error,
      );
    } finally {
      secondaryAnimation?.removeStatusListener(onRouteCovered);
      releaseLock();
    }
  }

  //--STATIC --

  var isEnableLog = false;
  var allowTracking = false;
  var pref = UserPreference();

  final queue = Queue(parallel: 1);

  PamConfig? config;

  DateTime sessionExpire = DateTime(1983, 11, 14);
  String sessionID = "";
  String? publicContact, loginContact, deviceUDID, custID, pushToken;
  String? _lastIdentityMismatchFingerprint;
  String? _trackingPauseReasonCode;
  DateTime? _identityMismatchRetryAfter;
  DateTime? _trackingPausedUntil;
  int _sessionVersion = 0;

  @visibleForTesting
  Duration trackingPauseDuration = const Duration(hours: 1);

  TrackerAPI? trackerAPI;

  Function(String)? _onToken;
  Future<void>? _consentSync;

  Future<void> _reset() async {
    await queue.add(() async {
      Pam.log([
        'Reset started session_version=$_sessionVersion',
      ], category: PamLogCategory.storage);
      try {
        // Consent sync runs in the background, outside the tracking queue.
        await _consentSync;
        await pref.clear();
        Pam.log(['Reset storage cleared'], category: PamLogCategory.storage);
      } catch (error, stackTrace) {
        Pam.log(
          ['Reset storage cleanup failed', error, stackTrace],
          category: PamLogCategory.storage,
          level: PamLogLevel.error,
        );
        rethrow;
      } finally {
        _consentSync = null;
        _sessionVersion++;
        Pam.contactID = '';
        Pam.customerID = '';
        Pam.databaseAlias = '';
        publicContact = null;
        loginContact = null;
        custID = null;
        deviceUDID = null;
        pushToken = null;
        allowTracking = false;
        sessionID = '';
        sessionExpire = DateTime(1983, 11, 14);
        _resetIdentityMismatch();
        _clearTrackingPause();
        Pam.log([
          'Reset memory cleared session_version=$_sessionVersion',
        ], category: PamLogCategory.storage);
      }
    });
  }

  static Future<dynamic> methodsHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'onToken':
        var token = methodCall.arguments;
        Pam.log(
          [
            'Push token received callback_registered=${Pam.shared._onToken != null}',
          ],
          category: PamLogCategory.push,
          level: PamLogLevel.debug,
        );
        Pam.shared._onToken?.call(token);
        return '';
      default:
        return '';
    }
  }

  Future<void> init(PamConfig config, bool debug) async {
    WidgetsFlutterBinding.ensureInitialized();
    PamFlutterPlatform.instance.setOnPlatformCallback(methodsHandler);

    trackerAPI = TrackerAPI(config.pamServer);
    this.config = config;
    isEnableLog = debug;
    await PamLogWriter.configureNative(debug);
    Pam.log([
      'Initializing public_database=${config.publicDBAlias} login_database=${config.loginDBAlias} '
          'consent_message_id=${config.trackingConsentMessageID}',
    ], category: PamLogCategory.general);

    var allow = await pref.getBool(SaveKey.allowTracking);
    if (allow != null) {
      allowTracking = allow;
    }

    _consentSync = _syncConsentStatus(config.trackingConsentMessageID);
    unawaited(_consentSync);
    Pam.log([
      'Initialized consent_sync=background',
    ], category: PamLogCategory.general);
  }

  Future<CustomerConsentStatus> _loadConsentStatus(
    String consentMessageID,
  ) async {
    final status = await _fetchConsentStatus(consentMessageID);
    if (status != null) {
      return status;
    }

    var fallbackStatus = CustomerConsentStatus();
    fallbackStatus.needConsentReview = true;
    return fallbackStatus;
  }

  Future<CustomerConsentStatus?> _fetchConsentStatus(
    String consentMessageID,
  ) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    var contactID = await shared.getContactID() ?? '';
    if (contactID != '') {
      return consentAPI.loadConsentStatus(contactID, consentMessageID);
    }

    Pam.log(
      [
        "LOAD CONSENT STATUS",
        "Consent Message ID = $consentMessageID",
        "It's like it's the first time installing the app so there isn't any consent information yet.",
      ],
      category: PamLogCategory.consent,
      level: PamLogLevel.info,
    );
    return null;
  }

  Future<void> _syncConsentStatus(String consentMessageID) async {
    try {
      final status = await _fetchConsentStatus(consentMessageID);
      if (status == null) {
        return;
      }

      final isAllowPreferences =
          status.trackingPermission?.preferencesCookies ?? false;
      allowTracking = isAllowPreferences;
      await pref.saveBool(isAllowPreferences, SaveKey.allowTracking);
    } catch (error, stackTrace) {
      Pam.log(
        ["SYNC CONSENT STATUS ERROR", stackTrace, error],
        category: PamLogCategory.consent,
        level: PamLogLevel.error,
      );
    }
  }

  Future<void> setAllowTracking(bool allow) async {
    allowTracking = allow;
    await pref.saveBool(allow, SaveKey.allowTracking);
  }

  Future<void> _saveStringPreferenceSafely(
    String value,
    SaveKey key,
    String label,
  ) async {
    try {
      await pref.saveString(value, key);
    } catch (error, stackTrace) {
      Pam.log(
        [label, stackTrace, error],
        category: PamLogCategory.storage,
        level: PamLogLevel.error,
      );
    }
  }

  Future<void> _removePreferenceSafely(SaveKey key, String label) async {
    try {
      await pref.remove(key);
    } catch (error, stackTrace) {
      Pam.log(
        [label, stackTrace, error],
        category: PamLogCategory.storage,
        level: PamLogLevel.error,
      );
    }
  }

  Map<String, dynamic> _createIdentityPayload(String identityValue) {
    final matcher = config!.identityMatcher;
    if (!matcher.isSecondary) {
      return {matcher.key: identityValue};
    }

    return {
      "_key_name": matcher.key,
      "_key_value": identityValue,
      matcher.key: identityValue,
      "_force_create": false,
    };
  }

  Future<PamResponse> trackUserLogin(String custID) async {
    return await queue.add(() async {
      try {
        final loginPayload = _createIdentityPayload(custID);
        if (!isNotEmpty(config?.loginDBAlias)) {
          await _activateCustomer(custID);
          final destination = await _createTrackingDestination();
          return await _postTrackerTo("login", loginPayload, destination);
        }
        var notiKey = Platform.isAndroid
            ? "android_notification"
            : "ios_notification";
        var deletePayload = <String, dynamic>{
          "_delete_media": {notiKey: ""},
        };

        final previousDestination = await _createTrackingDestination();
        if (isNotEmpty(previousDestination.databaseAlias)) {
          final deleteResponse = await _postTrackerTo(
            "delete_media",
            deletePayload,
            previousDestination,
          );
          if (deleteResponse.error != null) {
            await _activateCustomer(custID);
            return deleteResponse;
          }
        }

        if (previousDestination.sessionType == _TrackingSessionType.public &&
            isNotEmpty(previousDestination.databaseAlias)) {
          final publicLoginResponse = await _postTrackerTo(
            "login",
            loginPayload,
            previousDestination,
          );
          if (publicLoginResponse.error != null) {
            await _activateCustomer(custID);
            return publicLoginResponse;
          }
        }

        await _activateCustomer(custID);

        final loginDestination = await _createTrackingDestination();
        final response = await _postTrackerTo(
          "login",
          loginPayload,
          loginDestination,
        );

        final push = await getPushToken();
        if (push != null && response.error == null) {
          await _setDeviceToken(push);
        }

        return response;
      } catch (error, stackTrace) {
        return _createInternalErrorResponse(
          "USER LOGIN ERROR",
          error,
          stackTrace,
          category: PamLogCategory.identity,
        );
      }
    });
  }

  Future<void> _activateCustomer(String customerID) async {
    final previousCustomerID = custID;
    final identityChanged =
        isNotEmpty(previousCustomerID) && previousCustomerID != customerID;
    if (identityChanged) {
      loginContact = null;
      await _removePreferenceSafely(
        SaveKey.loginContactID,
        "REMOVE LOGIN CONTACT ID ERROR",
      );
    }

    custID = customerID;
    Pam.customerID = customerID;
    _resetIdentityMismatch();
    _sessionVersion++;
    Pam.log([
      'Identity activated account_switch=$identityChanged session_version=$_sessionVersion',
    ], category: PamLogCategory.identity);
    await _saveStringPreferenceSafely(
      customerID,
      SaveKey.customerID,
      "SAVE CUSTOMER ID ERROR",
    );
  }

  Future<PamResponse> setDeviceToken(String deviceToken) async {
    return await queue.add(() async {
      try {
        return await _setDeviceToken(deviceToken);
      } catch (error, stackTrace) {
        return _createInternalErrorResponse(
          "SET PUSH TOKEN ERROR",
          error,
          stackTrace,
          category: PamLogCategory.push,
        );
      }
    });
  }

  Future<PamResponse> _setDeviceToken(String deviceToken) async {
    var saveToken = deviceToken;
    var mediaKey = "";
    if (Platform.isIOS) {
      if (!kReleaseMode) {
        saveToken = "_$deviceToken";
      }
      mediaKey = "ios_notification";
    } else {
      mediaKey = "android_notification";
    }
    pushToken = deviceToken;
    try {
      await pref.saveString(deviceToken, SaveKey.pushKey);
    } catch (error, stackTrace) {
      Pam.log(
        ["SAVE PUSH TOKEN ERROR", stackTrace, error],
        category: PamLogCategory.storage,
        level: PamLogLevel.error,
      );
    }

    var destination = await _createTrackingDestination();
    var res = await _postTrackerTo("save_push", {
      mediaKey: saveToken,
    }, destination);

    return res;
  }

  Future<void> trackUserLogout({Map<String, dynamic>? payload}) async {
    await queue.add(() async {
      try {
        var alias = (Platform.isIOS)
            ? "ios_notification"
            : "android_notification";
        var deletePayload = <String, dynamic>{
          "_delete_media": {alias: ""},
        };
        payload?.forEach((key, val) {
          deletePayload[key] = val;
        });

        final previousDestination = await _createTrackingDestination();
        final wasLoggedIn = isNotEmpty(await _getCustID());

        custID = null;
        loginContact = null;
        Pam.customerID = "";
        _resetIdentityMismatch();
        _sessionVersion++;
        Pam.log([
          'Identity cleared was_logged_in=$wasLoggedIn session_version=$_sessionVersion',
        ], category: PamLogCategory.identity);
        await _removePreferenceSafely(
          SaveKey.customerID,
          "REMOVE CUSTOMER ID ERROR",
        );
        await _removePreferenceSafely(
          SaveKey.loginContactID,
          "REMOVE LOGIN CONTACT ID ERROR",
        );

        if (!isNotEmpty(config?.loginDBAlias)) {
          if (wasLoggedIn) {
            await _postTrackerTo("logout", payload, previousDestination);
          }
          return;
        }

        final deleteResponse = await _postTrackerTo(
          "delete_media",
          deletePayload,
          previousDestination,
        );
        if (deleteResponse.error != null) {
          return;
        }

        if (wasLoggedIn) {
          await _postTrackerTo("logout", payload, previousDestination);
        }
      } catch (error, stackTrace) {
        _createInternalErrorResponse(
          "USER LOGOUT ERROR",
          error,
          stackTrace,
          category: PamLogCategory.identity,
        );
      }
    });
  }

  String getSessionID() {
    final now = DateTime.now();
    final difference = now.difference(sessionExpire).inMinutes;
    if (difference >= 60) {
      sessionExpire = DateTime.now().add(const Duration(minutes: 60));
      sessionID = genUUID();
      return sessionID;
    }
    return sessionID;
  }

  String genUUID() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));

    // Set the UUID version to 4 and the RFC 9562 variant to binary 10.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<String?> _getDeviceUDID() async {
    if (isNotEmpty(deviceUDID)) {
      return deviceUDID;
    }
    deviceUDID = await pref.getString(SaveKey.deviceUDID);
    if (deviceUDID == null) {
      deviceUDID = await Pam.identifierForVendor();
      if (isNotEmpty(deviceUDID)) {
        await pref.saveString(deviceUDID!, SaveKey.deviceUDID);
      }
    }
    return deviceUDID;
  }

  bool isNotEmpty(String? str) {
    if (str == null) return false;
    return str.isNotEmpty;
  }

  Future<String?> getPushToken() async {
    if (isNotEmpty(pushToken)) {
      return pushToken;
    }
    pushToken = await pref.getString(SaveKey.pushKey);
    if (isNotEmpty(pushToken)) {
      return pushToken;
    }
    return null;
  }

  Future<String?> getContactID() async {
    final destination = await _createTrackingDestination();
    Pam.contactID = destination.contactID ?? '';
    return destination.contactID;
  }

  Future<bool> isUserLogin() async {
    var ncustID = await _getCustID();
    return isNotEmpty(ncustID);
  }

  Future<String?> _getCustID() async {
    if (isNotEmpty(custID)) {
      return custID;
    }
    custID = await pref.getString(SaveKey.customerID);

    if (isNotEmpty(custID)) {
      Pam.customerID = custID ?? '';
      return custID;
    }
    return null;
  }

  Future<PamUserIdentity?> _getSdkIdentity() async {
    final customer = await _getCustID();
    if (!isNotEmpty(customer)) {
      return null;
    }

    return PamUserIdentity(customer!);
  }

  Future<PamResponse?> _validateIdentityForTrack(String event) async {
    final provider = config?.identityProvider;
    if (provider == null) {
      return null;
    }

    late PamUserState appState;
    try {
      appState = provider();
    } catch (error, stackTrace) {
      Pam.log(
        ["IDENTITY PROVIDER ERROR", stackTrace, error],
        category: PamLogCategory.identity,
        level: PamLogLevel.error,
      );
      return PamResponse.createErrorResponse(
        code: "IDENTITY_PROVIDER_ERROR",
        errorMessage: error.toString(),
      );
    }

    if (appState.type == PamUserStateType.unknown) {
      return null;
    }

    final newIdentity = appState.identity;
    if (appState.type == PamUserStateType.identified &&
        (newIdentity == null || newIdentity.value.isEmpty)) {
      return PamResponse.createErrorResponse(
        code: "IDENTITY_PROVIDER_ERROR",
        errorMessage:
            "The identity provider returned an invalid identified state.",
      );
    }

    final oldIdentity = await _getSdkIdentity();
    // No existing identity means this is an initial identity, not a mismatch.
    if (oldIdentity == null) {
      _resetIdentityMismatch();
      return null;
    }

    final isMatch = _isSameIdentity(oldIdentity, newIdentity);
    if (isMatch) {
      _resetIdentityMismatch();
      return null;
    }

    final mismatchType = newIdentity == null
        ? PamIdentityMismatchType.logoutRequired
        : PamIdentityMismatchType.accountSwitchRequired;
    final mismatch = PamIdentityMismatch(
      type: mismatchType,
      oldIdentity: oldIdentity,
      newIdentity: newIdentity,
      event: event,
    );
    final fingerprint = jsonEncode({
      "type": mismatchType.name,
      "old_value": oldIdentity.value,
      "new_value": newIdentity?.value,
    });

    final canRetryNotification =
        _identityMismatchRetryAfter != null &&
        !DateTime.now().isBefore(_identityMismatchRetryAfter!);
    if (_lastIdentityMismatchFingerprint != fingerprint ||
        canRetryNotification) {
      _lastIdentityMismatchFingerprint = fingerprint;
      _identityMismatchRetryAfter = null;
      Pam.log(
        [
          "IDENTITY STATE MISMATCH",
          "Type = ${mismatchType.name}",
          "Identity matcher = ${config?.identityMatcher.type.name}/${config?.identityMatcher.key}",
          "Old identity = ${oldIdentity.value}",
          "New identity = ${newIdentity?.value}",
          "Event $event was dropped.",
        ],
        category: PamLogCategory.identity,
        level: PamLogLevel.warning,
      );
      _notifyIdentityMismatch(mismatch, fingerprint);
    }

    return PamResponse.createErrorResponse(
      code: "IDENTITY_STATE_MISMATCH",
      errorMessage:
          "The app identity does not match the current PAM SDK identity.",
    );
  }

  bool _isSameIdentity(
    PamUserIdentity? oldIdentity,
    PamUserIdentity? newIdentity,
  ) {
    if (oldIdentity == null || newIdentity == null) {
      return oldIdentity == null && newIdentity == null;
    }
    return oldIdentity.value == newIdentity.value;
  }

  void _resetIdentityMismatch() {
    _identityMismatchRetryAfter = null;
    _lastIdentityMismatchFingerprint = null;
  }

  PamResponse? _createPausedTrackingResponse(String? event) {
    if (_isWhitelistEvent(event) || _trackingPausedUntil == null) {
      return null;
    }

    final now = DateTime.now();
    if (!now.isBefore(_trackingPausedUntil!)) {
      _clearTrackingPause();
      return null;
    }

    Pam.log(
      [
        "TRACKING PAUSED",
        "Event $event was dropped.",
        "Reason = $_trackingPauseReasonCode",
        "Retry after = $_trackingPausedUntil",
      ],
      category: PamLogCategory.tracking,
      level: PamLogLevel.warning,
    );
    return PamResponse.createErrorResponse(
      code: "TRACKING_PAUSED",
      errorMessage:
          "Tracking is paused until $_trackingPausedUntil because PAM returned $_trackingPauseReasonCode.",
    );
  }

  void _applyTrackingResponsePolicy(String? event, PamResponse response) {
    final errorCode = response.error?.code;
    if (errorCode == null) {
      if (_shouldClearTrackingPauseAfterSuccess(event)) {
        _clearTrackingPause();
      }
      return;
    }

    if (!_shouldPauseTrackingForErrorCode(errorCode)) {
      return;
    }

    _trackingPauseReasonCode = errorCode;
    _trackingPausedUntil = DateTime.now().add(trackingPauseDuration);
    Pam.log(
      [
        "TRACKING PAUSE STARTED",
        "Event = $event",
        "Reason = $errorCode",
        "Retry after = $_trackingPausedUntil",
      ],
      category: PamLogCategory.tracking,
      level: PamLogLevel.warning,
    );
  }

  bool _shouldPauseTrackingForErrorCode(String code) {
    return code == "UNAUTHORIZED" ||
        code == "CONTACT_NOT_FOUND" ||
        code == "CONSENT_MESSAGE_ID_IS_REQUIRED" ||
        code == "NEED_CONSENT_REVIEW" ||
        code == "TRACKING_IS_NOT_ALLOWED" ||
        code == "INVALID_EVENT";
  }

  bool _shouldClearTrackingPauseAfterSuccess(String? event) {
    return !_isWhitelistEvent(event) ||
        event == "login" ||
        event == "register" ||
        event == "register_success" ||
        event == "save_push" ||
        event == "allow_consent";
  }

  void _clearTrackingPause() {
    _trackingPausedUntil = null;
    _trackingPauseReasonCode = null;
  }

  void _notifyIdentityMismatch(
    PamIdentityMismatch mismatch,
    String fingerprint,
  ) {
    final handler = config?.onIdentityMismatch;
    if (handler == null) {
      return;
    }

    unawaited(
      Future<void>.microtask(() async {
        try {
          await handler(mismatch);
        } catch (error, stackTrace) {
          Pam.log(
            ["IDENTITY MISMATCH HANDLER ERROR", stackTrace, error],
            category: PamLogCategory.identity,
            level: PamLogLevel.error,
          );
          if (_lastIdentityMismatchFingerprint == fingerprint) {
            _identityMismatchRetryAfter = DateTime.now().add(
              const Duration(seconds: 30),
            );
          }
        }
      }),
    );
  }

  Future<String> getDatabaseAlias() async {
    final destination = await _createTrackingDestination();
    Pam.databaseAlias = destination.databaseAlias;
    return destination.databaseAlias;
  }

  Future<_TrackingDestination> _createTrackingDestination() async {
    final customer = await _getCustID();
    if (isNotEmpty(customer) && isNotEmpty(config?.loginDBAlias)) {
      if (!isNotEmpty(loginContact)) {
        loginContact = await pref.getString(SaveKey.loginContactID);
      }
      return _TrackingDestination(
        sessionType: _TrackingSessionType.login,
        databaseAlias: config?.loginDBAlias ?? "",
        contactID: loginContact,
        customerID: customer,
        sessionVersion: _sessionVersion,
      );
    }

    if (!isNotEmpty(publicContact)) {
      publicContact = await pref.getString(SaveKey.contactID);
    }
    return _TrackingDestination(
      sessionType: _TrackingSessionType.public,
      databaseAlias: config?.publicDBAlias ?? "",
      contactID: publicContact,
      customerID: customer,
      sessionVersion: _sessionVersion,
    );
  }

  Future<Map<String, dynamic>> createTrackingBody(
    String? event,
    Map<String, dynamic>? payload,
  ) async {
    final destination = await _createTrackingDestination();
    return _createTrackingBodyForDestination(event, payload, destination);
  }

  Future<Map<String, dynamic>> _createTrackingBodyForDestination(
    String? event,
    Map<String, dynamic>? payload,
    _TrackingDestination destination,
  ) async {
    const channel = MethodChannel('pam_flutter');
    final appInfo = await channel.invokeMapMethod<String, String>(
      'getTrackingAppInfo',
    );
    final osVersion = appInfo?['osVersion'] ?? '';
    final appName = appInfo?['appName'] ?? '';
    final appVersion = appInfo?['appVersion'] ?? '';
    final buildNumber = appInfo?['buildNumber'] ?? '';

    Map<String, dynamic> body = {
      "event": event,
      "platform": "$osVersion,  $appName: $appVersion($buildNumber)",
      "form_fields": [],
    };

    Pam.log(
      ["GET contact ID = ${destination.contactID}"],
      category: PamLogCategory.tracking,
      level: PamLogLevel.debug,
    );

    Map<String, dynamic> formField = {
      "os_version": osVersion,
      "app_version": appVersion,
      "_session_id": getSessionID(),
      "_consent_message_id": config?.trackingConsentMessageID,
      "_database": destination.databaseAlias,
    };

    final identityMatcher = config!.identityMatcher;
    final payloadHasIdentity =
        payload?.containsKey(identityMatcher.key) == true ||
        payload?.containsKey("_key_name") == true;
    final mustAddressExistingContact = event == "delete_media";
    if ((!payloadHasIdentity || mustAddressExistingContact) &&
        isNotEmpty(destination.contactID)) {
      formField["_contact_id"] = destination.contactID;
    }

    payload?.forEach((key, value) {
      if (key == "page_url" || key == "page_title") {
        body[key] = value;
      } else {
        formField[key] = value;
      }
    });

    if (isNotEmpty(destination.customerID)) {
      formField.addAll(_createIdentityPayload(destination.customerID!));
    }

    formField["uuid"] = await _getDeviceUDID();

    body["form_fields"] = formField;
    return body;
  }

  Future<void> _saveContactID(
    String? contactId,
    _TrackingDestination destination,
  ) async {
    if (contactId?.isEmpty ?? true) {
      return;
    }
    String cid = contactId ?? "";

    if (destination.sessionType == _TrackingSessionType.login) {
      if (destination.sessionVersion != _sessionVersion ||
          destination.customerID != custID) {
        Pam.log(
          [
            "Ignore stale logged-in contact ID = $cid",
            "Request session version = ${destination.sessionVersion}",
            "Current session version = $_sessionVersion",
          ],
          category: PamLogCategory.identity,
          level: PamLogLevel.warning,
        );
        return;
      }

      Pam.log(
        ["Save Logged-in contact ID = $cid"],
        category: PamLogCategory.storage,
        level: PamLogLevel.debug,
      );
      loginContact = cid;
      Pam.contactID = cid;
      await _saveStringPreferenceSafely(
        cid,
        SaveKey.loginContactID,
        "SAVE LOGIN CONTACT ID ERROR",
      );
      return;
    }

    Pam.log(
      ["Save Anonymous contact ID = $cid"],
      category: PamLogCategory.storage,
      level: PamLogLevel.debug,
    );
    publicContact = cid;
    if (destination.sessionVersion == _sessionVersion) {
      Pam.contactID = cid;
    }
    await _saveStringPreferenceSafely(
      cid,
      SaveKey.contactID,
      "SAVE PUBLIC CONTACT ID ERROR",
    );
  }

  Future<PamResponse> postTracker(
    String? event,
    Map<String, dynamic>? payload,
  ) async {
    try {
      final destination = await _createTrackingDestination();
      return await _postTrackerTo(event, payload, destination);
    } catch (error, stackTrace) {
      return _createInternalErrorResponse("TRACKING ERROR", error, stackTrace);
    }
  }

  Future<PamResponse> _postTrackerTo(
    String? event,
    Map<String, dynamic>? payload,
    _TrackingDestination destination,
  ) async {
    try {
      if (!isNotEmpty(destination.databaseAlias)) {
        Pam.log(
          [
            'Event skipped event=$event session=${destination.sessionType.name} reason=no_database_alias',
          ],
          category: PamLogCategory.tracking,
          level: PamLogLevel.warning,
        );
        return PamResponse.createErrorResponse(
          code: "TRACKING_DISABLED",
          errorMessage: "No database alias configured for the current session.",
        );
      }
      var body = await _createTrackingBodyForDestination(
        event,
        payload,
        destination,
      );

      var response = await trackerAPI?.postTracker(body);
      final effectiveResponse =
          response ??
          PamResponse.createErrorResponse(
            code: "EMPTY_RESPONSE",
            errorMessage: "PAM return empty response.",
          );

      Pam.log(
        [
          'Event completed event=$event database=${destination.databaseAlias} '
              'session=${destination.sessionType.name} session_version=${destination.sessionVersion} '
              'error_code=${effectiveResponse.error?.code ?? 'none'} '
              'error_message=${effectiveResponse.error?.errorMessage ?? ''}',
        ],
        category: PamLogCategory.tracking,
        level: effectiveResponse.error == null
            ? PamLogLevel.info
            : PamLogLevel.error,
      );

      _applyTrackingResponsePolicy(event, effectiveResponse);

      if (effectiveResponse.error == null) {
        await _saveContactID(effectiveResponse.contactID, destination);
      }

      return effectiveResponse;
    } catch (error, stackTrace) {
      Pam.log(
        ["TRACKING ERROR", stackTrace, error],
        category: PamLogCategory.tracking,
        level: PamLogLevel.error,
      );
      return PamResponse.createErrorResponse(
        code: "EXCEPTION",
        errorMessage: error.toString(),
      );
    }
  }

  PamResponse _createInternalErrorResponse(
    String label,
    Object error,
    StackTrace stackTrace, {
    PamLogCategory category = PamLogCategory.tracking,
  }) {
    Pam.log(
      [label, stackTrace, error],
      category: category,
      level: PamLogLevel.error,
    );
    return PamResponse.createErrorResponse(
      code: "EXCEPTION",
      errorMessage: error.toString(),
    );
  }
}
