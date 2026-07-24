library;

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import './api/consent_api.dart';
import './api/crm_api.dart';
import './response/allow_consent.dart';
import './response/consent_message.dart';
import './response/customer_consent_status.dart';
import './response/pam_response.dart';
import './api/push_notification_api.dart';
import './response/pam_push_message.dart';

import 'preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'dart:io' show Platform;
import 'package:uuid/uuid.dart';
import './api/tracker_api.dart';
import 'package:flutter/services.dart';
import 'package:queue/queue.dart';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'pam_flutter_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

typedef TrackerCallBack = Function(PamResponse);

class LoginOptions {
  late String? alternateKey;
  LoginOptions({this.alternateKey});
}

class PamConfig {
  String pamServer,
      publicDBAlias,
      loginDBAlias,
      loginKey,
      trackingConsentMessageID;
  bool enableLog, blockEventsIfNoConsent;

  PamConfig(
    this.pamServer,
    this.publicDBAlias,
    this.loginDBAlias,
    this.trackingConsentMessageID,
    this.enableLog, {
    this.loginKey = "",
    this.blockEventsIfNoConsent = false,
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
          String consentMessageID) =>
      shared._loadConsentStatus(consentMessageID);

  static Future<String?> getCustID() => shared._getCustID();

  static Future<void> initialize(PamConfig config) =>
      shared.init(config, config.enableLog);

  static void log(List<Object?> args) {
    if (!shared.isEnableLog) return;

    const spliter = "◦🦄◦🦄◦🦄◦PAM◦🦄◦🦄◦🦄◦";

    final stringList = args.map((e) => e?.toString() ?? "<null>");
    final content = stringList.join("\n");

    debugPrint("\n$spliter\n\n$content\n\n$spliter\n");
  }

  static Future<String?> getPlatformVersion() {
    return PamFlutterPlatform.instance.getPlatformVersion();
  }

  //iOS App Tracking Transparencyx
  static Future<TrackingStatus> get trackingAuthorizationStatus async {
    if (Platform.isIOS) {
      final int status =
          await PamFlutterPlatform.instance.getTrackingAuthorizationStatus();
      return TrackingStatus.values[status];
    }
    return TrackingStatus.notSupported;
  }

  static Future<TrackingStatus> requestTrackingAuthorization() async {
    if (Platform.isIOS) {
      final int status =
          await PamFlutterPlatform.instance.requestTrackingAuthorization();
      return TrackingStatus.values[status];
    }
    return TrackingStatus.notSupported;
  }

  static Future<String?> identifierForVendor() async {
    if (Platform.isIOS) {
      return await PamFlutterPlatform.instance.identifierForVendor();
    } else if (Platform.isAndroid) {
      const androidIdPlugin = AndroidId();
      return await androidIdPlugin.getId();
    }
    return "";
  }

  static bool isPushNotiFromPam(RemoteMessage message) {
    return message.data.containsKey('pam');
  }

  static PamPushMessage? convertToPamPushMessage(RemoteMessage message) {
    if (isPushNotiFromPam(message)) {
      var data = message.data;
      final String pam = data["pam"];

      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(pam);
      } catch (e) {
        Pam.log([e]);
        return null;
      }

      final String flex = payload['flex'];
      RegExp regExp = RegExp(r'src="(.*?)"');
      String? match = regExp.firstMatch(flex)?.group(1);
      String banner = match?.toString() ?? "";
      String pixel = payload['pixel'] ?? "";
      String popupType = payload['popup_type'] ?? "";
      String url = payload['url'] ?? "";
      String title = message.notification?.title ?? "";
      String description = message.notification?.body ?? "";

      String? clickTrackingUrl = payload["click_tracking_url"];
      String? redirectId = payload["redirect_id"];

      var item = PamPushMessage(
          deliverID: "",
          pixel: pixel,
          title: title,
          description: description,
          thumbnailUrl: banner,
          flex: flex,
          url: url,
          popupType: popupType,
          date: DateTime.now(),
          isOpen: false,
          data: payload,
          clickTrackingUrl: clickTrackingUrl,
          redirectId: redirectId);

      return item;
    }
    return null;
  }

  static Future<SubmitConsentResult?> allowConsent(
      String consentMessageId) async {
    var consentMessage = await loadConsentMessage(consentMessageId);
    consentMessage?.allowAll();
    if (consentMessage != null) {
      final result = await submitConsent(consentMessage);
      return result;
    }
    return null;
  }

  //iOS App Tracking Transparency

  static Future<List<PamPushMessage>?> loadPushNotificationsFromMobile(
      String mobileNumber) async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotificationsFromMobile(mobileNumber);
  }

  static Future<List<PamPushMessage>?> loadPushNotificationsFromEmail(
      String email) async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotificationsFromEmail(email);
  }

  static Future<List<PamPushMessage>?> loadPushNotificationsFromCustomerID(
      String customer) async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotificationsFromCustomerID(customer);
  }

  static Future<List<PamPushMessage>?> loadPushNotifications() async {
    var pushAPI = PamPushNotificationAPI(shared.config?.pamServer ?? "");
    return await pushAPI.loadPushNotifications();
  }

  static bool _isWhitelistEvent(String? event) {
    return event == "allow_consent" || event == "save_push";
  }

  static Future<PamResponse?> track(String event,
      {Map<String, dynamic>? payload, TrackerCallBack? callback}) async {
    if (Pam.shared.config?.blockEventsIfNoConsent == true) {
      var isAllowTracking = shared.allowTracking || _isWhitelistEvent(event);
      if (!isAllowTracking) {
        Pam.log([
          "No Track Event $event with Payload $payload. Because of usr not yet allow Preferences cookies."
        ]);
        return null;
      }
    }

    return await shared.queue.add(() async {
      var result = await _track(event, payload: payload, callback: callback);
      return result;
    });
  }

  static Future<PamResponse> _track(String event,
      {Map<String, dynamic>? payload, TrackerCallBack? callback}) async {
    final res = await shared.postTracker(event, payload);
    callback?.call(res);
    return res;
  }

  static Future<PamResponse> setPushNotificationToken(
      String deviceToken) async {
    return await shared.setDeviceToken(deviceToken);
  }

  static Future<PamResponse> userLogin(String loginId,
      [LoginOptions? options]) async {
    Map<String, dynamic> payload = {};
    if (options != null &&
        options.alternateKey != null &&
        options.alternateKey!.isNotEmpty) {
      String key = options.alternateKey!;
      payload["_key_name"] = options.alternateKey;
      payload["_key_value"] = loginId;
      payload[key] = loginId;
      payload["_force_create"] = false;
    }

    return await shared.trackUserLogin(loginId, payload: payload);
  }

  static Future<void> userLogout({Map<String, dynamic>? payload}) async {
    await shared.trackUserLogout(payload: payload);
  }

  static Future<ConsentMessage?> loadConsentMessage(
      String consentMessageID) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    return await consentAPI.loadConsentMessage(consentMessageID);
  }

  static Future<Map<String, ConsentMessage>> loadConsentMessages(
      List<String> consentMessageIDs) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    Map<String, ConsentMessage> result = {};

    await Future.wait(consentMessageIDs.map((id) async {
      var consentMessage = await consentAPI.loadConsentMessage(id);
      if (consentMessage != null) {
        result[id] = consentMessage;
      }
    }));

    return result;
  }

  static Future<SubmitConsentResult> submitConsents(
      Map<String, ConsentMessage> consentMessages) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");

    return shared.queue.add(() async {
      Map<String, AllowConsentResult> consentResult = {};
      List<String> ids = [];

      await Future.wait(consentMessages.keys.map((aKey) async {
        var item = consentMessages[aKey];
        if (item != null) {
          var result = await consentAPI.submitConsent(item);
          if (result != null) {
            consentResult = {item.id ?? "x": result};
            ids.add(result.consentID ?? "");
          }
        }
      }));

      return SubmitConsentResult(consentResult, ids.join(","));
    });
  }

  static Future<SubmitConsentResult> submitConsent(
      ConsentMessage consentMessage) async {
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

  static void appAttention(BuildContext context,
      {String pageName = "",
      bool Function(Map<String, dynamic>? bannerData)? onBannerClick}) async {
    var api = CRMAPI(shared.config?.pamServer ?? "");
    var attention = await api.getAppAttention(pageName);

    if (attention != null && attention.isNotEmpty) {
      try {
        Map<String, dynamic> json = jsonDecode(attention);
        if (json.isNotEmpty) {
          var result =
              await PamFlutterPlatform.instance.appAttentionPopup(json);

          if (result != null) {
            // คลิก Banner
            if (onBannerClick == null || !onBannerClick(result)) {
              // Default Behavior: เปิด URL
              final url = result["url"] as String?;
              if (url != null) {
                // await launchUrl(Uri.parse(url));
                final Uri uri = Uri.parse(url);

                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  Pam.log(["Could not launch $url"]);
                }
              }
            }
          }
        }
      } catch (e) {
        Pam.log(["App Attention Error: ${e.toString()}"]);
      }
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
  int _sessionVersion = 0;

  TrackerAPI? trackerAPI;

  Function(String)? _onToken;

  static Future<dynamic> methodsHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'onToken':
        var token = methodCall.arguments;
        Pam.setPushNotificationToken(token);
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

    var allow = await pref.getBool(SaveKey.allowTracking);
    if (allow != null) {
      allowTracking = allow;
    }

    unawaited(_syncConsentStatus(config.trackingConsentMessageID));
  }

  Future<CustomerConsentStatus> _loadConsentStatus(
      String consentMessageID) async {
    final status = await _fetchConsentStatus(consentMessageID);
    if (status != null) {
      return status;
    }

    var fallbackStatus = CustomerConsentStatus();
    fallbackStatus.needConsentReview = true;
    return fallbackStatus;
  }

  Future<CustomerConsentStatus?> _fetchConsentStatus(
      String consentMessageID) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    var contactID = await shared.getContactID() ?? '';
    if (contactID != '') {
      return consentAPI.loadConsentStatus(contactID, consentMessageID);
    }

    Pam.log([
      "LOAD CONSENT STATUS",
      "Consent Message ID = $consentMessageID",
      "It's like it's the first time installing the app so there isn't any consent information yet."
    ]);
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
      Pam.log(["SYNC CONSENT STATUS ERROR", stackTrace, error]);
    }
  }

  Future<void> setAllowTracking(bool allow) async {
    allowTracking = true;
    await pref.saveBool(allow, SaveKey.allowTracking);
  }

  Future<PamResponse> trackUserLogin(String custID,
      {Map<String, dynamic>? payload}) async {
    return await queue.add(() async {
      try {
        var loginPayload = Map<String, dynamic>.from(payload ?? {});
        var notiKey =
            Platform.isAndroid ? "android_notification" : "ios_notification";
        var deletePayload = <String, dynamic>{
          "_delete_media": {notiKey: ""}
        };

        if (config?.loginKey == "") {
          loginPayload["customer"] = custID;
        } else {
          loginPayload[config?.loginKey ?? "customer"] = custID;
        }

        final previousDestination = await _createTrackingDestination();
        final deleteResponse = await _postTrackerTo(
            "delete_media", deletePayload, previousDestination);
        if (deleteResponse.error != null) {
          await _activateCustomer(custID);
          return deleteResponse;
        }

        if (previousDestination.sessionType == _TrackingSessionType.public) {
          final publicLoginResponse =
              await _postTrackerTo("login", loginPayload, previousDestination);
          if (publicLoginResponse.error != null) {
            await _activateCustomer(custID);
            return publicLoginResponse;
          }
        }

        await _activateCustomer(custID);

        final loginDestination = await _createTrackingDestination();
        final response =
            await _postTrackerTo("login", loginPayload, loginDestination);

        final push = await getPushToken();
        if (push != null && response.error == null) {
          await _setDeviceToken(push);
        }

        return response;
      } catch (error, stackTrace) {
        return _createInternalErrorResponse(
            "USER LOGIN ERROR", error, stackTrace);
      }
    });
  }

  Future<void> _activateCustomer(String customerID) async {
    final previousCustomerID = custID;
    if (isNotEmpty(previousCustomerID) && previousCustomerID != customerID) {
      loginContact = null;
      await pref.remove(SaveKey.loginContactID);
    }

    custID = customerID;
    Pam.customerID = customerID;
    _sessionVersion++;
    await pref.saveString(customerID, SaveKey.customerID);
  }

  Future<PamResponse> setDeviceToken(String deviceToken) async {
    return await queue.add(() async {
      try {
        return await _setDeviceToken(deviceToken);
      } catch (error, stackTrace) {
        return _createInternalErrorResponse(
            "SET PUSH TOKEN ERROR", error, stackTrace);
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
      Pam.log(["SAVE PUSH TOKEN ERROR", stackTrace, error]);
    }

    var destination = await _createTrackingDestination();
    var res =
        await _postTrackerTo("save_push", {mediaKey: saveToken}, destination);

    return res;
  }

  Future<void> trackUserLogout({Map<String, dynamic>? payload}) async {
    await queue.add(() async {
      try {
        var alias =
            (Platform.isIOS) ? "ios_notification" : "android_notification";
        var deletePayload = <String, dynamic>{
          "_delete_media": {alias: ""}
        };
        payload?.forEach((key, val) {
          deletePayload[key] = val;
        });

        final previousDestination = await _createTrackingDestination();
        final wasLoggedIn =
            previousDestination.sessionType == _TrackingSessionType.login;

        custID = null;
        loginContact = null;
        Pam.customerID = "";
        _sessionVersion++;
        await pref.remove(SaveKey.customerID);
        await pref.remove(SaveKey.loginContactID);

        final deleteResponse = await _postTrackerTo(
            "delete_media", deletePayload, previousDestination);
        if (deleteResponse.error != null) {
          return;
        }

        if (wasLoggedIn) {
          await _postTrackerTo("logout", payload, previousDestination);
        }

        final savedPushToken = await getPushToken();
        if (savedPushToken != null) {
          await _setDeviceToken(savedPushToken);
        }
      } catch (error, stackTrace) {
        _createInternalErrorResponse("USER LOGOUT ERROR", error, stackTrace);
      }
    });
  }

  Future<String> _getOSVersion() async {
    if (Platform.isAndroid) {
      var androidInfo = await DeviceInfoPlugin().androidInfo;
      var release = androidInfo.version.release;
      var sdkInt = androidInfo.version.sdkInt;
      return 'Android: $release (SDK $sdkInt)';
    } else if (Platform.isIOS) {
      var iosInfo = await DeviceInfoPlugin().iosInfo;
      var version = iosInfo.systemVersion;
      return 'iOS: $version';
    }
    return '';
  }

  Future<String> _getPlatformName() async {
    String osVersion = await _getOSVersion();
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String appName = packageInfo.appName;
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    return "$osVersion,  $appName: $version($buildNumber)";
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
    const uuid = Uuid();
    return uuid.v1();
  }

  Future<String?> _getDeviceUDID() async {
    if (isNotEmpty(deviceUDID)) {
      return deviceUDID;
    }
    deviceUDID = await pref.getString(SaveKey.deviceUDID);
    if (deviceUDID == null) {
      deviceUDID = await Pam.identifierForVendor();
      if (isNotEmpty(deviceUDID)) {
        pref.saveString(deviceUDID!, SaveKey.deviceUDID);
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

  Future<String> getDatabaseAlias() async {
    final destination = await _createTrackingDestination();
    Pam.databaseAlias = destination.databaseAlias;
    return destination.databaseAlias;
  }

  Future<_TrackingDestination> _createTrackingDestination() async {
    final customer = await _getCustID();
    if (isNotEmpty(customer)) {
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
      customerID: null,
      sessionVersion: _sessionVersion,
    );
  }

  Future<Map<String, dynamic>> createTrackingBody(
      String? event, Map<String, dynamic>? payload) async {
    final destination = await _createTrackingDestination();
    return _createTrackingBodyForDestination(event, payload, destination);
  }

  Future<Map<String, dynamic>> _createTrackingBodyForDestination(String? event,
      Map<String, dynamic>? payload, _TrackingDestination destination) async {
    var platformName = await _getPlatformName();
    var packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> body = {
      "event": event,
      "platform": platformName,
      "form_fields": [],
    };

    var osVersion = await _getOSVersion();

    Pam.log(["GET contact ID = ${destination.contactID}"]);

    Map<String, dynamic> formField = {
      "os_version": osVersion,
      "app_version": packageInfo.version,
      "_session_id": getSessionID(),
      "_consent_message_id": config?.trackingConsentMessageID,
      "_database": destination.databaseAlias
    };

    String loginKey = "customer";

    if (config?.loginKey != "") {
      loginKey = config?.loginKey ?? "customer";
    }

    final payloadHasIdentity = payload?.containsKey(loginKey) == true ||
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
      formField["customer"] = destination.customerID;
    }

    formField["uuid"] = await _getDeviceUDID();

    body["form_fields"] = formField;
    return body;
  }

  Future<void> _saveContactID(
      String? contactId, _TrackingDestination destination) async {
    if (contactId?.isEmpty ?? true) {
      return;
    }
    String cid = contactId ?? "";

    if (destination.sessionType == _TrackingSessionType.login) {
      if (destination.sessionVersion != _sessionVersion ||
          destination.customerID != custID) {
        Pam.log([
          "Ignore stale logged-in contact ID = $cid",
          "Request session version = ${destination.sessionVersion}",
          "Current session version = $_sessionVersion"
        ]);
        return;
      }

      Pam.log(["Save Logged-in contact ID = $cid"]);
      await pref.saveString(cid, SaveKey.loginContactID);
      loginContact = cid;
      Pam.contactID = cid;
      return;
    }

    Pam.log(["Save Anonymous contact ID = $cid"]);
    await pref.saveString(cid, SaveKey.contactID);
    publicContact = cid;
    if (destination.sessionVersion == _sessionVersion) {
      Pam.contactID = cid;
    }
  }

  Future<PamResponse> postTracker(
      String? event, Map<String, dynamic>? payload) async {
    try {
      final destination = await _createTrackingDestination();
      return _postTrackerTo(event, payload, destination);
    } catch (error, stackTrace) {
      return _createInternalErrorResponse("TRACKING ERROR", error, stackTrace);
    }
  }

  Future<PamResponse> _postTrackerTo(String? event,
      Map<String, dynamic>? payload, _TrackingDestination destination) async {
    try {
      var body =
          await _createTrackingBodyForDestination(event, payload, destination);

      var response = await trackerAPI?.postTracker(body);

      if (response?.error == null) {
        await _saveContactID(response?.contactID, destination);
      }

      return response ??
          PamResponse.createErrorResponse(
              code: "EMPTY_RESPONSE",
              errorMessage: "PAM return empty response.");
    } catch (error, stackTrace) {
      Pam.log(["TRACKING ERROR", stackTrace, error]);
      return PamResponse.createErrorResponse(
          code: "EXCEPTION", errorMessage: error.toString());
    }
  }

  PamResponse _createInternalErrorResponse(
      String label, Object error, StackTrace stackTrace) {
    Pam.log([label, stackTrace, error]);
    return PamResponse.createErrorResponse(
        code: "EXCEPTION", errorMessage: error.toString());
  }
}
