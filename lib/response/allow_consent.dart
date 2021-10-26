class AllowConsentResult {
  String? contactID;
  String? database;
  String? consentID;

  AllowConsentResult(this.contactID, this.database, this.consentID);

  static AllowConsentResult parse(Map<String, dynamic> json) {
    var contactID = json["contact_id"]?.toString();
    var database = json["_database"]?.toString();
    var consentID = json["consent_id"]?.toString();

    return AllowConsentResult(contactID, database, consentID);
  }
}
