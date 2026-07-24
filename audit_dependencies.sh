#!/bin/bash

# สคริปต์สำหรับตรวจเช็คช่องโหว่ความปลอดภัยของ Dependency ใน Flutter/Dart
# เครื่องมือที่ใช้: dart_audit (ดึงฐานข้อมูลจาก OSV.dev)

echo "=================================================="
echo "🔍 Starting Dependency Security Audit..."
echo "=================================================="

# 1. ตรวจสอบก่อนว่าในเครื่องมีการติดตั้ง Dart SDK หรือยัง
if ! command -v dart &> /dev/null
then
    echo "❌ Error: ไม่พบ Dart SDK ในเครื่องนี้ กรุณาติดตั้ง Flutter/Dart ก่อนรันสากริปต์"
    exit 1
fi

# 2. เช็คว่ามีคำสั่ง dart_audit ในระบบหรือยัง
# โดยตรวจจากโฟลเดอร์ глобал ของ pub
if ! dart pub global list | grep -q "dart_audit"; then
    echo "📦 ไม่พบ dart_audit ในเครื่อง -> กำลังดำเนินการติดตั้งให้อัตโนมัติ..."
    
    # สั่งติดตั้ง dart_audit แบบ Global
    dart pub global activate dart_audit
    
    if [ $? -eq 0 ]; then
        echo "✅ ติดตั้ง dart_audit เรียบร้อยแล้ว!"
    else
        echo "❌ เกิดข้อผิดพลาดในการติดตั้ง dart_audit"
        exit 1
    fi
else
    echo "✨ พบเครื่องมือ dart_audit เรียบร้อยแล้ว (ไม่ต้องติดตั้งใหม่)"
fi

echo "--------------------------------------------------"
echo "🚀 กำลังเริ่มสแกนโปรเจกต์หาช่องโหว่ความปลอดภัย..."
echo "--------------------------------------------------"

# 3. รันคำสั่งตรวจเช็คช่องโหว่
# หมายเหตุ: เครื่อง Mac/Linux บางเครื่องอาจต้องเรียกผ่าน 'dart pub global run' 
# หากยังไม่ได้เซ็ต PATH ไปที่โฟลเดอร์แคชของ pub
dart pub global run dart_audit audit

# เก็บสถานะการทำงาน (Exit Code) เพื่อเอาไว้ใช้ในระบบ CI/CD
AUDIT_RESULT=$?

echo "=================================================="
if [ $AUDIT_RESULT -eq 0 ]; then
    echo "🎉 การสแกนเสร็จสิ้น: ไม่พบช่องโหว่ร้ายแรง หรือ Dependency ปลอดภัยดี!"
else
    echo "⚠️ การสแกนเสร็จสิ้น: พบช่องโหว่ความปลอดภัยในโครงการของคุณ! กรุณาตรวจสอบรายงานด้านบน"
fi
echo "=================================================="

exit $AUDIT_RESULT