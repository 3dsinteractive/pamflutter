import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;
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
      if (Pam.shared.isEnableLog) {
        debugPrint("🦄🦄🦄🦄🦄 PAM LOAD CONSENT MESSAGE 🦄🦄🦄🦄🦄🦄\n\n");
        debugPrint(uri.toString());
        debugPrint("consent_message_id: $id");
        debugPrint("🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥");
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("----- Response Body -----");
        debugPrint(response.body);
        debugPrint("\n\n🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄");
      }
    } catch (e) {
      if (Pam.shared.isEnableLog) {
        debugPrint("\n\n🦄🦄🦄🦄🦄 PAM TRACKING ERROR 🦄🦄🦄🦄🦄🦄");
        debugPrint(e.toString());
      }
    }

    if (response != null) {
      return ConsentMessage.parse(response.body);
    }

    return null;
  }

  // Future<> loadConsentPermissions(String id) async {

  // }

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

    if (Pam.shared.isEnableLog) {
      debugPrint("🦄🦄🦄🦄🦄 PAM SUBMIT CONSENT 🦄🦄🦄🦄🦄🦄\n\n");
      debugPrint("Type: ${consentMessage.type}, ID: ${consentMessage.id}");
      for (var element in consentMessage.permission) {
        debugPrint("✏️ ${element.name.key}=${element.allow}");
      }
      debugPrint("🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥");
      debugPrint(response.toString());
      debugPrint("\n\n🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄");
    }

    return result;
  }
}
