import '../src/pam_log_request.dart';
import '../response/pam_response.dart';
import '../pam.dart';
import 'dart:convert';
import '../http/http_client.dart';

class TrackerAPI {
  String baseURL;
  final Duration? requestTimeout;

  TrackerAPI(this.baseURL, {this.requestTimeout});

  Future<PamResponse?> postTracker(Map<String, dynamic> body) async {
    var uri = Uri.parse("$baseURL/trackers/events");

    final log = PamLogRequest(
      PamLogCategory.tracking,
      'POST /trackers/events',
      details: {'server': Uri.tryParse(baseURL)?.host, 'event': body['event']},
    );
    try {
      if (Pam.shared.isEnableLog) {
        log.payload(const JsonEncoder.withIndent('  ').convert(body));
      }
      var response = await HttpClient.post(
        uri,
        body: body,
        timeout: requestTimeout,
      );

      log.complete(response.statusCode, body: response.body);

      final pamResponse = PamResponse.parse(response.body);
      return pamResponse;
    } catch (e, stackTrace) {
      log.fail(e, stackTrace);

      var errorResponse = PamResponse();
      errorResponse.error = PamErrorResponse(
        code: "EXCEPTION",
        errorMessage: e.toString(),
      );
      return errorResponse;
    }
  }
}
