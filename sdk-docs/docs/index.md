# คู่มือการใช้งาน PAM Flutter SDK

PAM Flutter SDK ช่วยเชื่อมต่อแอป Flutter กับ PAM เพื่อบันทึกกิจกรรมของผู้ใช้ จัดการความยินยอม และรองรับการสื่อสารกับผู้ใช้ผ่านแอป คู่มือนี้อธิบายแนวคิดและขั้นตอนการใช้งาน SDK ทีละส่วน

---

## แหล่งข้อมูล SDK

- [แพ็กเกจ pam_flutter บน pub.dev](https://pub.dev/packages/pam_flutter) — ดูเวอร์ชันและข้อมูลแพ็กเกจ
- [ซอร์สโค้ดและตัวอย่างบน GitHub](https://github.com/3dsinteractive/pamflutter) — ดูโค้ด SDK และตัวอย่างการใช้งาน

---

## การติดตั้ง SDK

เปิดเทอร์มินัลที่โฟลเดอร์โปรเจกต์ Flutter ของคุณ แล้วรันคำสั่ง:

```bash
flutter pub add pam_flutter
```

คำสั่งนี้จะเพิ่ม `pam_flutter` ลงในไฟล์ `pubspec.yaml` และดาวน์โหลดแพ็กเกจที่จำเป็น จากนั้นนำเข้า SDK ในไฟล์ Dart ที่ต้องการใช้งาน:

```dart
import 'package:pam_flutter/pam.dart';
```

---

## เนื้อหาหลัก

1. [ทำความเข้าใจระบบฐานข้อมูล (Database) ใน PAM](database.html)
2. [เตรียม Config และเริ่มต้นใช้งาน PAM](initialization.html)
3. [การจัดการความยินยอม (Consent)](consent.html)
4. [การเข้าสู่ระบบและออกจากระบบ](authentication.html)
5. [การส่ง Event Tracking](tracking.html)
6. [Push Notification](push-notification.html)
7. [App Attention](app-attention.html)
