import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pam_flutter/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserPreference preference;

  setUp(() {
    preference = UserPreference();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('saveString stores values in secure storage and clears legacy value',
      () async {
    final keyName = preference.getKeyName(SaveKey.customerID);
    SharedPreferences.setMockInitialValues({keyName: 'legacy-customer'});

    await preference.saveString('secure-customer', SaveKey.customerID);

    final secureStorage = const FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    expect(await secureStorage.read(key: keyName), 'secure-customer');
    expect(prefs.getString(keyName), isNull);
  });

  test('getString migrates legacy SharedPreferences value to secure storage',
      () async {
    final keyName = preference.getKeyName(SaveKey.pushKey);
    SharedPreferences.setMockInitialValues({keyName: 'legacy-token'});

    final value = await preference.getString(SaveKey.pushKey);

    final secureStorage = const FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    expect(value, 'legacy-token');
    expect(await secureStorage.read(key: keyName), 'legacy-token');
    expect(prefs.getString(keyName), isNull);
  });

  test('getString reads secure storage before legacy SharedPreferences',
      () async {
    final keyName = preference.getKeyName(SaveKey.contactID);
    FlutterSecureStorage.setMockInitialValues({keyName: 'secure-contact'});
    SharedPreferences.setMockInitialValues({keyName: 'legacy-contact'});

    final value = await preference.getString(SaveKey.contactID);

    final prefs = await SharedPreferences.getInstance();

    expect(value, 'secure-contact');
    expect(prefs.getString(keyName), 'legacy-contact');
  });

  test('remove clears secure storage and legacy SharedPreferences', () async {
    final keyName = preference.getKeyName(SaveKey.deviceUDID);
    FlutterSecureStorage.setMockInitialValues({keyName: 'secure-device'});
    SharedPreferences.setMockInitialValues({keyName: 'legacy-device'});

    await preference.remove(SaveKey.deviceUDID);

    final secureStorage = const FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();

    expect(await secureStorage.read(key: keyName), isNull);
    expect(prefs.getString(keyName), isNull);
  });
}
