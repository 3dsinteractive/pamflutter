# การส่ง Event Tracking

ใช้ `Pam.track()` เพื่อบันทึกกิจกรรมที่ผู้ใช้ทำในแอป เช่น ดูสินค้า เพิ่มสินค้าลงตะกร้า หรือซื้อสินค้าสำเร็จ โดยส่งชื่อ event พร้อมข้อมูลประกอบผ่านพารามิเตอร์ `payload`

```dart
Pam.track(
  'add_to_cart',
  payload: {
    'sku': 'SKU-001',
    'price': 590.0,
    'quantity': 2,
    'title': 'เสื้อยืดคอกลม',
  },
);
```

ตัวอย่างไม่ใช้ `await` เพื่อให้แอปทำงานต่อได้โดยไม่ต้องรอ PAM Server และควรดำเนินการขอ Tracking Consent ให้เรียบร้อยก่อนเริ่มส่งกิจกรรมของผู้ใช้

---

## กำหนด Event ร่วมกับทีม

ตั้งชื่อ event ได้ตามกิจกรรมที่ต้องการบันทึก แต่ควรตกลงชื่อ ความหมาย และ attributes ร่วมกับทีมที่นำข้อมูลไปใช้ เพื่อให้ทุกฝ่ายเข้าใจตรงกัน

| ชื่อ event ตัวอย่าง | จังหวะที่ส่ง | attributes ตัวอย่าง |
|---|---|---|
| `view_product` | แสดงรายละเอียดสินค้าให้ผู้ใช้แล้ว | `sku`, `title`, `price` |
| `add_to_cart` | เพิ่มสินค้าลงตะกร้าสำเร็จ | `sku`, `title`, `price`, `quantity` |
| `purchase` | ยืนยันคำสั่งซื้อสำเร็จ | `order_id`, `total` |

กำหนดความหมายของแต่ละ attribute ให้ชัดเจนด้วย เช่น `price` เป็นราคาต่อหน่วย และ `quantity` เป็นจำนวนที่เพิ่มในครั้งนั้น รวมถึงใช้ชื่อและชนิดข้อมูลอย่างสม่ำเสมอ

---

## สร้างคลาสกลางสำหรับส่ง Event

แนะนำให้รวมการเรียก tracking ไว้ในคลาสกลาง เพื่อให้ตรวจสอบและแก้ไขชื่อ event หรือ attributes ได้จากจุดเดียว ลดการเขียนข้อมูลต่างรูปแบบกันในแต่ละหน้าของแอป

หากต้องส่งกิจกรรมเดียวกันไปยังระบบอื่นในอนาคต สามารถเพิ่มการเรียกส่งในเมธอดนี้ได้ โดยไม่ต้องแก้ทุกหน้าที่เรียกใช้งาน

### ไฟล์ `lib/track_event.dart`

```dart
import 'package:pam_flutter/pam.dart';

class TrackEvent {
  static void trackAddToCart({
    required String sku,
    required double price,
    required int quantity,
    required String title,
  }) {
    Pam.track(
      'add_to_cart',
      payload: {
        'sku': sku,
        'price': price,
        'quantity': quantity,
        'title': title,
      },
    );

    // หากต้องการส่งกิจกรรมนี้ไปยังระบบอื่น ให้เพิ่มการเรียกที่นี่
  }

  static void trackViewProduct({
    required String sku,
    required double price,
    required String title,
  }) {
    Pam.track(
      'view_product',
      payload: {
        'sku': sku,
        'price': price,
        'title': title,
      },
    );
  }
}
```

---

## ตัวอย่างใช้งานในหน้าสินค้า

เรียก `TrackEvent.trackAddToCart()` หลังระบบตะกร้ายืนยันว่าเพิ่มสินค้าสำเร็จ เพื่อให้ event สะท้อนกิจกรรมที่เกิดขึ้นจริง

```dart
import 'track_event.dart';

// ตัวอย่าง onPressed ของปุ่มเพิ่มสินค้าลงตะกร้า
onPressed: () async {
  // รอผลจากระบบตะกร้าของแอปก่อน
  await cartRepository.addItem(
    sku: 'SKU-001',
    quantity: 2,
  );

  // แจ้งกิจกรรมโดยไม่รอผลจาก PAM
  TrackEvent.trackAddToCart(
    sku: 'SKU-001',
    price: 590.0,
    quantity: 2,
    title: 'เสื้อยืดคอกลม',
  );

  // แสดงผลสำเร็จหรือให้ผู้ใช้ทำรายการต่อได้ทันที
},
```

`cartRepository.addItem()` เป็นตัวอย่างเมธอดของระบบตะกร้า ให้แทนด้วยโค้ดของแอป หากเพิ่มสินค้าไม่สำเร็จ ไม่ควรส่ง `add_to_cart`

---

## บันทึกคำสั่งซื้อและสินค้าแต่ละรายการ

หลังระบบคำสั่งซื้อยืนยันสำเร็จ สามารถส่ง `purchase` สำหรับยอดรวม และ `purchase_item` สำหรับสินค้าแต่ละรายการ โดยเชื่อมกันด้วย `order_id` ตัวอย่างใช้ค่าที่รับเข้ามาจริง ไม่กำหนด SKU ราคา หรือสกุลเงินตายตัวในเมธอด

```dart
import 'package:pam_flutter/pam.dart';

void trackPurchase({
  required String orderId,
  required double totalAmount,
  required String currency,
  required List<Map<String, dynamic>> items,
}) {
  Pam.track(
    'purchase',
    payload: {
      'order_id': orderId,
      'total_amount': totalAmount,
      'currency': currency,
    },
  );

  for (final item in items) {
    Pam.track(
      'purchase_item',
      payload: {
        'order_id': orderId,
        'sku': item['sku'],
        'price': item['price'],
        'quantity': item['quantity'],
        'title': item['title'],
        'currency': currency,
      },
    );
  }
}
```

ให้ตกลงชื่อ event และ attributes กับทีม Data ก่อนใช้ เช่น เลือกใช้ `total` หรือ `total_amount` ให้สม่ำเสมอ แต่ละรายการต้องมี `sku`, `price`, `quantity` และ `title` ตามรูปแบบที่ตกลงไว้ คำขอแต่ละ event แยกจากกัน จึงไม่ใช่ธุรกรรมที่สำเร็จหรือล้มเหลวพร้อมกันทั้งหมด และควรเรียกจากจุดยืนยันคำสั่งซื้อเพียงครั้งเดียวเพื่อไม่ส่งซ้ำจากการสร้างหน้าจอใหม่

---

## นำ Event ไปใช้สร้าง Segment

ข้อมูล event สามารถนำไปกำหนดกลุ่มลูกค้าใน PAM ได้ เช่น **ลูกค้าที่เพิ่มสินค้า SKU-001 ลงตะกร้าภายใน 15 วันที่ผ่านมา** โดยพิจารณาร่วมกันจาก:

- ชื่อ event: `add_to_cart`
- attribute: `sku` มีค่าเป็น `SKU-001`
- ช่วงเวลา: ย้อนหลัง 15 วัน

เงื่อนไขที่นำไปใช้ได้ขึ้นอยู่กับ attributes ที่แนบมา หากไม่ได้ส่ง `sku` จะไม่สามารถใช้ข้อมูลนี้แยกกลุ่มตามสินค้าที่เพิ่มลงตะกร้าได้

ควรเก็บเฉพาะ event และ attributes ที่มีวัตถุประสงค์ชัดเจน เช่น ใช้สร้าง Segment วิเคราะห์พฤติกรรม หรือกำหนดแคมเปญ หลีกเลี่ยงการเก็บกิจกรรมที่ไม่มีแผนนำไปใช้ เพราะทำให้ข้อมูลมากขึ้นและดูแลยากโดยไม่เพิ่มประโยชน์

---

## ใช้ Event กับ User Journey

Event ที่ส่งจากแอปสามารถใช้เป็นเงื่อนไขในระบบ User Journey ของ PAM ได้ หาก Journey กำหนดให้รอ event ชื่อที่ระบุ เมื่อผู้ใช้เกิด event นั้นและตรงตามเงื่อนไข ระบบจะเลื่อนผู้ใช้ไปยังขั้นถัดไปของ Journey

สอบถามวิธีออกแบบและตั้งค่า User Journey เพิ่มเติมได้จากทีมงาน PAM

---

## ใช้ Event กับ Transaction Campaign

ส่ง `_campaign_id` ใน `payload` เพื่อระบุ Transaction Campaign ที่ต้องการให้เริ่มทำงานทันทีเมื่อได้รับ event เพื่อส่งข้อความของแคมเปญนั้นไปยังผู้ใช้ตามเงื่อนไขที่ตั้งค่าไว้

```dart
Pam.track(
  'order_confirmed',
  payload: {
    'order_id': 'ORDER-001',
    '_campaign_id': 'YOUR-CAMPAIGN-ID',
  },
);
```

ให้แทน `YOUR-CAMPAIGN-ID` ด้วยรหัสแคมเปญที่ต้องการเรียกใช้งาน และสอบถามรายละเอียดการตั้งค่า เงื่อนไขการส่ง และการใช้งาน Transaction Campaign จากทีมงาน PAM

[กลับหน้าแรก](index.html)
