library;

import 'package:shared_preferences/shared_preferences.dart';

enum SaveKey {
  customerID,
  contactID,
  loginContactID,
  pushKey,
  allowTracking,
  deviceUDID,
}

class UserPreference {
  String getKeyName(SaveKey key) {
    switch (key) {
      case SaveKey.customerID:
        return "@pam_customer_id";
      case SaveKey.contactID:
        return "@pam_contect_id";
      case SaveKey.loginContactID:
        return "@pam_login_contact_id";
      case SaveKey.pushKey:
        return "@pam_push_key";
      case SaveKey.allowTracking:
        return "@pam_allow_tracking";
      case SaveKey.deviceUDID:
        return "@pam_device_udid";
    }
  }

  Future<void> saveBool(bool value, SaveKey key) async {
    String keyName = getKeyName(key);
    var pref = await SharedPreferences.getInstance();
    await pref.setBool(keyName, value);
  }

  Future<void> saveString(String value, SaveKey key) async {
    String keyName = getKeyName(key);
    var pref = await SharedPreferences.getInstance();
    await pref.setString(keyName, value);
  }

  Future<bool?> getBool(SaveKey key) async {
    String keyName = getKeyName(key);
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyName);
  }

  Future<String?> getString(SaveKey key) async {
    String keyName = getKeyName(key);
    var prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyName);
  }

  Future<void> remove(SaveKey key) async {
    String keyName = getKeyName(key);
    var pref = await SharedPreferences.getInstance();
    await pref.remove(keyName);
  }
}
