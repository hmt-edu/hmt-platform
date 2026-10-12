# HMT Decision Log — P1 → P5 (đợt 5.3 · phần 1)

**HMT Platform · tổng hợp mọi quyết định đến 2026-10-11 · cập nhật đợt 5.0**

> Từ P5, thứ tự ưu tiên: **`HMT_LUAT_CHO_THIET_KE.md` (luật) > `HMT_BAN_DO_MAN_HINH.md` > Design System P1–P4 > ý tưởng riêng**. Chỗ nào P1–P4 trái luật đã được sửa và ghi ở mục "Thay đổi do luật".

| Trạng thái | Nghĩa |
| --- | --- |
| **APPROVED** | Đã được người phụ trách duyệt — áp dụng |
| **PROPOSED** | Đề xuất, chưa được duyệt riêng — không triển khai trước khi duyệt |
| **OPEN DECISION** | Cần quyết định hoặc thêm thông tin |

### Cách các giai đoạn được duyệt

| Giai đoạn | Tài liệu | Trạng thái | Ghi chú |
| --- | --- | --- | --- |
| P1 · Brand Color Discovery | `P1_COLOR_DISCOVERY.md` | APPROVED — chọn Hướng A | Chọn trực tiếp trong trao đổi |
| P2 · Brand Guidelines | `HMT_BRAND_GUIDELINES.md` | APPROVED | P3 gọi là "đã được duyệt" → các mục PROPOSED trong tài liệu được coi là APPROVED; mục OPEN vẫn mở |
| P3 · UI Design System Foundation | `HMT_DESIGN_SYSTEM_SPEC.md`, `HMT_DESIGN_TOKENS.css` | APPROVED | P4 gọi là "đã được duyệt" → tương tự |
| P4 · Core Components | `HMT_COMPONENT_SPEC.md` | APPROVED | Yêu cầu bàn giao gọi là "đã duyệt" → tương tự |
| P5 · đợt 5.0 · Thành phần CRM bổ sung | `HMT_COMPONENT_SPEC.md` §11, `HMT_COMPONENT_INVENTORY.md` | **Chờ duyệt** (manifest đợt 5.0) | 21 thành phần mới + sửa P4 theo luật |

> Vì vậy nhãn "PROPOSED" còn in bên trong các tài liệu P2–P4 là nhãn **lúc viết**; trạng thái hiện hành là bảng dưới đây. Nếu cách hiểu "đã duyệt cả tài liệu" không đúng, các mục ghi "APPROVED (theo tài liệu)" cần xem lại.

### Đổi tên token giữa các giai đoạn

Brand Guidelines (P2) viết theo tên token cũ. UI Design System (P3) là chuẩn hiện hành.

| P1/P2 (cũ) | P3+ (hiện hành) |
| --- | --- |
| `logo-orange`, `ops-brand` | `--hmt-brand` (primitive `--hmt-p-logo-orange`) |
| `ops-action` / `-hover` / `-ink` | `--hmt-action` / `--hmt-action-hover` / `--hmt-on-action` |
| `ops-tint` / `ops-on-tint` | `--hmt-selected` / `--hmt-on-selected` |
| `ops-secondary` / `-tint` | `--hmt-secondary` / `--hmt-secondary-subtle` |
| `ops-bg` / `ops-surface` / `ops-surface-2` | `--hmt-canvas` / `--hmt-surface` / `--hmt-surface-subtle` |
| `ops-border` / `ops-border-strong` | `--hmt-border` / `--hmt-border-strong` |
| `ops-text-muted` / `ops-ink` | `--hmt-fg-muted` / `--hmt-fg` |
| `lms-progress` / `lms-reward` | `--hmt-lms-progress` / `--hmt-lms-reward` |
| `status-*` (P1, tham khảo) | Thay bằng `--hmt-success/warning/danger/info-*` (P3) |

---

## APPROVED

### Thương hiệu & màu (P1–P2)

| # | Quyết định |
| --- | --- |
| B-A1 | Hướng màu **A · Cam vận hành** cho HMT Platform |
| B-A2 | Màu nhận diện = cam logo **#EF6926** (từ file vector), thay giả thuyết #EF6925 |
| B-A3 | Bảng màu Hướng A, light + dark: hành động #B54515 / #F28A52; secondary #2E4A66 / #8DB0D4; neutral xám ấm; chữ chính #211C16 / #EDE8E2 |
| B-A4 | **LMS dùng Hướng A + lớp ấm**: tiến độ #0F766E / #5EC4B6, thành tích #F6C343 — **chỉ trong LMS** |
| B-A5 | Hướng B (Cam giáo dục) và C (Cam công nghệ) không chọn; màu của chúng không dùng |
| B-A6 | Logo SVG chính thức: bản chính, bản nền tối, bản trắng; bản chính cắt khung do HMT cung cấp |
| B-A7 | Bản nền tối và bản trắng được cắt khung chỉ bằng `viewBox` (nét không đổi) |
| B-A8 | Không tự thay đổi logo gốc |
| B-A9 | Không dùng màu làm phương tiện duy nhất để phân biệt trạng thái |
| B-A10 | Không mặc định cam ở mọi thành phần |
| B-A11 | Mục tiêu WCAG 2.2 AA |
| B-A12 | HMT có **5 cơ sở** |
| B-A13 | Màu trạng thái, disabled, focus xác định trong UI DS, không suy ra từ màu thương hiệu |
| B-A14 | Bản chất thương hiệu "Nghiêm túc với kết quả, tận tâm với từng học sinh"; tính cách; cảm xúc theo đối tượng *(theo tài liệu P2)* |
| B-A15 | 4 thuộc tính: Đáng tin cậy, Tận tâm, Rõ ràng, Khích lệ *(theo tài liệu P2)* |
| B-A16 | Quy tắc dùng từng màu: một nút cam mỗi vùng, không tô cam số liệu, cam logo không làm chữ nhỏ trên nền sáng… *(theo tài liệu P2)* |
| B-A17 | Cam (thương hiệu và hành động) không dùng làm màu trạng thái *(theo tài liệu P2)* |
| B-A18 | Quy tắc neutral: không đen tuyền ở dark, viền control dùng border-strong *(theo tài liệu P2)* |
| B-A19 | Thang cấp bậc chữ 32/24/20/16/14/16/13/12 *(theo tài liệu P2)* |
| B-A20 | Nguyên tắc thị giác theo sản phẩm (mật độ, lượng cam, minh hoạ hình học, không hoạt hình) *(theo tài liệu P2)* |
| B-A21 | Quy tắc logo: theo nền, cao tối thiểu 96px, bản trắng ưu tiên trên nền cam hành động *(theo tài liệu P2)* |
| B-A22 | Header dùng tên sản phẩm bằng chữ cho tới khi có logo rút gọn *(theo tài liệu P2)* |
| B-A23 | Hoạ tiết toán học (dấu cộng, lưới) cho mảng trang trí lớn *(theo tài liệu P2)* |

### UI Design System (P3) *(theo tài liệu P3)*

| # | Quyết định |
| --- | --- |
| D-A1 | Token 3 tầng (primitive `--hmt-p-*`, semantic `--hmt-*`, Tailwind `@theme`); tắt bảng màu mặc định Tailwind |
| D-A2 | `data-theme` (light/dark) + `data-product` (crm/teacher/lms) trên `<html>` |
| D-A3 | Màu trạng thái 6 token mỗi loại; success #127436 / #6CCB8F, warning #8A5A00 / #F0C04A, danger #B42318 / #FF8A80, info #1F5FBF / #8AB8F5 — 106 cặp chữ/nền đạt AA |
| D-A4 | Hành động nguy hiểm mặc định dạng viền; nền đặc chỉ trong hộp xác nhận |
| D-A5 | Focus xanh #1F5FBF / #8AB8F5, vòng 2px cách 2px |
| D-A6 | Token disabled; không dùng opacity cho disabled |
| D-A7 | Thêm sắc cam pressed #7A2E0E / #FBC4A1 (ngoại lệ Brand §3.6) |
| D-A8 | Overlay hover/pressed; surface raised/overlay; scrim |
| D-A9 | Body theo sản phẩm: CRM 14px, Teacher 16px, LMS 16px |
| D-A10 | Spacing bước 4px; radius 2/4/6/8/12/16/full; elevation 3 cấp; z-index |
| D-A11 | Mật độ: control 36/48/44px, hàng 40/56/56px, gap 12/8/16, padding thẻ 16/16/24, bo thẻ 8/12/12 |
| D-A12 | Breakpoints Tailwind + 3xl 1920px; CRM desktop-first, Teacher/LMS mobile-first |
| D-A13 | Motion 80/150/220/320ms; tắt khi reduced-motion |
| D-A14 | Quy tắc riêng CRM / Teacher Portal / LMS (DS Spec §8) |
| D-A15 | Lint chặn token `lms-*` ngoài LMS |
| D-A16 | Tự host font bằng Fontsource |

### Component (P4) *(theo tài liệu P4)*

| # | Quyết định |
| --- | --- |
| C-A1 | Gom biến thể vào component cấu hình được (Button variant, Field, StateView kind, Drawer placement, ConfirmDialog = Dialog…) |
| C-A2 | Disabled dùng `aria-disabled` (vẫn focus được) |
| C-A3 | Kiểm tra form khi blur + khi gửi; tóm tắt lỗi nhận focus; không khoá nút gửi |
| C-A4 | Lịch bắt đầu Thứ Hai; DateInput native trên mobile *(lưới tháng P4 đổi tên `MonthGrid` — xem L-10)* |
| C-A5 | Bảng tự thành thẻ dưới 640px; 25 dòng/trang |
| C-A6 | Hoàn tác (Toast) thay hộp xác nhận cho hành động hoàn tác được |
| C-A7 | Toast 5s / 8s có thao tác / lỗi không tự ẩn; tối đa 3 |
| C-A8 | ~~Điểm danh: không lưu khi còn học sinh chưa đánh dấu~~ → **thay bằng L-9** (tự lưu từng lượt + chặn nút "Tiếp"). Giữ: nút "Còn lại: Có mặt" chỉ áp cho học sinh chưa đánh dấu, có Hoàn tác |
| C-A9 | Sidebar dùng tên bằng chữ thay logo |
| C-A10 | Văn phong: nhãn nút động từ + đối tượng; lỗi nói cách sửa; xác nhận nêu đúng đối tượng |

### Chốt theo luật §8 (đợt 5.0) — đóng các câu hỏi mở

| # | Quyết định | Áp dụng trong DS |
| --- | --- | --- |
| O-1 | Font **Inter** cho giao diện và số (chữ số đều cột), **Be Vietnam Pro** cho tiêu đề | Đúng với token hiện có (phương án C) — P-1 chuyển thành APPROVED |
| O-2, O-3 | Điểm danh **mặc định để trống**; **có màu**: Có mặt nhạt, Đi muộn vàng, Vắng đậm | AttendanceSheet: Có mặt = xanh nhạt, Đi muộn = vàng nhạt, Vắng có phép / Vắng không phép = đỏ đậm (nền đặc); luôn kèm chữ + icon. Bỏ công tắc so sánh "Có mặt sẵn" và "trung tính" |
| O-7 | Học sinh **lớp 2–12** | Dữ liệu mẫu, nội dung |
| O-8 | **Bỏ "18+ năm"** khỏi giao diện cho tới khi có số chắc chắn | Không dùng trong màn hình/nội dung |
| O-10 | Xưng hô: CRM **trung tính**; cổng Giáo viên gọi **"thầy cô"**; Học tập gọi học sinh **"em"**, xưng **"HMT"**; với phụ huynh gọi **"Anh/Chị"** | Áp từ đợt 5.1 (nội dung màn hình) |
| O-12 | Biểu tượng **Lucide**, nét **1,5px**, cỡ **16/20/24** | `Icon` đọc Lucide (CDN `lucide@0.460.0`), `stroke-width:1.5`; giữ icon vẽ tạm làm dự phòng |
| O-13 | **Chỉ làm giao diện sáng**; tối để sau khi chạy thật | Token tối giữ nguyên nhưng không kiểm thử cho thành phần mới |
| O-14, O-15 | Làm **Combobox** và **DateRange** | Đã thêm (đợt 5.0) |
| O-17 | Điểm danh mất mạng: **để giai đoạn 3**; hiện trạng thái **"đang lưu / đã lưu / chưa lưu được"** | `SaveState` trong AttendanceSheet; không vẽ hàng đợi ngoại tuyến |
| O-18 | **Có "Đi muộn"** (R-DD-01) | 4 trạng thái: Có mặt · Đi muộn · Vắng có phép · Vắng không phép |
| L-1 | **Báo cáo**: tổng hợp làm trên **Looker Studio**. Trong app chỉ có tổng quan Ban giám đốc, báo cáo trễ hạn giáo viên, giờ dạy giáo viên và các danh sách theo dõi | Không làm thành phần dashboard/biểu đồ tổng hợp; chỉ RadarChart (đánh giá học sinh) + HoursDisplay |
| L-2 | **CRM ưu tiên máy tính**. Màn duyệt (hàng chờ duyệt, duyệt đơn, duyệt yêu cầu buổi, duyệt ticket) và điểm danh vận hành có thêm **bản điện thoại** | Bản điện thoại cho: ApprovalChain, SlaBadge, StatusBar (gọn), BlockingDialog, ConfirmDialog có lý do, AttendanceSheet chế độ vận hành |
| L-3 | **In ấn**: báo giá, biên nhận phiếu thu, phiếu chi | `PrintLayout` khổ A4 (A-4) |

### Thay đổi do luật — thành phần P1–P4 bị sửa (đợt 5.0)

| # | Thành phần | Trước (P4) | Sau | Căn cứ |
| --- | --- | --- | --- | --- |
| L-4 | AttendanceSheet | 3 trạng thái, lựa chọn trung tính, công tắc so sánh mặc định | 4 trạng thái có màu; mặc định trống; "Còn lại: Có mặt"; chế độ GV / vận hành (cột + lý do liên hệ) / so sánh; trạng thái lưu | R-DD-01, O-2/3/17/18 |
| L-5 | SegmentedControl | Chỉ trung tính | Thêm `emphasis` tô màu theo trạng thái (subtle / solid) + `short` | O-3 |
| L-6 | ConfirmDialog | Chỉ xác nhận | Thêm ô **lý do bắt buộc** (danh mục + ghi chú), báo lỗi tại ô, không dùng hộp thoại trình duyệt | Brief P5 "hành động cần lý do" |
| L-7 | Table | Thanh thao tác hàng loạt riêng | Dùng `BulkActionBar` chung | Gom component (C-A1) |
| L-8 | Icon | Icon vẽ tạm | Lucide 1,5px + dự phòng | O-12 |
| L-9 | Điểm danh — lưu | Không cho lưu khi còn em chưa đánh dấu (C-A8) | **Tự lưu từng lượt**; nút "Tiếp" bị **chặn** bằng BlockingDialog liệt kê các em chưa đánh dấu | R-DD-01, O-17, luật bước chặn |
| L-10 | Calendar (lưới tháng P4) | Tên `Calendar` | Đổi tên **`MonthGrid`**; tên `Calendar` dùng cho lịch buổi học (ngày/tuần/tháng) | Tránh trùng tên |
| L-11 | Dữ liệu mẫu | "₫", CS3 có lớp, mã tự đặt | "đ" (`9.504.000 đ`), CS3 = Hội sở không có lớp/phòng/học sinh, mã theo luật §2 | Luật §1, §2 |
| L-12 | Nút "Tạo" | Ví dụ Drawer và Popover (P4) có "Tạo phiếu thu" tay; Popover lọc có chip CS3 | Đổi thành "Xem công nợ"; bỏ CS3 khỏi bộ lọc. Không có nút "Tạo" cho báo giá, đơn hàng, phiếu thu, phiếu tái tục, ghi danh — chỉ sinh từ luồng (ví dụ StatusBar cơ hội có "Tạo báo giá" vì cơ hội sinh báo giá) | R-TIEN-02, luật §1 |


### Chốt sau manifest đợt 5.0 (anh/chị trả lời 11/10)

| # | Quyết định | Áp dụng trong DS |
| --- | --- | --- |
| A-1 (Q-1) | Học bù / Học bổ trợ **không gắn quỹ giờ** trên lịch | Calendar chỉ hiện nhãn loại buổi, không có số giờ |
| A-2 (Q-2) | Vận hành điểm danh dùng **đúng 4 trạng thái** như giáo viên; danh mục lý do liên hệ 4 mục là đúng | P-7 → APPROVED |
| A-3 (Q-3) | "Sắp trễ" khi còn **≤ 4 giờ** (tham số cấu hình) | P-5 → APPROVED |
| A-4 (Q-4) | Cả ba bản in (báo giá, biên nhận phiếu thu, phiếu chi) dùng khổ **A4**; vai trò ký theo P-9 | P-8 sửa thành toàn A4 → APPROVED; P-9 → APPROVED |
| A-5 (Q-5) | Mô tả từng mức thang đánh giá **lấy từ cấu hình** (làm sau) | RatingScale nhận `descriptions` từ cấu hình rubric; chữ trong thẻ ví dụ chỉ là mẫu |
| ~~A-6~~ | **Điểm BTVN là số từ 1 đến 10, giáo viên gõ vào** (thay "điểm 1–5" ở R-GV-11 trong file luật) | Thêm `ScoreInput`; HomeworkStatus dùng ô số thay cho thang bấm 1–5; dạng xem "8/10". Điểm BTVN trung bình (R-GV-12) tính trên thang 10. **File luật §5 cần sửa dòng "Đã chấm (điểm 1–5)"** **Bị thay bởi A-47 (12/10): BTVN theo thang 1–5 (R-GV-11); 0–10 chỉ cho kiểm tra đầu vào.** |
| A-7 | **Cổng Giáo viên có cả giao diện máy tính**, không chỉ điện thoại | AttendanceSheet và TaskStepper tự chuyển bố cục khi khung ≥ 760px; HomeworkStatus xếp Trạng thái + Điểm cùng hàng khi ≥ 380px; trên máy tính dùng Sidebar thay BottomNav. Cột "Thiết bị" của các màn GV-* trong bản đồ màn hình hiểu là "Cả hai (điện thoại trước)" |
| A-8 (Q-6) | Điểm BTVN **cho số lẻ** | `ScoreInput`/`HomeworkStatus` mặc định `decimals = 1`: nhận 7,5 · 8,3; quá một chữ số sau dấu phẩy báo "Tối đa 1 chữ số sau dấu phẩy". P-14 bị thay Vẫn giữ một chữ số thập phân trên thang 1–5 (4,5) — A-47. |
| A-9 (Q-7) | Anh/chị giao đề xuất | Đề xuất sửa thẳng hai file nguồn: `HMT_DE_XUAT_SUA_NGUON_Q7.md` (chờ duyệt) |
| A-10 (Q-16) | Mã = chữ cái + 6 số, đánh số toàn hệ thống: lead `LD000123`, cơ hội `CO000123`, phiếu kiểm tra `PKT000123`, ghi danh `GD000123`, phiếu tái tục `TT000123`. Lịch hẹn không có mã. Mã cũ (ví dụ `LEAD-2609-0001`) hiện nhỏ dưới mã mới | Đã sửa mọi thẻ (part 4, 5.2, 5.3) |
| A-11 (Q-17) | Hình thức test: Offline, Online. Cấp độ đề: Cơ bản, Nâng cao (danh mục). Kết quả: điểm 0–10 (một chữ số lẻ), nhận xét, trình độ S/A/B/C, phân loại CB/NC, lớp đề xuất (không bắt buộc), đính kèm đề, bài làm, phiếu đánh giá | TS-15 thêm Cấp độ đề; TS-17, GV-15 giữ như vẽ |
| A-12 (Q-18) | Giai đoạn lead C1–C4 đổi tự do hai chiều, mọi lần đổi ghi lịch sử. C4D "Tạo cơ hội thành công" do hệ thống tự gắn khi tạo cơ hội, không có trong lựa chọn. Chỉ cơ hội chặn lùi | TS-01, TS-02 |
| A-13 (Q-19a) | Giờ tặng tính vào trần chiết khấu 20%, quy ra % = giờ tặng ÷ giờ mua (4/48 = 8,3%). Ô tổng chiết khấu trên dòng hiện cả phần % và phần giờ tặng đã quy đổi. Tặng tài liệu, dịch vụ (dòng 0 đ) là chính sách quà tặng riêng, không tính vào trần | BH-05 (dòng 1: 10% + 8,3% = 18,3%), BH-02, BH-03, CH-04, PrintLayout, K06 |
| A-14 (Q-19b, c) | Mã loại gói: `LC` lớp chung, `VIP` VIP 1:1 và 1:2, `VNN` VIP nhóm nhỏ, `KR` kèm riêng, `DV` dịch vụ (theo tháng), `TL` tài liệu (theo bộ); bỏ `HRD`. Mã gói không chứa hình thức (`LC-TOAN-K09`, nhóm khối `VIP-TOAN-K03K07`). Một gói hai giá Offline/Online, hình thức chọn trên dòng đơn; giá trống = không bán (VNN, KR chỉ Offline). DV, TL không có quỹ giờ, không sinh ghi danh | CH-01, CH-03, VersionedConfig, K10; mọi mã `…-OFF/-ON` đã bỏ |
| A-15 (Q-20) | Toán Đại + Hình là một dòng đơn gói TOAN; trên dòng chọn tối đa hai lớp (DAI, HINH), mỗi lớp một ngày vào → hai dòng xếp lớp của cùng một ghi danh, chung một quỹ giờ | BH-05, BH-08 giữ như vẽ; sửa ghi chú |
| A-16 (Q-21) | Mã khoản tiền vào theo dạng chứng từ có mã cơ sở `KTV-CS1-2610-0221`; khoản đảo cùng dãy số, số tiền âm, ghi "Đảo của KTV-CS1-2610-0198" | TC-05, TC-08, TC-09 |
| A-17 | Gộp QT-15, TC-10, TC-11 vào đợt Chăm sóc khách hàng (đợt 5.4 phần 3) | |
| A-18 (Q-26) | Huỷ buổi được cho tới khi Done, kể cả sau khi đã chốt danh sách; người huỷ: CSKH, Trưởng cơ sở (giáo viên không có nút). Huỷ thì dòng điểm danh đã sinh bị vô hiệu. Buổi Done không huỷ, sai thì sửa qua BUOI-14 | BUOI-04, BUOI-02 |
| A-19 | Thêm học thử: cơ hội khác khối chỉ cảnh báo, không chặn (em học vượt khối) | BUOI-06 |
| A-20 (Q-28) | Học thử tối đa 2 buổi mỗi cơ hội (tham số `hoc_thu_toi_da`), vượt thì chặn kèm lý do. Học thử không tính vào sĩ số, không chiếm chỗ trống; buổi hiện "Sĩ số 12/15 · học thử 1"; vượt sĩ số tối đa chỉ cảnh báo | BUOI-06, BUOI-02 |
| A-21 (Q-27) | Yêu cầu củng cố bắt buộc mục "Phụ huynh đã đồng ý": kênh (gọi điện, Zalo, trực tiếp), ngày, người xác nhận; chưa tick thì Gửi duyệt bị chặn kèm lý do; Trưởng cơ sở duyệt như cũ | BUOI-08 |
| A-22 (Q-8) | Admin thấy và làm được mọi màn CRM ở mọi cơ sở (không chỉ đọc), menu đầy đủ; thêm AD vào vai trò của mọi màn CRM. Ô khoá theo luật trong ma trận quyền vẫn giữ (xem Q-33). | AppShell `menuFor`, QT-04, QT-05, RoleMenu, README các màn CRM |
| A-23 (Q-9) | Ô chọn cơ sở khi xem dữ liệu nghiệp vụ không có CS3. Màn Người dùng (QT-01, QT-02, QT-03) có CS3 vì nhân viên Hội sở thuộc CS3. Phiếu chi ghi theo cơ sở của học sinh, không ghi CS3. | AppShell, QT-01/02/03, TC-10, TC-11 |
| A-24 (Q-10) | Cổng Phụ huynh dùng khuôn K02, 5 tab: Trang chủ, Kết quả, Lịch, Học phí, Đề nghị; ô chọn con ở đầu trang (P-17 thành quyết định). | Đợt Phụ huynh |
| A-25 (Q-11) | QT-10 không có cột CS3. | QT-10 |
| A-26 (Q-12) | Tham số theo HMT_DANH_MUC_VA_THAM_SO.md mục 2: mặc định, khoảng cho phép, cột Ghi đè theo cơ sở. Tiền, giá, chiết khấu, đăng nhập chỉ có giá trị chung. | QT-09 |
| A-27 (Q-13) | Đăng nhập sai 10 lần liên tiếp thì tạm khoá 15 phút; cả hai là tham số nhóm Đăng nhập (3–20 lần; 5–1.440 phút). | QT-09, CHUNG-01, CHUNG-06, QT-01 |
| A-28 (Q-14) | Đăng nhập học sinh có Turnstile. | CHUNG-06 |
| A-29 (Q-15) | 30 danh mục theo HMT_DANH_MUC_VA_THAM_SO.md mục 1, ba loại khoá (Khoá, Khoá mục cha, Mở), giá trị nạp sẵn là dữ liệu thật. Không có C3K; C4D do hệ thống tự gắn; L5C–L5O nối lý do huỷ test; nguồn lead 3 cấp. | QT-06, QT-07, TS-01/02/03/08/11/17/19, BUOI-03/04/10/11, CS-04, TC-02/05, CHUNG-15, AttendanceSheet |
| A-30 (Q-22) | Thêm trạng thái ghi danh **Đã xếp lớp** giữa Chờ xếp lớp và Đang học: có lớp nhưng chưa có buổi Done, hiện ngày vào lớp. Hàng chờ xếp lớp (GD-06) chỉ gồm ghi danh Chờ xếp lớp. | GD_STATUS, GD-01, GD-02, GD-06, GD-03, K03 |
| A-31 (Q-23) | Trùng giờ khi xếp lớp là chặn: trùng với bất kỳ lớp nào em đang học (kể cả lớp của ghi danh khác) thì lớp hiện nhưng không chọn được, kèm lý do. | GD-03, BH-08 |
| A-32 (Q-24) | Ngày nghỉ áp dụng mọi cơ sở hoặc chọn từng cơ sở; mặc định mọi cơ sở. | QT-14 |
| A-33 (Q-25) | Lý do điều chỉnh giờ theo danh mục 25: Sửa sai danh sách/điểm danh, Bù giờ do lỗi trung tâm, Tặng giờ chăm sóc (cần duyệt), Chuyển dữ liệu từ hệ thống cũ, Khác (bắt buộc ghi chú). | GD-05 |
| A-34 (Q-29) | Hoàn toàn bộ theo R-TIEN-28 (giá gốc, trừ phí 10%). Hoàn một phần: giờ hoàn × giá sau chiết khấu, trừ phí 10%. Chuyển phí: giờ mua còn lại × giá sau chiết khấu, không trừ phí (tiền vẫn ở HMT). | CS-05, CS-10 (Hồ Minh Tuệ: 27 × 198.000 = 5.346.000 đ; đóng thêm 2.574.000 đ) |
| A-35 (Q-30) | Giai đoạn phiếu tái tục: L1 Chờ tái tục · L2 Đã liên hệ · L3 Đang tư vấn · L4 Đang cân nhắc · L5 Không tái tục (kết thúc, bắt buộc lý do) · L6 Đồng ý tái tục · L7 Dự thu · L8 Hoàn thành tái tục. | TT-01, TT-02, QT-07 |
| A-36 (Q-31) | Cờ rủi ro đếm buổi vắng trong 30 ngày gần nhất; khoảng 30 ngày là tham số (7–180). | QT-09, TT-01, TT-02 |
| A-37 (Q-32) | Một Kế toán vừa lập vừa duyệt phiếu chi được (ticket hoàn tiền đã qua Trưởng cơ sở và Kế toán); mọi thao tác ghi nhật ký. | TC-11 |
| A-38 (prompt 5.5) | Cổng Giáo viên có **hai bố cục dùng chung dữ liệu và thành phần**: điện thoại làm từng bước, từng em, một tay; laptop nhìn cả lớp trên một bảng, nhập bằng bàn phím. Đổi máy giữa buổi vẫn làm tiếp (lưu tự động). Chữ 16, xưng "thầy cô". Mọi màn GV trong bản đồ đổi thiết bị thành "Cả hai"; thêm khuôn K14 | Bản đồ mới `HMT_BAN_DO_MAN_HINH (1).md`; GV-01…GV-16, GV-18, HT-04, HT-09 |
| A-39 (Q-33) | Admin **được** duyệt phiếu thu, đảo khoản tiền và duyệt yêu cầu buổi để làm thay khi người phụ trách vắng; lịch sử ghi "Admin duyệt thay". Trưởng cơ sở vẫn không duyệt tiền | QT-05, TC-05, TC-09, BUOI-10 |
| A-40 (Q-34) | Danh mục 24 "Lý do từ chối" thêm cột **Áp dụng cho** (báo giá, đơn, phiếu thu, lớp, ticket, yêu cầu buổi), BH-04 và LOP-02 lọc theo loại. Thêm danh mục **31 Lý do đảo khoản** (Nhập sai số tiền, Trùng phiếu, Sai đơn hoặc sai khách, Khác) và **32 Lý do khoá tài khoản** (Nghỉ việc, Dừng học, Tạm nghỉ, Nghi lộ mật khẩu, Khác). Chọn "Khác" bắt buộc ghi chú | QT-06, QT-07, BH-02/BH-04, K08, LOP-02, TC-05, TC-09, QT-02, CHUNG-26, BUOI-04, BUOI-10 |
| A-41 (Q-35) | Nhóm con khiếu nại theo R-CS-04: Chương trình học (nội dung khó/dễ, tiến độ, không bám chương trình trên trường, tài liệu) · Giáo viên (thái độ, chuyên môn, đi muộn/nghỉ dạy, thay giáo viên nhiều, nhận xét/chấm bài) · Phương pháp giảng dạy (cách giảng khó hiểu, BTVN nhiều/ít, kiểm tra đánh giá, quản lý lớp) · Tư vấn tuyển sinh (không đúng cam kết, thái độ, chậm phản hồi, xếp lớp sai trình độ) · Vận hành (đổi lịch đột xuất, phòng học/cơ sở vật chất, sĩ số, đưa đón/an toàn, thông báo chậm) · Chăm sóc (không phản hồi, thái độ, không gửi nhận xét/báo cáo) · Khác | QT-07, CS-03, CS-04 |
| A-42 (Q-36) | Giữ hai định nghĩa (học sinh đang học; tỉ lệ tái tục = L8 ÷ (L8 + L5)). Thêm số **Đang bảo lưu** hiện riêng, không cộng vào học sinh đang học | BC-01 |
| A-43 (Q-37) | **Đơn giá ghi nhận = tiền dòng đơn ÷ (giờ mua + giờ tặng)**, chia đều mọi giờ (giờ tặng không 0 đ). Buổi huỷ có tính phí vẫn ghi nhận. Học bù, bổ trợ 0 đ. Tính cho cơ sở nơi buổi Done | BC-01, BC-03 |
| A-44 (Q-38) | Giờ dạy: mọi loại buổi thực dạy (Chính, Củng cố, Học bù, Học bổ trợ), buổi Done, theo thời lượng, cho người dạy thật, cả giáo viên và trợ giảng; buổi huỷ không tính. Nút **Chốt tháng** ở BC-09 cho Kế toán, Admin; đã chốt giữ nguyên, sửa buổi thì chênh lệch đưa vào tháng sau | BC-09, GV-16 |
| A-45 (Q-39) | Dừng học qua ticket đề nghị nhóm con Dừng học. Hai lựa chọn: hoàn tiền (R-TIEN-28) hoặc giữ thành số dư khách hàng (giờ còn lại × giá sau chiết khấu, không trừ phí, không hết hạn). Giờ tặng còn lại bị huỷ. Không có "giữ nguyên giờ". CS-14 bỏ chữ "cần chốt" (sửa bản đồ) | CS-02, CS-14 |
| A-46 (prompt 5.6) | Cổng Học tập cho học sinh lớp 2–12, **điện thoại trước**. Lớp màu ấm LMS (tiến độ, phần thưởng) **chỉ dùng trong cổng này**. Gọi học sinh là "em", xưng "HMT"; với phụ huynh gọi "Anh/Chị". HT-07 có **hai chỉ số BTVN tách riêng** (tỉ lệ làm bài, điểm TB). HT-01 vẽ **hai bản**: học sinh nhỏ (lớp 3) và học sinh lớn (lớp 11) | HT-*, PH-*, GV-17, GV-18 |
| A-47 (sửa 12/10) | **Điểm BTVN theo thang 1–5 (R-GV-11)**, một chữ số thập phân (4,5); điểm BTVN trung bình dạng "4,2/5". Thang 0–10 chỉ dùng cho kiểm tra đầu vào (GV-15). `HomeworkStatus`, `ScoreInput` mặc định 1–5. Dữ liệu 9A2 Buổi 3: Ánh 4 · Đức 3 (Làm chưa xong) · Kiệt 4,5 · Nam 4 · Thư 5 · Vân 4 · My 3 (Làm chưa xong) · Long 3,5 → TB 3,9/5 | GV-08, GV-18, HT-05, HT-07, PH-02, HomeworkStatus, K14, KH-05 |
| A-48 (sửa 12/10, Q-10) | Khung cổng phụ huynh 5 tab: **Trang chủ, Kết quả, Lịch, Học phí, Đề nghị**; Tài khoản ở menu ảnh đại diện trên đầu trang. PH-05 Lịch vẽ mức B | StudentShell `portal="ph"`, PH-01…PH-05 |
| A-49 (Q-40) | Phần thưởng = sao và chuỗi bài nộp đúng hạn; không điểm thưởng, không xếp hạng. **Tắt được theo cơ sở** bằng công tắc tính năng (QT-10 · "Cổng Học tập · Phần thưởng") | HT-01, HT-04, QT-10 |
| A-50 (Q-41) | Nộp sau hạn nhưng trước khi chấm: chấm bình thường kèm **nhãn "Nộp muộn"** (nhãn, không phải trạng thái). Tới lúc chấm chưa nộp: giáo viên chọn Nộp sau hoặc Không làm. Nộp lại không giới hạn trước khi chấm; chấm rồi thì khoá, trừ khi giáo viên mở lại. Tắt "Nhận bài muộn" thì quá hạn không nộp được | GV-17, GV-18, HT-03, HT-04 |
| A-51 (Q-42) | Bản học sinh nhỏ cho lớp 2–5 | HT-01, StudentShell `young` |
| A-52 (Q-43) | Hài lòng 5 mức: 4–5 đóng "hài lòng", 1–3 đóng "không hài lòng". "Chưa đồng ý phương án" → Đang xác minh. Hạn phụ huynh xác nhận 3 ngày là tham số mới `cs_han_ph_xac_nhan_ngay`; quá hạn thì nhắc CSKH gọi xác nhận, không tự đóng. Hạn mở lại 7 ngày dùng tham số "Mở lại khiếu nại trong" | PH-04, QT-09 |
| A-53 (Q-44) | Tối đa 10 MB mỗi tệp, 20 trang. Ảnh tự nén trên máy trước khi tải (cạnh dài khoảng 2.000px); HT-04 ghi "Ảnh sẽ được nén để tải nhanh" | HT-04 |
| A-54 (P6, 12/10) | Đồng ý kết quả P6. Sửa mọi lỗi Cao, Trung bình; vùng bấm sửa ở thành phần gốc. Lỗi Thấp: **bỏ** dòng "tên rút gọn so với bản đồ" (giữ tên hiện tại, mã màn đúng, tiêu đề rõ nghĩa) và dòng "màu viết cứng mã QR" (**ngoại lệ**: mã QR giữ đen trên nền trắng); các lỗi Thấp khác sửa | Mọi màn |
| A-55 (Q-45) | Quỹ giờ còn quy ra tiền = giờ còn × đơn giá ghi nhận của từng ghi danh (cùng cách tính doanh thu ghi nhận) | BC-01, BC-04 |

### Đợt 5.1 · phần 1 — điều hướng (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-15 | Menu CRM 9 nhóm theo yêu cầu; vị trí các mục bản đồ không nói rõ: **Phiếu tái tục** (TT-01) ở *Chăm sóc khách hàng*; **Ngày nghỉ lễ** (QT-14), **Người duyệt ticket** (QT-15) ở *Cấu hình*; **Tổng quan Ban giám đốc** (BC-01) ở *Báo cáo*; một mục **"Báo cáo trên Looker"** mở Looker Studio cho BC-02…07, BC-10; *Đào tạo* chia 3 nhóm con Ghi danh · Lớp · Buổi học | Thẻ NavMap |
| P-16 | Tab **Tài khoản** cổng Giáo viên gồm: Hồ sơ (CHUNG-13), Giờ dạy của tôi (GV-16), Ticket lớp tôi (GV-14), Đổi cổng (CHUNG-25) | GV-01 chỉ ghi tên tab |
| P-17 | Cổng **Phụ huynh** (GĐ4): khuôn K02, 5 tab Trang chủ · Kết quả · Lịch · Học phí · Đề nghị, ô chọn con ở đầu trang | Bản đồ chưa có khung PH — Q-10 |
| P-18 | Ô **chọn cơ sở** trên thanh trên (AD, KT): Tất cả cơ sở · CS1 · CS2 · CS4 · CS5 — không có CS3 | Q-9 |
| P-19 | Quyền thấy mục menu lấy **đúng cột Vai trò** của màn danh sách trong bản đồ; "(BM xem)" = chỉ xem | Bảng RoleMenu: AD 30 · BM 32 · SA 18 · CS 26 · KT 16 mục |

### Đợt 5.2 — Chung + Quản trị (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-20 | Khuôn dùng lại thành component: **AppShell** (K01), **AuthLayout** (K11), **PageHeader**, **StatTile** (K09), **TurnstileSlot**, **OtpInput**, **PasswordInput** + **PasswordRules** | Phần 2 đợt 5.1 (vẽ riêng 13 khuôn) chưa làm; các khuôn K01, K03, K06, K07, K08, K09, K10, K11 đã có qua màn 5.2 |
| P-21 | Menu CRM: nhóm thu gọn được, nhóm chứa mục đang mở tự mở; thu gọn còn biểu tượng nhóm; điện thoại: menu trong ngăn kéo trái | CHUNG-10 |
| P-22 | Đăng nhập: nút Đăng nhập chỉ dùng được khi Turnstile báo "Đã xác minh"; lỗi sai thông tin chung một câu; lỗi máy chủ có mã lỗi để báo IT | CHUNG-01, CHUNG-06 |
| P-23 | Học sinh quên mật khẩu: màn hướng dẫn liên hệ CSKH kèm số hotline từng cơ sở (số trong thẻ là mẫu) | CHUNG-06 |
| P-24 | Thiết lập hai bước 3 bước chỉ đi tới; 10 mã dự phòng, phải tích "Tôi đã lưu" mới hoàn tất | CHUNG-03 |
| P-25 | Ma trận quyền: ô "Khoá theo luật" (BM không duyệt tiền; phiếu thu chỉ KT duyệt; yêu cầu buổi chỉ BM duyệt; chỉ KT đảo khoản); ô "Sinh từ luồng" ở cột Tạo của báo giá, đơn, phiếu thu, ghi danh; lưu = phiên bản mới + ngày hiệu lực + lý do | QT-05 |
| P-26 | Danh mục: thêm mục nhập Mã một lần (không đổi sau), đổi thứ tự bằng kéo hoặc nút mũi tên, Ngừng có hộp thoại nêu số bản ghi đang dùng | QT-07 |
| P-27 | Tham số: sửa trong ngăn kéo phải; giá trị chung + ô ghi đè CS1, CS2, CS4, CS5 (không có CS3); bắt buộc lý do; tab lịch sử | QT-09 |
| P-28 | Trạng thái tài khoản học sinh thêm "Chưa cấp" và "Chờ đổi mật khẩu" bên cạnh Đang dùng · Khoá · Tạm khoá | QT-13 |

### Đợt 5.3 · phần 1 — Tuyển sinh, Kiểm tra đầu vào, Khách hàng (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-29 | Cơ hội: bấm bước phía sau trên thanh giai đoạn, bấm "Tạo phiếu kiểm tra" hoặc kéo thẻ kanban sang L5+ khi thiếu tên/năm sinh → BlockingDialog có nút đến đúng ô | TS-07, TS-08 |
| P-30 | Lead đã có cơ hội: hai lựa chọn "Gộp vào cơ hội cũ" (mặc định) / "Vẫn tạo mới" (bắt buộc tích xác nhận lần hai) | TS-06 |
| P-31 | Trùng số điện thoại khi tạo lead: cảnh báo ngay dưới ô, ba nút Gắn vào hồ sơ có sẵn · Mở lead cũ · Vẫn tạo mới | TS-03, TS-14 |
| P-32 | Lịch hẹn: Hoàn thành, Huỷ một bấm + Hoàn tác trong Toast; danh sách chia Quá hạn / Hôm nay / Sắp tới; màu theo loại hoạt động (danh mục) kèm chữ | TS-11 |
| P-33 | Phiếu kiểm tra: Huỷ, Từ chối là nhãn cuối thanh trạng thái (không phải bước); "Đưa về Nháp" bắt buộc lý do | TS-17 |
| P-34 | Cổng Giáo viên GĐ1 chỉ có danh sách phiếu test được giao + màn chấm (không có thanh dưới) | GV-15 |
| P-35 | Hồ sơ học sinh 360°: tab Tổng quan gom quỹ giờ, lớp đang học (Đại + Hình từ khối 7), điểm danh gần nhất; tab Điểm danh, Nhận xét (biểu đồ tiêu chí + lời nhắn đã/chưa gửi), BTVN, Ticket, Tài khoản học tập | KH-05 |
| P-36 | Calendar nhận `types` để dùng cho lịch hẹn (loại hoạt động) ngoài loại buổi | Thay đổi DS nhỏ |

### Đợt 5.1 · phần 2 — khuôn K01–K13 (làm bù 12/10, đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-47 | Năm trạng thái chuẩn cho mọi khuôn: Có dữ liệu, Trống, Đang tải, Lỗi (kèm mã lỗi để báo IT + Thử lại), Không có quyền (không lộ dữ liệu + Về trang chủ). Khuôn nào không có trạng thái Trống thì ghi rõ (K11, K13); K07, K08, K11 dùng tên trạng thái riêng | Thẻ K01–K13 |
| P-48 | Quy ước vùng: viền xám = **cố định** (giống nhau ở mọi màn dùng khuôn), viền xanh = **thay đổi** (mỗi màn tự điền); bật bằng nút "Hiện vùng" trên thẻ, không có trong app thật | `[data-zone]` trong bundle.css |
| P-49 | Đang tải dùng khung xám đúng hình nội dung (menu, thẻ số, hàng bảng, cột kanban), không dùng vòng xoay toàn trang; riêng nút đang xử lý dùng nút bận | K01, K03, K04, K09, K12 |
| P-50 | Biểu mẫu: ≤ 6 ô dùng ngăn kéo, dài hơn dùng trang; Lưu nháp không kiểm ô bắt buộc; bấm Lưu khi còn lỗi hiện Alert liệt kê ô sai | K07 |
| P-51 | Tác vụ từng bước lưu tự động sau mỗi lần chọn, không có nút Lưu; mất mạng giữ dữ liệu trên máy và tự gửi lại (Alert vàng, không chặn) | K12 |
| P-52 | Không có quyền trong hộp thoại: nút mở hộp thoại bị ẩn nên hộp thoại không hiện; mở link ngoài quyền thì ra trang CHUNG-16 | K08 |

### Đợt 5.3 · phần 2 — Bán hàng, Thu chi, Cấu hình bán hàng (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-37 | Đơn hàng: bảng dòng đặt cả chiều rộng, khung trao đổi (Chatter) đặt **dưới** thay vì cột phải, vì bảng dòng có 7 cột và mã lớp dài | BH-05. Các bản ghi khác (BH-02, TC-02) giữ Chatter cột phải |
| P-38 | Trình đơn bị chặn: hộp thoại chỉ liệt kê đúng chỗ thiếu theo dạng "Dòng N · Tên học sinh · Tên ô: lý do", mỗi dòng có nút "Đến ô"; ô thiếu tô đỏ trong bảng. Không chọn lớp **không** chặn trình (ghi danh vào Chờ xếp lớp) | BH-05, R-GD-06 |
| P-39 | Chiết khấu vượt trần 20% (tính cả giờ tặng quy đổi, A-13) là **cảnh báo** (vàng, vẫn trình được), Trưởng cơ sở duyệt riêng; không phải chặn | BH-05, BH-07, CHUNG-15, R-TIEN-29 |
| P-40 | Đơn bị từ chối: nhãn cuối "Bị từ chối · về Nháp" trên thanh trạng thái, Alert đỏ có người, giờ, lý do; nút chính "Sửa và trình lại" | BH-05, TC-02 |
| P-41 | Đơn đã duyệt: Alert "đã duyệt và khoá", biểu tượng khoá cạnh trạng thái trong danh sách; nút Huỷ đơn mờ kèm lý do "phải qua ticket hoàn tiền" khi đơn đã có tiền | BH-05, BH-06, R-CS-02 |
| P-42 | Kế toán duyệt phiếu thu: hộp thoại tóm tắt chứng từ + khối "Duyệt sẽ" (khoản tiền vào, đơn sau khi duyệt, giờ cấp, ghi danh, giờ tặng); "Đã qua N buổi" là Alert vàng không chặn | TC-05, R-TIEN-21, R-TIEN-27 |
| P-43 | Trưởng cơ sở không có nút duyệt tiền ở bất kỳ màn nào: CHUNG-15 bản Trưởng cơ sở không có phiếu thu, đảo khoản; TC-04, TC-05 chỉ Kế toán | Luật §1 |
| P-44 | Chọn lớp cho dòng đơn: lớp đã có buổi → chọn trong 3 buổi sắp tới (radio); lớp chưa có buổi → ô ngày, kiểm đúng thứ có lịch và không trước khai giảng; lớp hết chỗ hiện nhưng không chọn được, kèm lý do; nút phụ "Để trống (Chờ xếp lớp)" | BH-08, R-GD-08 |
| P-45 | Số điện thoại hotline cơ sở trên bản in đổi sang dạng giả `0900 100 xxx` cho đúng quy định dữ liệu mẫu | BH-03, TC-07, PrintLayout, CHUNG (part 6) |
| P-46 | Chip không co và không xuống dòng (`flex: none; white-space: nowrap`), để hàng chip cuộn ngang trên điện thoại | Thay đổi DS nhỏ; CHUNG-15 bản điện thoại |

### Đợt 5.4 · phần 1 — Ghi danh, Lớp học, Cấu hình đào tạo (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-53 | Ghi danh: thanh trạng thái Chờ xếp lớp → Đang học → Hoàn thành, các tình trạng Bảo lưu, Chuyển lớp, Dừng, Hoàn phí là nhãn cuối; **không có nút** trên thanh vì tình trạng do hệ thống, ticket đổi | GD-02 |
| P-54 | Quỹ giờ đặt đầu bản ghi ghi danh (HoursDisplay + đơn, đã mua, hình thức học thuộc ghi danh); tab Dòng xếp lớp · Sổ giờ (5 dòng gần nhất + link GD-04) · Ticket | GD-02 |
| P-55 | Nút trên ghi danh: Xếp lớp (CSKH, Trưởng cơ sở), Điều chỉnh giờ (Trưởng cơ sở, Admin), Tạo ticket, Tạo phiếu tái tục thủ công (ẩn khi đã có phiếu); Kế toán chỉ xem | GD-02, GD-07 |
| P-56 | Xếp lớp: hai khối Đại số / Hình học, mỗi lớp là một thẻ chọn có lịch, sĩ số, kiểm đúng môn-loại-cơ sở; lớp không hợp lệ vẫn hiện nhưng khoá kèm lý do; ngày vào chọn bằng chip buổi sắp tới; khối "Sau khi xếp" báo số dòng xếp lớp và ngày hết giờ dự kiến | GD-03 |
| P-57 | Sổ giờ: mỗi dòng có ngày, nguồn (Phiếu thu, Giờ tặng, Buổi, Điều chỉnh), chi tiết + người ghi, thay đổi (+ xanh, − chữ thường), số dư chạy; lọc theo nguồn; không có nút sửa, xoá | GD-04 |
| P-58 | Lớp: thanh bước duyệt Nháp → Đã trình → Đã xác nhận → Đã duyệt → Đã đóng (Từ chối là nhãn cuối, về Nháp); trường Vận hành hiện riêng dưới tiêu đề; Huỷ lớp mờ kèm lý do khi có buổi Done, bấm Đóng lớp mở hộp thoại chặn liệt kê em còn giờ | LOP-02, LOP-06 |
| P-59 | Thời khoá biểu: nhóm theo thứ, mỗi khung một hàng (giờ, giáo viên, trợ giảng, phòng), nút Thêm khung theo thứ và Thêm thứ; cột phải xem trước số buổi, ngày kết thúc (đã trừ ngày nghỉ) và số cảnh báo | LOP-04 |
| P-60 | Lịch tuần: trùng phòng, trùng giáo viên là cảnh báo có chữ trên buổi + Alert đầu trang + chip "Chỉ buổi trùng" | LOP-08 |
| P-61 | `Calendar` / `EventChip`: `conflict` nhận `true \| "room" \| "teacher" \| "both"` → "Trùng phòng", "Trùng giáo viên", "Trùng phòng, giáo viên" | Thay đổi DS nhỏ |
| P-62 | Thêm ngày nghỉ khi đã sinh buổi: hộp thoại liệt kê buổi bị ảnh hưởng, ngày kết thúc cũ → mới, rồi mới lưu | QT-14 |
| P-63 | Mẫu dữ liệu lớp CS1 2026–2027 dùng chung (8A1 Đại/Hình, 9A2 Đại/Hình, 9S1 Đại, 6B2, 7A1 Hình, 7A2 Đại, lớp riêng); đã sửa các thẻ trước cho khớp (giờ 9A2 Đại 19:15, số buổi 8A1, GV 8A1 Hình, sổ giờ KH-05) | K02, K03, K05, BH-08, CHUNG-15, KH-05 |

### Đợt 5.4 · phần 2 — Buổi học (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-64 | Buổi học: thanh Nháp → Đã chốt → Done (Done có biểu tượng khoá), Huỷ có/không tính phí là nhãn cuối; nút theo bước: Nháp (Chốt danh sách, Thêm học thử, Dời, Đổi giáo viên buổi, Huỷ), Đã chốt (Điểm danh vận hành, Thêm học thử, Nhắc giáo viên khi quá hạn), Done (Trưởng cơ sở: Sửa điểm danh) | BUOI-02 |
| P-65 | Chưa Done: Alert nêu từng việc giáo viên còn thiếu (điểm danh, nhận xét, BTVN buổi trước) + SlaBadge hạn hoàn tất; xanh khi còn hạn, vàng khi quá hạn | BUOI-02, BUOI-12 |
| P-66 | Tab "Không vào danh sách" liệt kê từng em kèm lý do (chưa tới ngày vào, bảo lưu, không đủ giờ ngoài hạn mức) | BUOI-02 |
| P-67 | Huỷ buổi: một hộp thoại cho cả hai trường hợp; ô Người huỷ quyết định có hiện lựa chọn phí; xem trước hệ quả (buổi thêm cuối lịch, ngày kết thúc mới / giờ bị trừ / buổi bù) trước khi xác nhận | BUOI-04 |
| P-68 | Yêu cầu buổi: nêu rõ "trừ giờ" / "không trừ giờ" ngay dưới loại; chỉ Trưởng cơ sở có Duyệt, Từ chối | BUOI-07…10 |
| P-69 | Điểm danh vận hành trong ngày: chọn nhiều em, ghi lý do liên hệ hàng loạt từ thanh thao tác hàng loạt | BUOI-11 |

### Đợt 5.4 · phần 3 — Chăm sóc khách hàng, Tái tục, QT-15, TC-10, TC-11 (đề xuất, chờ duyệt)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| P-70 | Ticket đề nghị: thanh 6 bước chỉ đi tới, Từ chối / Khách huỷ là nhãn cuối; khối Chuỗi duyệt (ApprovalChain) và khối Hạn xử lý (phản hồi, xử lý xong) luôn hiện; nút Thực hiện đổi theo nhóm con và vai trò | CS-02 |
| P-71 | Khiếu nại quá hạn: Alert đỏ "đã tự nâng cấp" + nhãn phụ trên thanh trạng thái; mức độ là Badge có chữ; đóng ghi mức hài lòng 1–5; mở lại trong 7 ngày | CS-03 |
| P-72 | Bảng tính hoàn hiện từng bước (đã đóng → trừ giờ đã học theo giá gốc → còn lại → phí xử lý → hoàn), giờ tặng nói rõ không hoàn; bảng tính khoá theo lúc lập phiếu chi | CS-05, TC-11 |
| P-73 | Chuyển phí dùng cùng cách tính giá trị còn lại như hoàn tiền nhưng không trừ phí xử lý; thiếu thì đơn mới thu thêm, dư thì chọn giữ số dư hoặc hoàn | CS-10 (chờ Q-29) |
| P-74 | Duyệt ticket trên điện thoại: tấm trượt từ dưới, hai nút to cả hàng | CS-08 |
| P-75 | Nhận xét chờ gửi: mỗi lời nhắn là một thẻ có Sao chép, Xuất ảnh, Đánh dấu đã gửi | CS-16 |
| P-76 | Đổi lịch học là hộp thoại chọn cách, chuyển sang đúng màn thực hiện (BUOI-05, CS-06, BUOI-07) | CS-11 |
| P-77 | Mẫu dữ liệu: sửa cho khớp — ApprovalChain (P4) dùng đúng Trưởng cơ sở CS1/CS5; phiếu chi mẫu đổi sang Bùi Thanh Hà (đã Hoàn phí); ticket gia hạn bảo lưu là Lương Thảo Nhi | part4, CHUNG-15, GD-02, LOP-02 |
| P-78 | Thành phần mới **LineChart**: 1–4 chuỗi, một trục y, chú giải + nhãn cuối đường, chuỗi 2+ nét đứt, hộp số khi rê chuột/phím mũi tên, bảng ẩn. Màu cat-1, cat-3 (đã chạy bộ kiểm tra bảng màu: đạt; cat-3 tương phản 2,7:1 nên luôn kèm nhãn + bảng số) | BC-01; dự kiến GV-16, HT-07, PH-02 |
| P-79 | Màn báo cáo của Admin, Kế toán lọc cơ sở bằng ô chọn cơ sở trên thanh trên (không thêm ô thứ hai trong trang); Trưởng cơ sở thấy dòng chữ "Cơ sở: CS1 … (cơ sở của bạn)". Helper `Shell` nhận `campus`, `onCampus` | BC-01, BC-08, BC-09 |
| P-80 | BC-01: thẻ tiền hiện "1.208,4 triệu đ", số đầy đủ ở dòng phụ; link ra Looker ghi "Xem trên Looker" kèm mã màn; link ngoài vai trò bị ẩn (Trưởng cơ sở không thấy BC-04) | BC-01 |
| P-81 | Đối chiếu prompt đợt 5.4 (12/10): CS-05 dùng đúng ví dụ file luật (20 giờ → hoàn 4.593.600 đ), lan sang CS-02, CS-08, TC-10, TC-11, LOP-02; BUOI-10 thêm bản điện thoại; CS-02 thêm trạng thái Thực hiện dừng học và danh sách nhóm con → hộp thoại | CS-02, CS-05, BUOI-10 |
| P-82 | Màn đã vẽ trước đợt của mình: CH-07, CS-16, BC-08, BC-09 (đợt 5.5), BC-01 (đợt 5.7). Khi nhận prompt đợt đó: đối chiếu lại với yêu cầu, sai thì sửa, đúng thì giữ và làm phần còn lại | Đợt 5.5, 5.7 |
| P-83 | `TeacherShell` (GV-01): cùng 5 mục; điện thoại = tiêu đề + thanh dưới; laptop = menu trái thu gọn 64px + vùng nội dung rộng, mật độ 40/48px; trạng thái lưu nằm trên thanh tiêu đề | GV-01, mọi màn GV |
| P-84 | `QuickGrid` (K14): điểm danh là 4 cột trạng thái (bấm hoặc phím 1–4), nhận xét là cột tiêu chí nhóm Thái độ / Kiến thức / Vận dụng + cột TB vận dụng (hệ thống tính) + cột lời nhắn (mở ngăn bên), BTVN là cột trạng thái (phím 1–5) + cột điểm 1–10 (A-6, A-8). Ô trống nét đứt; 0 hoặc ngoài thang báo lỗi tại ô; em vắng một ô "Vắng · không chấm" | K14, GV-05, GV-07, GV-08 |
| P-85 | Buổi mẫu xuyên suốt đợt 5.5: **9A2 Đại · Buổi 4 · Thứ Hai 12/10/2026 19:15–20:45 · P102 · Lê Văn Khánh**, 12 em (Lê Gia Huy buổi đầu); 3 dòng nội dung chương Căn bậc hai; BTVN buổi trước là Buổi 3 | GV-02…GV-09 |
| P-86 | GV-09 còn thiếu là **lỗi chặn**: liệt kê từng em + việc còn thiếu, mỗi dòng có nút "Đi tới"; nút Hoàn tất khoá. Điện thoại dùng tấm trượt dưới, laptop dùng hộp thoại | GV-09 |
| P-87 | Màn GV mức B chỉ vẽ một bố cục (GV-10, 11, 12, 14, 16): chọn **điện thoại** làm bố cục chính; laptop dùng cùng nội dung trong khung GV-01 laptop | GV-10…GV-16 |
| P-88 | Số liệu thầy Lê Văn Khánh khớp giữa GV-16, BC-08, BC-09 (09/2026: 26 buổi, 39,0 giờ, 4 buổi trễ, 9,0 giờ trễ); CS-16 dùng lời nhắn của buổi 9A2 Đại · Buổi 4 | GV-16, BC-08, BC-09, CS-16 |

---

### Đợt 5.6 — Học tập + Phụ huynh (đề xuất, chờ duyệt)

| # | Đề xuất | Màn |
| --- | --- | --- |
| P-89 | `StudentShell` (HT-09): 5 tab học sinh (Trang chủ, Bài tập, Lịch, Kết quả, Tài khoản); laptop = menu trái mở rộng + nội dung **một cột** giữa trang, tối đa 720px; `portal="ph"` cho phụ huynh với 5 tab Trang chủ, Kết quả, Lịch, Học phí, Đề nghị; Tài khoản ở menu ảnh đại diện (A-48, chỉ điện thoại) | HT-09, mọi màn HT, PH |
| P-90 | Bản học sinh nhỏ (`young`, lớp 2–5): chữ 18, nút 52px, bo 16px, nhãn thanh dưới 14px; trang chủ chỉ 3 khối, một bài gần hạn nhất, ngày viết bằng chữ ("ngày mai"), không có số phần trăm | HT-01 |
| P-91 | Phần thưởng = **sao / chuỗi bài nộp đúng hạn**, đếm từ dữ liệu có sẵn; không cộng điểm, không xếp hạng, không so với bạn. Nền thưởng (`--hmt-lms-reward`) luôn đi kèm chữ mực ấm; không có ở cổng phụ huynh | HT-01, HT-04 |
| P-92 | Nộp bài 3 bước: thêm trang → xem lại → nộp (hộp thoại xác nhận). Thứ tự trang đổi bằng nút (đưa lên trước / ra sau). Trang lỗi, đang tải, mất mạng → bấm nộp mở hộp thoại liệt kê lý do. Trang đã chụp giữ trong máy khi mất mạng | HT-04 |
| P-93 | Nộp lại: chỉ khi còn hạn **và** giáo viên chưa chấm; bản mới thay bản cũ, lịch sử lần nộp vẫn giữ và hiện ở HT-05; giáo viên chấm bản cuối | HT-03, HT-04, HT-05, GV-18 |
| P-94 | GV-17: hạn nộp mặc định = giờ vào buổi sau; hai công tắc riêng "Cho nộp lại trước hạn" và "Nhận bài nộp muộn" (nhận đến khi chấm); giao cả lớp hoặc từng em (em không được chọn không thấy bài) | GV-17 |
| P-95 | GV-18 ghi thẳng vào trạng thái BTVN của buổi (R-GV-11): chấm online trước buổi thì bước BTVN ở GV-08 đã có sẵn; em chưa nộp không chấm ở GV-18 mà xử lý trên lớp. Laptop ba cột (danh sách · ảnh · phiếu chấm) theo K14; điện thoại ảnh trên, phiếu chấm dưới theo K12 | GV-18, GV-08 |
| P-96 | Dữ liệu xuyên suốt 5.6: Khúc Bảo Nam (HS000420, 9A2) — BTVN Buổi 3 chấm online 12/10 17:05 được 4/5 (khớp GV-08, thang 1–5 theo A-47); BTVN Buổi 4 giao 12/10 20:40, hạn 15/10/2026 19:15; tỉ lệ làm BTVN 67% (2/3), điểm TB 3,8/5. Phụ huynh Anh Khúc Văn Thành (PH000233), con thứ hai Khúc Bảo Ngọc (HS000515, lớp 3, 3A1 Toán). Học sinh lớn mẫu: Võ Thuỳ Dương (HS000298, lớp 11; đổi tên 12/10 vì trùng học sinh Trịnh Khánh Linh HS000427 ở các màn khác) | HT-*, PH-*, GV-17, GV-18 |
| P-97 | Khiếu nại KN-CS1-2610-0011 (Vận hành · phòng học): phương án 9A2 học tạm P104 từ 15/10 đến khi thay xong điều hoà P102 → HT-06 hiện P104 cho các buổi đó | PH-04, HT-06, PH-01 |
| P-98 | Cổng phụ huynh chỉ xem tiền và giờ: không có nút tạo đơn, phiếu thu, thanh toán; không hiện tên người duyệt nội bộ, SLA nội bộ; mức độ ticket do CSKH đánh giá | PH-03, PH-04 |
| P-99 | BC-01 đối chiếu đợt 5.7 (12/10): thêm thẻ riêng "Đang bảo lưu" và "Quỹ giờ còn (quy ra tiền)" (giờ còn phải dạy × đơn giá ghi nhận từng ghi danh; Trưởng cơ sở mở GD-01, Admin mở BC-04 trên Looker); bảng theo cơ sở thêm cột quỹ giờ còn. Đủ 7 chỉ số: đang học, đang bảo lưu, doanh thu ghi nhận, tiền thu, quỹ giờ còn, tỉ lệ tái tục, ticket mở · quá hạn | BC-01 |
| P-100 | Vùng bấm ≥ 44px trên điện thoại sửa ở thành phần gốc: Chip, Button `size="sm"`, nút chỉ có biểu tượng, ô nhập/ô chọn (phủ hết chiều cao khung), Tabs, nút đổi kiểu xem, link mã trong danh sách. Áp cho `data-product` teacher/lms, khung `.hmt-phone` và màn hình ≤ 640px; laptop giáo viên (`data-device="desktop"`) giữ 32–36px | Chip, Button, Field, Tabs, FilterBar, RatingScale, PasswordInput, DateInput |
| P-101 | `KanbanCard` nhận `onOpen`: mã trên thẻ là link mở bản ghi (TT-01 → TT-02); kéo thả không bị ảnh hưởng | Kanban, TT-01 |

## PROPOSED (chưa duyệt riêng)

| # | Đề xuất | Ghi chú |
| --- | --- | --- |
| ~~P-1~~ | ~~Font phương án C~~ | **APPROVED** theo O-1 |
| ~~P-2~~ | ~~Điểm danh mặc định để trống~~ | **APPROVED** theo O-2 |
| ~~P-3~~ | ~~Lựa chọn điểm danh trung tính~~ | **Bị thay** — luật O-3 chọn có màu |
| P-4 | **Bảng màu phân loại** `--hmt-cat-1..4` (xanh dương #2A78D6, hồng #E87BA4, xanh ngọc #1BAF7A, xám ấm #8A8178) + `-subtle`; `--hmt-chart-1` | Dùng cho loại buổi trong Calendar (Chính / Củng cố / Học bù / Học bổ trợ) và RadarChart. Đã chạy bộ kiểm tra bảng màu: đạt độ sáng/độ tương phản; cặp 2–3 sát ngưỡng mù màu (6,1) → luôn kèm nhãn chữ. Đóng một phần O-11 |
| ~~P-5~~ | ~~SlaBadge "Sắp trễ" khi còn ≤ 4 giờ~~ | **APPROVED** (A-3) |
| P-6 | Lựa chọn điểm danh xếp **lưới 2×2** trên điện thoại và cột hẹp | Nhãn "Vắng không phép" không bị cắt/xuống 3 dòng |
| ~~P-7~~ | ~~Điểm danh vận hành dùng cùng 4 trạng thái + cột "Lý do liên hệ"~~ | **APPROVED** (A-2) |
| ~~P-8~~ | ~~Bản in: báo giá A4; biên nhận, phiếu chi A5~~ | **Sửa và APPROVED**: cả ba A4 (A-4) |
| ~~P-9~~ | ~~Ô ký: báo giá = Phụ huynh / Người lập; phiếu thu = Người nộp tiền / Người thu tiền; phiếu chi = Người nhận / Người lập / Kế toán / Quản lý cơ sở~~ | **APPROVED** (A-4) |
| P-10 | Lịch tháng: quá 3 buổi/ngày hiện "+n buổi" | |
| P-11 | StatusBar quá 5 bước thì dùng nhãn rút gọn; dưới 640px chỉ hiện bước hiện tại + nút "Các bước" | |
| P-12 | **Mật độ Giáo viên trên máy tính**: app đặt `data-device="desktop"` khi màn ≥ 1024px → nút/ô 40px, hàng 48px, khe 12px; chữ giữ 16px | Điện thoại giữ 48/56px. Dùng thuộc tính thay vì media query để khung điện thoại xem thử trên máy tính không bị đổi |
| P-13 | Điểm danh trên máy tính: bảng Học sinh · Ghi chú · 4 lựa chọn trên một hàng; chấm từng em trên máy tính: danh sách em bên trái (Đủ / x/6) + phiếu chấm hai cột Thái độ · Kiến thức | Cùng component với điện thoại, đổi theo độ rộng khung |
| ~~P-14~~ | ~~Điểm BTVN chỉ nhận số nguyên~~ | **Bị thay** bởi A-8 (cho số lẻ) |

---

## OPEN DECISION

| # | Vấn đề | Nguồn | Ghi chú |
| --- | --- | --- | --- |
| O-4 | **Logo rút gọn** (header, favicon, ảnh đại diện app) | Brand O2 | Hoãn theo yêu cầu; cần người thiết kế logo |
| O-5 | Vùng trống tối thiểu quanh logo | Brand O3 | Cần HMT xác nhận |
| O-6 | Cỡ chữ lớn hơn cho học sinh lớp 2–5 trong LMS | Brand O4, DS O4 | Cần kiểm thử |
| O-9 | Nội dung "Nguyên tắc 5 Không" | Brand O7 | Chỉ có dạng ảnh trên website |
| O-11 | Bảng màu phân loại cho 5 cơ sở, môn học | Brand U5, DS O5 | Phần biểu đồ/loại buổi: đề xuất P-4 |
| O-16 | Chỉnh sửa trực tiếp trong ô bảng | Component C3 | |
| O-19 | Phím tắt CRM | Component C6 | Làm cùng màn nghiệp vụ |

### Câu hỏi nghiệp vụ (đợt 5.0)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-1…Q-5~~ | Đã trả lời 11/10 | | Xem A-1…A-5 |
| ~~Q-6, Q-7~~ | Đã trả lời 11/10 | | Xem A-8, A-9 |
| ~~Q-8~~ | Đã trả lời 12/10 → A-22 | | |
| ~~Q-9~~ | Đã trả lời 12/10 → A-23 | | |
| ~~Q-10~~ | Đã trả lời 12/10 → A-24 | | |
| ~~Q-11~~ | Đã trả lời 12/10 → A-25 | | |
| ~~Q-12~~ | Đã trả lời 12/10 → A-26 | | |
| ~~Q-13~~ | Đã trả lời 12/10 → A-27 | | |
| ~~Q-14~~ | Đã trả lời 12/10 → A-28 | | |
| ~~Q-16, Q-17, Q-18~~ | Đã trả lời 12/10 | | Xem A-10…A-12 |
| ~~Q-15~~ | Đã trả lời 12/10 → A-29 | | |

### Câu hỏi nghiệp vụ (đợt 5.3 · phần 2)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-19, Q-20, Q-21~~ | Đã trả lời 12/10 | | Xem A-13…A-16 |

### Câu hỏi nghiệp vụ (đợt 5.4 · phần 1)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-22~~ | Đã trả lời 12/10 → A-30 | | |
| ~~Q-23~~ | Đã trả lời 12/10 → A-31 | | |
| ~~Q-24~~ | Đã trả lời 12/10 → A-32 | | |
| ~~Q-25~~ | Đã trả lời 12/10 → A-33 | | |
| ~~Q-26~~ | ~~Huỷ buổi sau khi đã chốt danh sách~~ → A-18 |  |  |
| ~~Q-27~~ | Đã trả lời → A-21 | | |
| ~~Q-28~~ | Đã trả lời → A-20 | | |

### Câu hỏi nghiệp vụ (đợt 5.4 · phần 3)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-29~~ | Đã trả lời 12/10 → A-34 | | |
| ~~Q-30~~ | Đã trả lời 12/10 → A-35 | | |
| ~~Q-31~~ | Đã trả lời 12/10 → A-36 | | |
| ~~Q-32~~ | Đã trả lời 12/10 → A-37 | | |

### Câu hỏi nghiệp vụ (sau khi áp dụng A-22…A-37)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-33~~ | Đã trả lời 12/10 → A-39 | | |
| ~~Q-34~~ | Đã trả lời 12/10 → A-40 | | |
| ~~Q-35~~ | Đã trả lời 12/10 → A-41 | | |
| ~~Q-36~~ | Đã trả lời 12/10 → A-42 | | |
| ~~Q-37~~ | Đã trả lời 12/10 → A-43 | | |
| ~~Q-38~~ | Đã trả lời 12/10 → A-44 | | |
| ~~Q-39~~ | Đã trả lời 12/10 → A-45 | | |

### Câu hỏi nghiệp vụ (đợt 5.6)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-40~~ | Đã trả lời 12/10 → A-49 | | |
| ~~Q-41~~ | Đã trả lời 12/10 → A-50 | | |
| ~~Q-42~~ | Đã trả lời 12/10 → A-51 | | |
| ~~Q-43~~ | Đã trả lời 12/10 → A-52 | | |
| ~~Q-44~~ | Đã trả lời 12/10 → A-53 | | |

### Câu hỏi nghiệp vụ (đợt 5.7)

| # | Câu hỏi | Ảnh hưởng | Đang vẽ thế nào |
| --- | --- | --- | --- |
| ~~Q-45~~ | Đã trả lời 12/10 → A-55 | | |

### Đã đóng (đợt 5.0)

O-1, O-2, O-3, O-7, O-8, O-10, O-12, O-13, O-14, O-15, O-17, O-18 — đóng theo luật §8 (xem "Chốt theo luật §8").

---

## Chưa làm / bước tiếp theo

- **Đợt 5.1 phần 2** (khuôn K01–K13) đã làm bù 12/10; chờ duyệt.
- **Áp dụng câu trả lời 12/10 (A-22…A-37)** xong; chờ duyệt. Còn mở: Q-33…Q-35.
- **Đợt 5.6** Học tập + Phụ huynh xong 12/10 (HT-01, HT-04 mức A; GV-17, GV-18, HT-02, 03, 05, 06, 07, 09, PH-01…04 mức B); đã áp dụng câu trả lời Q-40…Q-44 (A-47…A-53) và sửa thang điểm BTVN 1–5, khung phụ huynh 5 tab, thêm PH-05; chờ duyệt.
- **Đợt 5.5** đủ hai phần (GV-01…GV-16, K14; đối chiếu CH-07, CS-16, BC-08, BC-09) xong 12/10; chờ duyệt. 
- **Đợt 5.7 Báo cáo** (theo bản đồ: 1 màn mức A + 7 Looker): BC-01 vẽ trước, đối chiếu prompt 12/10: bổ sung thẻ Đang bảo lưu, Quỹ giờ còn (P-99), mở Q-45; BC-02…BC-07, BC-10 là Looker, không vẽ. BC-08, BC-09 thuộc đợt 5.5. Chờ duyệt. Đã trả lời Q-33…Q-39 (A-39…A-45).
- **Đợt 5.4** đủ ba phần (Đào tạo; Chăm sóc khách hàng, Tái tục).
- Kiểm tra hiển thị icon Lucide thật (môi trường làm việc chặn CDN; đang thấy icon dự phòng).
- Biên dịch thử `HMT_DESIGN_TOKENS.css` với Tailwind v4 trong repo (môi trường làm việc không có Tailwind).
- Kiểm thử với trình đọc màn hình thật và thiết bị thật.

- **Manifest tổng P5:** `HMT_MANIFEST_P5.md` (12/10). **P6 kiểm tra:** `HMT_QA_P6.md` — đã sửa theo A-54, kiểm lại đạt 147/147; gói bàn giao cuối `HMT_P5_BAN_GIAO.zip`.
