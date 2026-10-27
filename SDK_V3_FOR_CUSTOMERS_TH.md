# ทำไมจึงแนะนำให้เปลี่ยนจาก PAM Flutter SDK v2 เป็น v3

PAM Flutter SDK v3 ช่วยให้แอปส่งข้อมูลไปยัง CDP โดยระบุตัวตนผู้ใช้ได้ชัดเจนขึ้น จัดการ push notification ได้ยืดหยุ่นขึ้น และส่ง event ได้เป็นลำดับมากขึ้น โดยเฉพาะช่วงที่มีการเข้าสู่ระบบ สลับบัญชี หรือออกจากระบบ

การเปลี่ยนครั้งนี้มีผลต่อวิธีตั้งค่าและการเรียกใช้ SDK บางส่วน ทีมพัฒนาแอปจึงต้องปรับโค้ดก่อนอัปเกรด

## ความสำคัญหลัก: ส่ง event ให้ถูกบัญชี แม้ผู้ใช้กำลังเปลี่ยนสถานะ

ช่วงที่ผู้ใช้ออกจากระบบหรือสลับบัญชีเป็นจุดที่ข้อมูลกิจกรรมอาจผิดคนได้ง่าย เพราะคำขอหลายรายการอาจเกิดขึ้นเกือบพร้อมกัน SDK v3 จัดการเรื่องนี้ด้วยกลไกสามส่วนที่ทำงานร่วมกัน:

1. **จัดลำดับคำขอ:** คำขอ tracking, login และ logout เข้าคิวและทำงานทีละรายการ จึงลดโอกาสที่ event จะส่งคาบเกี่ยวกับการเปลี่ยนบัญชี
2. **กำหนดปลายทางให้แต่ละ event:** ก่อนส่งคำขอ SDK ระบุฐานข้อมูลและ contact ที่ event นั้นต้องไปหาไว้กับคำขอ แม้สถานะผู้ใช้จะเปลี่ยนระหว่างทาง ผลตอบกลับของคำขอเก่าก็ไม่ควรเปลี่ยนปลายทางของ event ถัดไป
3. **หยุดคำขอที่ค้างนาน:** คำขอ HTTP มี timeout 5 วินาที เมื่อหมดเวลา SDK ปิด client ของคำขอนั้น เพื่อไม่ให้คำขอเก่าทำงานต่อและแทรกกับขั้นตอนเปลี่ยนตัวตนที่ตามมา

ตัวอย่างเช่น ผู้ใช้ A กดออกจากระบบ แล้วผู้ใช้ B เข้าสู่ระบบทันที SDK จะจัดลำดับคำขอที่เกี่ยวข้องและใช้ปลายทางตามสถานะของแต่ละคำขอ แนวทางนี้ช่วยลดความเสี่ยงที่กิจกรรมของ B จะไปอยู่ใน contact ของ A และทำให้ข้อมูลใน CDP น่าเชื่อถือขึ้น

คิวนี้ทำงานในหน่วยความจำของแอป จึงช่วยจัดลำดับระหว่างที่แอปยังทำงาน แต่ event ที่ยังส่งไม่เสร็จอาจสูญหายหากแอปถูกปิด

## การตั้งค่าตัวตนและ push ที่เปลี่ยนไปใน v3

| เรื่อง | ใน v2 | ใน v3 | ประโยชน์ที่ได้รับ |
| --- | --- | --- | --- |
| การจับคู่ตัวตนกับ CDP | แอปอาจระบุ key สำหรับ login ผ่าน `loginKey` หรือเลือก secondary key เป็นรายครั้งด้วย `LoginOptions` | กำหนด `identityMatcher` ครั้งเดียวใน `PamConfig` ให้ตรงกับ primary หรือ secondary key ที่ตั้งไว้ใน CDP | ลดความเสี่ยงจากการใช้ key คนละแบบในแต่ละจุดของแอป ซึ่งอาจทำให้ข้อมูลกิจกรรมไปผูกกับ contact ผิดรายการ |
| การตรวจสถานะผู้ใช้ก่อนส่ง event | ไม่มีตัวตรวจสอบสถานะระหว่างแอปกับ SDK แบบนี้ | เลือกเปิด `identityProvider` เพื่อเทียบผู้ใช้ปัจจุบันของแอปกับสถานะใน SDK ก่อนส่ง event | หากพบว่าไม่ตรงกัน SDK จะไม่ส่ง event นั้นและแจ้งผ่าน `onIdentityMismatch` ให้แอปจัดการ จึงช่วยลดความเสี่ยงที่กิจกรรมจะถูกบันทึกภายใต้ผู้ใช้ผิดคน |
| การทำงานร่วมกับระบบ push | ตัวช่วยอ่าน push รับ `RemoteMessage` ของ Firebase โดยตรง และแพ็กเกจ PAM พึ่งพา `firebase_messaging` | ตัวช่วยรับเฉพาะ data map เช่น `message.data`; แอปเลือกและกำหนดเวอร์ชันของ push provider เอง | ลดปัญหาเวอร์ชัน Firebase ชนกับ dependency ของแอป และรองรับแอปที่ใช้ push provider อื่นได้ง่ายขึ้น |
| การจัดการ push token ตอนออกจากระบบ | หลัง logout อาจนำ token ที่บันทึกไว้ไปลงทะเบียนกับ anonymous contact อีกครั้ง | ลบ notification media ของ contact เดิม โดยไม่ผูก token เดิมกับ anonymous contact อัตโนมัติ | ลดโอกาสที่อุปกรณ์หลัง logout จะยังถูกเชื่อมกับ contact ที่ไม่ต้องการ |

**ตัวอย่างที่เห็นภาพ:** หากผู้ใช้ A ออกจากระบบแล้วผู้ใช้ B เข้าสู่ระบบ แอปควรแจ้ง `Pam.userLogout()` และ `Pam.userLogin()` ตามลำดับ ใน v3 ทีมพัฒนาสามารถเพิ่มตัวตรวจสอบสถานะผู้ใช้ก่อนส่ง event ได้ หากแอปเป็น B แล้วแต่ SDK ยังจำ A อยู่ event นั้นจะถูกหยุดไว้และแจ้งให้แอปแก้สถานะก่อนส่ง event ถัดไป ความสามารถนี้ต้องเปิดใช้ `identityProvider` และจัดการ `onIdentityMismatch` ในแอป

### ตัวอย่างการตั้งค่าและเริ่มใช้ PAM

ตัวอย่างนี้ใช้เบอร์โทรศัพท์เป็น primary key ของ CDP โดย `authRepository` คือส่วนจัดการการเข้าสู่ระบบที่แอปมีอยู่แล้ว ให้เรียก `initializePam()` ระหว่างเริ่มแอป หลังจากเตรียม `authRepository` ให้พร้อมและก่อนเริ่มส่ง event:

```dart
import 'package:pam_flutter/pam.dart';

Future<void> initializePam(AuthRepository authRepository) async {
  final config = PamConfig(
    'https://[YOUR-DOMAIN]pams.ai',
    '[PUBLIC-DB-ALIAS]',
    '[LOGIN-DB-ALIAS]',
    '[TRACKING-CONSENT-MESSAGE-ID]',
    false, // เปิด log เป็น true ระหว่างทดสอบได้

    // เลือก key ให้ตรงกับ CDP เพียงครั้งเดียวตอนตั้งค่า SDK
    identityMatcher: PamIdentityMatcher.primary(
      PamPrimaryIdentityKey.sms,
    ),

    // SDK เรียกก่อนส่ง Pam.track() เมื่อ event ผ่านเงื่อนไข consent แล้ว
    // เพื่อเทียบตัวตนในแอปกับ SDK
    // อ่านสถานะที่แอปเก็บไว้แล้วเท่านั้น; ไม่เรียก API หรือทำงานแบบ async
    identityProvider: () {
      if (authRepository.isLoading) {
        // ยังไม่รู้ว่าใคร login: ข้ามการตรวจครั้งนี้
        return const PamUserState.unknown();
      }

      final user = authRepository.currentUser;
      if (user == null) {
        return const PamUserState.anonymous();
      }

      // ใช้ค่าเดียวกับที่แอปส่งให้ Pam.userLogin() และ key ที่ตั้งใน CDP
      return PamUserState.identified(user.mobile);
    },

    // SDK เรียกเมื่อ identityProvider คืนสถานะที่ไม่ตรงกับ SDK
    // โดยแจ้งหนึ่งครั้งต่อสถานะที่ไม่ตรงกันชุดเดิม
    // event ที่ทำให้ตรวจพบจะถูกหยุด; callback นี้ใช้ปรับสถานะสำหรับ event ถัดไป
    onIdentityMismatch: (mismatch) async {
      final correctIdentity = mismatch.newIdentity;
      if (correctIdentity == null) {
        // แอปออกจากระบบแล้ว แต่ SDK ยังจำผู้ใช้เดิม
        await Pam.userLogout();
      } else {
        // แอปมีผู้ใช้ใหม่ แต่ SDK ยังไม่ login หรือจำบัญชีอื่นอยู่
        await Pam.userLogin(correctIdentity.value);
      }
    },
  );

  // ส่ง config ที่มีทั้งสอง callback เข้า SDK ณ จุดเริ่มต้นใช้งาน
  await Pam.initialize(config);
}
```

`AuthRepository` ในตัวอย่างเป็นคลาสของแอปเอง ต้องมี `isLoading` และ `currentUser` ซึ่งมี `mobile` ตัวอย่างนี้แสดงจุดเชื่อมต่อกับ PAM; ให้แทนค่าตั้งต้นและชนิดข้อมูลตามแอปจริง

ใน flow ปกติ แอปยังต้องเรียก `Pam.userLogin()` เมื่อผู้ใช้เข้าสู่ระบบ และ `Pam.userLogout()` เมื่อออกจากระบบ `onIdentityMismatch` เป็นตัวช่วยแก้กรณีสถานะคลาดเคลื่อน ไม่ใช่ตัวแทนของ flow เหล่านั้น หากแอปกับ SDK มีตัวตนไม่ตรงกัน SDK จะไม่ส่ง **event ปัจจุบัน** และคืนข้อผิดพลาด `IDENTITY_STATE_MISMATCH` การแก้สถานะไม่ได้ส่ง event ที่ถูกหยุดไปแล้วซ้ำโดยอัตโนมัติ หาก event นั้นจำเป็น แอปต้องพิจารณาส่งใหม่หลังจัดการสถานะเสร็จ

## สิ่งที่ทีมพัฒนาแอปต้องปรับ

1. เปลี่ยน dependency เป็น `pam_flutter: ^3.0.0` และกำหนด `identityMatcher` ใน `PamConfig` ให้ตรงกับ key ถาวรของ CDP เช่น `customer`, `email`, `sms` หรือ secondary key ที่ตกลงกัน
2. เปลี่ยน `Pam.userLogin(identity, options)` เป็น `Pam.userLogin(identity)` และเลิกใช้ `loginKey` กับ `LoginOptions`
3. หากใช้ Firebase Messaging ให้แอปประกาศ dependency `firebase_messaging` เอง และส่ง `message.data` ให้ `Pam.isPushNotiFromPam()` กับ `Pam.convertToPamPushMessage()`
4. ส่ง push token ที่ได้จาก provider ของแอปผ่าน `Pam.setPushNotificationToken(token)` โดยตรง รวมถึงจัดการกรณี token เปลี่ยน; SDK ไม่ดึง token ให้เอง
5. ทดสอบการเข้าใช้งาน สลับบัญชี ออกจากระบบ การส่ง event และการรับ push กับสภาพแวดล้อม CDP ที่ใช้งานจริง หากต้องการตรวจสถานะผู้ใช้ก่อนส่ง event ให้เพิ่ม `identityProvider` และ `onIdentityMismatch`

## แหล่งอ้างอิงภายในโครงการ

- [คู่มือย้ายจาก v2 เป็น v3](MIGRATE.md)
- [รายการเปลี่ยนแปลง](CHANGELOG.md)
- โค้ดที่เกี่ยวข้อง: [`lib/pam.dart`](lib/pam.dart), [`lib/http/http_client.dart`](lib/http/http_client.dart), [`pubspec.yaml`](pubspec.yaml)
- Git history: `873004b` (v2.4.15), `3f8f82b` (v3.0.0 draft), `db6f4ae` (migration guide)
