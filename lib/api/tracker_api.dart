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

    try {
      var response =
          await HttpClient.post(uri, body: body, timeout: requestTimeout);

      const encoder = JsonEncoder.withIndent('  ');
      var bodyLog = encoder.convert(body);

      Pam.log([
        "${DateTime.now()}",
        "🦄🦄🦄🦄🦄 PAM TRACKING EVENT 🦄🦄🦄🦄🦄🦄\n\n",
        uri,
        "----- Payload -----",
        bodyLog,
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body,
        "-------------",
        "RES+ = ${response.body}"
      ]);

      final pamResponse = PamResponse.parse(response.body);
      return pamResponse;
    } catch (e, stackTrace) {
      Pam.log(["TRACKING ERROR", stackTrace, e]);

      var errorResponse = PamResponse();
      errorResponse.error =
          PamErrorResponse(code: "EXCEPTION", errorMessage: e.toString());
      return errorResponse;
    }
  }
}
