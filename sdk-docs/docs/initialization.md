# เตรียม Config และเริ่มต้นใช้งาน PAM

หลังติดตั้ง `pam_flutter` ให้สร้าง `PamConfig` เพื่อกำหนดการเชื่อมต่อ ฐานข้อมูล และการระบุตัวตนผู้ใช้ จากนั้นส่ง config ให้ `Pam.initialize()` ก่อนเริ่มใช้งาน SDK

---

## เตรียม Config

ตัวอย่างนี้แยกค่าพารามิเตอร์ออกเป็นตัวแปรเพื่อให้อ่านโครงสร้างได้ง่าย โดยต้องกำหนดค่าตัวแปรเหล่านี้ก่อนนำไปใช้งานจริง

```dart
import 'package:pam_flutter/pam.dart';

final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  identityMatcher: identityMatcher,
  identityProvider: identityProvider,
  onIdentityMismatch: onIdentityMismatch,
);
```

---

## พารามิเตอร์

| ชื่อพารามิเตอร์ | คำอธิบาย |
|---|---|
| `endpoint` | URL ของเซิร์ฟเวอร์ PAM ที่แอปต้องการเชื่อมต่อ เช่น `https://example.pams.ai` |
| `publicDBAlias` | ชื่ออ้างอิงฐานข้อมูลสำหรับผู้ใช้ที่ยังไม่ได้เข้าสู่ระบบ SDK จะส่งข้อมูลกิจกรรมไปยังฐานข้อมูลนี้ขณะอยู่ในสถานะผู้ใช้ไม่ระบุตัวตน |
| `loginDBAlias` | ชื่ออ้างอิงฐานข้อมูลสำหรับผู้ใช้ที่เข้าสู่ระบบแล้ว SDK จะใช้ฐานข้อมูลนี้หลังจากระบุตัวตนผ่าน `Pam.userLogin()` สำเร็จ |
| `trackingConsentMessageID` | รหัสข้อความขอความยินยอมสำหรับการติดตามกิจกรรม ใช้อ้างอิงความยินยอมที่ตั้งค่าไว้ใน PAM และตรวจสอบสถานะความยินยอมของผู้ใช้ |
| `enableLog` | กำหนดให้ SDK แสดงบันทึกการทำงานเพื่อช่วยตรวจสอบปัญหา ใช้ `true` เพื่อเปิด หรือ `false` เพื่อปิด |
| `identityMatcher` | กำหนดฟิลด์ที่ PAM ใช้จับคู่ตัวตนผู้ใช้ เช่น รหัสลูกค้า (`customer`), อีเมล (`email`) หรือเบอร์โทรศัพท์ (`sms`) ค่าที่ส่งให้ `Pam.userLogin()` และ `identityProvider` ต้องสอดคล้องกับฟิลด์นี้ ต้องระบุพารามิเตอร์นี้ และไม่สามารถเปลี่ยนตัว matcher หลังสร้าง config แล้ว [อ่านเพิ่มเติม](#identity-matcher) |
| `identityProvider` | ฟังก์ชันที่ SDK เรียกเพื่ออ่านสถานะผู้ใช้ปัจจุบันจากแอป แล้วนำมาเทียบกับตัวตนที่ SDK เก็บไว้ก่อนส่ง tracking event ที่มีการตรวจสอบตัวตน เป็นตัวเลือกเสริม หากไม่ระบุ SDK จะไม่ตรวจสอบตัวตนกับสถานะของแอป [อ่านเพิ่มเติม](#identity-provider) |
| `onIdentityMismatch` | ฟังก์ชันที่ SDK เรียกเมื่อพบว่าตัวตนในแอปไม่ตรงกับตัวตนใน SDK ใช้จัดการความคลาดเคลื่อน เช่น เรียก `Pam.userLogin()` หรือ `Pam.userLogout()` รองรับการทำงานแบบ asynchronous และเป็นตัวเลือกเสริม [อ่านเพิ่มเติม](#identity-mismatch) |

---

## ตรวจสอบการทำงานด้วย Log

ตั้ง `enableLog` เป็น `true` เพื่อเปิด log ทุกหมวดของ SDK และตั้งเป็น `false` เพื่อปิดทุกระดับ การเรียกแบบเดิมยังใช้ได้ และเลือกหมวดกับระดับเพิ่มเติมได้:

```dart
Pam.log(['SDK ready']); // General / INFO
Pam.log(
  ['Failed to load consent'],
  category: PamLogCategory.consent,
  level: PamLogLevel.error,
);
```

หมวด `PamLogCategory` มี `general`, `tracking`, `identity`, `consent`, `push`, `attention` และ `storage` ส่วน `PamLogLevel` มี `debug`, `info` (ค่าเริ่มต้น), `warning` และ `error` แต่ละบรรทัดมีรูปแบบ `[PAM][Consent][ERROR] ข้อความ` รวมถึง stack trace และข้อความยาวที่แบ่งเป็นหลายบรรทัด

- **Android Studio Logcat:** กรองด้วย `tag:PAM`, `tag:PAM message:Consent` หรือ `tag:PAM level:ERROR`
- **iOS Xcode / Console:** กรอง subsystem `ai.pams.flutter` และ category เช่น `Consent` หากต้องการรายละเอียดให้เปิดการแสดงข้อความระดับ info/debug ด้วย ระดับ warning ใช้ชนิด default ของ OSLog พร้อม `[WARN]` ในข้อความ
- หากระบบ log ของ native ยังไม่พร้อม จะใช้ Flutter console แทน โดยค้นหา `[PAM]` ได้

Log ของ API มี `request_id` สำหรับจับคู่คำขอกับผลลัพธ์ พร้อม HTTP status และ `duration_ms` ส่วน payload/response body อยู่ระดับ DEBUG ข้อผิดพลาดอยู่ระดับ ERROR นอกจากนี้มีเหตุผลที่ข้าม Attention, แหล่งค่าปุ่ม API/code/default, การเปลี่ยน session และผลการ reset เพื่อช่วยไล่ปัญหา

หลังอัปเดต SDK ต้อง rebuild แอปเพื่อรวมโค้ด native ใหม่ การ hot reload อย่างเดียวไม่เพียงพอ

---

<a id="identity-matcher"></a>

## identityMatcher: เลือกข้อมูลที่ใช้ระบุตัวตน

เลือกฟิลด์ให้ตรงกับคีย์ของฐานข้อมูลใน PAM เช่น หากใช้รหัสลูกค้า ให้กำหนดดังนี้:

```dart
final identityMatcher = PamIdentityMatcher.primary(
  PamPrimaryIdentityKey.customer,
);
```

จากนั้นใช้รหัสลูกค้าเดียวกันเมื่อเรียก `Pam.userLogin()` และเมื่อคืนค่าจาก `identityProvider` หากใช้คีย์หลักชนิดอื่น ให้เลือก `PamPrimaryIdentityKey.email` หรือ `PamPrimaryIdentityKey.sms` ส่วนคีย์รองใช้ `PamIdentityMatcher.secondary("ชื่อฟิลด์")`

---

<a id="identity-provider"></a>

## identityProvider: อ่านผู้ใช้ปัจจุบันจากแอป

`identityProvider` คือฟังก์ชันที่ PAM SDK เรียกเมื่อต้องการตรวจสอบว่า ขณะนี้ผู้ใช้ในแอปล็อกอินเป็นใครอยู่ โดยแอปต้องส่งกลับสถานะผู้ใช้ปัจจุบัน พร้อมข้อมูลระบุตัวตนที่ตรงกับ `identityMatcher` ที่ตั้งค่าไว้

ตัวอย่าง หากกำหนด `identityMatcher` เป็น `customer` ให้ส่งกลับ `PamUserState.identified(user.customerId)` หากกำหนดเป็น `email` ให้ส่งกลับ `PamUserState.identified(user.email)`

หากผู้ใช้ไม่ได้ล็อกอิน ให้ส่งกลับ `PamUserState.anonymous()` และหากยังไม่ทราบสถานะ เช่น กำลังโหลด session ให้ส่งกลับ `PamUserState.unknown()`

SDK จะนำข้อมูลนี้ไปเทียบกับตัวตนที่เก็บไว้ หากมีตัวตนเดิมอยู่แล้วและไม่ตรงกัน จะไม่ส่ง event นั้นและเรียก `onIdentityMismatch` หากกำหนดไว้ เพื่อให้แอปจัดการปรับสถานะให้ถูกต้อง หากตัวตนเดิมเป็น `null` จะให้ event ทำงานต่อโดยไม่เรียก callback เพราะถือเป็นช่วงสร้าง identity ครั้งแรก การสร้าง contact แรกอาจเกิดจากการให้ consent เช่น `Pam.allowAllTrackingConsent()` ได้ โดยไม่จำเป็นต้องผ่าน `Pam.userLogin()`

### ตัวอย่างการใช้งาน

ตัวอย่างนี้ใช้คู่กับ `identityMatcher` แบบ `customer` โดย `authRepository` หมายถึงส่วนจัดการสถานะผู้ใช้ของแอป ให้แทนด้วยระบบที่แอปใช้งานจริง

```dart
final identityProvider = () {
  // ยังโหลดสถานะการเข้าสู่ระบบไม่เสร็จ
  if (authRepository.isLoading) {
    return const PamUserState.unknown();
  }

  final user = authRepository.currentUser;

  // ไม่มีผู้ใช้ที่เข้าสู่ระบบ
  if (user == null) {
    return const PamUserState.anonymous();
  }

  // ส่งรหัสลูกค้าของผู้ใช้ปัจจุบัน
  return PamUserState.identified(user.customerId);
};
```

ฟังก์ชันนี้ต้องอ่านสถานะที่แอปโหลดไว้แล้วและคืนค่าทันที โดยไม่ใช้ `async/await` การคืน `PamUserState.unknown()` จะข้ามการตรวจสอบตัวตนครั้งนั้น ไม่ได้พัก event ไว้รอโหลด session

---

<a id="identity-mismatch"></a>

## onIdentityMismatch: จัดการเมื่อตัวตนไม่ตรงกัน

`onIdentityMismatch` จะถูกเรียกเมื่อ PAM มี identity เดิมอยู่แล้ว และตรวจพบว่าไม่ตรงกับผู้ใช้ปัจจุบันของแอป โดยอ้างอิงสถานะที่ได้จาก `identityProvider` กรณี `oldIdentity` เป็น `null` จะไม่เรียก callback นี้

### ข้อมูลตัวตนที่ได้รับ

SDK ส่งออบเจ็กต์ `mismatch` ให้ callback โดยมีข้อมูลตัวตนสองค่าที่แอปสามารถนำไปตรวจสอบเพิ่มเติมก่อนตัดสินใจ:

| ฟิลด์ | ความหมาย |
|---|---|
| `mismatch.oldIdentity` | ตัวตนที่ PAM SDK เก็บไว้ก่อนตรวจพบความคลาดเคลื่อน โดย SDK จะเรียก callback เฉพาะเมื่อค่านี้ไม่เป็น `null` |
| `mismatch.newIdentity` | ตัวตนปัจจุบันของแอปที่อ่านจาก `identityProvider` เป็น `null` หากแอปส่งสถานะ `PamUserState.anonymous()` |

ทั้งสองค่าเป็น `PamUserIdentity?` อ่านค่าระบุตัวตนได้ผ่าน `.value` เช่น หากกำหนด `identityMatcher` เป็น `customer` ค่านี้จะเป็นรหัสลูกค้า

```dart
final oldIdentity = mismatch.oldIdentity?.value;
final newIdentity = mismatch.newIdentity?.value;
```

ตัวอย่างเช่น หาก `oldIdentity` เป็น `CUST-001` แต่ `newIdentity` เป็น `CUST-002` หมายความว่า SDK ยังเก็บตัวตนลูกค้า `CUST-001` ขณะที่แอปใช้งานด้วยลูกค้า `CUST-002` อยู่ แอปสามารถใช้ข้อมูลนี้ร่วมกับสถานะ session ของตนเพื่อตัดสินใจว่าจะให้ผู้ใช้ออกจากระบบ หรือปรับตัวตนใน PAM ให้ตรงกับแอป

### แนวทางจัดการ

แอปสามารถเลือกจัดการตามนโยบายการเข้าสู่ระบบได้สองแนวทาง:

1. **ให้ผู้ใช้ออกจากระบบแอป** เพื่อเริ่มกระบวนการเข้าสู่ระบบใหม่ แล้วแจ้งให้ PAM ออกจากสถานะผู้ใช้เดิมด้วย
2. **ให้ PAM ทำงานต่อกับผู้ใช้ปัจจุบันของแอป** โดยส่ง identity ล่าสุดให้ PAM เพื่อปรับตัวตนให้ตรงกัน

### ทางเลือกที่ 1: ให้ผู้ใช้ออกจากระบบแอป

ตัวอย่างนี้ใช้ `authRepository.logout()` แทนขั้นตอนออกจากระบบของแอป ให้เปลี่ยนเป็นเมธอดที่แอปใช้งานจริง

```dart
final PamIdentityMismatchHandler onIdentityMismatch = (mismatch) async {
  // ออกจากระบบแอป และล้างสถานะผู้ใช้ในระบบจัดการ session ของแอป
  await authRepository.logout();

  // แจ้ง PAM ให้เลิกทำงานภายใต้ตัวตนผู้ใช้เดิม
  // Pam.userLogout() เปลี่ยนสถานะเฉพาะใน SDK ไม่ได้ logout แอปให้
  Pam.userLogout();

  // แอปสามารถนำผู้ใช้กลับไปยังหน้าเข้าสู่ระบบได้ตาม flow ที่กำหนด
};
```

### ทางเลือกที่ 2: ให้ PAM ใช้ตัวตนปัจจุบันของแอป

`mismatch.newIdentity` คือตัวตนล่าสุดที่ SDK ได้รับจาก `identityProvider` โดยค่าต้องสอดคล้องกับ `identityMatcher` ที่ตั้งค่าไว้

```dart
final PamIdentityMismatchHandler onIdentityMismatch = (mismatch) async {
  final identity = mismatch.newIdentity;

  if (identity == null) {
    // แอปไม่มีผู้ใช้ที่ล็อกอินแล้ว จึงแจ้ง PAM ให้ออกจากตัวตนเดิม
    Pam.userLogout();
  } else {
    // ส่ง identity ของผู้ใช้ปัจจุบันให้ PAM
    // เพื่อให้กิจกรรมถัดไปถูกบันทึกภายใต้ผู้ใช้คนนี้
    Pam.userLogin(identity.value);
  }
};
```

เลือกใช้ callback เพียงแนวทางเดียว แล้วส่งให้พารามิเตอร์ `onIdentityMismatch` ใน `PamConfig`

SDK จะไม่ส่ง event ที่ตรวจพบความคลาดเคลื่อน และไม่ส่ง event นั้นซ้ำให้อัตโนมัติ การปรับสถานะมีผลสำหรับ event ถัดไป ในขั้นตอนล็อกอินและออกจากระบบตามปกติ แอปยังต้องเรียก `Pam.userLogin()` และ `Pam.userLogout()`

---

## เริ่มต้นใช้งาน SDK

แยกการตั้งค่าออกจากจุดเริ่มต้นแอปเป็นสองไฟล์ เพื่อเลือกใช้ค่าของสภาพแวดล้อมพัฒนาหรือใช้งานจริงได้จาก `main.dart`

### ไฟล์ `lib/pam_config_provider.dart`

`PamConfigProvider` เตรียม config สำหรับแต่ละสภาพแวดล้อม โดยตัวอย่างนี้ใช้ค่าจำลองทั้งหมด ให้เปลี่ยนเป็นข้อมูลของโครงการก่อนเชื่อมต่อจริง

```dart
import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  static PamConfig getDevelopConfig(
    PamIdentityProvider identityProvider,
    PamIdentityMismatchHandler onIdentityMismatch,
  ) {
    // ค่าจำลองสำหรับพัฒนา: สอบถาม endpoint, publicDBAlias,
    // loginDBAlias และ trackingConsentMessageID ได้จากตัวแทน PAM
    return _createConfig(
      endpoint: 'https://dev-example.pams.ai',
      publicDBAlias: 'dev-public',
      loginDBAlias: 'dev-login',
      trackingConsentMessageID: 'DEV-TRACKING-CONSENT-MESSAGE-ID',
      enableLog: true,
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }

  static PamConfig getProductionConfig(
    PamIdentityProvider identityProvider,
    PamIdentityMismatchHandler onIdentityMismatch,
  ) {
    // ค่าจำลองสำหรับใช้งานจริง: สอบถามข้อมูลของสภาพแวดล้อมนี้
    // จากตัวแทน PAM แยกจากค่าที่ใช้ระหว่างพัฒนา
    return _createConfig(
      endpoint: 'https://example.pams.ai',
      publicDBAlias: 'production-public',
      loginDBAlias: 'production-login',
      trackingConsentMessageID: 'PRODUCTION-TRACKING-CONSENT-MESSAGE-ID',
      enableLog: false,
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }

  static PamConfig _createConfig({
    required String endpoint,
    required String publicDBAlias,
    required String loginDBAlias,
    required String trackingConsentMessageID,
    required bool enableLog,
    required PamIdentityProvider identityProvider,
    required PamIdentityMismatchHandler onIdentityMismatch,
  }) {
    return PamConfig(
      endpoint,
      publicDBAlias,
      loginDBAlias,
      trackingConsentMessageID,
      enableLog,
      // ตัวอย่างนี้ใช้รหัสลูกค้า สอบถามคีย์ที่ตั้งค่าไว้กับตัวแทน PAM
      // และยืนยันให้ตรงกับแนวทางระบุตัวตนของทีม Data
      identityMatcher: PamIdentityMatcher.primary(
        PamPrimaryIdentityKey.customer,
      ),
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }
}
```

### ไฟล์ `lib/main.dart`

เลือก config แล้วรอให้ PAM เริ่มต้นเสร็จก่อนเรียก `runApp()` หากต้องการใช้สภาพแวดล้อมจริง ให้เปลี่ยนเป็น `PamConfigProvider.getProductionConfig(identityProvider, onIdentityMismatch)`

```dart
import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import 'pam_config_provider.dart';

// ตัวอย่างเริ่มต้น: ยังโหลด session ไม่เสร็จ
// เปลี่ยนให้อ่านสถานะที่แอปเก็บไว้จริงตามหัวข้อ identityProvider ด้านบน
PamUserState identityProvider() {
  return const PamUserState.unknown();
  // โหลดเสร็จแต่ยังไม่ login: PamUserState.anonymous()
  // login แล้ว: PamUserState.identified(user.customerId)
}

Future<void> onIdentityMismatch(PamIdentityMismatch mismatch) async {
  final identity = mismatch.newIdentity;
  if (identity == null) {
    await Pam.userLogout();
  } else {
    await Pam.userLogin(identity.value);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = PamConfigProvider.getDevelopConfig(
    identityProvider,
    onIdentityMismatch,
  );
  await Pam.initialize(config);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('ตัวอย่างแอปที่เชื่อมต่อ PAM')),
      ),
    );
  }
}
```

`identityProvider` และ `onIdentityMismatch` เป็นส่วนที่แอปกำหนดให้สอดคล้องกับระบบจัดการผู้ใช้ของตน ในขั้นตอนล็อกอินและออกจากระบบตามปกติ ยังต้องเรียก `Pam.userLogin()` และ `Pam.userLogout()` ด้วย

[กลับหน้าแรก](index.html)
