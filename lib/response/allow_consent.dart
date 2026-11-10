class AllowConsentResult {
  String? contactID;
  String? database;
  String? consentID;
  String? consentMessageID;

  AllowConsentResult(this.contactID, this.database, this.consentID,
      [this.consentMessageID]);

  static AllowConsentResult parse(Map<String, dynamic> json) {
    var contactID = json["contact_id"]?.toString();
    var database = json["_database"]?.toString();
    var consentID = json["consent_id"]?.toString();
    var consentMessageID = json["consent_message_id"]?.toString();

    return AllowConsentResult(contactID, database, consentID, consentMessageID);
  }
}
