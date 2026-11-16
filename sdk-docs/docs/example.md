# แอปตัวอย่างพร้อมปุ่มทดสอบ API

โฟลเดอร์ `example/` เป็นแอป Android/iOS สำหรับทดลอง PAM Flutter SDK เปิดแอปแล้ว initialize จากโค้ดทันที ไม่มีฟอร์มหรือปุ่มแก้ config ใน UI ส่วน Consent, Tracking, Push และ App Attention ยังมีปุ่มให้ทดลองพร้อมผลลัพธ์และข้อผิดพลาด

ตัวอย่างมี REST API สำหรับระบบสมาชิกจำลองภายในแอป เพื่อสาธิต `identityProvider`, `onIdentityMismatch` และ lifecycle โดยไม่ต้องตั้ง auth server แยก ส่วนคำขอ PAM ยังคงใช้ server จริงจาก config

## ตั้งค่าใน Code แล้วรัน

แก้ `example/lib/pam_config.dart` ก่อนรัน:

- `endpoint`, `publicDatabase`, `loginDatabase`: ค่า PAM environment สำหรับทดสอบ ต้องมี database alias อย่างน้อยหนึ่งฐานข้อมูล
- `trackingMessageId`, `contactingMessageId`: รหัส Consent ให้ตรงกับประเภท
- ปรับ log หรือ `blockEventsIfNoConsent` ในโค้ดสร้าง `PamConfig` ตามการใช้งาน

Runtime เรียก **`getDevelopConfig()` เท่านั้น** ส่วน `getProductionConfig()` เก็บเป็นโค้ดอ้างอิง ไม่ได้ถูกเลือกจาก UI เมื่อเปลี่ยน config ให้ restart แอปเพื่อรัน `main()` ใหม่ ไม่ใช้เพียง hot reload

```bash
cd example
flutter pub get
flutter run
```

ใช้ Flutter/Dart ตามข้อกำหนด SDK และเลือกอุปกรณ์ Android หรือ iOS ส่วนโครงสร้าง startup ใน `main.dart` เป็นดังนี้:

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

หลังเปิด UI จะโหลด session จำลองใน frame แรก ระหว่างโหลด `identityProvider` คืน `unknown` และปุ่ม API ที่ต้องใช้ตัวตนจะยังไม่เปิด เมื่อทราบ session และ sync PAM แล้วจึงพร้อมทดสอบ ไม่มีการยอมรับ Consent หรือเปิด App Attention เอง

หมวด **การเริ่มต้น / Session** แสดง config แบบอ่านอย่างเดียว และมีปุ่ม refresh session, retry sync และ reset ข้อมูล PAM การ reset ไม่ได้ logout ระบบสมาชิก ตัวอย่างจึง sync ตัวตนกลับให้ตรงกับ app session หลัง reset

## Sync และ Build บน Android

เปิดโฟลเดอร์ `example/` เป็น Flutter project หรือเปิด `example/android/` เมื่อต้องการตรวจ Gradle โดยตรง โฟลเดอร์ `android/` ที่ root ของ repository เป็นโมดูล SDK ไม่ใช่แอปตัวอย่าง

ชุด build ของ example ใช้ Gradle 9.1.0, Android Gradle Plugin 9.0.1 และ Kotlin 2.3.20 โดยกำหนด Java/Kotlin target 17 และ minSdk 24 ชุดนี้ตรงกับรุ่นที่ Flutter ในการตรวจสอบใช้อยู่ และ Gradle 9.1 รองรับ Java 25 ที่มากับ Android Studio รุ่นใหม่ ตาม [ตารางความเข้ากันได้ของ Gradle](https://docs.gradle.org/current/userguide/compatibility.html)

```bash
cd example
flutter pub get
flutter build apk --debug
```

หากพบ `Unsupported class file major version 69` ให้ตรวจว่า Sync ด้วย wrapper ของ `example/android/` รุ่นใหม่แล้ว ไม่ได้ใช้ Gradle 8.2.1 เดิม ส่วน `android.builtInKotlin=false` และ `android.newDsl=false` ใน example เป็นค่ารองรับ Flutter/plugin ที่ยังใช้ Kotlin plugin และ Android DSL แบบเดิม

โมดูล SDK ใช้ `compileSdk 36` ให้ตรงกับข้อกำหนดของ `flutter_secure_storage` โดยยังคง `minSdk 24` จึงไม่ได้เพิ่มเวอร์ชัน Android ขั้นต่ำของอุปกรณ์

ใช้ `flutter doctor -v` ตรวจ Android SDK และอุปกรณ์ หากขาด SDK component ให้ติดตั้งจาก Android Studio > SDK Manager ตามข้อความ build ไม่ต้องเปลี่ยนค่าการเชื่อมต่อ PAM ใน UI

## จำลอง Login, Logout และ lifecycle

เปิดหมวด **ตัวตนผู้ใช้** แล้วกรอก Customer ID ได้เอง เช่น `CUSTOMER-A` ไม่ต้องแก้ Customer ID ในโค้ด ตัวอย่างใช้ `identityMatcher` แบบ `customer` จึงส่งรหัสเดียวกันให้ทั้ง provider และ `Pam.userLogin()`

REST API จำลองรับส่ง JSON ผ่าน HTTP client ที่ทำงานในหน่วยความจำ ไม่มี socket หรือ request ไปยัง `demo-auth.invalid` จริง:

| Endpoint จำลอง | การทำงาน |
|---|---|
| `POST /auth/login` | รับ `{ "customer_id": "CUSTOMER-A" }` แล้วคืน session และ token จำลอง |
| `POST /auth/logout` | ยกเลิก token ของ session ปัจจุบัน |
| `GET /auth/session` | คืน Customer ID ปัจจุบัน หรือ `401` เมื่อยังไม่ login / session หมดอายุ |
| `POST /demo/expire` | จำลอง session หมดอายุเฉพาะฝั่ง server |
| `POST /demo/switch-customer` | จำลองการเปลี่ยน Customer ID ฝั่ง server โดยยังไม่เปลี่ยน cache ในแอป |

ลำดับการทำงานปกติ:

1. **เปิดแอป:** initialize PAM → `GET /auth/session` → เก็บ session ในแอป → sync ตัวตนกับ PAM
2. **Login:** กด `POST /auth/login → Pam.userLogin` → รอ REST สำเร็จ → เก็บ Customer ID ใน app session → แจ้ง PAM ด้วยรหัสเดียวกัน
3. **Logout:** กด `POST /auth/logout → Pam.userLogout` → รอ REST สำเร็จ → เปลี่ยน app session เป็น anonymous → แจ้ง PAM
4. **กลับเข้าแอป:** `WidgetsBindingObserver` รับ `AppLifecycleState.resumed` → โหลด session อีกครั้ง → หาก Customer ID เปลี่ยนหรือกลายเป็น guest จะ sync PAM ก่อนเปิดปุ่ม API อื่น

ปุ่ม **GET /auth/session → sync PAM (resume)** เรียกเส้นทางเดียวกับ lifecycle จริง ใช้ทดลองได้โดยไม่ต้องสลับออกจากแอป การ refresh ซ้ำขณะกำลังโหลดจะรวมเป็นงานเดียว และการเปลี่ยน session จะเรียงลำดับเพื่อป้องกันผลลัพธ์เก่าทับบัญชีใหม่

`identityProvider` อ่านเฉพาะ cache แบบ synchronous ไม่เรียก REST เอง:

```dart
PamUserState identityProvider() {
  if (_loadingSession || !sessionKnown) {
    return const PamUserState.unknown();
  }
  final current = session;
  return current == null
      ? const PamUserState.anonymous()
      : PamUserState.identified(current.customerId);
}
```

โค้ดนี้อยู่ใน `demo_auth_controller.dart` โดย `unknown` ของ SDK ไม่ได้พัก event ให้อัตโนมัติ ดังนั้น example จึงปิดปุ่มที่ต้องใช้ตัวตนระหว่างโหลดหรือรอ sync เพิ่มเติมเอง

## ทดลอง onIdentityMismatch ให้เกิดจริง

Flow ปกติ sync PAM อยู่แล้ว จึงมีปุ่มสำหรับจงใจจำลองกรณีแอปลืมแจ้ง PAM แยกต่างหาก:

1. Login ด้วย `CUSTOMER-A` ให้ PAM มี identity เดิมก่อน
2. เปลี่ยนช่อง Customer ID เป็น `CUSTOMER-B` แล้วกด **จำลอง server: เปลี่ยน Customer ID**
3. กด **ทดสอบ: โหลด session แต่ยังไม่แจ้ง PAM** ตอนนี้ app session เป็น B แต่ PAM ยังเป็น A ปุ่ม API ปกติจะปิดไว้
4. กด **Pam.track(test) → ตรวจ identity mismatch** SDK จะทิ้ง event นี้และเรียก callback
5. ดู **ลำดับเหตุการณ์ Auth / PAM** จะเห็น A → B และการเรียก `Pam.userLogin(B)` เพื่อแก้สถานะ
6. กดทดสอบ event อีกครั้งเมื่อตัวตนตรงกัน โดย SDK ไม่ส่ง event เก่าซ้ำให้เอง

หากต้องการทดลอง logout mismatch ให้ใช้ปุ่ม **จำลอง server: session หมดอายุ** แทนการเปลี่ยนบัญชี แล้วทำข้อ 3–4 จะได้ callback จาก A → anonymous และเรียก `Pam.userLogout()`

Callback รอ REST operation ที่ยังค้าง แล้วอ่าน app session ล่าสุดใหม่ก่อน sync จึงไม่ใช้ `mismatch.newIdentity` เก่าทับผู้ใช้ที่เพิ่งเปลี่ยนอีกครั้ง หาก SDK ยังไม่มี identity เดิม จะไม่เรียก callback ตามกติกาของ SDK ตัวอย่างจึงให้ Login ก่อนทดสอบ

`test` ใช้ตรวจตัวตนและผ่าน gate Consent/ช่วงพักของ SDK เพื่อให้ทดลองได้ แต่การส่งไป PAM จริงยังขึ้นอยู่กับ config และผลตอบกลับของ server

### กรณีผิดพลาด

- REST login/logout ไม่สำเร็จ: ไม่เปลี่ยน app session และไม่แจ้งการเปลี่ยนตัวตนให้ PAM
- โหลด session ได้ `401`: ถือว่า guest แล้ว sync logout ตามสถานะจริง
- โหลด session ล้มเหลว เช่น `500`: คืน `unknown` และไม่เดาว่าเป็น logout ให้ลอง refresh ใหม่
- REST สำเร็จแต่ PAM login ล้มเหลว: เก็บ session ที่สำเร็จของแอปไว้ ปิดปุ่มที่ต้องใช้ PAM และให้กด **Sync PAM กับ session ล่าสุด** เพื่อ retry แม้ SDK จะเปลี่ยน identity ในเครื่องไปแล้ว
- `Pam.userLogout()` คืน `Future<void>` ตัวอย่างตรวจ identity ในเครื่องหลังเรียก แต่ผลเครือข่ายฝั่ง PAM ให้ดู SDK log เพิ่มเติม

Auth จำลองเก็บ token และ session ในหน่วยความจำเท่านั้น เมื่อปิด process แล้วเริ่มใหม่จะเริ่มเป็น guest ไม่ใช่ระบบ authentication สำหรับ production แอปจริงต้องแทนด้วย API และการเก็บ session ของตนเอง

## API ที่มีปุ่มให้ทดสอบ

| หมวด | API / ตัวอย่าง | ผลลัพธ์ที่ดูได้ |
|---|---|---|
| การเริ่มต้น / Session | `Pam.initialize` ใน main, `Pam.reset`, refresh / retry sync | Config จาก Code และสถานะ app session |
| Consent — UI กลาง | `Pam.showConsent` แยกปุ่ม Tracking / Contacting | หน้าจอจากข้อความจริง และผล `saved` หรือ `dismissed` |
| Consent — อ่านข้อมูล | `Pam.loadConsentMessage`, `Pam.loadConsentStatus`, `Pam.loadConsentMessages` | ประเภท เวอร์ชัน ภาษา permission และสถานะเดิม |
| Consent — เลือกบางรายการ | `TrackingConsent`, `ContactingConsent`, `Pam.saveConsent` | consent ID และผลรายข้อความ |
| Consent — แก้สถานะเดิม | `TrackingConsent.fromStatus`, `ContactingConsent.fromStatus`, `copyWith` | โหลดค่าเดิมลง switch แล้วเปลี่ยนเฉพาะรายการที่ต้องการ |
| Consent — API เดิม | `Pam.allowConsent`, `Pam.allowAllTrackingConsent`, `Pam.allowAllContactingConsent`, `Pam.submitConsent`, `Pam.submitConsents` | ผลการบันทึกด้วยรูปแบบเดิม |
| ตัวตนผู้ใช้ | REST login/logout จำลอง, `identityProvider`, `onIdentityMismatch`, `Pam.userLogin`, `Pam.userLogout`, `Pam.getCustID` | สถานะทั้งแอปและ SDK พร้อมลำดับเหตุการณ์ |
| Tracking | `Pam.track`, `Pam.log` | response จาก event หรือ log ของแพลตฟอร์ม |
| Push — token | `Pam.setPushNotificationToken`, `Pam.onToken` | ผลส่ง token และ callback เมื่อได้รับ token |
| Push — ประวัติ | `Pam.loadPushNotifications`, `Pam.loadPushNotificationsFromEmail`, `Pam.loadPushNotificationsFromMobile`, `Pam.loadPushNotificationsFromCustomerID` | รายการข้อความที่นำไปเลือกทดสอบ read/click ได้ |
| Push — payload / tracking | `Pam.isPushNotiFromPam`, `Pam.convertToPamPushMessage`, `PamPushMessage.trackRead`, `PamPushMessage.trackPushUrlClick` | ผลตรวจ payload ข้อความที่แปลงแล้ว และการเรียก read/click pixel |
| App Attention / อุปกรณ์ | `Pam.appAttention`, `Pam.getPlatformVersion`, `Pam.identifierForVendor`, `Pam.trackingAuthorizationStatus`, `Pam.requestTrackingAuthorization` | popup ที่เข้าเงื่อนไข ข้อมูลอุปกรณ์ และสถานะ ATT |

ตัวอย่างจะแสดง field ที่อ่านได้จริงแทนข้อความ `Instance of ...` และแสดงข้อผิดพลาดบนหน้าจอ ระหว่างทำงานจะป้องกันการกดปุ่มซ้ำและการแก้ค่าที่กำลังใช้งาน

## ทดลอง Consent ตามลำดับ

### เปิด UI กลาง

เลือกหมวด **Consent** ตั้งภาษาเริ่มต้นเป็นอัตโนมัติ ไทย อังกฤษ หรือญี่ปุ่น แล้วกด **Pam.showConsent — Tracking** หรือ **Contacting**

```dart
final result = await Pam.showConsent(
  context,
  messageId: trackingConsentMessageId,
  // ไม่ส่ง locale: เลือก th → en → jp
);

if (result.outcome == PamConsentOutcome.saved) {
  print(result.submission!.consentID);
}
```

หากเลือกญี่ปุ่นใน example จะส่ง `Locale('ja')` ให้ SDK ไปอ่านข้อความจาก key `jp` กรณีภาษาที่เลือกไม่มีข้อความจะ fallback ตาม `th` → `en` → `jp` ผู้ใช้เปลี่ยนภาษาในหน้าจอ Consent ได้โดยไม่ล้างตัวเลือก อ่านเงื่อนไขเพิ่มเติมที่ [การจัดการ Consent](consent.html)

### เลือกบางรายการด้วย API

กดโหลด message เพื่อดูรายละเอียดก่อน จากนั้นปรับ switch ใต้ประเภทที่ต้องการ แล้วกด **Pam.saveConsent** รายการบังคับจะเปิดและล็อกไว้ ส่วนรายการเสริมเริ่มเป็นปิด ปุ่มบันทึกคือการยืนยันตัวเลือกในแบบฟอร์มทดสอบนี้

```dart
final consent = ContactingConsent(
  messageId: contactingConsentMessageId,
  termsAndConditions: true,
  privacyOverview: true,
  email: true,
  sms: false,
);
final result = await Pam.saveConsent(consent);
```

แบบฟอร์มนี้สาธิตการเรียก API ระดับล่างและไม่ได้แทนหน้าจอขอความยินยอมสำหรับลูกค้าจริง แอปจริงต้องแสดงข้อความตามวัตถุประสงค์ก่อนให้ยืนยัน หรือใช้ `Pam.showConsent()` ซึ่งโหลดรายละเอียดมาแสดงให้

### เปลี่ยนจากสถานะเดิม

กด **TrackingConsent.fromStatus → copyWith** หรือ **ContactingConsent.fromStatus → copyWith** เพื่อโหลดค่าที่เคยยืนยันลง switch แล้วแก้เฉพาะรายการที่ต้องการและกด **Pam.saveConsent**

```dart
final status = await Pam.loadConsentStatus(contactingConsentMessageId);
final current = ContactingConsent.fromStatus(status);
final updated = current.copyWith(sms: true);
await Pam.saveConsent(updated);
```

หากยังไม่เคยยอมรับ โหลดสถานะไม่สำเร็จ หรือต้องทบทวน จะเห็นข้อผิดพลาดจาก factory ให้ใช้ปุ่ม UI กลางเพื่อโหลดข้อความและขอการยืนยันใหม่ ตัวอย่างจะทิ้ง draft เดิมเมื่อ app session เปลี่ยนบัญชี และนำตัวเลือกที่เพิ่งบันทึกจาก UI กลางกลับมาแสดงใน switch

### เปรียบเทียบกับ API เดิม

- `allowConsent` และ `allowAll...` ยอมรับทุกรายการเมื่อกดปุ่ม โดยไม่ใช้ค่าจาก switch
- `submitConsent` โหลดข้อความแล้วกำหนด `setPermission()` ตาม switch ก่อนส่งเวอร์ชันที่โหลดมา
- `submitConsents` โหลดทั้งสองข้อความให้สำเร็จก่อนส่ง แต่การบันทึกหลายข้อความไม่ใช่ธุรกรรมที่สำเร็จพร้อมกันทั้งหมด ให้ตรวจผลรายข้อความ
- `loadConsentMessages` โหลดหลายข้อความเพื่อดูผล โดยไม่ส่ง Consent

API เดิมยังคงใช้งานได้ เลือกวิธีให้ตรงกับรูปแบบ UI ของแอป

## หมวดอื่น ๆ

**ตัวตนผู้ใช้:** ใช้ REST API จำลองและ lifecycle ตามหัวข้อข้างต้น โค้ดรอผลเพื่อให้เห็นแต่ละขั้นตอนชัดเจน อ่านกติกาของ SDK เพิ่มที่ [การเข้าสู่ระบบ](authentication.html) และ [Identity Provider](initialization.html)

**Tracking:** กรอกชื่อ event และ JSON object เช่น `{"sku":"DEMO-SKU-001","price":590}` แล้วกด `Pam.track` หากเปิด block และยังไม่ยอมรับ Tracking Consent อาจได้ `null` โดยไม่มีการส่ง event ดู [Event Tracking](tracking.html)

**Push:** กรอก token ที่ได้จากระบบ Push ของแอปเอง ตัวอย่างไม่ได้ติดตั้ง Firebase Messaging หรือขอสิทธิ์ notification ให้อัตโนมัติ โหลดประวัติก่อนเลือกข้อความที่จะกด read/click การโหลดรายการหรือแปลง payload ไม่เรียก `trackRead()` เอง การเรียก pixel ส่งแบบไม่รอผล ให้ดู SDK log สำหรับผลเครือข่าย ดู [Push Notification](push-notification.html)

**App Attention:** กรอก `pageName` ที่ตรงกับ Campaign แล้วกดปุ่ม หากไม่มีข้อความเข้าเงื่อนไขจะไม่แสดง popup ไม่ได้หมายความว่าเรียก API ผิด ดู [App Attention](app-attention.html)

**ATT:** ทดสอบการขอสิทธิ์บน iOS เท่านั้น โดยมี `NSUserTrackingUsageDescription` ใน `Info.plist` ของแอป แพลตฟอร์มอื่นคืน `notSupported` สิทธิ์นี้แยกจาก PAM Consent

## โครงสร้างซอร์สตัวอย่าง

| ไฟล์ | หน้าที่ |
|---|---|
| `example/lib/main.dart` | เรียก getDevelopConfig และ await Pam.initialize ก่อน runApp |
| `example/lib/pam_config.dart` | แหล่ง config ที่แก้ใน Code ก่อน restart แอป |
| `example/lib/demo_auth_api.dart` | REST client และ auth server จำลองภายในแอป |
| `example/lib/demo_auth_controller.dart` | Cache session, provider, mismatch callback และลำดับ login/logout/refresh |
| `example/lib/sdk_demo_page.dart` | แบบฟอร์ม ปุ่ม และโค้ดเรียก API จริง แยกตามเมธอด `_overview`, `_consents`, `_identity`, `_tracking`, `_push`, `_device` |
| `example/lib/demo_results.dart` | แปลง field ของผลลัพธ์เป็น JSON สำหรับแสดงบนหน้าจอ |

[กลับหน้าแรก](index.html)
