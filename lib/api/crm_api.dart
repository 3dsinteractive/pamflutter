import 'package:http/http.dart' show Response;
import '../pam.dart';
import 'dart:async';
import '../http/http_client.dart';

class CRMAPI {
  String baseURL;

  CRMAPI(this.baseURL);

  Future<String?> getAppAttention(String pageName) async {
    var contactID = await Pam.shared.getContactID();
    if (contactID == null) {
      return null;
    }

    try {
      var uri = Uri.parse("$baseURL/app-attention");
      var response = await HttpClient.post(uri,
          body: {"page_name": pageName, "_contact_id": contactID});

      Pam.log([
        "GET APP ATTENTION",
        uri.toString(),
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body
      ]);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
    } catch (e) {
      Pam.log(["APP ATTENTION", e.toString()]);
    }

    return null;
  }
}
