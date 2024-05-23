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
    Pam.log([
      "LOAD PUSH NOTIFICATION",
      "_database=$db&_contact_id=$contact&sms=$mobileNumber"
    ]);
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&sms=$mobileNumber");
      response = await HttpClient.get(uri);

      Pam.log([
        "LOAD PUSH NOTIFICATION",
        uri.toString(),
        "mobile number = $mobileNumber",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        utf8.decode(response.bodyBytes),
      ]);
    } catch (e) {
      Pam.log(["ERROR", e.toString()]);
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

    Pam.log([
      "LOAD PUSH NOTIFICATION",
      "_database=$db&_contact_id=$contact&email=$email"
    ]);
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&email=$email");
      response = await HttpClient.get(uri);
      Pam.log([
        "LOAD PUSH NOTIFICATION",
        uri.toString(),
        "email = $email",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        utf8.decode(response.bodyBytes)
      ]);
    } catch (e) {
      Pam.log(["ERROR", e.toString()]);
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
    Pam.log([
      "LOAD PUSH NOTIFICATION",
      "_database=$db&_contact_id=$contact&customer=$customer"
    ]);
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact&customer=$customer");
      response = await HttpClient.get(uri);
      Pam.log([
        "LOAD PUSH NOTIFICATION",
        uri.toString(),
        "customer id = $customer",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        utf8.decode(response.bodyBytes),
      ]);
    } catch (e) {
      Pam.log(["ERROR", e.toString()]);
    }

    if (response != null) {
      return PamPushMessage.parse(utf8.decode(response.bodyBytes));
    }

    return null;
  }
}
