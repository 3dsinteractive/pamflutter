import 'package:http/http.dart' show Response;
import 'package:pam_flutter/response/customer_consent_status.dart';
import '../pam.dart';
import '../response/consent_message.dart';
import 'package:flutter/foundation.dart';
import '../response/allow_consent.dart';
import 'dart:async';
import '../http/http_client.dart';

class ConsentAPI {
  String baseURL;

  ConsentAPI(this.baseURL);

  Future<ConsentMessage?> loadConsentMessage(String id) async {
    Response? response;
    try {
      var uri = Uri.parse("$baseURL/consent-message/$id");
      response = await HttpClient.get(uri);

      Pam.log([
        "LOAD CONSENT MESSAGE",
        uri.toString(),
        "consent_message_id: $id",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body
      ]);
    } catch (e) {
      Pam.log(["TRACKING ERROR", e.toString()]);
    }

    if (response != null) {
      return ConsentMessage.parse(response.body);
    }

    return null;
  }

  Future<CustomerConsentStatus?> loadConsentStatus(
      String contactId, String consentMessageIDs) async {
    Response? response;
    try {
      var uri =
          Uri.parse("$baseURL/contacts/$contactId/consents/$consentMessageIDs");
      response = await HttpClient.get(uri);

      Pam.log([
        "LOAD CONSENT STATUS",
        uri.toString(),
        "consent_message_id: $consentMessageIDs",
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body
      ]);
    } catch (e) {
      Pam.log(["LOAD CONSENT STATUS ERROR", e.toString()]);
    }

    if (response != null) {
      return CustomerConsentStatus.parse(response.body);
    }

    return null;
  }

  Future<AllowConsentResult?> submitConsent(
      ConsentMessage consentMessage) async {
    Map<String, dynamic> payload = {
      "_consent_message_id": consentMessage.id,
      "_version": consentMessage.version
    };

    var trackingConsentMessageID =
        Pam.shared.config?.trackingConsentMessageID ?? "x";

    for (var element in consentMessage.permission) {
      payload["_allow_${element.name.key}"] = element.allow;
      if (consentMessage.id == trackingConsentMessageID &&
          element.name == ConsentPermissionName.preferencesCookies) {
        Pam.shared.setAllowTracking(true);
      }
    }

    var body = await Pam.shared.createTrackingBody("allow_consent", payload);
    var response = await Pam.shared.trackerAPI?.postTracker(body);
    var result = AllowConsentResult(
        response?.contactID, response?.database, response?.consentID);

    Pam.log([
      "SUBMIT CONSENT",
      "Type: ${consentMessage.type}, ID: ${consentMessage.id}",
      ...consentMessage.permission.map((t) => "⦾${t.name.key}=${t.allow}"),
      "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
      response.toString()
    ]);

    return result;
  }
}
