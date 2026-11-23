# Đối chiếu canvas Đào tạo và Giáo viên: `8a0d` (28/10) với v41 `1793782759-fcd1` (04/11)

Gói mới ở `design/hmt-canvas-fcd1/` (339 khung + `canvas.json` + `ds/`), thay `hmt-canvas-8a0d` (đã xoá). Canvas `6f57` (Bán hàng, Thu chi) giữ nguyên. **Anh Trường đã duyệt bảng này với các trả lời ở mục 4 (04/11, Đ292).** Chưa viết mã. Số liệu: 8a0d có 243 file, v41 có 347 file; thêm 128, bỏ 24, đổi 104 (so nội dung file).

Quy ước: khung nháp GV07b, GV08b (23 khung của 8a0d) không còn trong gói. Nhóm GV07X nằm cuối canvas, từ y ≈ 101.614.

## 1. Màn thêm mới
| Nhóm | Số khung | Là gì | Ảnh hưởng tới việc làm |
|---|---|---|---|
| **GV-07K** | 12 | Chấm buổi **kiểm tra**: 3 nhóm điểm (kể cả vượt điểm tối đa), điểm tổng, chưa điểm danh, em vắng, đã chấm đủ, lỗi lưu, buổi Done chỉ xem; laptop và điện thoại | D2: loại buổi "Kiểm tra", bảng điểm kiểm tra (3 nhóm điểm, tổng, ngưỡng lệch tổng) |
| **GV-06 buổi kiểm tra** | 2 (+1) | Phạm vi kiến thức của buổi kiểm tra (laptop, điện thoại); thêm khung "để trống BTVN vẫn lưu" | Xem mục 3, câu hỏi 1 |
| **GV-07 mới** | 6 | Công tắc tiêu chí của buổi (**ô tick tạm**), chấm theo cột + "Cả lớp mức 3", ô 4 trạng thái (từng em) | D2: tiêu chí theo buổi, 9 tiêu chí, ô chưa đánh giá, chưa đủ căn cứ, không áp dụng |
| **GV07X** | 15 | Xuất nhận xét ra PDF A4 hoặc ảnh 1080 px: nút xuất, hộp thoại một em và cả lớp, xem trước, đang tạo, lỗi, chưa lưu đủ, mẫu A4 và ảnh (thường, kiểm tra), mẫu câu lời nhắn | Tạo file ngay trên trình duyệt, không lưu lên máy chủ; giáo viên tự gửi tay vào group Zalo lớp; không có nút Chia sẻ |
| **BUOI-07, 08, 09 bổ sung** | 9 | Chọn loại buổi (Buổi học / Kiểm tra, 3 nhóm điểm, lỗi lệch tổng) trong các form buổi | D2 |
| **DM** | 1 | Danh mục chung: form thêm/sửa loại buổi (chọn form nhận xét) | D2: loại buổi là danh mục |
| **GV-14 ticket giáo viên** | 2 | Tạo ticket giáo viên, có "Tính chất" chỉ đọc | A1 |
| **Aftersale CSN01 đến CSN09** | 77 | Danh sách ticket (Chờ đóng), Kanban, form ticket, đổi loại khi tiếp nhận, phiếu nghiệp vụ (chờ tôi duyệt, chờ kế toán duyệt, duyệt cấp 2), cấu hình danh mục Đề nghị, cấu hình SLA | A1. **Danh mục ticket giáo viên, 12 loại phiếu, thứ tự ưu tiên chỉ là minh hoạ, không coi là luật** (anh dặn) |
| Tài sản, tài liệu | 3 | `assets/hmt-logo.svg`, nhật ký bàn giao v40, v41 | Không |

## 2. Màn bỏ
| Nhóm | Số khung | Ghi chú |
|---|---|---|
| GV07b, GV08b | 23 | Bản nháp chờ đổi luật R-GV-01 và R-GV-04; **không làm** (anh dặn) |
| GV06_thieu_btvn_dt | 1 | Khung "thiếu BTVN" của GV-06 bỏ vì BTVN không còn bắt buộc (xem câu hỏi 1) |
| CS-16 "Nhận xét chờ gửi PH" | (7 + 2 khung CSN06f, đã bỏ từ v40) | Không có danh sách chờ gửi, CSKH không tham gia |
| Điều chỉnh học phí hai cấp duyệt | (trong CSN) | Không có trong tài liệu gốc, đã gỡ |

## 3. Màn đổi (104 file, theo nhóm)
| Màn | Số khung đổi | Nội dung đổi chính (đọc từ chữ trong khung) |
|---|---|---|
| GV-01, 03, 10, 13, 15 | 3 / 5 / 5 / 5 / 7 | Chỉ khác mã nền (script ô nhập); không đổi chữ nghiệp vụ |
| GV-02 Hôm nay | 5 | Nhóm "VIỆC SẮP TRỄ HẠN / QUÁ HẠN" thành "VIỆC SẮP TRỄ HẠN": khung không còn dòng buổi đã quá hạn |
| GV-04 Buổi dạy | 11 | Điều kiện hoàn thành bước nhận xét: "em có mặt cần **đủ 9 tiêu chí**" (trước: đủ điểm và lời nhắn); bước nội dung: "3 dòng nội dung" (trước: kèm BTVN); bỏ nhắc R-GIO-06 |
| GV-05 Điểm danh | 6 | Thêm khung buổi Done chỉ xem; trong khung không còn thấy hộp hỏi "Đổi sang Vắng?" (xem câu hỏi 3) |
| GV-06 Nội dung buổi | 7 | **BTVN không bắt buộc** ("Để trống nếu buổi này không giao; không ảnh hưởng việc hoàn thành bước 2"); thêm "Loại buổi" |
| GV-07 Chấm nhận xét | 10 | "Lời nhắn phụ huynh" bỏ; thêm "Nhận xét chung", "Định hướng cải thiện" (không bắt buộc); tên tiêu chí "Tinh thần học tập" thành "Tự giác" |
| GV-08 Chấm BTVN | 6 | Khung "buổi trước không giao BTVN" (tự bỏ qua, không chặn Done, QĐ-Đ22) |
| GV-09 Kiểm còn thiếu | 6 | Theo GV-04 và GV-06: "x/4 bước", "Xong", "3 dòng nội dung" |
| GV-11 Lớp chi tiết | 5 | "Hoàn thành" thành "Done"; nút "Mở học sinh" đổi thành "Mở" |
| GV-12 Cần làm | 5 | Bài "Nộp sau": thêm bài của em vắng buổi chấm (chờ cập nhật); số việc minh hoạ đổi (5, trước 6) |
| GV-14 Ticket | 5 | Giáo viên thêm trường "Tính chất" (chỉ đọc); trong khung không còn thấy các trạng thái "Đã duyệt", "Đang xác minh" và dòng "Ticket lớp tôi" |
| KG | 3 | "Hoàn thành" thành "Done"; "Tinh thần học tập" thành "Tự giác" |
| Main (mục lục) | 1 | Cập nhật GV-16 12 khung, KG 10 khung (thêm K15), hàng GV07X |
| Man_GV02, 04, 05, 06, 08, 09, 12 | 7 | Nhãn mô tả theo các thay đổi trên |

## 4. Chỗ vênh với luật hiện hành: anh Trường đã trả lời 04/11 (Đ292)
| # | Câu hỏi | Anh chốt | Vào luật |
|---|---|---|---|
| 1 | BTVN không còn bắt buộc ở GV-06 | Theo canvas: BTVN để trống = không giao. Bỏ điều kiện R-GIO-06, QĐ-Đ22, QĐ-Đ23 (phần BTVN) | R-V2-35 |
| 2 | Chấm BTVN buổi trước (GV-08) | Buổi trước không có BTVN thì tự bỏ qua (hệ quả của câu 1) | R-V2-35 |
| 3 | GV-05 đổi Có mặt thành Vắng | **Giữ hộp xác nhận** theo luật hiện hành; canvas chỉ chưa vẽ | R-V2-36 |
| 4 | GV-02 buổi quá hạn | Theo canvas: Hôm nay chỉ buổi trong ngày; quá hạn ở GV-12. Menu "Cần làm" thêm số đếm công việc nhỏ (canvas hiện chưa có số đếm ở menu, GV01 chỉ có chữ "Cần làm") | R-V2-37 |
| 5 | Lời nhắn phụ huynh trong form nhận xét | Theo canvas: "Nhận xét chung", "Định hướng cải thiện"; mẫu câu chỉ có khi xuất | R-V2-39, 40 |
| 6 | Dấu "Đã xuất" | Lưu cờ trong DB, một cờ mỗi em mỗi buổi, không lịch sử | R-V2-38 |
| 7 | Ngưỡng mức gợi ý và 24 mẫu câu | Ngưỡng là tham số Cài đặt; 24 câu là danh mục nạp sẵn, Admin sửa được; so sánh trên điểm chưa làm tròn | R-V2-39 |
| 8 | GV-14 trường "Tính chất" chỉ đọc | Chờ danh mục ticket giáo viên thật | (A1) |
| 9 | Aftersale CSN | Chưa là luật; chờ anh chốt danh mục ticket giáo viên và thứ tự ưu tiên | (A1) |

## 5. Việc kế tiếp (sau khi anh duyệt bảng này)
D1/D2 (DB): loại buổi và Kiểm tra, 9 tiêu chí, bảng điểm kiểm tra (3 nhóm điểm), tiêu chí theo buổi, tham số ngưỡng mức gợi ý và danh mục mẫu câu, cờ "Đã xuất". Giao diện cổng giáo viên dựng theo khuôn KG của `design/hmt-canvas-fcd1/`. Mốc ~17/11 (sau Bán hàng, Thu chi ~12/11). **Chưa viết mã Đào tạo; Bán hàng làm trước Đào tạo** (anh 04/11).

## 6. Rà lại ngày 23/11/2026 với canvas v52 (thẻ A-23-05, Code A)

**Phạm vi:** cổng giáo viên (GV-01..16, GV07K, GV07X) và BUOI-03, BUOI-07..09, so với `design/hmt-canvas-9189/` bản v52 (391 khung).

**Kết quả chính:** từ bản v48 (#231) tới v52 (#512) **không khung GV, GV07X, BUOI nào đổi** (chỉ thêm 18 khung Aftersale CSN và đổi `canvas.json`). Vì vậy kết luận đối chiếu của bảng `docs/ke-hoach/man-hinh-theo-trang-thai.md` (GV-02, 04, 07, 16 «Lệch → đã sửa»; các màn khác Đúng hoặc Gần đúng) vẫn đúng với v52. 23 khung `GV07b_*`, `GV08b_*` là bản nháp, không làm (đã kiểm: code không dựng).

**Đã kiểm trong code (đọc mã, không chụp màn hình):**

| Luật / khung | Kết quả |
|---|---|
| R-V2-37: GV-02 không hiện buổi quá hạn | Đúng: `TeacherTodayPage` ghi buổi quá hạn ở GV-12, máy chủ quyết buổi nào hiện (`app.teacher_today`) |
| R-V2-35: BTVN tuỳ giáo viên, không ô «không giao BTVN» | Đúng: `SessionContentPage`; GV-08 buổi trước không giao thì tự bỏ qua, không chặn Done (`HomeworkGradingPage`, Vitest `sessionSteps.test.ts`) |
| GV-07 / GV07K: «Nhận xét chung», «Định hướng cải thiện», bỏ «Lời nhắn phụ huynh» | Đúng (`ExamGradingPage`; không còn chuỗi «Lời nhắn phụ huynh» ở cổng giáo viên) |
| Tiêu chí «Tự giác» (trước «Tinh thần học tập») | Đúng: danh mục nạp bằng migration `…0103` (mã `TD_TU_GIAC`), không còn tên cũ |
| GV-14: trường «Tính chất» chỉ đọc | Có (`TeacherTicketCreatePage`) |
| Chữ «Done» thay «Hoàn thành» ở tình trạng buổi | Phần lớn đúng; còn vài chỗ viết «Buổi đã Hoàn thành» (`ExamGradingPage` dòng 155, 187; `TeacherAttendancePage` 207) |

**Lệch nhỏ chưa sửa (chữ, không ảnh hưởng nghiệp vụ; mã nằm vùng Code E nên chỉ ghi, không sửa chéo vùng):**
1. Ba chỗ chữ «Hoàn thành» ở trên nên đổi thành «Done» cho thống nhất với GV-09, GV-11 và khuôn KG.
2. GV-11: canvas bản máy tính dùng nút «Mở» ở một số dòng; code dùng «Mở học sinh» (khớp các khung còn lại). Không đổi.

**Chưa kiểm:** so từng khung ở cỡ điện thoại bằng ảnh chụp, và e2e: do Tester/CI. Không có lệch lớn nào cần báo anh.
