import '../src/pam_log_request.dart';
import 'package:http/http.dart' show Response;
import 'package:pam_flutter/response/customer_consent_status.dart';
import '../pam.dart';
import '../response/consent_message.dart';
import '../response/allow_consent.dart';
import 'dart:async';
import '../http/http_client.dart';

class ConsentAPI {
  String baseURL;

  ConsentAPI(this.baseURL);

  Future<ConsentMessage?> loadConsentMessage(String id) async {
    Response? response;
    final log = PamLogRequest(
      PamLogCategory.consent,
      'GET /consent-message',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'consent_message_id': id,
      },
    );
    try {
      var uri = Uri.parse("$baseURL/consent-message/$id");
      response = await HttpClient.get(uri);

      log.complete(response.statusCode, body: response.body);
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    if (response != null) {
      return ConsentMessage.parse(response.body);
    }

    return null;
  }

  Future<CustomerConsentStatus?> loadConsentStatus(
    String contactId,
    String consentMessageIDs,
  ) async {
    Response? response;
    final log = PamLogRequest(
      PamLogCategory.consent,
      'GET /contacts/consents',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'contact_id': contactId,
        'consent_message_ids': consentMessageIDs,
      },
    );
    try {
      var uri = Uri.parse(
        "$baseURL/contacts/$contactId/consents/$consentMessageIDs",
      );
      response = await HttpClient.get(uri);

      log.complete(response.statusCode, body: response.body);
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    if (response != null) {
      return CustomerConsentStatus.parse(response.body);
    }

    return null;
  }

  Future<AllowConsentResult?> submitConsent(
    ConsentMessage consentMessage,
  ) async {
    Map<String, dynamic> payload = {
      "_consent_message_id": consentMessage.id,
      "_version": consentMessage.version,
    };

    var trackingConsentMessageID =
        Pam.shared.config?.trackingConsentMessageID ?? "x";

    for (var element in consentMessage.permission) {
      payload["_allow_${element.name.key}"] = element.allow;
      if (consentMessage.id == trackingConsentMessageID &&
          element.name == ConsentPermissionName.preferencesCookies) {
        await Pam.shared.setAllowTracking(true);
      }
    }

    var response = await Pam.shared.postTracker("allow_consent", payload);

    var result = AllowConsentResult(
      response.contactID,
      response.database,
      response.consentID,
      response.consentMessageID,
    );

    Pam.log(
      [
        'Submit consent id=${consentMessage.id} version=${consentMessage.version} '
            'consent_id=${response.consentID} error_code=${response.error?.code}',
      ],
      category: PamLogCategory.consent,
      level: response.error == null ? PamLogLevel.info : PamLogLevel.error,
    );

    return result;
  }

  Future<AllowConsentResult?> allowAllConsent(String consentMessageId) async {
    final payload = {
      "_consent_message_id": consentMessageId,
      "_version": "latest",
      "_allow_terms_and_conditions": true,
      "_allow_privacy_overview": true,
      "_allow_necessary_cookies": true,
      "_allow_preferences_cookies": true,
      "_allow_analytics_cookies": true,
      "_allow_marketing_cookies": true,
      "_allow_social_media_cookies": true,
      "_allow_email": true,
      "_allow_sms": true,
      "_allow_line": true,
      "_allow_facebook_messenger": true,
      "_allow_push_notification": true,
    };

    var response = await Pam.shared.postTracker("allow_consent", payload);

    var result = response.error == null
        ? AllowConsentResult(
            response.contactID,
            response.database,
            response.consentID,
            response.consentMessageID,
          )
        : null;

    Pam.log(
      [
        'Allow all consent id=$consentMessageId version=latest '
            'consent_id=${response.consentID} error_code=${response.error?.code}',
      ],
      category: PamLogCategory.consent,
      level: response.error == null ? PamLogLevel.info : PamLogLevel.error,
    );

    return result;
  }
}
