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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pam_flutter/pam.dart';

void registerPamPushToken() {
  // รับ token ที่เปลี่ยนแปลง และส่งค่าใหม่ให้ PAM ทุกครั้ง
  FirebaseMessaging.instance.onTokenRefresh.listen((deviceToken) {
    Pam.setPushNotificationToken(deviceToken);
  });

  // ส่ง token ปัจจุบันให้ PAM ด้วยเมื่อเริ่มใช้งาน
  FirebaseMessaging.instance.getToken().then((deviceToken) {
    if (deviceToken != null) {
      Pam.setPushNotificationToken(deviceToken);
    }
  });
}
```

แอปต้องเพิ่ม dependency `firebase_messaging` เอง ดูขั้นตอนตั้งค่าและการจัดการ token ใน [เอกสาร Firebase Messaging](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)

---

## เมื่อผู้ใช้กดแจ้งเตือนจาก Notification Center

เมื่อได้รับเหตุการณ์เปิดแจ้งเตือน ให้ตรวจด้วย `Pam.isPushNotiFromPam(message.data)` หากได้ `true` แสดงว่าเป็นข้อความของ PAM จากนั้นแปลงข้อมูลด้วย `Pam.convertToPamPushMessage()` เพื่ออ่านฟิลด์และเรียกเมธอดของ PAM ได้สะดวก

ตัวอย่าง Firebase Messaging รองรับทั้งการเปิดแอปจากเบื้องหลังและจากสถานะที่แอปปิดอยู่:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pam_flutter/pam.dart';

void handleNotificationOpened(RemoteMessage message) {
  // ข้อความจากระบบอื่น ให้แอปจัดการตาม flow ของตน
  if (!Pam.isPushNotiFromPam(message.data)) {
    return;
  }

  final noti = Pam.convertToPamPushMessage(message.data);
  if (noti == null) {
    return;
  }

  // ส่งสัญญาณกลับ PAM ว่าผู้ใช้เปิดอ่านข้อความแล้ว
  // เมธอดนี้ส่งเบื้องหลัง ไม่ต้อง await
  noti.trackRead();

  // อ่านข้อมูลเพื่อแสดงเนื้อหาหรือเลือกหน้าปลายทางในแอป
  final destinationUrl = noti.url;
  final imageUrl = noti.thumbnailUrl;
  final popupType = noti.popupType;
  final payload = noti.data;

  // นำข้อมูลไปใช้กับระบบเปิดหน้าปลายทางของแอป
}

void registerNotificationOpenHandlers() {
  // ผู้ใช้กดแจ้งเตือนขณะแอปอยู่เบื้องหลัง
  FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationOpened);

  // ผู้ใช้กดแจ้งเตือนเพื่อเปิดแอปที่ปิดอยู่
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      handleNotificationOpened(message);
    }
  });
}
```

เรียก `registerNotificationOpenHandlers()` ครั้งเดียวหลัง Firebase และ PAM พร้อมใช้งาน หากเปิดหน้าปลายทางด้วย Navigator ให้รอจนหน้าจอและระบบนำทางของแอปพร้อมก่อน ดูรายละเอียดเหตุการณ์เปิดแจ้งเตือนใน [เอกสาร Firebase](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)

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
