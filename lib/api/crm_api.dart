import 'package:http/http.dart' show Response;
import '../pam.dart';
import 'dart:async';
import '../http/http_client.dart';

class CRMAPI {
  String baseURL;

  CRMAPI(this.baseURL);

  Future<String?> getAppAttention(String pageName) async {
    Response? response;
    var contactID = await Pam.shared.getContactID();
    if (contactID == null) {
      return null;
    }

    try {
      var uri = Uri.parse("$baseURL/app-attention");

      response = await HttpClient.post(uri, body: {
        "page_name": pageName,
        "_contact_id": await Pam.shared.getContactID()
      });

      Pam.log([
        "GET APP ATTENTION",
        uri.toString(),
        "🚥🚥🚥🚥🚥 RESULT 🚥🚥🚥🚥🚥",
        "Status Code: ${response.statusCode}",
        "----- Response Body -----",
        response.body
      ]);
    } catch (e) {
      Pam.log(["APP ATTENTION", e.toString()]);
    }

    if (response != null) {
      return response.body;
    }

    return null;
  }
}
