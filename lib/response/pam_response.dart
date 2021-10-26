import 'dart:convert';

class PamResponse{
  String? code, message, database, contactID, consentID;

  static PamResponse parse(String jsonString) {
    Map<String, dynamic> map = jsonDecode(jsonString);
    PamResponse response = PamResponse();
    response.code = map['code'];
    response.message = map["message"];
    response.contactID = map["contact_id"];
    response.consentID = map["consent_id"];
    response.database = map["database"];
    
    return response;
  }
}