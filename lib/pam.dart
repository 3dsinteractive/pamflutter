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

  static void log(List<String> args) {
    if (shared.isEnableLog) {
      var spliter = "◦🦄◦🦄◦🦄◦PAM◦🦄◦🦄◦🦄◦";
      debugPrint("\n$spliter\n\n${args.join("\n")}\n\n$spliter\n");
    }
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
        Pam.log([e.toString()]);
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
          data: payload);

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
          shared._saveContactID(result?.contactID);
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
      shared._saveContactID(result?.contactID);
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

  final queue = Queue(
      parallel: 1,
      delay: const Duration(milliseconds: 50),
      timeout: const Duration(seconds: 5));

  PamConfig? config;

  DateTime sessionExpire = DateTime(1983, 11, 14);
  String sessionID = "";
  String? publicContact, loginContact, deviceUDID, custID, pushToken;

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

    var status = await _loadConsentStatus(config.trackingConsentMessageID);
    var isAllowPreferences =
        status.trackingPermission?.preferencesCookies ?? false;

    if (isAllowPreferences) {
      allowTracking = true;
      pref.saveBool(true, SaveKey.allowTracking);
    } else {
      pref.saveBool(false, SaveKey.allowTracking);
    }

    var token = await pref.getString(SaveKey.pushKey);
    if (token != null) {
      Pam.setPushNotificationToken(token);
    }
  }

  Future<CustomerConsentStatus> _loadConsentStatus(
      String consentMessageID) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    var contactID = await shared.getContactID() ?? '';
    if (contactID != '') {
      var result =
          await consentAPI.loadConsentStatus(contactID, consentMessageID);
      if (result != null) {
        return result;
      }
    } else {
      Pam.log([
        "LOAD CONSENT STATUS",
        "Consent Message ID = $consentMessageID",
        "It's like it's the first time installing the app so there isn't any consent information yet."
      ]);
    }
    var status = CustomerConsentStatus();
    status.needConsentReview = true;
    return status;
  }

  Future<void> setAllowTracking(bool allow) async {
    allowTracking = true;
    await pref.saveBool(allow, SaveKey.allowTracking);
  }

  Future<PamResponse> trackUserLogin(String custID,
      {Map<String, dynamic>? payload}) async {
    var notiKey =
        Platform.isAndroid ? "android_notification" : "ios_notification";
    Map<String, dynamic> defaultPayload = {
      "_delete_media": {notiKey: ""}
    };

    if (config?.loginKey == "") {
      payload?["customer"] = custID;
    } else {
      payload?[config?.loginKey ?? "customer"] = custID;
    }

    payload?.forEach((key, val) {
      defaultPayload[key] = val;
    });

    //Delete Push Noti from anonymous
    await queue.add(() => postTracker("delete_media", defaultPayload));
    await pref.saveString(custID, SaveKey.customerID);

    // Track Login To Public
    var response = await queue.add(() => postTracker("login", payload));

    // Track Login To Login
    this.custID = custID;
    response = await queue.add(() => postTracker("login", payload));
    if (isNotEmpty(response.contactID)) {
      this.custID = custID;
      loginContact = response.contactID;
      if (loginContact != null && loginContact!.isNotEmpty) {
        pref.saveString(response.contactID!, SaveKey.loginContactID);
      }
    }

    var push = await getPushToken();
    if (push != null) {
      setDeviceToken(push);
    }

    return response;
  }

  Future<PamResponse> setDeviceToken(String deviceToken) async {
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
    var res =
        await queue.add(() => postTracker("save_push", {mediaKey: saveToken}));
    pref.saveString(deviceToken, SaveKey.pushKey);

    return res;
  }

  Future<void> trackUserLogout({Map<String, dynamic>? payload}) async {
    var alias = (Platform.isIOS) ? "ios_notification" : "android_notification";
    Map<String, dynamic> defaultPayload = {
      "_delete_media": {alias: ""}
    };
    payload?.forEach((key, val) {
      defaultPayload[key] = val;
    });
    await queue.add(() => postTracker("delete_media", defaultPayload));
    await queue.add(() => postTracker("logout", payload));

    custID = null;
    loginContact = null;
    await pref.remove(SaveKey.customerID);
    await pref.remove(SaveKey.loginContactID);

    if (isNotEmpty(pushToken)) {
      defaultPayload = {alias: pushToken};
      payload?.forEach((key, val) {
        defaultPayload[key] = val;
      });
      await queue.add(() => setPushNotificationToken(pushToken ?? ''));
    }
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
    if (isNotEmpty(loginContact)) {
      Pam.contactID = loginContact ?? '';
      return loginContact;
    }

    if (isNotEmpty(publicContact)) {
      Pam.contactID = publicContact ?? '';
      return publicContact;
    }

    loginContact = await pref.getString(SaveKey.loginContactID);
    if (isNotEmpty(loginContact)) {
      Pam.contactID = loginContact ?? '';
      return loginContact;
    }

    publicContact = await pref.getString(SaveKey.contactID);
    if (isNotEmpty(publicContact)) {
      Pam.contactID = publicContact ?? '';
      return publicContact;
    }

    return null;
  }

  bool isUserLogin() {
    return isNotEmpty(custID);
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

  String getDatabaseAlias() {
    if (isUserLogin()) {
      Pam.databaseAlias = config?.loginDBAlias ?? "";
      return config?.loginDBAlias ?? "";
    }
    Pam.databaseAlias = config?.publicDBAlias ?? "";
    return config?.publicDBAlias ?? "";
  }

  Future<Map<String, dynamic>> createTrackingBody(
      String? event, Map<String, dynamic>? payload) async {
    var platformName = await _getPlatformName();
    var packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> body = {
      "event": event,
      "platform": platformName,
      "form_fields": [],
    };

    var contactID = await getContactID();
    var osVersion = await _getOSVersion();

    Pam.log(["GET contact ID = $contactID"]);

    Map<String, dynamic> formField = {
      "os_version": osVersion,
      "app_version": packageInfo.version,
      "_session_id": getSessionID(),
      "_consent_message_id": config?.trackingConsentMessageID,
      "_database": getDatabaseAlias()
    };

    String loginKey = "customer";

    if (config?.loginKey != "") {
      loginKey = config?.loginKey ?? "customer";
    }

    if (payload?.containsKey(loginKey) == false &&
        payload?.containsKey("_key_name") == false) {
      if (isNotEmpty(contactID)) {
        formField["_contact_id"] = contactID;
      }
    }

    payload?.forEach((key, value) {
      if (key == "page_url" || key == "page_title") {
        body[key] = value;
      } else {
        formField[key] = value;
      }
    });

    if (isUserLogin()) {
      formField["customer"] = await _getCustID();
    }

    formField["uuid"] = await _getDeviceUDID();

    body["form_fields"] = formField;
    return body;
  }

  void _saveContactID(String? contactId) {
    if (contactId?.isEmpty ?? true) {
      return;
    }
    String cid = contactId ?? "";

    if (isUserLogin()) {
      if (isNotEmpty(contactId)) {
        Pam.log(["Save Logged-in contact ID = $cid"]);

        pref.saveString(cid, SaveKey.loginContactID);
        loginContact = cid;
      }
    } else {
      if (isNotEmpty(cid)) {
        Pam.log(["Save Anonymous contact ID = $cid"]);

        pref.saveString(cid, SaveKey.contactID);
        publicContact = cid;
      }
    }
  }

  Future<PamResponse> postTracker(
      String? event, Map<String, dynamic>? payload) async {
    var body = await createTrackingBody(event, payload);

    var response = await trackerAPI?.postTracker(body);

    if (response?.error == null) {
      _saveContactID(response?.contactID);
    }

    return response ??
        PamResponse.createErrorResponse(
            code: "EMPTY_RESPONSE", errorMessage: "PAM return empty response.");
  }
}
