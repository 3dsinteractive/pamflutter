import '../http/http_client.dart';
import '../response/pam_push_message.dart';
import '../pam.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' show Response;

class PamPushNotificationAPI {
  String baseURL;

  PamPushNotificationAPI(this.baseURL);

  Future<void> read(String? pixel) async {
    if (pixel != null) {
      var uri = Uri.parse(pixel);
      await HttpClient.get(uri);
    }
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromMobile(
      String mobileNumber) async {
    Response? response;
    var db = Pam.shared.getDatabaseAlias();
    var contact = Pam.shared.getContactID();
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&sms=$mobileNumber");
      response = await HttpClient.get(uri);

      if (Pam.shared.isEnableLog) {
        debugPrint("🦄🦄🦄🦄🦄 PAM LOAD PUSH NOTIFICATION 🦄🦄🦄🦄🦄🦄\n\n");
        debugPrint(uri.toString());
        debugPrint("mobile number = $mobileNumber");
        debugPrint("🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥");
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("----- Response Body -----");
        debugPrint(utf8.decode(response.bodyBytes));
        debugPrint("\n\n🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄");
      }
    } catch (e) {
      if (Pam.shared.isEnableLog) {
        debugPrint("\n\n🦄🦄🦄🦄🦄 ERROR 🦄🦄🦄🦄🦄🦄");
        debugPrint(e.toString());
      }
    }

    if (response != null) {
      return PamPushMessage.parse(utf8.decode(response.bodyBytes));
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromEmail(
      String email) async {
    Response? response;
    var db = Pam.shared.getDatabaseAlias();
    var contact = Pam.shared.getContactID();
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&email=$email");
      response = await HttpClient.get(uri);
      if (Pam.shared.isEnableLog) {
        debugPrint("🦄🦄🦄🦄🦄 PAM LOAD PUSH NOTIFICATION 🦄🦄🦄🦄🦄🦄\n\n");
        debugPrint(uri.toString());
        debugPrint("email = $email");
        debugPrint("🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥");
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("----- Response Body -----");
        debugPrint(utf8.decode(response.bodyBytes));
        debugPrint("\n\n🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄");
      }
    } catch (e) {
      if (Pam.shared.isEnableLog) {
        debugPrint("\n\n🦄🦄🦄🦄🦄 ERROR 🦄🦄🦄🦄🦄🦄");
        debugPrint(e.toString());
      }
    }

    if (response != null) {
      return PamPushMessage.parse(utf8.decode(response.bodyBytes));
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromCustomerID(
      String customer) async {
    Response? response;
    var db = Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&customer=$customer");
      response = await HttpClient.get(uri);
      if (Pam.shared.isEnableLog) {
        debugPrint("🦄🦄🦄🦄🦄 PAM LOAD PUSH NOTIFICATION 🦄🦄🦄🦄🦄🦄\n\n");
        debugPrint(uri.toString());
        debugPrint("customer id = $customer");
        debugPrint("🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥");
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("----- Response Body -----");
        debugPrint(utf8.decode(response.bodyBytes));
        debugPrint("\n\n🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄");
      }
    } catch (e) {
      if (Pam.shared.isEnableLog) {
        debugPrint("\n\n🦄🦄🦄🦄🦄 ERROR 🦄🦄🦄🦄🦄🦄");
        debugPrint(e.toString());
      }
    }

    if (response != null) {
      return PamPushMessage.parse(utf8.decode(response.bodyBytes));
    }

    return null;
  }
}
