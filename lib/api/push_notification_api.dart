import '../http/http_client.dart';
import '../response/pam_push_message.dart';
import '../pam.dart';
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
    var contact = await Pam.shared.getContactID();
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
        uri,
        "mobile number = $mobileNumber",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body,
      ]);
    } catch (e, stackTrace) {
      Pam.log(["ERROR", stackTrace, e]);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotificationsFromEmail(
      String email) async {
    Response? response;
    var db = Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();

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
        uri,
        "email = $email",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body
      ]);
    } catch (e, stackTrace) {
      Pam.log(["ERROR", stackTrace, e]);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
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
        uri,
        "customer id = $customer",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body,
      ]);
    } catch (e, stackTrace) {
      Pam.log(["ERROR", stackTrace, e]);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }

  Future<List<PamPushMessage>?> loadPushNotifications() async {
    Response? response;
    var db = Pam.shared.getDatabaseAlias();
    var contact = await Pam.shared.getContactID();
    Pam.log(["LOAD PUSH NOTIFICATION", "_database=$db&_contact_id=$contact"]);
    try {
      var uri = Uri.parse(
          "$baseURL/api/app-notifications?_database=$db&_contact_id=$contact");
      response = await HttpClient.get(uri);
      Pam.log([
        "LOAD PUSH NOTIFICATION",
        uri,
        "contact id = $contact",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body,
      ]);
    } catch (e, stackTrace) {
      Pam.log(["ERROR", stackTrace, e]);
    }

    if (response != null) {
      return PamPushMessage.parse(response.body);
    }

    return null;
  }
}
