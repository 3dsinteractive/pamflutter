# Example App

ตัวอย่าง Flutter เป็นแอปดูสินค้าที่เริ่มใช้งานได้ก่อน Login และพาเดินตามขั้นตอนที่พบในแอปจริง หน้าจอแสดงสถานะด้วยข้อความ ไม่แสดง JSON คำสั่งของแต่ละปุ่มและรายละเอียด response ดูได้จาก SDK Log

## ตั้งค่าและเปิดแอป

แก้ `example/lib/pam_config.dart` ให้ตรงกับ server, database และ Tracking Consent Message ID ของคุณ หากใช้ Contacting Consent ให้ใส่ ID เพิ่ม แล้วรัน:

```bash
cd example
flutter pub get
flutter run
```

`main` ใช้ `getDevelopConfig` และรอ `Pam.initialize` ก่อนเปิดแอป ค่า develop เปิด Log ไว้ ต้อง restart หลังเปลี่ยน config ส่วน REST auth เป็น server จำลองในแอป PAM ใช้ server จริงตาม config

## เส้นทางการลองใช้งาน

| ขั้นตอน | สิ่งที่ผู้ใช้ลอง | การทำงาน |
|---|---|---|
| 1. ลองใช้ก่อน Login | ดูสินค้าและเก็บรายการที่ชอบ | `Pam.track("view_product")` และ `Pam.track("favorite_product")` พร้อม `is_favorite` ตามสถานะที่เลือก |
| 2. เลือก Consent ก่อน Login | อ่านและเลือกสิทธิ์ด้วยตัวเอง | `Pam.showConsent` ใช้ตัวตน guest ปิดโดยไม่บันทึกได้ |
| 3. Track ก่อน Login | ส่งเหตุการณ์ดูสินค้า | `Pam.track('view_product', payload: ...)` พร้อม `demo_stage: guest` |
| 4. Login เมื่อพร้อม | กรอก Customer ID จำลอง | REST login → เก็บ session → `Pam.userLogin` |
| 5. ตรวจและปรับ Consent | โหลดสถานะสมาชิกและแก้ตัวเลือก | `Pam.loadConsentStatus` และ `Pam.showConsent` |
| 6. Track หลัง Login | ดูสินค้าหรือจำลองซื้อสินค้า | `view_product` หรือ `Pam.trackBatch` ที่รวม `purchase_order` และ `purchase_order_item` ของสินค้า 2 รายการ โดยใช้ `order_id` เดียวกัน |
| 7. App Attention | กรอก PageName แล้วตรวจสอบ Popup ได้ทั้งก่อนและหลัง Login | `Pam.appAttention(context, pageName: pageName)` ต้องมี Campaign เข้าเงื่อนไข |
| 8. Logout และเริ่มใหม่ | เริ่มรอบทดสอบใหม่เป็น guest | REST logout → `Pam.userLogout` → `Pam.reset` → ล้าง state บนหน้าจอ |

Login ไม่บังคับให้ทำขั้นก่อนหน้าครบ ปุ่ม Event ก่อน Login ใช้ได้เฉพาะ guest ส่วนปุ่มหลัง Login ใช้ได้เฉพาะสมาชิก การส่ง Event ขึ้นอยู่กับ Consent และ config ของ SDK ถ้า SDK คืน `null` หน้าจอจะแจ้งว่ายังไม่ได้ส่ง และให้ตรวจ Log

Consent ใช้ UI ของ SDK เพื่อโหลดข้อความจริง ไม่ยอมรับแทนผู้ใช้ การปิดหน้าต่างไม่เปลี่ยน Consent เมื่อเปลี่ยนตัวตนจะล้างสถานะที่แสดงไว้และให้โหลดใหม่ตามบัญชีปัจจุบัน หากกำหนด Contacting ID จะมีส่วนจัดการ Consent สำหรับการติดต่อหลัง Login ด้วย

Reset ล้างข้อมูล PAM ในเครื่อง รวมถึง contact, identity, token และสถานะ tracking พร้อมล้างสินค้าและสถานะบนหน้าจอ ไม่ลบข้อมูลบน server และไม่นำ session สมาชิกเดิมกลับมา sync จึงเริ่มลองใหม่ได้ในฐานะ guest

## ดูคำสั่งจาก Log และโค้ด

เปิด Debug Console / Android Studio / Xcode แล้วมองหา `Example button:` ซึ่งระบุคำสั่งที่ปุ่มเรียก ตามด้วย Log ของ SDK เช่น consent, identity, tracking และ storage โค้ดใน `example/lib/sdk_demo_page.dart` แสดงการเรียก API และข้อมูลสินค้าตัวอย่างโดยตรง

## Session และ lifecycle

เปิดแอปหรือกลับเข้าแอปจะโหลด `GET /auth/session` อัปเดต cache แล้ว sync PAM โดย provider ไม่เรียก HTTP เอง ระหว่างโหลดเป็น `unknown` เมื่อไม่ Login เป็น `anonymous` และเมื่อ Login เป็น `identified`

Session ตอบ `401` หมายถึง guest แต่ server/network error ไม่ใช่ logout ถ้า REST สำเร็จแต่ PAM ไม่สำเร็จ แอปเก็บ session ที่สำเร็จไว้และมีปุ่มเชื่อมต่อ PAM ใหม่ ส่วน `onIdentityMismatch` ใช้ session ล่าสุดเพื่อ sync และไม่ replay Event ที่ถูกทิ้ง

Auth จำลองเก็บ session ในหน่วยความจำ เมื่อเริ่ม process ใหม่จะเริ่มเป็น guest แอป production ต้องใช้ auth API และการเก็บ session ของตนเอง

## ซอร์สและการทดสอบ

- `main.dart`: เริ่ม SDK จาก config
- `pam_config.dart`: config ที่แก้ก่อน restart
- `demo_auth_api.dart`: REST client และ auth server จำลอง
- `demo_auth_controller.dart`: session, identity provider, callback และ logout/reset
- `sdk_demo_page.dart`: flow 8 ขั้นและ lifecycle observer

รัน `flutter analyze` และ `flutter test` จาก `example/` การทดสอบไม่ส่งข้อมูลไปยัง PAM จริง

อ่านเพิ่มเติม: [Consent](consent.html), [Login / Logout](authentication.html), [Event Tracking](tracking.html)

[กลับหน้าแรก](index.html)
