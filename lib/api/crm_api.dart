import '../src/pam_log_request.dart';
import '../pam.dart';
import 'dart:async';
import '../http/http_client.dart';

class CRMAPI {
  String baseURL;
  final Duration requestTimeout;

  CRMAPI(this.baseURL, {this.requestTimeout = const Duration(seconds: 30)});

  Future<String?> getAppAttention(String pageName) async {
    final log = PamLogRequest(
      PamLogCategory.attention,
      'POST /app-attention',
      details: {
        'server': Uri.tryParse(baseURL)?.host,
        'page': pageName,
        'timeout_ms': requestTimeout.inMilliseconds,
      },
    );
    try {
      final contactID = await Pam.shared.getContactID();
      if (contactID == null || contactID.isEmpty) {
        log.skip('no_contact');
        return null;
      }
      var uri = Uri.parse("$baseURL/app-attention");
      var response = await HttpClient.post(
        uri,
        body: {"page_name": pageName, "_contact_id": contactID},
        timeout: requestTimeout,
      );

      log.complete(response.statusCode, body: response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);
    }

    return null;
  }
}
