# PAM Flutter SDK Example

แอป Android/iOS พร้อมปุ่มทดสอบ API และ REST auth จำลองสำหรับ login/logout, `identityProvider`, `onIdentityMismatch` และ lifecycle

## แก้ config ใน Code แล้วรัน

แก้ `lib/pam_config.dart`: endpoint, database aliases, Tracking / Contacting Consent Message IDs และตัวเลือกของ PamConfig จากนั้น:

```bash
cd example
flutter pub get
flutter run
```

ใช้ Flutter 3.41+ / Dart 3.11+ Runtime เรียก **getDevelopConfig เท่านั้น** ส่วน getProductionConfig เก็บเป็นตัวอย่างอ้างอิง ไม่มี UI แก้ config หรือปุ่ม initialize ต้อง restart แอปหลังเปลี่ยน config

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = DemoAuthController();
  final config = PamConfigProvider.getDevelopConfig(
    auth.identityProvider,
    auth.onIdentityMismatch,
  );
  await Pam.initialize(config);
  runApp(MyApp(auth: auth));
}
```

PAM ใช้ server จริงจาก config ส่วน auth server จำลองรับส่ง JSON ภายในแอป ไม่มี request ออกไปยัง auth server ภายนอก และไม่ใช่ระบบ authentication สำหรับ production

## Android Sync / Build

เปิด Flutter project ที่ `example/` หรือ Gradle project ที่ `example/android/` ตัวอย่างใช้ Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20, Java target 17 และ minSdk 24 เพื่อรองรับเครื่องมือ Flutter และ Android Studio ปัจจุบัน หากพบ `Unsupported class file major version 69` ให้ Sync wrapper รุ่นใหม่ก่อน

```bash
flutter build apk --debug
```

## Login / Logout และ lifecycle

เปิดหมวด **ตัวตนผู้ใช้** แล้วกรอก Customer ID เอง:

- Login: `POST /auth/login` สำเร็จ → เก็บ app session → `Pam.userLogin(customerId)`
- Logout: `POST /auth/logout` สำเร็จ → app เป็น anonymous → `Pam.userLogout()`
- เปิดแอป / resume: `GET /auth/session` → อัปเดต cache → sync PAM ก่อนเปิดปุ่ม API อื่น
- Provider อ่าน cache ทันที: `unknown` ขณะโหลด, `anonymous` เมื่อ guest, `identified` พร้อม Customer ID เมื่อ login
- `401` จาก session หมายถึง guest แต่ `500` / network error หมายถึงยังไม่ทราบสถานะ จึงไม่ logout โดยเดา
- หาก PAM ล้มเหลวหลัง REST สำเร็จ จะคง app session ไว้และให้ retry sync

ปุ่ม refresh ใช้ flow เดียวกับ `WidgetsBindingObserver` เมื่อ `AppLifecycleState.resumed` Token และ session จำลองอยู่ในหน่วยความจำ เมื่อเริ่ม process ใหม่จะเริ่มเป็น guest

## ทดลอง mismatch callback

1. Login เป็น A ให้ PAM มี identity ก่อน
2. จำลอง server เปลี่ยนบัญชีเป็น B หรือทำให้ session หมดอายุ
3. กด **โหลด session แต่ยังไม่แจ้ง PAM** เพื่อจงใจจำลองแอปลืมแจ้ง SDK
4. กด **Pam.track(test) → ตรวจ identity mismatch** แล้วดูลำดับเหตุการณ์และการ sync ใน callback

Event ที่ mismatch ถูกทิ้งและไม่ replay อัตโนมัติ Callback อ่าน session ล่าสุดหลัง REST operation ที่ค้างจบ เพื่อไม่ใช้ identity เก่าทับบัญชีใหม่ เมื่อ SDK ยังไม่มี identity เดิมจะไม่เกิด callback ตามกติกาของ SDK

## API อื่น

ยังมีปุ่ม Consent ทั้ง API ใหม่/เดิม, UI กลาง, fromStatus/copyWith, Tracking พร้อม JSON payload, Push และ App Attention / อุปกรณ์ ภาษา Consent ใช้ `th → en → jp` เป็น fallback และแปลง `Locale('ja')` ไปอ่าน key `jp`

Push ต้องนำ token จริงจากระบบ Push ของแอปมาใส่ ตัวอย่างไม่ได้ตั้งค่า Firebase ให้ ส่วน App Attention ต้องมี Campaign เข้าเงื่อนไข และ ATT ต้องตั้งค่า native บน iOS

## โครงสร้างและการทดสอบ

- `lib/main.dart`: startup และ getDevelopConfig
- `lib/demo_auth_api.dart`: REST client และ server จำลอง
- `lib/demo_auth_controller.dart`: session, provider, mismatch และ lifecycle flow
- `lib/sdk_demo_page.dart`: ปุ่มทดสอบและ WidgetsBindingObserver
- `lib/demo_results.dart`: แสดงผล API เป็น JSON

```bash
flutter test
```

Tests ไม่ส่งข้อมูลไปยัง PAM จริง ดู flow และตาราง API เพิ่มใน [sdk-docs](../sdk-docs/docs/example.md)
