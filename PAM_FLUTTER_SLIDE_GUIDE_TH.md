# คู่มือทำสไลด์ PAM Flutter SDK v3.0.1

กลุ่มผู้ฟังคือนักพัฒนา Flutter ที่กำลังเชื่อมแอปกับ PAM Real CDP ใช้หัวข้อระดับสองเป็นขอบเขตของแต่ละสไลด์ นำส่วน **ทำอะไร** ขึ้นสไลด์ ใช้ **ทำไม** เป็นคำอธิบายประกอบ และแสดงโค้ดต่อท้าย ตัวอย่างเป็นส่วนย่อยตามลำดับบท โดย `MyApp`, ระบบล็อกอิน และฟังก์ชัน UI มาจากแอปของผู้ฟัง

## 00 · ภาพรวม App Server, Flutter และ PAM

**ทำอะไร** ให้ App Server จัดการการยืนยันตัวตนและซิงก์โปรไฟล์เข้า Login DB ส่วนแอป Flutter ส่ง consent และกิจกรรมผ่าน SDK โดย Public DB รับกิจกรรม anonymous และ Login DB รับกิจกรรมของผู้ใช้ที่ระบุตัวตนแล้ว

**ทำไม** เมื่อสมัครสมาชิกสำเร็จในแอป โปรไฟล์ใน PAM อาจยังซิงก์ไม่เสร็จ ให้ทีม App Server กำหนดว่าแอปจะรู้ได้อย่างไรว่าโปรไฟล์พร้อมก่อนเรียก login และส่ง event สำหรับสมาชิก เก็บ credential ของการเชื่อมต่อแบบ server-to-server ไว้ฝั่งเซิร์ฟเวอร์

```text
App Server ── sync โปรไฟล์ด้วย customer ID ──► PAM Login DB
Flutter    ── event ของ anonymous ───────────► PAM Public DB
Flutter    ── userLogin(customerId) → track ──► PAM Login DB
```

## 01 · ติดตั้ง SDK

**ทำอะไร** เพิ่ม `pam_flutter` ในโปรเจกต์ Flutter

**ทำไม** แอปจะเรียก PAM ผ่าน Dart API ชุดเดียว เตรียม Flutter ที่มาพร้อม Dart 3.6 ขึ้นไปตามเงื่อนไขของแพ็กเกจใน repo นี้

```sh
flutter pub add 'pam_flutter:3.0.1'
```

## 02 · ตั้งค่าปลายทางและวิธีจับคู่ผู้ใช้

**ทำอะไร** นำ endpoint, database aliases และ tracking consent message ID จาก PAM CMS มาใส่ใน `PamConfig` เลือก matcher ให้ตรงกับ CDP

**ทำไม** Public DB ใช้กับผู้ใช้ anonymous ส่วน Login DB ใช้กับผู้ใช้ที่ระบุตัวตนแล้ว ตัวอย่างนี้ใช้ customer ID จึงต้องส่ง customer ID เมื่อเรียก login หาก CDP ใช้ primary key แบบอีเมลหรือมือถือ ให้เลือก `email` หรือ `sms` ตามลำดับ ส่วน secondary key ใช้ `PamIdentityMatcher.secondary('line')` เมื่อ CDP ตั้งคีย์นี้ไว้

```dart
import 'package:pam_flutter/pam.dart';

const trackingConsentId = '<TRACKING_CONSENT_MESSAGE_ID>';

final pamConfig = PamConfig(
  'https://<PAM_HOST>',
  '<PUBLIC_DB_ALIAS>',
  '<LOGIN_DB_ALIAS>',
  trackingConsentId,
  false, // เปิด log ระหว่างทดสอบได้
  identityMatcher: PamIdentityMatcher.primary(
    PamPrimaryIdentityKey.customer,
  ),
);
```

## 03 · เริ่ม SDK ตอนเปิดแอป

**ทำอะไร** เริ่ม Flutter binding และรอให้ PAM initialize ก่อนเปิด UI ที่จะเรียก SDK

**ทำไม** การเรียก SDK ตั้งแต่เฟรมแรกต้องอาศัยค่าตั้งต้นและสถานะที่ SDK โหลดไว้

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Pam.initialize(pamConfig);
  runApp(const MyApp());
}
```

## 04 · บันทึก consent ตามตัวเลือกของผู้ใช้

**ทำอะไร** โหลดข้อความ consent ที่กำหนดใน CMS แสดงตัวเลือกในแอป แล้วส่งผลหลังผู้ใช้ยืนยัน ตัวอย่างนี้เป็นกรณีที่ผู้ใช้เลือกอนุญาตทุกข้อของข้อความนั้น

**ทำไม** Tracking consent และ contacting consent มีจุดประสงค์คนละอย่าง ให้ใช้ message ID ตามจุดประสงค์ของหน้าจอและบันทึกตามตัวเลือกจริงของผู้ใช้

```dart
Future<SubmitConsentResult?> submitAllowAll(String messageId) async {
  final consent = await Pam.loadConsentMessage(messageId);
  if (consent == null) return null;

  consent.allowAll();
  return Pam.submitConsent(consent);
}

// เรียกจากปุ่มยืนยันหลังผู้ใช้เลือกอนุญาตทุกข้อ
// await submitAllowAll(trackingConsentId);
```

## 05 · แจ้ง PAM เมื่อผู้ใช้เข้าสู่ระบบ

**ทำอะไร** หลังแอปยืนยันตัวตนสำเร็จและโปรไฟล์ใน PAM พร้อมแล้ว ส่งค่าที่ตรงกับ matcher ในสไลด์ 02 และตรวจผลก่อนเริ่มส่ง event สำหรับบัญชีนี้

**ทำไม** SDK ใช้ค่านี้จับคู่ contact และกำหนดปลายทางของกิจกรรมหลัง login

```dart
Future<bool> identifyInPam(String customerId) async {
  final result = await Pam.userLogin(customerId);
  return result.error == null;
}
```

## 06 · ส่ง event พร้อม payload

**ทำอะไร** เรียก `Pam.track` จากจุดที่กิจกรรมเกิดขึ้นจริง เช่น หลังระบบยืนยันการซื้อสำเร็จ

**ทำไม** ชื่อ event บอกว่าผู้ใช้ทำอะไร ส่วน payload เก็บรายละเอียดสำหรับวิเคราะห์และแบ่งกลุ่ม ควรใช้ชื่อและชนิดข้อมูลที่ตกลงกับทีม CDP

```dart
final response = await Pam.track('purchase', payload: {
  'order_id': orderId,
  'total': 300,
  'currency': 'THB',
});
if (response?.error != null) {
  debugPrint('PAM tracking error: ${response?.error?.code}');
}
```

**โน้ตผู้บรรยาย** เมื่อ PAM ตอบกลับด้วยข้อผิดพลาดบางประเภท เช่น ไม่พบ contact หรือยังไม่พร้อมเรื่อง consent รุ่น 3.0.1 จะพัก tracking ทั่วไป 1 ชั่วโมง แล้วลองส่งเมื่อมี event ครั้งถัดไปหลังครบเวลา คำขอแก้สถานะอย่าง login หรือการยินยอมให้ติดตามที่สำเร็จสามารถปลดการพักก่อนครบเวลาได้

## 07 · ออกจากระบบและสลับบัญชี

**ทำอะไร** ผูกการเรียก logout กับขั้นตอนออกจากระบบของแอป หากสลับจาก A ไป B ให้รอ logout ของ A ก่อนแจ้ง login ของ B

**ทำไม** SDK จัดคิวคำขอที่เกี่ยวข้องและกำหนดปลายทางของแต่ละ event การเรียกตามลำดับของแอปช่วยให้ช่วงเปลี่ยนบัญชีตรวจสอบได้ง่าย

```dart
await Pam.userLogout();
// หลังแอปยืนยันตัวตนบัญชี B สำเร็จ
final result = await Pam.userLogin(nextCustomerId);
```

**โน้ตผู้บรรยาย** สำหรับแอปที่มีหลายจุดเปลี่ยนบัญชี สามารถเพิ่ม `identityProvider` ใน `PamConfig` เพื่อเทียบสถานะจากแอปก่อนส่ง tracking อ่านจากสถานะที่แอปเก็บไว้ และใช้ `PamUserState.unknown()` ระหว่างโหลด session หากพบสถานะไม่ตรงกัน SDK จะหยุด event นั้นและแจ้ง `onIdentityMismatch` เพื่อให้แอปปรับสถานะสำหรับ event ถัดไป

## 08 · ส่ง push token ให้ PAM

**ทำอะไร** ให้แอปรับ token จาก push provider และส่งให้ PAM ทั้งตอนมี token ครั้งแรกและเมื่อ token เปลี่ยน ตัวอย่างใช้ Firebase Messaging ที่แอปตั้งค่าไว้แล้ว

**ทำไม** PAM ใช้ token เพื่อส่ง push ไปยังอุปกรณ์ เมื่อ logout SDK จะถอด token จาก contact เดิม และใช้ token ที่บันทึกไว้ได้เมื่อแอปแจ้ง login ครั้งถัดไป

```dart
final messaging = FirebaseMessaging.instance;
final token = await messaging.getToken();
if (token != null) {
  await Pam.setPushNotificationToken(token);
}

final tokenSubscription = messaging.onTokenRefresh.listen((token) async {
  await Pam.setPushNotificationToken(token);
});
```

**โน้ตผู้บรรยาย** ถ้า App Server ใช้ token สำหรับข้อความระบบอยู่แล้ว ให้ส่ง token ไปที่ App Server ตาม flow เดิม และลงทะเบียนกับ PAM เพิ่มสำหรับข้อความแคมเปญ ให้ส่วนที่ดูแล push ระดับแอปลงทะเบียน listener ครั้งเดียวและจัดการอายุ subscription

## 09 · แยก PAM push และบันทึกเมื่อผู้ใช้เปิด

**ทำอะไร** ใช้ handler เดียวสำหรับการเปิดจากแอปที่ปิดอยู่และจากแอปที่อยู่เบื้องหลัง ส่ง `message.data` ให้ PAM

**ทำไม** Push provider ดูแลการรับข้อความ ส่วน PAM แปลงข้อมูลและบันทึกการอ่านเมื่อผู้ใช้เปิดข้อความ หากแอปได้รับ push ขณะเปิดอยู่ ให้แสดงตาม UX ของแอปและบันทึกการอ่านเมื่อผู้ใช้เปิดจริง

```dart
void handlePushTap(RemoteMessage message) {
  if (!Pam.isPushNotiFromPam(message.data)) {
    handleSystemPushTap(message); // handler ที่แอปมีอยู่แล้ว
    return;
  }

  final push = Pam.convertToPamPushMessage(message.data);
  push?.trackRead();
  // เปิดหน้าที่เกี่ยวข้องตามข้อมูลของ push เมื่อ UI พร้อม
}

final openedSubscription =
    FirebaseMessaging.onMessageOpenedApp.listen(handlePushTap);

final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) handlePushTap(initial);
```

## 10 · แสดงประวัติการแจ้งเตือน

**ทำอะไร** โหลดรายการสำหรับผู้ใช้ปัจจุบันหลังเข้าสู่ระบบ แล้วผูกการเปิดรายการกับ `trackRead()`

**ทำไม** SDK คืนข้อมูลข้อความให้แอปนำไปสร้าง UI และแยกการโหลดรายการออกจากการอ่านแต่ละข้อความ

```dart
final messages = await Pam.loadPushNotifications();
if (messages != null && messages.isNotEmpty) {
  // ตัวอย่าง callback ของรายการแรก เรียกเมื่อผู้ใช้แตะรายการ
  void onFirstMessageTap() => messages.first.trackRead();
}
```

**โน้ตผู้บรรยาย** ถ้าแอปมีข้อความระบบจาก App Server ให้รวมกับข้อความแคมเปญจาก PAM โดยแปลงเป็นโมเดลรายการเดียวกัน เรียงตามวันเวลา และเก็บแหล่งที่มาไว้เพื่อเรียกตัวบันทึกการอ่านของแต่ละระบบเมื่อแตะรายการ

## 11 · แสดง App Attention ตามหน้า

**ทำอะไร** เรียกจากจุดที่หน้าจอพร้อมแสดง popup เช่น callback หลังเฟรมแรกของหน้า Home ใช้ `pageName` ให้ตรงกับแคมเปญ

**ทำไม** PAM เลือกแบนเนอร์หรือข้อความตามหน้าที่ตั้งไว้ แอปสามารถจัดการการกดแบนเนอร์ผ่าน callback

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!context.mounted) return;
  Pam.appAttention(
    context,
    pageName: 'home',
    onBannerClick: (bannerData) {
      return false; // ให้ SDK ทำพฤติกรรมเริ่มต้นต่อ
    },
  );
});
```

**โน้ตผู้บรรยาย** ฝั่ง PAM Admin สร้างแคมเปญ App Attention ให้ชื่อหน้าตรงกับ `pageName` คู่มือเดิมแนะนำสื่อแนวตั้ง 9:16 ขนาด 720 × 1280 พิกเซล และเว้นข้อความสำคัญจากขอบประมาณ 80 พิกเซลที่ขนาดนี้ ใช้เป็นจุดเริ่มต้นแล้วพรีวิวบนอุปกรณ์จริงตาม layout ของแคมเปญ

## 12 · ทดสอบตั้งแต่ anonymous ถึงสลับบัญชี

**ทำอะไร** ใช้บัญชีทดสอบ A และ B ไล่เปิดแอป ให้ consent ส่ง event หลัง login และสลับบัญชี ตรวจฐานข้อมูลและ contact ปลายทางใน CDP จากนั้นทดสอบ push tap ทั้งตอนแอปปิดและอยู่เบื้องหลัง

**ทำไม** การสลับบัญชีเป็นจุดที่ event และ push token อาจไปผูกกับ contact ผิดคน การทดสอบตามลำดับจริงช่วยให้ตรวจทั้งสถานะในแอปและข้อมูลปลายทางได้

```dart
// เรียกในบัญชีทดสอบที่เปิด tracking consent ตาม flow ของแอปแล้ว
await Pam.userLogin(testCustomerA);
await Pam.track('qa_account_switch', payload: {'step': 'before_switch'});
await Pam.userLogout();
await Pam.userLogin(testCustomerB);
await Pam.track('qa_account_switch', payload: {'step': 'after_switch'});
```

**โน้ตผู้บรรยาย** ทีมที่ย้ายจาก v2 ให้ตรวจสามจุดก่อนเดโม ย้ายการเลือกคีย์จาก `loginKey` หรือ `LoginOptions` ไปไว้ใน `identityMatcher` เปลี่ยน push helpers ให้รับ data map และตรวจ flow ผูก token เมื่อสลับบัญชี

## เอกสารประกอบสำหรับผู้ทำสไลด์

- [README ของ SDK](README.md)
- [คู่มือย้ายจาก v2 เป็น v3](MIGRATE.md)
- [คำอธิบาย SDK v3 สำหรับลูกค้า](SDK_V3_FOR_CUSTOMERS_TH.md)
- [แอปตัวอย่าง](example/lib/main.dart)
- [Flutter PAM Integration Guide สำหรับ SDK v2](NEW%20-%20Flutter%20PAM%20Integration%20Guide.pdf) ใช้อ้างอิงแผนภาพการซิงก์และฐานข้อมูล (หน้า 4–10), push และ inbox (หน้า 11–14), และการเตรียม App Attention (หน้า 18–25)
