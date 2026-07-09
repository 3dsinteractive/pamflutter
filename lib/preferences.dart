library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _secureStorage = FlutterSecureStorage();

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
    await _secureStorage.write(key: keyName, value: value);

    var pref = await SharedPreferences.getInstance();
    await pref.remove(keyName);
  }

  Future<bool?> getBool(SaveKey key) async {
    String keyName = getKeyName(key);
    var prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyName);
  }

  Future<String?> getString(SaveKey key) async {
    String keyName = getKeyName(key);
    var secureValue = await _secureStorage.read(key: keyName);
    if (secureValue != null) {
      return secureValue;
    }

    return _readLegacySharedPreferencesStringAndMigrate(keyName);
  }

  Future<void> remove(SaveKey key) async {
    String keyName = getKeyName(key);
    await _secureStorage.delete(key: keyName);

    var pref = await SharedPreferences.getInstance();
    await pref.remove(keyName);
  }

  Future<String?> _readLegacySharedPreferencesStringAndMigrate(
    String keyName,
  ) async {
    var prefs = await SharedPreferences.getInstance();
    var legacyValue = prefs.getString(keyName);
    if (legacyValue == null) {
      return null;
    }

    // Backward compatibility:
    // Versions before secure storage saved string preferences as plain text in
    // SharedPreferences. Read the old value once, copy it into secure storage,
    // then remove the legacy entry so existing users keep their IDs/tokens
    // after upgrading.
    await _secureStorage.write(key: keyName, value: legacyValue);
    await prefs.remove(keyName);

    return legacyValue;
  }
}
