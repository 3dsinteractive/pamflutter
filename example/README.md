# PAM Flutter SDK Example

ตัวอย่างแอปดูสินค้า ให้ลองใช้งานตามเส้นทางผู้เยี่ยมชม → สมาชิก → ออกจากระบบ โดยไม่ต้องกรอกหรืออ่าน JSON บนหน้าจอ ดูคำสั่งของแต่ละปุ่มและผลการเรียก SDK ผ่าน Log ใน Debug Console / Android Studio / Xcode

## ตั้งค่าแล้วรัน

แก้ `lib/pam_config.dart`: endpoint, database aliases และ Tracking Consent Message ID ถ้ามี Contacting Consent ให้ใส่ ID เพิ่ม แล้วรัน:

```bash
cd example
flutter pub get
flutter run
```

ใช้ Flutter 3.41+ / Dart 3.11+ โดย `main` เรียก `getDevelopConfig` และรอ `Pam.initialize` ก่อนเปิดแอป ต้อง restart หลังเปลี่ยน config ค่า develop เปิด SDK Log ไว้ ส่วน `getProductionConfig` เป็นตัวอย่างอ้างอิง

PAM ติดต่อ server จริงตาม config ส่วน REST auth เป็น server จำลองภายในแอป เก็บ session ในหน่วยความจำ ไม่ใช่ระบบ authentication สำหรับ production

## ทดลองตามลำดับ

1. **ลองใช้แอปก่อน Login:** ดูรายละเอียดสินค้าเรียก `Pam.track("view_product")` ส่วนกด/ยกเลิกรายการที่ชอบเรียก `Pam.track("favorite_product")` พร้อม `is_favorite: true/false` ไม่บังคับ Login เพื่อใช้งาน และการส่ง Event ยังเป็นไปตาม Consent/config ของ SDK
2. **เลือก Consent ก่อน Login:** เปิด `Pam.showConsent` เพื่ออ่านข้อความจริง เลือกและยืนยันเอง ปิดหน้าต่างโดยไม่บันทึกได้
3. **ส่ง Event ก่อน Login:** กดส่ง `view_product` พร้อมข้อมูลสินค้าตัวอย่างในฐานะ guest ถ้า SDK ไม่ส่ง เช่นถูกบล็อกด้วย Consent หน้าจอจะไม่อ้างว่าส่งสำเร็จ
4. **พร้อมแล้วค่อย Login:** ใส่ Customer ID → REST login จำลองสำเร็จ → เก็บ app session → `Pam.userLogin` ไม่บังคับให้ผ่านขั้นก่อนหน้าครบ
5. **ตรวจสอบหรือปรับ Consent หลัง Login:** ใช้ `Pam.loadConsentStatus` โหลดสถานะสมาชิกใหม่ แสดงตัวเลือกเป็นข้อความและป้ายอนุญาต/ไม่อนุญาต เปิด `Pam.showConsent` อีกครั้งเพื่อแก้ไข หากตั้ง Contacting ID จะมีตัวเลือกสำหรับการติดต่อด้วย
6. **ส่ง Event หลัง Login:** ส่ง `view_product` เดิมพร้อม `demo_stage: member` หรือกดจำลองซื้อสินค้าเพื่อเรียก `Pam.trackBatch([purchase_order, ...purchase_order_item])` โดยรวมคำสั่งซื้อกับสินค้า 2 รายการในคำขอเดียว ใช้ `order_id` เดียวกัน ยอดรวม 1,090 THB กดแต่ละครั้งสร้างคำสั่งซื้อจำลองใหม่ ผลแสดงใต้ปุ่ม และรายละเอียดดูได้ใน Log ผล Batch อาจไม่ครบและไม่ใช่ธุรกรรมที่สำเร็จพร้อมกันทั้งหมด
7. **ทดสอบ App Attention:** กรอก PageName (ค่าเริ่มต้น `home`) แล้วกด `Pam.appAttention` ใช้ได้ทั้ง guest และสมาชิก ต้องมี Campaign ที่ตรงกับ PageName และผู้ใช้ปัจจุบัน ผลแสดงใต้ปุ่มและรายละเอียดอยู่ใน Log
8. **Logout และเริ่มใหม่:** REST logout → app เป็น anonymous → `Pam.userLogout` → `Pam.reset` → ล้างรายการที่ชอบ รายละเอียดสินค้า และสถานะ Consent บนหน้าจอ ไม่มีการนำ session สมาชิกเดิมกลับมา sync

Reset ล้างข้อมูล SDK ในเครื่อง รวมถึง contact, identity, token และสถานะ tracking ไม่ได้ลบข้อมูลที่ส่งไปยัง server แล้ว จึงอาจพบ Consent เดิมอีกเมื่อระบุตัวตนเดิมในภายหลัง

แต่ละปุ่มบันทึก `Example button:` พร้อมชื่อคำสั่งลง SDK Log อ่านโค้ดที่ `sdk_demo_page.dart` เพื่อดูการเรียกจริงและ payload ตัวอย่าง ไม่ต้องคัดลอก JSON จากหน้าจอ

## Session และการกลับเข้าแอป

เปิดแอปหรือ resume จะเรียก `GET /auth/session` → อัปเดต cache → sync PAM ก่อนเปิดปุ่มที่ต้องใช้ SDK โดย `identityProvider` อ่าน cache เท่านั้น: `unknown` ระหว่างโหลด, `anonymous` สำหรับ guest และ `identified` สำหรับสมาชิก

- Session ตอบ `401` หมายถึง guest ส่วน `500` หรือ network error หมายถึงยังไม่ทราบสถานะ จึงไม่เดาว่า logout
- REST login/logout ล้มเหลวจะไม่เปลี่ยน session เดิม
- PAM ล้มเหลวหลัง REST login สำเร็จจะเก็บ app session ไว้และมีปุ่มเชื่อมต่อ PAM อีกครั้ง
- สถานะ Consent บนหน้าจอจะถูกล้างเมื่อเปลี่ยนบัญชี เพื่อไม่ใช้ข้อมูลของตัวตนก่อนหน้า
- `onIdentityMismatch` sync ตัวตนล่าสุดโดยไม่ replay Event ที่ถูกทิ้ง
- `Pam.userLogout` คืน `Future<void>` ให้ดูผลเครือข่ายใน SDK Log เพิ่มเติม

## Android Sync / Build

เปิด Flutter project ที่ `example/` หรือ Gradle project ที่ `example/android/` ตัวอย่างใช้ Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20, Java target 17 และ minSdk 24

```bash
flutter build apk --debug
```

## โครงสร้างและการทดสอบ

- `lib/main.dart`: initialize SDK ก่อนเปิดแอป
- `lib/pam_config.dart`: config สำหรับ develop / production
- `lib/demo_auth_api.dart`: REST client และ auth server จำลอง
- `lib/demo_auth_controller.dart`: session, provider, mismatch และลำดับ logout/reset
- `lib/sdk_demo_page.dart`: หน้าลองสินค้าและ flow 8 ขั้น พร้อม lifecycle observer

```bash
flutter analyze
flutter test
```

Tests ใช้ SDK และ HTTP จำลอง ไม่ส่งข้อมูลไปยัง PAM จริง
