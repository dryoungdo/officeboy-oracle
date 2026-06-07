---
type: learning
topic: ByteHR Complete Guide — Thailand HR System
source: vendor-docs
maturity: emerging
retrieval_terms: [byte-hr, bytehr, hr-system, payroll, thailand-hr, complete-guide, leave-management, timesheet, kpi, recruitment, government-reports]
date: 2026-06-07
gate_hook: verify-freshness-quarterly
---

# ByteHR Complete Guide — Thailand HR System

**ระบบจัดการทรัพยากรบุคคลออนไลน์สำหรับธุรกิจในประเทศไทย**

Help Center: https://help.byte-hr.com

---

## สารบัญ (Table of Contents)

1. [ภาพรวม ByteHR](#1-ภาพรวม-bytehr)
2. [การตั้งค่าระบบ (System Setup)](#2-การตั้งค่าระบบ)
3. [จัดการพนักงาน (Employees)](#3-จัดการพนักงาน)
4. [ตารางกะ (Shift Schedules)](#4-ตารางกะ)
5. [ตารางเวลา (Timesheets)](#5-ตารางเวลา)
6. [ร้องขอ (Requests)](#6-ร้องขอ)
7. [การทำเงินเดือน (Payroll)](#7-การทำเงินเดือน)
8. [รายงานมาตรฐาน (Standard Reports)](#8-รายงานมาตรฐาน)
9. [รายงานราชการ (Government Reports)](#9-รายงานราชการ)
10. [การประเมิน KPI (KPI Reviews)](#10-การประเมิน-kpi)
11. [ระบบติดตามผู้สมัครงาน (Recruitment)](#11-ระบบติดตามผู้สมัครงาน)
12. [แอปมือถือ (Mobile App)](#12-แอปมือถือ)
13. [ClassicHR (Legacy System)](#13-classichr)
14. [Open API](#14-open-api)
15. [คำถามที่พบบ่อย (FAQ)](#15-คำถามที่พบบ่อย)

---

## 1. ภาพรวม ByteHR

ByteHR เป็นระบบ HR Management ออนไลน์ที่ออกแบบมาสำหรับธุรกิจในประเทศไทย รองรับทั้งกฎหมายแรงงานไทยและการยื่นแบบภาษี/ประกันสังคมออนไลน์

### ฟีเจอร์หลัก
- **จัดการพนักงาน** — เพิ่ม/ลบ/แก้ไขข้อมูลพนักงาน, สัญญาจ้าง, ทดลองงาน
- **ตารางกะ** — กะปกติ + กะยืดหยุ่น (Add-On), รูปแบบกะ, วันหยุด
- **ตารางเวลา** — ลงเวลาเข้า/ออก, สแกนนิ้ว, GPS check-in, Face scan
- **ร้องขอ** — ลา, OT, สลับกะ, แก้ไขเวลา, เงินคืน (reimbursement)
- **เงินเดือน** — คำนวณอัตโนมัติ, ภาษี, ประกันสังคม, กองทุนสำรองเลี้ยงชีพ
- **รายงาน** — Dashboard, สลิปเงินเดือน, หนังสือรับรอง
- **รายงานราชการ** — ภ.ง.ด.1/1ก/3, สปส.1-10, ใบ 50 ทวิ, กท.20
- **KPI** — ประเมินผลงาน, Template, คะแนน, แจ้งผล
- **Recruitment** — ตำแหน่งว่าง, ผู้สมัคร, กระบวนการรับเข้าทำงาน (Add-On)
- **แอปมือถือ** — iOS/Android, Face scan, ลงเวลา, ดูสลิป, ส่งคำร้อง

### รุ่นของระบบ
- **ByteHR** — รุ่นปัจจุบัน (ใช้งานหลัก)
- **ClassicHR** — รุ่นเก่า (Legacy, ยังมีลูกค้าใช้อยู่)

### Add-On Features (ซื้อเพิ่ม)
- ตารางกะยืดหยุ่น (Flexible Shift)
- สกุลเงินหลายสกุลเงิน (Multi Currencies)
- การแจ้งเตือนผ่าน LINE
- ระบบติดตามผู้สมัครงาน (Recruitment/ATS)
- eCheckin Face Scan
- Google Calendar Sync
- เปลี่ยนชั่วโมงโอทีเป็นวันลา
- ภาษี/ประกันสังคมที่นายจ้างออกให้
- Open API

---

## 2. การตั้งค่าระบบ

### 2.1 กฎค่าล่วงเวลา (Overtime Rules)
ตั้งค่าอัตราค่าล่วงเวลาตามกฎหมายแรงงานไทย:
- OT วันทำงานปกติ (1.5x)
- OT วันหยุดประจำสัปดาห์ (3x ทำงาน, 3x OT)
- OT วันหยุดนักขัตฤกษ์ (2x ทำงาน, 3x OT)

📖 รายละเอียด: `notebooklm-docs/admin/01-preferences-and-setup.md`

### 2.2 กฎการจ่ายเงิน (Payment Rules)
- กำหนดวิธีจ่ายเงินเดือน (โอนธนาคาร/เช็ค)
- ตั้งค่ารอบจ่าย (เดือนละ 1 ครั้ง / 2 ครั้ง / รายสัปดาห์)

### 2.3 กฎการปัดเศษ (Rounding Rules)
- ปัดเศษนาทีสาย/ออกก่อน/OT
- เช่น ปัดขึ้นเป็น 15 นาที หรือ 30 นาที

### 2.4 กฎการหักเงิน (Deduction Rules)
- ตั้งค่าการหักเงินคงที่ / ตามสัดส่วน
- กำหนดวันตัดรอบ

### 2.5 กองทุนสำรองเลี้ยงชีพ (Provident Fund)
- รองรับ TISCO, UOB, SCB
- ตั้งค่ากฎอัตราสมทบ

### 2.6 การลงเวลาทำงาน
- GPS check-in ตามสาขา
- กำหนดตำแหน่งเพิ่มเติม
- ระบบสแกนลายนิ้วมือ ADMS

### 2.7 การแจ้งเตือน
- LINE Notify (Add-On)
- แจ้งเตือนวันสิ้นสุดทดลองงาน
- แจ้งเตือนวันเกิดพนักงาน

### 2.8 ผู้อนุมัติเงินเดือน (Payroll Approvers)
- กำหนดผู้อนุมัติตามสาขา/แผนก

### 2.9 สกุลเงิน (Multi Currencies) — Add-On
- เพิ่มสกุลเงินต่างประเทศ
- คำนวณเงินเดือนสกุลต่างประเทศ

---

## 3. จัดการพนักงาน

### 3.1 เพิ่มพนักงาน
- กรอกข้อมูลส่วนตัว, ที่อยู่, ธนาคาร
- กำหนดสาขา, แผนก, ตำแหน่ง
- ตั้งค่าเงินเดือน, ประเภทเงินได้ (40(1) หรือ 40(2))

### 3.2 สัญญาจ้าง
- เพิ่มสัญญาจ้าง (กำหนดเริ่ม/สิ้นสุด)
- ปิดสัญญาจ้าง (ลาออก/เลิกจ้าง)
- ทดลองงาน (Probation) + แจ้งเตือนครบกำหนด

### 3.3 ค่าลดหย่อนภาษี
- เพิ่มค่าลดหย่อนต่างๆ (บิดามารดา, บุตร, ประกันชีวิต)
- กองทุนบำเหน็จบำนาญข้าราชการ
- กองทุนสงเคราะห์ครูเอกชน

### 3.4 กองทุนสำรองเลี้ยงชีพ (PVF)
- กำหนดอัตราสมทบพนักงาน/นายจ้าง
- ตั้งค่ากฎตามอายุงาน

### 3.5 ผู้จัดการ
- เพิ่มผู้จัดการ (Manager)
- กำหนดสิทธิ์ดู/อนุมัติ

### 3.6 ปรับเงินเดือน
- ปรับทีละคน หรืออัปโหลดเป็น batch

📖 รายละเอียด: `notebooklm-docs/admin/03-employees.md`

---

## 4. ตารางกะ

### 4.1 สร้างตารางกะ
- กำหนดชื่อ, รหัส, วันที่เริ่มต้น
- เพิ่มพนักงานเข้าตารางกะ

### 4.2 ตั้งเวลาทำงาน
- กำหนดเวลาเข้า/ออก
- วันหยุดประจำสัปดาห์
- ตัวอย่าง: จันทร์-ศุกร์ 08:00-17:00

### 4.3 รูปแบบกะ (Shift Pattern)
- สร้าง template กะหมุนเวียน
- เช่น กะเช้า-บ่าย-ดึก

### 4.4 การตั้งค่ากะ
- นาทีสาย/ออกก่อน + Grace Period
- ชั่วโมง OT สูงสุด
- กฎค่าล่วงเวลาในกะ

### 4.5 ตารางกะยืดหยุ่น (Flexible Shift) — Add-On
- กำหนดช่วงเวลาเข้างานได้ (เช่น 07:00-10:00)
- ชั่วโมงทำงานขั้นต่ำ

### 4.6 พนักงานไม่มีตารางกะ (Non-Shift)
- สำหรับพนักงานที่ไม่ต้องลงเวลา

📖 รายละเอียด: `notebooklm-docs/admin/05-shifts.md`

---

## 5. ตารางเวลา

### 5.1 โหลดตารางเวลา
- โหลดข้อมูลตามรอบเงินเดือน
- มุมมอง Timestamp vs Work Hours

### 5.2 ดึงข้อมูลสแกนนิ้ว
- **Auto Sync** — ดึงจาก Sync App / ADMS อัตโนมัติ
- **Auto Upload** — อัปโหลดอัตโนมัติ
- **ZKTeco** — รองรับเครื่องสแกน ZKTeco

### 5.3 อัปโหลดตารางเวลา
- **Excel** — ดาวน์โหลด template แล้วอัปโหลด
- **Text file** — รูปแบบ text
- **Manual** — แก้ไขตรงในระบบ

### 5.4 สร้างตารางเวลาใหม่ (Regenerate)
- สร้างใหม่เมื่อแก้ไขตารางกะ
- ระวัง: ข้อมูลเก่าถูก overwrite

### 5.5 ความหมายของสถานะ
- 12 สถานะ (ปกติ, สาย, ออกก่อน, ขาดงาน, ลา, วันหยุด, etc.)

### 5.6 โอนตารางเวลาเป็นเงินเดือน
- Approve Timesheet → Transfer to Payroll

📖 รายละเอียด: `notebooklm-docs/admin/06-timesheets.md`

---

## 6. ร้องขอ

### 6.1 คำร้องขอวันลา
- พนักงานส่งคำร้อง → ผู้จัดการอนุมัติ/ไม่อนุมัติ
- รองรับหลายประเภทลา (ลาป่วย, ลากิจ, ลาพักร้อน, etc.)

### 6.2 คำร้องขอทำ OT
- ส่งได้ทีละ 1 คำร้อง หรือหลายคำร้อง
- ระบบ auto-detect OT วันหยุดประจำสัปดาห์/นักขัตฤกษ์

### 6.3 คำร้องแก้ไขกะ
- แก้ไขเวลาทำงาน
- สลับกะ (Swap Shift) — ทั้งกะปกติและยืดหยุ่น

### 6.4 คำร้องแก้ไขเวลาเข้า/ออก
- แก้ไขเวลาลงชื่อเมื่อลืมหรือผิดพลาด

### 6.5 คำร้องเงินคืน (Reimbursement)
- ส่งคำร้องเบิกเงินคืน
- แนบเอกสาร, ใบเสร็จ

### 6.6 ขั้นตอนการอนุมัติ (Approval Workflow)
- ตั้งค่าลำดับการอนุมัติ (1 ขั้น / หลายขั้น)
- อนุมัติ/ไม่อนุมัติหลายคำร้องพร้อมกัน

### 6.7 การแจ้งเตือน
- แจ้งเตือนเมื่อส่ง/อนุมัติ/ไม่อนุมัติ
- ผ่าน email, LINE, in-app

### 6.8 เปลี่ยน OT เป็นวันลา — Add-On
- แปลงชั่วโมง OT เป็นวันลาชดเชย

📖 รายละเอียด: `notebooklm-docs/admin/04-requests.md`

---

## 7. การทำเงินเดือน

### 7.1 ขั้นตอนหลัก
1. โหลดตารางเวลา → อนุมัติ
2. Generate Payroll (หรืออัปโหลด)
3. ตรวจสอบ/แก้ไข
4. อนุมัติเงินเดือน
5. สร้างไฟล์ธนาคาร
6. แจ้งเตือนสลิปเงินเดือน

### 7.2 วิธีทำเงินเดือน
- **จากตารางเวลา** — Approve Timesheet → Generate
- **จากสัญญาจ้าง** — สำหรับพนักงานที่ไม่ลงเวลา
- **อัปโหลด** — Upload Salary Payments จาก Excel

### 7.3 การคำนวณ
- คำนวณตามสัดส่วน (เข้าใหม่/ลาออก/ปรับเงินเดือน)
- OT ตามสัดส่วน
- ประกันสังคมสำหรับจ่าย 2 ครั้ง/สัปดาห์

### 7.4 ภาษี/ประกันสังคมที่นายจ้างออกให้ — Add-On
- Gross-up ภาษี
- นายจ้างออกประกันสังคมให้

### 7.5 การจ่ายเงินชดเชย (Severance)
- คำนวณตามอายุงาน (120 วัน ถึง 20+ ปี)
- ตามกฎหมายแรงงานไทย

### 7.6 ไฟล์ธนาคาร
- สร้างไฟล์สำหรับโอนเงินเดือน
- รองรับธนาคารหลักในไทย (KBank, SCB, etc.)

### 7.7 สลิปเงินเดือน
- แจ้งเตือนทันที หรือตั้งเวลา
- แก้ไขสลิปรายคน (หลังแจ้งเตือนแล้ว)

📖 รายละเอียด: `notebooklm-docs/admin/02-payroll.md`

---

## 8. รายงานมาตรฐาน

### 8.1 Dashboards
- **พนักงาน** — จำนวนพนักงาน, เข้าใหม่/ลาออก, อายุงาน
- **ตารางเวลา (รายวัน)** — เข้างาน/ขาดงาน/สาย วันนี้
- **ตารางเวลา (รายเดือน)** — ภาพรวมรายเดือน
- **วันลา** — สรุปการลา, ยอดคงเหลือ
- **เงินเดือน** — สรุปค่าใช้จ่ายเงินเดือน

### 8.2 สลิปเงินเดือน
- มุมมองแอดมิน — สร้าง/พิมพ์สลิปเป็น batch
- มุมมองพนักงาน — ดูสลิปผ่าน web app
- ล็อคสลิป — ป้องกันดูก่อนกำหนด

### 8.3 หนังสือรับรอง
- ปรับแต่ง template
- พนักงานส่งคำร้อง → แอดมินอนุมัติ

### 8.4 รายงานอื่นๆ
- KPI Review Report
- Payroll Register
- Salary Adjustment
- Location Timestamp
- Training Report
- Allowance/Deduction Rule Reports

📖 รายละเอียด: `notebooklm-docs/admin/08-standard-reports.md`

---

## 9. รายงานราชการ

### 9.1 ภาษีเงินได้ (ภ.ง.ด.)
- **ภ.ง.ด.1** — ยื่นรายเดือน + ยื่นออนไลน์
- **ภ.ง.ด.1ก** — ยื่นรายปี + ยื่นออนไลน์
- **ภ.ง.ด.3** — ยื่นรายเดือน + ยื่นออนไลน์

### 9.2 ใบ 50 ทวิ (หนังสือรับรองการหักภาษี ณ ที่จ่าย)
- สร้างจาก ภ.ง.ด.1ก หรือ ภ.ง.ด.3
- ส่งให้พนักงานทาง email

### 9.3 ประกันสังคม
- **สปส.1-10** — รายงานสมทบรายเดือน + ยื่นออนไลน์
- **สปส.1-03** — แจ้งเข้า/ออกงาน

### 9.4 กองทุนสำรองเลี้ยงชีพ (PVF)
- รายงาน PVF ทั่วไป
- รายงานเฉพาะ TISCO / UOB / SCB

### 9.5 อื่นๆ
- **กท.20** — รายงานเงินได้รายปี
- **สกล.3 (EWF)** — กองทุนสงเคราะห์ลูกจ้าง
- ตั้งค่ารายงานตามเดือนที่จ่าย vs วันที่จ่าย

📖 รายละเอียด: `notebooklm-docs/admin/09-government-reports.md`

---

## 10. การประเมิน KPI

### 10.1 ประเภท KPI
- **User KPI** — หัวข้อที่กำหนดเอง
- **System KPI** — ดึงจากข้อมูลในระบบ (ลา, สาย, ขาด)

### 10.2 ประเภทการให้คะแนน (4 แบบ)
1. ไม่ให้คะแนน
2. เฉพาะ Overall
3. หัวข้อย่อย + Overall
4. KPI Goal (เป้าหมายเชิงตัวเลข)

### 10.3 ขั้นตอนการประเมิน
1. **สร้าง KPI / KPI Template**
2. **สร้างการประเมิน (Create Review)**
3. **Draft** — แก้ไขรายละเอียด, เพิ่มหัวข้อ
4. **In-Process** — ให้คะแนน (พนักงาน/ผู้จัดการ/แอดมิน)
5. **Completed** — ปิดการประเมิน + แจ้งผล

### 10.4 น้ำหนักคะแนน (Two-Tier Weighting)
- น้ำหนักหัวข้อย่อย (item weight)
- น้ำหนักตามบทบาท (role weight: employee/manager/admin)

📖 รายละเอียด: `notebooklm-docs/admin/07-kpi-reviews.md`

---

## 11. ระบบติดตามผู้สมัครงาน (Add-On)

### 11.1 ขั้นตอน
1. สร้างตำแหน่งว่าง (Vacancy)
2. สร้างลิงก์รับสมัคร
3. เพิ่มผู้สมัคร (Manual / จากลิงก์)
4. กระบวนการคัดเลือก
5. รับเข้าทำงาน (Hiring)
6. ปิดตำแหน่งว่าง

📖 ดูเพิ่มเติมที่ help center: `/category/239-recruitment`

---

## 12. แอปมือถือ

### 12.1 ฟีเจอร์หลัก
- **ลงเวลาเข้า/ออก** — GPS + Face scan (Add-On)
- **ดูตารางเวลา** — ตรวจสอบเวลาทำงาน
- **ส่งคำร้อง** — ลา, OT, แก้ไขกะ, เงินคืน
- **ดูสลิปเงินเดือน** — ตามเดือน/วันจ่าย
- **ดูประกาศ** — ประกาศจากบริษัท
- **ผู้จัดการ** — ดู/อนุมัติคำร้องพนักงาน
- **Google Calendar Sync** — Add-On

### 12.2 Platform
- iOS (App Store)
- Android (Google Play)

### 12.3 การเข้าใช้
- ตั้งรหัสผ่านครั้งแรก
- รองรับ Face ID / Fingerprint

📖 รายละเอียด: `notebooklm-docs/mobile/01-mobile-app.md`

---

## 13. ClassicHR

ClassicHR เป็นรุ่นเก่าของ ByteHR ที่ยังมีลูกค้าใช้อยู่ ฟีเจอร์หลักเหมือนกันแต่ UI ต่างกัน

ฟีเจอร์หลัก:
- เพิ่มพนักงาน
- อัปโหลดวันลา
- ePortal (คำร้องออนไลน์)
- OT Request
- Severance Pay
- ไฟล์ KBank (K-Cash Connect Plus)
- กองทุนสงเคราะห์ลูกจ้าง

📖 รายละเอียด: `notebooklm-docs/classichr/01-classichr-admin.md`

---

## 14. Open API (Add-On)

ByteHR มี Open API สำหรับ integration กับระบบอื่นๆ (Add-On ซื้อเพิ่ม)

📖 ดูเพิ่มเติม: `/article/677-open-api-add-on`

---

## 15. คำถามที่พบบ่อย

### การเริ่มต้นใช้งาน
- ตั้งรหัสผ่าน — `/article/256-faqsfirstuseapplicationsetpassword`
- รีเซ็ตรหัสผ่าน — `/article/509-faqsfirstuseapplicationresetpassword`
- ดูค่าบริการรอบถัดไป — `/article/602-faqsstartusingappview-next-billing-amount`

### การคำนวณวันลา
- เฉลี่ยวันลาพนักงานใหม่ — `/article/526-faqsleavescalculationprorateleavenewjoiner`
- เฉลี่ยวันลาลาออก — `/article/693--prorate-leave-resign-calculation`
- อัปโหลดวันลา — `/article/284-faqsleavescalculationuploadleaves`
- แบบขั้นตอน/คงที่ — `/article/266-faqsleavescalculationprorateleavestep`

### ตารางเวลา
- คำนวณชั่วโมง OT — `/article/318-faqsworkhoursintimesheetsot-calculation`
- นับวันทำงาน (รายสัปดาห์) — `/article/349-faqsworkhoursintimesheetsweekly-day-count`
- แก้ไขวันทำงานต่อเดือน — `/article/328-faqsworkhoursintimesheetsedit-workdays`
- ลงชื่อก่อนเวลาเริ่มงาน — `/article/281-faqsemployeetimestampsigninbeforeshiftstart`

### เงินเดือน
- Approve Timesheet ไม่ตรงรอบ — `/article/435-faqscalculate-editpayrollsapprovetimesheetwrongperiod`
- เปลี่ยนประเภทเงินได้ — `/article/574-faqscalculate-editpayrollschangepaymenttype`
- เปลี่ยนจำนวนเบี้ยขยัน — `/article/455-faqscalculate-editpayrollschangeallowancepayment`

### คำร้อง
- ขั้นตอนการอนุมัติ (Approval Workflow) — `/article/471-faqssubmit-approve-reject-requestsapproval-workflow`
- ขอ OT กะยืดหยุ่น — `/article/437-faqssubmit-approve-reject-requestsotforflexibleshift`

### อื่นๆ
- สร้างวันหยุดนักขัตฤกษ์ซ้ำทุกปี — `/article/658-repeat-public-holiday`
- ตั้งค่าแสดงวันเกิด — `/article/1036-control-birthday-visibility-in-your-company`

📖 รายละเอียด: `notebooklm-docs/admin/10-faqs.md`

---

## Pre-publish Ledger

- **Sources checked**: help.byte-hr.com (all 4 collections, 12+ categories, ~170 articles mapped)
- **Claims made**: all claims sourced from official ByteHR help center (maturity: 🟡 Emerging — single vendor source)
- **Conflicts resolved**: none found — single authoritative source
- **Application evidence**: N/A — vendor documentation review, no hands-on testing yet
- **Codex reviewed**: no

---

## NotebookLM Documents

ไฟล์ทั้งหมดอยู่ใน `ψ/learn/byte-hr/notebooklm-docs/`:

| ไฟล์ | เนื้อหา | จำนวนบทความ |
|------|---------|-------------|
| `admin/01-preferences-and-setup.md` | การตั้งค่าระบบ | 12 |
| `admin/02-payroll.md` | การทำเงินเดือน | 12 |
| `admin/03-employees.md` | จัดการพนักงาน | 10 |
| `admin/04-requests.md` | ร้องขอ | 10 |
| `admin/05-shifts.md` | ตารางกะ | 10 |
| `admin/06-timesheets.md` | ตารางเวลา | 10 |
| `admin/07-kpi-reviews.md` | KPI | 7 |
| `admin/08-standard-reports.md` | รายงานมาตรฐาน | 10 |
| `admin/09-government-reports.md` | รายงานราชการ | 10 |
| `admin/10-faqs.md` | คำถามที่พบบ่อย | 10 |
| `mobile/01-mobile-app.md` | แอปมือถือ | 10 |
| `classichr/01-classichr-admin.md` | ClassicHR | 10 |

**รวม ~121 บทความ** — พร้อมอัปโหลด NotebookLM

### วิธีใช้กับ NotebookLM
1. ไปที่ NotebookLM (notebooklm.google.com)
2. สร้าง Notebook ใหม่ชื่อ "ByteHR Guide"
3. กด "Add Source" → "Upload" → เลือกไฟล์ .md ทั้งหมดจาก `notebooklm-docs/`
4. NotebookLM จะ index เนื้อหาทั้งหมดให้ถามตอบได้
