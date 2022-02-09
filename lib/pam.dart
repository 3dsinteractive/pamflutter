library pamflutter;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pamflutter/api/consent_api.dart';
import 'package:pamflutter/response/allow_consent.dart';
import 'package:pamflutter/response/consent_message.dart';
import 'package:pamflutter/response/pam_response.dart';
import 'preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info/device_info.dart';
import 'dart:io' show Platform;
import 'package:uuid/uuid.dart';
import './api/tracker_api.dart';
import 'package:flutter/services.dart';
import 'package:pamflutter/api/push_notification_api.dart';
import 'package:pamflutter/response/pam_push_message.dart';
import 'package:queue/queue.dart';

typedef TrackerCallBack = Function(PamResponse);

class PamConfig {
  String pamServer, publicDBAlias, loginDBAlias, trackingConsentMessageID;
  bool enableLog;

  PamConfig(this.pamServer, this.publicDBAlias, this.loginDBAlias,
      this.trackingConsentMessageID, this.enableLog);
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
  static const MethodChannel _channel = MethodChannel('ai.pams.flutter');

  static Future<String?> getCustID() async {
    return await shared._getCustID();
  }

  static Future<void> initialize(PamConfig config) async {
    await shared.init(config, config.enableLog);
  }

  //iOS App Tracking Transparency
  static Future<TrackingStatus> get trackingAuthorizationStatus async {
    if (Platform.isIOS) {
      final int status =
          (await _channel.invokeMethod<int>('getTrackingAuthorizationStatus'))!;
      return TrackingStatus.values[status];
    }
    return TrackingStatus.notSupported;
  }

  static Future<TrackingStatus> requestTrackingAuthorization() async {
    if (Platform.isIOS) {
      final int status =
          (await _channel.invokeMethod<int>('requestTrackingAuthorization'))!;
      return TrackingStatus.values[status];
    }
    return TrackingStatus.notSupported;
  }

  static Future<String?> identifierForVendor() async {
    final uuid =
          await _channel.invokeMethod<String>('identifierForVendor');
    if (uuid == "") {
      return null;
    }
    return uuid;
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

  static void track(String event,
      {Map<String, dynamic>? payload, TrackerCallBack? callback}) {
    unawaited(shared.queue
        .add(() async => _track(event, payload: payload, callback: callback)));
  }

  static Future<void> _track(String event,
      {Map<String, dynamic>? payload, TrackerCallBack? callback}) async {
    final res = await shared.postTracker(event, payload);
    callback?.call(res);
  }

  static Future<PamResponse> setPushNotificationToken(
      String deviceToken) async {
    return await shared.setDeviceToken(deviceToken);
  }

  static Future<PamResponse> userLogin(String custID,
      {Map<String, dynamic>? payload}) async {
    return await shared.trackUserLogin(custID, payload: payload);
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
  }

  static Future<SubmitConsentResult> submitConsent(
      ConsentMessage consentMessage) async {
    var consentAPI = ConsentAPI(shared.config?.pamServer ?? "");
    Map<String, AllowConsentResult> consentResult = {};
    String ids = "";
    var result = await consentAPI.submitConsent(consentMessage);
    if (result != null) {
      consentResult = {consentMessage.id ?? "x": result};
      ids = result.consentID ?? "";
    }
    return SubmitConsentResult(consentResult, ids);
  }

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

  static void onToken(Function(String)? onToken) {
    Pam.shared._onToken = onToken;
  }
  //--STATIC --

  var isEnableLog = false;
  var allowTracking = false;
  var pref = UserPreference();
  //var queue = TrackerQueueManger();
  final queue = Queue(delay: const Duration(milliseconds: 1000));
  PamConfig? config;

  DateTime sessionExpire = DateTime(1983, 11, 14);
  String sessionID = "";
  String? publicContact, loginContact, deviceUDID, custID, pushToken;

  TrackerAPI? trackerAPI;

  Function(String)? _onToken;

  Future<void> init(PamConfig config, bool debug) async {
    _channel.setMethodCallHandler(Pam.methodsHandler);
    trackerAPI = TrackerAPI(config.pamServer);
    this.config = config;
    isEnableLog = debug;

    var allow = await pref.getBool(SaveKey.allowTracking);
    if (allow != null) {
      allowTracking = allow;
    }

    //var custID = await pref.getString(SaveKey.customerID);
    // if (custID != null) {
    //   Pam.userLogin(custID);
    // }

    var token = await pref.getString(SaveKey.pushKey);
    if (token != null) {
      Pam.setPushNotificationToken(token);
    }
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
    payload?.forEach((key, val) {
      defaultPayload[key] = val;
    });

    //Delete Push Noti from anonymous
    await queue.add(() => postTracker("delete_media", defaultPayload));
    await pref.saveString(custID, SaveKey.customerID);
    this.custID = custID;

    //Login
    var response = await queue.add(() => postTracker("login", payload));
    if (isNotEmpty(response.contactID)) {
      loginContact = response.contactID;
      pref.saveString(response.contactID!, SaveKey.loginContactID);
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

  Future<String> getOSVersion() async {
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

  Future<String> getPlatformName() async {
    String osVersion = await getOSVersion();
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

  Future<String?> getDeviceUDID() async {
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
    var platformName = await getPlatformName();
    var packageInfo = await PackageInfo.fromPlatform();

    Map<String, dynamic> body = {
      "event": event,
      "platform": platformName,
      "form_fields": [],
    };

    var contactID = await getContactID();
    var osVersion = await getOSVersion();

    if (isEnableLog) {
      debugPrint("GET contact ID = $contactID");
    }

    Map<String, dynamic> formField = {
      "os_version": osVersion,
      "app_version": packageInfo.version,
      "_session_id": getSessionID(),
      "_consent_message_id": config?.trackingConsentMessageID,
      "_database": getDatabaseAlias()
    };

    if (isNotEmpty(contactID)) {
      formField["_contact_id"] = contactID;
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

    formField["uuid"] = await getDeviceUDID();

    body["form_fields"] = formField;
    return body;
  }

  Future<PamResponse> postTracker(
      String? event, Map<String, dynamic>? payload) async {
    var body = await createTrackingBody(event, payload);
    var response = await trackerAPI?.postTracker(body);

    if (response?.error == null) {
      if (isUserLogin()) {
        if (isNotEmpty(response?.contactID)) {
          if (isEnableLog) {
            debugPrint(
                "PAM: Save Logged-in contact ID = ${response?.contactID}");
          }
          pref.saveString(response?.contactID ?? '', SaveKey.loginContactID);
          loginContact = response?.contactID;
        }
      } else {
        if (isNotEmpty(response?.contactID)) {
          if (isEnableLog) {
            debugPrint(
                "PAM: Save Anonymous contact ID = ${response?.contactID}");
          }
          pref.saveString(response?.contactID ?? '', SaveKey.contactID);
          publicContact = response?.contactID;
        }
      }
    }

    return response ??
        PamResponse.createErrorResponse(
            code: "EMPTY_RESPONSE", errorMessage: "PAM return empty response.");
  }
}
