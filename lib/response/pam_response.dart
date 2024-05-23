import 'dart:convert';
import "../pam.dart";

class PamErrorResponse {
  String? code, errorMessage;
  PamErrorResponse({required this.code, required this.errorMessage});
}

class PamResponse {
  String? database, contactID, consentID;
  PamErrorResponse? error;

  static PamResponse createErrorResponse(
      {required String code, required String errorMessage}) {
    var response = PamResponse();
    response.error = PamErrorResponse(code: code, errorMessage: errorMessage);
    return response;
  }

  static PamResponse? parse(String jsonString) {
    Map<String, dynamic> map;
    try {
      map = jsonDecode(jsonString);
    } catch (e) {
      Pam.log(["PamResponse parse Error", e.toString()]);
      return null;
    }

    var response = PamResponse();
    final code = map['code'];
    final errorMessage = map["message"];

    if (code != null) {
      response.error = PamErrorResponse(code: code, errorMessage: errorMessage);
    }

    response.contactID = map["contact_id"];
    response.consentID = map["consent_id"];
    response.database = map["database"];

    return response;
  }
}
