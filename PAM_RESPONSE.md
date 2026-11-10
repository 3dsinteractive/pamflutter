สรุป response contract สำหรับ Mobile SDK:

**1. Track สำเร็จ**
HTTP `200`

```json
{
  "contact_id": "xxx",
  "_database": "login_db",
  "consent_id": "",
  "tracker_id": "yyy"
}
```

ไม่มี `error` และไม่มี `error_code`  
รวมถึง whitelist event เช่น `login`, `register`, `register_success`, `logout`, `save_push`, `test`, `allow_consent`

**2. Unauthorized**
เช่น login DB ตั้ง `IsRequireAuthorization=true` แต่ mobile ไม่มี/ส่ง token ไม่ถูกต้อง

HTTP `401`

```json
{
  "contact_id": "",
  "_database": "",
  "error": "Unauthorized",
  "error_code": "UNAUTHORIZED"
}
```

Mobile: หยุด retry ชั่วคราว เช่น 1 ชั่วโมง หรือรอ token ใหม่

**3. ไม่มี Customer จริง**
เช่นหา profile จาก key แล้วไม่เจอ หรือ auto-create ถูกปิด

HTTP เดิมยังเป็น `200`

```json
{
  "contact_id": "",
  "_database": "",
  "error": "Contact not found",
  "error_code": "CONTACT_NOT_FOUND"
}
```

Mobile: อย่า retry ถี่ ๆ; pause/retry later รอ server sync profile

**4. ไม่มี `_consent_message_id`**
สำหรับ event ที่ต้อง consent แต่ payload ไม่ส่ง `form_fields._consent_message_id`

HTTP `400`

```json
{
  "contact_id": "",
  "_database": "",
  "error": "Invalid consent",
  "error_code": "CONSENT_MESSAGE_ID_IS_REQUIRED"
}
```

Mobile: แก้ payload หรือเข้าสู่ consent setup flow

**5. ไม่มี Consent / Consent เก่า ต้อง Review**
มี customer แล้ว แต่ยังไม่มี consent หรือ consent ต้อง review

HTTP `400`

```json
{
  "contact_id": "xxx",
  "_database": "login_db",
  "error": "Need consent review",
  "error_code": "NEED_CONSENT_REVIEW"
}
```

Mobile: หยุด track event ที่ต้อง consent แล้วเปิด consent flow; หลัง consent สำเร็จค่อยยิงใหม่

**6. Tracking ไม่อนุญาตตาม consent**
เช่นมี consent record แต่ `IsTrackingAllowed=false`

HTTP `401`

```json
{
  "contact_id": "",
  "_database": "",
  "error": "Unauthorized",
  "error_code": "TRACKING_IS_NOT_ALLOWED"
}
```

Mobile: ไม่ควร retry event เดิมทันที; treat เป็น blocked by consent

**7. Fallback ไป default แต่ mobile ไม่ได้เปิด legacy flag**
ปกติ mobile ไม่ส่ง `_fallback_to_default_db=true` ดังนั้นถ้า login/import DB ไม่มี tokenแล้ว flow fallback ไป default จะถูก reject

HTTP `400`

```json
{
  "contact_id": "",
  "_database": "",
  "error": "Invalid Request: Unauthorized, Unable to Create Contact Please provide a valid authorization token to proceed with creating a new contact in `login_db` database.",
  "error_code": "INVALID_EVENT"
}
```

Mobile: treat เป็น auth/customer-not-ready case; หยุด retry ถี่ ๆ

หลักสำหรับ SDK: ให้ตัดสินจาก `error_code` เป็นหลัก ไม่ต้อง parse `error` string.
