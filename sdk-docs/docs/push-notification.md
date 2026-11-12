# Push Notification

แอปเป็นผู้จัดการการขอสิทธิ์รับแจ้งเตือน รับ device token และรับข้อความจากผู้ให้บริการ Push Notification ส่วน PAM ใช้ token และข้อมูลข้อความที่แอปส่งให้ผ่าน SDK

PAM ไม่ดึง device token หรืออ่านข้อความแจ้งเตือนจากแอปด้วยตนเอง การส่งข้อมูลให้ PAM จึงเป็นขั้นตอนที่แอปกำหนดไว้อย่างชัดเจน เพื่อความโปร่งใสในการเชื่อมต่อข้อมูล

---

## ส่ง Device Token ให้ PAM

หลัง initialize PAM แล้ว เมื่อแอปได้รับ token ให้ส่งผ่าน `Pam.setPushNotificationToken()` โดยไม่ต้องรอผลจาก PAM Server:

```dart
Pam.setPushNotificationToken(deviceToken);
```

**ต้องส่ง token ใหม่ให้ PAM ทุกครั้งที่มีการเปลี่ยนแปลง** ไม่ว่าจะเกิดจากการต่ออายุ token การติดตั้งแอปใหม่ หรือเหตุผลอื่น เพราะ PAM ไม่สามารถตรวจพบการเปลี่ยนแปลงนี้เองได้

### ตัวอย่างสำหรับแอปที่ใช้ Firebase Messaging

ตัวอย่างนี้สมมติว่าแอปติดตั้งและตั้งค่า Firebase Messaging รวมถึงขอสิทธิ์รับแจ้งเตือนเรียบร้อยแล้ว ให้เรียกฟังก์ชันนี้ครั้งเดียวหลัง Firebase และ PAM พร้อมใช้งาน โดยไม่ต้องรอขั้นตอนนี้ก่อนเปิดหน้าจอหลักของแอป

```dart
import 'package:pam_flutter/pam.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// แอปจัดการ Firebase.initializeApp(), การตั้งค่า Firebase และสิทธิ์แจ้งเตือนเอง
// เรียกครั้งเดียวหลัง Firebase และ PAM พร้อมใช้งาน โดยไม่ต้อง await
void registerPamPushToken() {
  void logPushError(Object error, [StackTrace? stackTrace]) {
    Pam.log(
      [
        'PAM push token registration failed',
        error,
        if (stackTrace != null) stackTrace,
      ],
      category: PamLogCategory.push,
      level: PamLogLevel.error,
    );
  }

  void sendToken(String token) {
    if (token.trim().isEmpty) return;
    Pam.setPushNotificationToken(token)
        .then<void>((response) {
          if (response.error != null) {
            Pam.log(
              [
                'PAM push token registration failed: ${response.error?.code}',
                response.error?.errorMessage,
              ],
              category: PamLogCategory.push,
              level: PamLogLevel.error,
            );
          }
        })
        .catchError(logPushError);
  }

  final messaging = FirebaseMessaging.instance;

  // ส่งค่าใหม่ให้ PAM เมื่อ push token เปลี่ยน
  messaging.onTokenRefresh.listen(sendToken, onError: logPushError);

  // ส่ง token ปัจจุบันให้ PAM ด้วย ไม่ต้องรอให้ token เปลี่ยนก่อน
  messaging
      .getToken()
      .then<void>((token) {
        if (token != null) sendToken(token);
      })
      .catchError(logPushError);
}
```

แอปต้องเพิ่ม dependency `firebase_messaging` เอง ดูขั้นตอนตั้งค่าและการจัดการ token ใน [เอกสาร Firebase Messaging](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)

---

## จัดการเมื่อผู้ใช้กดแจ้งเตือนจาก Notification Center

ตัวอย่างนี้ทำงานเฉพาะเมื่อผู้ใช้ตั้งใจกดแจ้งเตือนจาก Notification Center ในสองกรณี:

1. แอปอยู่ใน background แล้วกลับมาทำงานผ่าน `FirebaseMessaging.onMessageOpenedApp`
2. แอปไม่มี process ทำงานอยู่ แล้วเปิดขึ้นใหม่จากการกดแจ้งเตือน โดยอ่านผ่าน `FirebaseMessaging.instance.getInitialMessage()`

เมื่อได้รับ push ระหว่างใช้งานแอป (foreground) ตัวอย่างนี้จะไม่เปิดหน้าอ่าน ไม่เปลี่ยนหน้าปัจจุบัน ไม่แสดง banner หรือ popup และไม่ส่ง `trackRead()` / `trackPushUrlClick()` เพื่อไม่ขัดจังหวะการใช้งาน การเปิดแอปตามปกติโดยไม่ได้กดแจ้งเตือนก็ไม่ถือว่าเปิดอ่านข้อความ

ลงทะเบียนครั้งเดียวหลัง Firebase, PAM และระบบนำทางพร้อม โดยใช้ร่วมกับ `registerPamPushToken()` ด้านบน และใช้แทน listener เปิดแจ้งเตือนเดิมเพื่อไม่ส่งผลการอ่านหรือเปิดหน้าซ้ำ

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pam_flutter/pam.dart';

bool _pamPushHandlersRegistered = false;

// จัดการเฉพาะการกด Push จาก PAM สำหรับแอปที่ใช้ Firebase Messaging
// ใช้ร่วมกับ registerPamPushToken() ด้านบน ซึ่งทำหน้าที่ส่ง token
//
// เรียกครั้งเดียวหลัง Firebase, PAM และระบบนำทางของแอปพร้อมแล้ว
// เช่น เรียกหลังเฟรมแรกของหน้าหลัก ไม่ต้อง await ฟังก์ชันนี้
//
// registerPamPushHandlers(
//   openDestination: (url) {
//     // เปิด url ด้วยระบบ deep link หรือระบบนำทางของแอป
//     // เช่น myapp://coupon -> หน้าคูปอง โดยแอปเป็นผู้กำหนด logic เอง
//   },
// );
void registerPamPushHandlers({
  required void Function(String url) openDestination,
}) {
  // ไม่เพิ่ม listener ซ้ำหากเผลอเรียกฟังก์ชันนี้หลายครั้ง
  // ตัวอย่างนี้ให้ listener อยู่ตลอดอายุแอป ไม่ต้องลงทะเบียนใหม่ตอน login/logout
  if (_pamPushHandlersRegistered) return;
  _pamPushHandlersRegistered = true;

  void logPushError(Object error, [StackTrace? stackTrace]) {
    Pam.log(
      ['PAM push handling failed', error, if (stackTrace != null) stackTrace],
      category: PamLogCategory.push,
      level: PamLogLevel.error,
    );
  }

  void handleOpened(RemoteMessage message) {
    // Push จากระบบอื่น ให้แอปเชื่อม handler ของระบบนั้นเพิ่มเติมเอง
    if (!Pam.isPushNotiFromPam(message.data)) return;

    try {
      final pamMessage = Pam.convertToPamPushMessage(message.data);
      if (pamMessage == null) return;

      // ตอนนี้ผู้ใช้เปิดข้อความแล้ว จึงส่งสัญญาณว่าอ่านแล้ว
      // trackRead() ส่งเบื้องหลัง ไม่ต้อง await
      pamMessage.trackRead();

      final url = pamMessage.url;
      if (url == null || url.trim().isEmpty) return;

      // ตัวอย่างนี้เปิด URL ปลายทางทันทีเมื่อคลิกแจ้งเตือน
      // จึงบันทึกคลิก URL ด้วย แล้วเปิดหน้าปลายทางโดยไม่ต้องรอ PAM
      pamMessage.trackPushUrlClick();
      openDestination(url);

      // ถ้าแอปเลือกเปิดหน้ารายละเอียดก่อน แล้วมีปุ่มให้กด URL อีกที
      // ให้ย้าย trackPushUrlClick() ไปจุดกดปุ่ม URL จริงแทน เพื่อไม่นับซ้ำ
    } catch (error, stackTrace) {
      logPushError(error, stackTrace);
    }
  }

  // 1. ผู้ใช้กดแจ้งเตือนจาก Notification Center ขณะแอปอยู่เบื้องหลัง
  FirebaseMessaging.onMessageOpenedApp.listen(
    handleOpened,
    onError: logPushError,
  );

  // 2. ผู้ใช้กดแจ้งเตือนเพื่อเปิดแอปที่ปิดอยู่ (cold start)
  // อ่านข้อความเริ่มต้นในเบื้องหลัง โดยไม่ให้ flow เปิดแอปต้องรอ PAM
  FirebaseMessaging.instance
      .getInitialMessage()
      .then<void>((message) {
        if (message != null) handleOpened(message);
      })
      .catchError(logPushError);

  // ไม่ลงทะเบียน FirebaseMessaging.onMessage ในตัวอย่างนี้
  // การได้รับ push ขณะใช้แอปจึงไม่เปิดหน้าอ่านหรือส่ง read/click tracking
}
```

ส่ง `openDestination` ให้เชื่อมกับระบบนำทางที่แอปใช้อยู่ เพื่อเปิดหน้าปลายทางหลังผู้ใช้กดแจ้งเตือนเท่านั้น ตัวอย่างนี้ให้ listeners อยู่ตลอดอายุแอป หากลงทะเบียนเฉพาะหน้าต้องจัดเก็บ subscriptions และยกเลิกเมื่อเลิกใช้งาน

การรับข้อความยังไม่ใช่การอ่าน เรียก `trackRead()` เมื่อเปิดข้อความจริง และเรียก `trackPushUrlClick()` เมื่อเปิด URL จริง หากแอปเปิดหน้ารายละเอียดก่อน ให้ย้ายการนับคลิกไปที่ปุ่ม URL ในหน้ารายละเอียด ตัวอย่างนี้ไม่ได้แสดง banner หรือสร้าง local notification ให้อัตโนมัติ

---

## ข้อมูลใน PamPushMessage

| ฟิลด์ | ข้อมูลที่ได้จากการแปลงข้อความ Push |
|---|---|
| `noti.url` | URL ปลายทางที่กำหนดมากับข้อความ |
| `noti.thumbnailUrl` | URL รูปภาพที่ SDK อ่านจาก `flex` |
| `noti.flex` | เนื้อหา `flex` ของข้อความ |
| `noti.popupType` | รูปแบบการแสดงผลที่ระบุมากับข้อความ |
| `noti.data` | ข้อมูล payload ของ PAM หลังแปลงจากข้อความ |
| `noti.pixel` | URL สำหรับส่งสัญญาณการอ่าน ซึ่ง `trackRead()` ใช้ภายใน |
| `noti.clickTrackingUrl` | URL สำหรับติดตามการกดลิงก์ หากมี |
| `noti.redirectId` | รหัสอ้างอิงการ redirect หากมี |

สำหรับ `convertToPamPushMessage()` ใน SDK ปัจจุบัน ฟิลด์ `title`, `description` และ `deliverID` ถูกกำหนดเป็นข้อความว่าง หากต้องการชื่อและรายละเอียดแจ้งเตือนจาก Firebase ให้อ่าน `message.notification?.title` และ `message.notification?.body` ส่วน `date` เป็นเวลาที่แปลงข้อความ และ `isOpen` เริ่มต้นเป็น `false`

เรียก `noti.trackRead()` เมื่อผู้ใช้เปิดข้อความแล้ว เพื่อแจ้งผลการอ่านกลับไปยัง PAM โดยไม่ต้องเรียกตั้งแต่ตอนรับข้อความเข้ามา

---

## ดึงประวัติ Push Notification

เรียก `Pam.loadPushNotifications()` เพื่อดึงรายการข้อความย้อนหลัง โดย SDK คืนเฉพาะข้อมูล แอปต้องสร้างหน้าจอแสดงรายการและรายละเอียดข้อความเอง

```dart
final messages = await Pam.loadPushNotifications();
```

ผลลัพธ์เป็น `List<PamPushMessage>?` สามารถนำฟิลด์ เช่น `title`, `description`, `thumbnailUrl`, `date` และ `isOpen` ไปใช้แสดงผลได้ หากได้ `null` ให้แสดงสถานะโหลดข้อมูลไม่สำเร็จ และหากได้รายการว่าง ให้แสดงว่ายังไม่มีข้อความ

เมื่อผู้ใช้เปิดอ่านข้อความจากหน้าประวัติ ให้เรียก `message.trackRead()` เพื่อแจ้งผลการอ่านกลับไปยัง PAM เช่นเดียวกับการเปิดจาก Notification Center

```dart
// ตัวอย่าง onTap ของรายการข้อความในหน้าประวัติ
onTap: () {
  // แจ้ง PAM ว่าผู้ใช้เปิดอ่านข้อความนี้แล้ว โดยไม่ต้อง await
  message.trackRead();

  // แสดงรายละเอียดข้อความตาม UI ที่แอปออกแบบไว้
},
```

เรียก `trackRead()` เมื่อผู้ใช้เปิดข้อความแต่ละรายการ ไม่ใช่ตอนโหลดรายการประวัติ เพื่อให้สถานะการอ่านสะท้อนการใช้งานจริง

ขั้นตอนนี้ใช้ `await` เพราะหน้าประวัติต้องนำข้อมูลที่ได้มาแสดงผล ระหว่างรอแอปสามารถแสดงสถานะกำลังโหลดในหน้านั้นได้

[กลับหน้าแรก](index.html)
