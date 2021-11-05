import 'package:http/http.dart' as http;
import '../response/pam_response.dart';
import '../pam.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class TrackerAPI {
  String baseURL;

  TrackerAPI(this.baseURL);

  Future<PamResponse> postTracker(Map<String, dynamic> body) async {
    var uri = Uri.parse("$baseURL/trackers/events");

    try {
      var jsonbody = json.encode(body);
      var response = await http.post(uri, body: jsonbody);

      if (Pam.shared.isEnableLog) {
        debugPrint("${DateTime.now()}");
        debugPrint("🦄🦄🦄🦄🦄 PAM TRACKING EVENT 🦄🦄🦄🦄🦄🦄\n\n");
        debugPrint(uri.toString());
        debugPrint("----- Payload -----");
        const encoder = JsonEncoder.withIndent('  ');
        var bodyLog = encoder.convert(body);
        debugPrint(bodyLog);
        debugPrint("🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥");
        debugPrint("Status Code: ${response.statusCode}");
        debugPrint("----- Response Body -----");
        debugPrint(response.body);
        debugPrint("\n\n🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄🦄");
        debugPrint("RES+ = ${response.body}");
      }
     
      final pamResponse = PamResponse.parse(response.body);
      return pamResponse;
    } catch (e) {
      if (Pam.shared.isEnableLog) {
        debugPrint("\n\n🦄🦄🦄🦄🦄 PAM TRACKING ERROR 🦄🦄🦄🦄🦄🦄");
        debugPrint(e.toString());
      }
      var errorResponse = PamResponse();
      errorResponse.error =
          PamErrorResponse(code: "EXCEPTION", errorMessage: e.toString());
      return errorResponse;
    }
  }
}
