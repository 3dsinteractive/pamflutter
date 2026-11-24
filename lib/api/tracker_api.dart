import '../src/pam_log_request.dart';
import '../response/pam_response.dart';
import '../pam.dart';
import 'dart:convert';
import '../http/http_client.dart';

class TrackerAPI {
  String baseURL;
  final Duration? requestTimeout;

  TrackerAPI(this.baseURL, {this.requestTimeout});

  Future<PamBatchResponse> postTrackerBatch(Map<String, dynamic> body) async {
    final log = PamLogRequest(
      PamLogCategory.tracking,
      'POST /trackers/events (batch)',
      details: {'server': Uri.tryParse(baseURL)?.host},
    );
    try {
      if (Pam.shared.isEnableLog) {
        log.payload(const JsonEncoder.withIndent('  ').convert(body));
      }
      final response = await HttpClient.post(
        Uri.parse('$baseURL/trackers/events'),
        body: body,
        timeout: requestTimeout,
      );
      log.complete(response.statusCode, body: response.body);
      final result = PamBatchResponse.parse(response.body);
      if (response.statusCode >= 400 && result.error == null) {
        return PamBatchResponse(
          results: result.results,
          error: PamErrorResponse(
            code: 'HTTP_${response.statusCode}',
            errorMessage: 'Batch tracking request failed.',
          ),
        );
      }
      return result;
    } catch (error, stackTrace) {
      log.fail(error, stackTrace);
      return PamBatchResponse.failure('EXCEPTION', error.toString());
    }
  }

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
