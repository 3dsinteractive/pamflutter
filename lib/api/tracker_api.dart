import '../response/pam_response.dart';
import '../pam.dart';
import 'dart:convert';
import '../http/http_client.dart';

class TrackerAPI {
  String baseURL;

  TrackerAPI(this.baseURL);

  Future<PamResponse?> postTracker(Map<String, dynamic> body) async {
    var uri = Uri.parse("$baseURL/trackers/events");

    try {
      var response = await HttpClient.post(uri, body: body);

      const encoder = JsonEncoder.withIndent('  ');
      var bodyLog = encoder.convert(body);

      Pam.log([
        "${DateTime.now()}",
        "🦄🦄🦄🦄🦄 PAM TRACKING EVENT 🦄🦄🦄🦄🦄🦄\n\n",
        uri.toString(),
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
    } catch (e) {
      Pam.log(["TRACKING ERROR", e.toString()]);

      var errorResponse = PamResponse();
      errorResponse.error =
          PamErrorResponse(code: "EXCEPTION", errorMessage: e.toString());
      return errorResponse;
    }
  }
}
