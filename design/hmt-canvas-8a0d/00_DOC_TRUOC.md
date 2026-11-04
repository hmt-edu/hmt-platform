# HMT Đào tạo & Giáo viên · gói canvas cho Code

- **Số bản canvas:** `1793184970-8a0d` (đăng 28/10/2026 17:56, giờ Hà Nội)
- **Ngày xuất gói:** 04/11/2026
- **Canvas:** HMT Đào tạo & Giáo viên (claude.ai/artifact/2o4UUZQ7YSJH1f9EiUaxvY). Đây là canvas tách từ HMT Platform theo QĐ-Đ14.
- **Nội dung gói:** 238 file khung `*.dc.html` + `canvas.json` + 3 file token/CSS của hệ thiết kế. Không có ảnh PNG, không có logo (khung không dùng).
- **Đối chiếu:** `canvas.json` sha256 `78c2118222575ed179ca15fbf11a946704da81659c8fc3633a36db39cbbabff5`.
- **Gói còn lại:** `HMT_canvas_1793759210-6f57_2026-11-04.zip` (canvas HMT Platform, bản `1793759210-6f57`). Hai gói không trùng khung.

## Phạm vi
Có: cổng Giáo viên GV-01..16, BUOI-03 (điểm danh trong ngày), LOP-08 (lịch tuần cơ sở), bộ khuôn KG.
Không có: Aftersale (CS-...), GV-17, GV-18 (giao bài, chấm bài online, LMS giai đoạn 4, chưa dựng). Các màn khác (TS, KH, BH, TC, GD, TT, LOP-01..07/09, BUOI-01/02/04..15, K1..K12, P0..P2) nằm ở canvas HMT Platform.

## Tình trạng duyệt (theo Mục lục `Main.dc.html` trong canvas; canvas không có bản ghi duyệt riêng)
| Mã | Tình trạng ghi trong Mục lục |
|---|---|
| LOP-08, BUOI-03 | đã đưa lên canvas này (đợt 1), 6 trạng thái mỗi màn |
| GV-01..04, 09 | đợt 2, duyệt 23/10; sửa 24/10 (GV-02, 04, 09) |
| GV-05..08 | đợt 3, duyệt 24/10; sửa 24/10 |
| GV-10..14 | duyệt 24/10 |
| GV-15 | theo QĐ-Đ25, duyệt 24/10 |
| GV-16 | dựng 24/10, **chờ duyệt** (8 khung) |
| GV-17, 18 | đợt 5, chưa dựng |
| KG (bộ khuôn) | anh đã duyệt 23/10 (7 khung); khuôn báo cáo tháng duyệt 24/10 (2 khung, QĐ-Đ24) |
| GV07b, GV08b (23 khung) | **bản nháp**: bộ tiêu chí mới, chờ đổi luật R-GV-01 / R-GV-04 (ghi chú trên canvas) |

## Cách đọc
1. Mỗi file `.dc.html` là một khung. Cần `support.js` của Claude Design để mở đúng hình (không nằm trong gói); không có thì đọc mã HTML/CSS. CSS dùng chung ở `ds/hmt/...`.
2. `canvas.json` ghi tên, vị trí (x, y), kích thước (w, h). Phần Máy tính và Điện thoại nằm ở hai vùng khác nhau của canvas. Hậu tố `_pc` là laptop, `_dt` là điện thoại, `_quyen` là không có quyền, `_tai` là đang tải, `_trong` là trống.
3. `Main.dc.html` là Mục lục mã màn. `Man_*` là nhãn từng màn.
4. Dữ liệu trong khung là dữ liệu giả.

## Danh sách khung (238)


### Main (1)

| File | Tên khung | w×h |
|---|---|---|
| Main.dc.html | Mục lục mã màn theo canvas | 1440×880 |

### KG (10)

| File | Tên khung | w×h |
|---|---|---|
| KG_danh_sach_buoc_pc.dc.html | KG · Danh sách bước (laptop, hai cột) | 1440×900 |
| KG_K14.dc.html | KG · K14 Bảng chấm nhanh (laptop) | 1440×900 |
| KG_bao_cao_thang_pc.dc.html | KG · Báo cáo tháng (laptop, chép K09) | 1440×900 |
| KG_K02.dc.html | KG · K02 Khung điện thoại, thanh tab dưới | 390×844 |
| KG_danh_sach_the.dc.html | KG · Danh sách thẻ (điện thoại) | 390×844 |
| KG_lich_ngay.dc.html | KG · Lịch ngày (điện thoại) | 390×844 |
| KG_ban_ghi_dt.dc.html | KG · Bản ghi (điện thoại) | 390×844 |
| KG_danh_sach_buoc.dc.html | KG · Danh sách bước (điện thoại) | 390×844 |
| KG_bao_cao_thang_dt.dc.html | KG · Báo cáo tháng (điện thoại) | 390×844 |
| KG_K15.dc.html | KG · K15 Ngăn dưới (khuôn mới, anh duyệt Đ230) | 1440×1080 |

### Man_GV01 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV01.dc.html | Màn · GV-01 Khung cổng giáo viên | 1440×100 |
| Man_GV01_bs_dt.dc.html | Màn · GV-01 Khung cổng giáo viên (dùng chung, bản sao) | 1440×100 |

### GV01 (4)

| File | Tên khung | w×h |
|---|---|---|
| GV01_pc.dc.html | GV-01 · Khung cổng giáo viên · laptop, menu trái thu gọn | 1440×900 |
| GV01_quyen_bs_pc.dc.html | GV-01 · Khung cổng giáo viên · điện thoại, không có quyền (dùng chung, bản sao) | 390×844 |
| GV01_dt.dc.html | GV-01 · Khung cổng giáo viên · điện thoại, thanh tab dưới | 390×844 |
| GV01_quyen.dc.html | GV-01 · Khung cổng giáo viên · điện thoại, không có quyền | 390×844 |

### Man_GV02 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV02.dc.html | Màn · GV-02 Hôm nay | 1440×130 |
| Man_GV02_bs_dt.dc.html | Màn · GV-02 Hôm nay (dùng chung, bản sao) | 1440×130 |

### GV02 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV02_pc.dc.html | GV-02 · Hôm nay · laptop | 1440×900 |
| GV02_trong_bs_pc.dc.html | GV-02 · Hôm nay · điện thoại, trống (dùng chung, bản sao) | 390×844 |
| GV02_tai_bs_pc.dc.html | GV-02 · Hôm nay · điện thoại, đang tải (dùng chung, bản sao) | 390×844 |
| GV02_quyen_bs_pc.dc.html | GV-02 · Hôm nay · điện thoại, không có quyền (dùng chung, bản sao) | 390×844 |
| GV02_dt.dc.html | GV-02 · Hôm nay · điện thoại | 390×844 |
| GV02_trong.dc.html | GV-02 · Hôm nay · điện thoại, trống | 390×844 |
| GV02_tai.dc.html | GV-02 · Hôm nay · điện thoại, đang tải | 390×844 |
| GV02_quyen.dc.html | GV-02 · Hôm nay · điện thoại, không có quyền | 390×844 |

### Man_GV03 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV03.dc.html | Màn · GV-03 Lịch dạy | 1440×100 |
| Man_GV03_bs_dt.dc.html | Màn · GV-03 Lịch dạy (dùng chung, bản sao) | 1440×100 |

### GV03 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV03_pc.dc.html | GV-03 · Lịch dạy · laptop, cả tuần (có xem tháng) | 1440×900 |
| GV03_trong_bs_pc.dc.html | GV-03 · Lịch dạy · điện thoại, trống (dùng chung, bản sao) | 390×844 |
| GV03_tai_bs_pc.dc.html | GV-03 · Lịch dạy · điện thoại, đang tải (dùng chung, bản sao) | 390×844 |
| GV03_quyen_bs_pc.dc.html | GV-03 · Lịch dạy · điện thoại, không có quyền (dùng chung, bản sao) | 390×844 |
| GV03_dt.dc.html | GV-03 · Lịch dạy · điện thoại, theo ngày | 390×844 |
| GV03_trong.dc.html | GV-03 · Lịch dạy · điện thoại, trống | 390×844 |
| GV03_tai.dc.html | GV-03 · Lịch dạy · điện thoại, đang tải | 390×844 |
| GV03_quyen.dc.html | GV-03 · Lịch dạy · điện thoại, không có quyền | 390×844 |

### Man_GV04 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV04.dc.html | Màn · GV-04 Buổi dạy (các bước cần làm) | 1440×160 |
| Man_GV04_bs_dt.dc.html | Màn · GV-04 Buổi dạy (các bước cần làm) (dùng chung, bản sao) | 1440×160 |

### GV04 (15)

| File | Tên khung | w×h |
|---|---|---|
| GV04_pc.dc.html | GV-04 · Buổi dạy · laptop, hai cột | 1440×900 |
| GV04_tai_bs_pc.dc.html | GV-04 · Buổi dạy · điện thoại, đang tải (dùng chung, bản sao) | 390×844 |
| GV04_quyen_bs_pc.dc.html | GV-04 · Buổi dạy · điện thoại, không có quyền (dùng chung, bản sao) | 390×844 |
| GV04_khong_btvn_pc.dc.html | GV-04 · Buổi dạy · buổi trước không giao BTVN (laptop) | 1440×900 |
| GV04_khong_btvn_xong_pc.dc.html | GV-04 · Buổi dạy · buổi trước không giao BTVN, đủ ba bước (laptop) | 1440×900 |
| GV04_dau_lop_pc.dc.html | GV-04 · Buổi dạy · buổi đầu của lớp (laptop) | 1440×900 |
| GV04_dt.dc.html | GV-04 · Buổi dạy · điện thoại, đang làm | 390×844 |
| GV04_tai.dc.html | GV-04 · Buổi dạy · điện thoại, đang tải | 390×844 |
| GV04_quyen.dc.html | GV-04 · Buổi dạy · điện thoại, không có quyền | 390×844 |
| GV04_dung_han.dc.html | GV-04 · Buổi dạy · điện thoại, đã hoàn tất Đúng hạn | 390×844 |
| GV04_tre_han.dc.html | GV-04 · Buổi dạy · điện thoại, đã hoàn tất Trễ hạn | 390×844 |
| GV04_chua_chot.dc.html | GV-04 · Buổi dạy · điện thoại, buổi chưa chốt danh sách | 390×844 |
| GV04_khong_btvn.dc.html | GV-04 · Buổi dạy · buổi trước không giao BTVN (điện thoại) | 390×844 |
| GV04_khong_btvn_xong.dc.html | GV-04 · Buổi dạy · buổi trước không giao BTVN, đủ ba bước (điện thoại) | 390×844 |
| GV04_dau_lop.dc.html | GV-04 · Buổi dạy · buổi đầu của lớp (điện thoại) | 390×844 |

### Man_GV05 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV05.dc.html | Màn · GV-05 Điểm danh (4 trạng thái) | 1440×130 |
| Man_GV05_bs_dt.dc.html | Màn · GV-05 Điểm danh (4 trạng thái) (dùng chung, bản sao) | 1440×130 |

### GV05 (10)

| File | Tên khung | w×h |
|---|---|---|
| GV05_pc.dc.html | GV-05 · Điểm danh (laptop) | 1440×900 |
| GV05_tai_bs_pc.dc.html | GV-05 · Điểm danh · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV05_quyen_bs_pc.dc.html | GV-05 · Điểm danh · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV05_xung_dot_pc.dc.html | GV-05 · Điểm danh · hai người cùng sửa một ô (laptop) | 1440×900 |
| GV05_dt.dc.html | GV-05 · Điểm danh · (điện thoại) | 390×844 |
| GV05_tai.dc.html | GV-05 · Điểm danh · đang tải (điện thoại) | 390×844 |
| GV05_quyen.dc.html | GV-05 · Điểm danh · không có quyền (điện thoại) | 390×844 |
| GV05_done_dt.dc.html | GV-05 · Điểm danh · buổi đã Hoàn thành, chỉ xem (điện thoại) | 390×844 |
| GV05_chua_chot.dc.html | GV-05 · Điểm danh · buổi chưa chốt danh sách (điện thoại) | 390×844 |
| GV05_xung_dot_dt.dc.html | GV-05 · Điểm danh · hai người cùng sửa một ô (điện thoại) | 390×844 |

### Man_GV06 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV06.dc.html | Màn · GV-06 Nội dung buổi và giao BTVN | 1440×160 |
| Man_GV06_bs_dt.dc.html | Màn · GV-06 Nội dung buổi và giao BTVN (dùng chung, bản sao) | 1440×160 |

### GV06 (11)

| File | Tên khung | w×h |
|---|---|---|
| GV06_pc.dc.html | GV-06 · Nội dung buổi và BTVN (laptop) | 1440×900 |
| GV06_trong_bs_pc.dc.html | GV-06 · Nội dung buổi và BTVN · chưa có dòng (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV06_tai_bs_pc.dc.html | GV-06 · Nội dung buổi và BTVN · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV06_quyen_bs_pc.dc.html | GV-06 · Nội dung buổi và BTVN · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV06_sau_cham_pc.dc.html | GV-06 · Nội dung buổi và BTVN · đã chấm vận dụng, sửa nội dung (laptop) | 1440×900 |
| GV06_dt.dc.html | GV-06 · Nội dung buổi và BTVN · (điện thoại) | 390×844 |
| GV06_trong.dc.html | GV-06 · Nội dung buổi và BTVN · chưa có dòng (điện thoại) | 390×844 |
| GV06_tai.dc.html | GV-06 · Nội dung buổi và BTVN · đang tải (điện thoại) | 390×844 |
| GV06_quyen.dc.html | GV-06 · Nội dung buổi và BTVN · không có quyền (điện thoại) | 390×844 |
| GV06_thieu_btvn_dt.dc.html | GV-06 · Nội dung buổi và BTVN · thiếu BTVN giao mới (điện thoại) | 390×844 |
| GV06_sau_cham_dt.dc.html | GV-06 · Nội dung buổi và BTVN · đã chấm vận dụng, sửa nội dung (điện thoại) | 390×844 |

### Man_GV07 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV07.dc.html | Màn · GV-07 Chấm nhận xét từng em | 1440×130 |
| Man_GV07_bs_dt.dc.html | Màn · GV-07 Chấm nhận xét từng em (dùng chung, bản sao) | 1440×130 |

### GV07 (13)

| File | Tên khung | w×h |
|---|---|---|
| GV07_pc.dc.html | GV-07 · Chấm nhận xét (laptop, danh sách em + thẻ chấm) · CŨ, theo R-GV-01 hiện hành | 1440×900 |
| GV07_trong_bs_pc.dc.html | GV-07 · Chấm nhận xét · chưa có em có mặt (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV07_tai_bs_pc.dc.html | GV-07 · Chấm nhận xét · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV07_quyen_bs_pc.dc.html | GV-07 · Chấm nhận xét · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV07_chua_dd_pc.dc.html | GV-07 · Chấm nhận xét · em chưa điểm danh (laptop, danh sách em + thẻ chấm) · CŨ, theo R-GV-01 hiện hành | 1440×900 |
| GV07_xung_dot_pc.dc.html | GV-07 · Chấm nhận xét · hai người cùng sửa một ô (laptop, danh sách em + thẻ chấm) · CŨ, theo R-GV-01 hiện hành | 1440×900 |
| GV07_dt.dc.html | GV-07 · Chấm nhận xét · từng em (điện thoại) · CŨ, theo R-GV-01 hiện hành | 390×844 |
| GV07_trong.dc.html | GV-07 · Chấm nhận xét · chưa có em có mặt (điện thoại) | 390×844 |
| GV07_tai.dc.html | GV-07 · Chấm nhận xét · đang tải (điện thoại) | 390×844 |
| GV07_quyen.dc.html | GV-07 · Chấm nhận xét · không có quyền (điện thoại) | 390×844 |
| GV07_vang_dt.dc.html | GV-07 · Chấm nhận xét · em vắng, không chấm (điện thoại) · CŨ, theo R-GV-01 hiện hành | 390×844 |
| GV07_chua_dd_dt.dc.html | GV-07 · Chấm nhận xét · em chưa điểm danh (điện thoại) · CŨ, theo R-GV-01 hiện hành | 390×844 |
| GV07_xung_dot_dt.dc.html | GV-07 · Chấm nhận xét · hai người cùng sửa một ô (điện thoại) · CŨ, theo R-GV-01 hiện hành | 390×844 |

### Man_GV08 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV08.dc.html | Màn · GV-08 Chấm BTVN của buổi trước (5 trạng thái) | 1440×160 |
| Man_GV08_bs_dt.dc.html | Màn · GV-08 Chấm BTVN của buổi trước (5 trạng thái) (dùng chung, bản sao) | 1440×160 |

### GV08 (14)

| File | Tên khung | w×h |
|---|---|---|
| GV08_pc.dc.html | GV-08 · Chấm BTVN buổi trước (laptop) | 1440×900 |
| GV08_trong_bs_pc.dc.html | GV-08 · Chấm BTVN buổi trước · buổi trước không giao BTVN (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV08_tai_bs_pc.dc.html | GV-08 · Chấm BTVN buổi trước · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV08_quyen_bs_pc.dc.html | GV-08 · Chấm BTVN buổi trước · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV08_vang_giao_pc.dc.html | GV-08 · Chấm BTVN buổi trước · em vắng buổi giao bài (laptop) | 1440×900 |
| GV08_vang_cham_pc.dc.html | GV-08 · Chấm BTVN buổi trước · em vắng buổi chấm (laptop) | 1440×900 |
| GV08_xung_dot_pc.dc.html | GV-08 · Chấm BTVN buổi trước · hai người cùng sửa một ô (laptop) | 1440×900 |
| GV08_dt.dc.html | GV-08 · Chấm BTVN buổi trước (điện thoại) | 390×844 |
| GV08_trong.dc.html | GV-08 · Chấm BTVN buổi trước · buổi trước không giao BTVN (điện thoại) | 390×844 |
| GV08_tai.dc.html | GV-08 · Chấm BTVN buổi trước · đang tải (điện thoại) | 390×844 |
| GV08_quyen.dc.html | GV-08 · Chấm BTVN buổi trước · không có quyền (điện thoại) | 390×844 |
| GV08_dau_lop.dc.html | GV-08 · Chấm BTVN buổi trước · buổi đầu của lớp (điện thoại) | 390×844 |
| GV08_vang_giao_dt.dc.html | GV-08 · Chấm BTVN buổi trước · em vắng buổi giao bài (điện thoại) | 390×844 |
| GV08_xung_dot_dt.dc.html | GV-08 · Chấm BTVN buổi trước · hai người cùng sửa một ô (điện thoại) | 390×844 |

### Man_GV09 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV09.dc.html | Màn · GV-09 Kiểm còn thiếu, dấu thời hạn (hộp thoại) | 1440×130 |
| Man_GV09_bs_dt.dc.html | Màn · GV-09 Kiểm còn thiếu, dấu thời hạn (hộp thoại) (dùng chung, bản sao) | 1440×130 |

### GV09 (6)

| File | Tên khung | w×h |
|---|---|---|
| GV09_thieu_pc.dc.html | GV-09 · Kiểm còn thiếu · còn thiếu, laptop | 1440×900 |
| GV09_du_pc.dc.html | GV-09 · Kiểm còn thiếu · đủ, đóng dấu Trễ hạn, laptop | 1440×900 |
| GV09_thieu_btvn_pc.dc.html | GV-09 · Kiểm còn thiếu · chưa chọn BTVN giao mới (laptop) | 1440×900 |
| GV09_thieu_dt.dc.html | GV-09 · Kiểm còn thiếu · còn thiếu, điện thoại | 390×844 |
| GV09_du_dt.dc.html | GV-09 · Kiểm còn thiếu · đủ, đóng dấu Đúng hạn, điện thoại | 390×844 |
| GV09_thieu_btvn_dt.dc.html | GV-09 · Kiểm còn thiếu · chưa chọn BTVN giao mới (điện thoại) | 390×844 |

### Man_GV10 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV10.dc.html | Màn · GV-10 Lớp của tôi (danh sách thẻ) | 1440×100 |
| Man_GV10_bs_dt.dc.html | Màn · GV-10 Lớp của tôi (danh sách thẻ) (dùng chung, bản sao) | 1440×100 |

### GV10 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV10_pc.dc.html | GV-10 · Lớp của tôi (laptop) | 1440×900 |
| GV10_trong_bs_pc.dc.html | GV-10 · Lớp của tôi · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV10_tai_bs_pc.dc.html | GV-10 · Lớp của tôi · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV10_quyen_bs_pc.dc.html | GV-10 · Lớp của tôi · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV10_dt.dc.html | GV-10 · Lớp của tôi (điện thoại) | 390×844 |
| GV10_trong.dc.html | GV-10 · Lớp của tôi · trống (điện thoại) | 390×844 |
| GV10_tai.dc.html | GV-10 · Lớp của tôi · đang tải (điện thoại) | 390×844 |
| GV10_quyen.dc.html | GV-10 · Lớp của tôi · không có quyền (điện thoại) | 390×844 |

### Man_GV11 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV11.dc.html | Màn · GV-11 Lớp chi tiết cho giáo viên | 1440×100 |
| Man_GV11_bs_dt.dc.html | Màn · GV-11 Lớp chi tiết cho giáo viên (dùng chung, bản sao) | 1440×100 |

### GV11 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV11_pc.dc.html | GV-11 · Lớp chi tiết (laptop) | 1440×900 |
| GV11_trong_bs_pc.dc.html | GV-11 · Lớp · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV11_tai_bs_pc.dc.html | GV-11 · Lớp · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV11_quyen_bs_pc.dc.html | GV-11 · Lớp · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV11_dt.dc.html | GV-11 · Lớp chi tiết (điện thoại) | 390×844 |
| GV11_trong.dc.html | GV-11 · Lớp · trống (điện thoại) | 390×844 |
| GV11_tai.dc.html | GV-11 · Lớp · đang tải (điện thoại) | 390×844 |
| GV11_quyen.dc.html | GV-11 · Lớp · không có quyền (điện thoại) | 390×844 |

### Man_GV12 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV12.dc.html | Màn · GV-12 Cần làm, quá hạn | 1440×130 |
| Man_GV12_bs_dt.dc.html | Màn · GV-12 Cần làm, quá hạn (dùng chung, bản sao) | 1440×130 |

### GV12 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV12_pc.dc.html | GV-12 · Cần làm (laptop) | 1440×900 |
| GV12_trong_bs_pc.dc.html | GV-12 · Cần làm · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV12_tai_bs_pc.dc.html | GV-12 · Cần làm · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV12_quyen_bs_pc.dc.html | GV-12 · Cần làm · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV12_dt.dc.html | GV-12 · Cần làm (điện thoại) | 390×844 |
| GV12_trong.dc.html | GV-12 · Cần làm · trống (điện thoại) | 390×844 |
| GV12_tai.dc.html | GV-12 · Cần làm · đang tải (điện thoại) | 390×844 |
| GV12_quyen.dc.html | GV-12 · Cần làm · không có quyền (điện thoại) | 390×844 |

### Man_GV13 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV13.dc.html | Màn · GV-13 Học sinh, hồ sơ rút gọn | 1440×100 |
| Man_GV13_bs_dt.dc.html | Màn · GV-13 Học sinh, hồ sơ rút gọn (dùng chung, bản sao) | 1440×100 |

### GV13 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV13_pc.dc.html | GV-13 · Học sinh, hồ sơ rút gọn (laptop) | 1440×900 |
| GV13_trong_bs_pc.dc.html | GV-13 · Học sinh · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV13_tai_bs_pc.dc.html | GV-13 · Học sinh · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV13_quyen_bs_pc.dc.html | GV-13 · Học sinh · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV13_dt.dc.html | GV-13 · Học sinh, hồ sơ rút gọn (điện thoại) | 390×844 |
| GV13_trong.dc.html | GV-13 · Học sinh · trống (điện thoại) | 390×844 |
| GV13_tai.dc.html | GV-13 · Học sinh · đang tải (điện thoại) | 390×844 |
| GV13_quyen.dc.html | GV-13 · Học sinh · không có quyền (điện thoại) | 390×844 |

### Man_GV14 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV14.dc.html | Màn · GV-14 Tạo ticket và ticket lớp tôi | 1440×100 |
| Man_GV14_bs_dt.dc.html | Màn · GV-14 Tạo ticket và ticket lớp tôi (dùng chung, bản sao) | 1440×100 |

### GV14 (8)

| File | Tên khung | w×h |
|---|---|---|
| GV14_pc.dc.html | GV-14 · Tạo ticket và ticket lớp tôi (laptop) | 1440×900 |
| GV14_trong_bs_pc.dc.html | GV-14 · Ticket · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV14_tai_bs_pc.dc.html | GV-14 · Ticket · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV14_quyen_bs_pc.dc.html | GV-14 · Ticket · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV14_dt.dc.html | GV-14 · Tạo ticket và ticket lớp tôi (điện thoại) | 390×844 |
| GV14_trong.dc.html | GV-14 · Ticket · trống (điện thoại) | 390×844 |
| GV14_tai.dc.html | GV-14 · Ticket · đang tải (điện thoại) | 390×844 |
| GV14_quyen.dc.html | GV-14 · Ticket · không có quyền (điện thoại) | 390×844 |

### Man_GV15 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV15.dc.html | Màn · GV-15 Chấm kiểm tra đầu vào (bản tối giản giai đoạn 1) | 1440×130 |
| Man_GV15_bs_dt.dc.html | Màn · GV-15 Chấm kiểm tra đầu vào (bản tối giản giai đoạn 1) (dùng chung, bản sao) | 1440×130 |

### GV15 (10)

| File | Tên khung | w×h |
|---|---|---|
| GV15_pc.dc.html | GV-15 · Chấm kiểm tra đầu vào (laptop) | 1440×900 |
| GV15_trong_bs_pc.dc.html | GV-15 · Chấm kiểm tra đầu vào · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV15_tai_bs_pc.dc.html | GV-15 · Chấm kiểm tra đầu vào · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV15_quyen_bs_pc.dc.html | GV-15 · Chấm kiểm tra đầu vào · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV15_xong_pc.dc.html | GV-15 · Đã nộp, chỉ xem (laptop) | 1440×900 |
| GV15_dt.dc.html | GV-15 · Chấm kiểm tra đầu vào (điện thoại) | 390×844 |
| GV15_trong.dc.html | GV-15 · Chấm kiểm tra đầu vào · trống (điện thoại) | 390×844 |
| GV15_tai.dc.html | GV-15 · Chấm kiểm tra đầu vào · đang tải (điện thoại) | 390×844 |
| GV15_quyen.dc.html | GV-15 · Chấm kiểm tra đầu vào · không có quyền (điện thoại) | 390×844 |
| GV15_xong_dt.dc.html | GV-15 · Đã nộp, chỉ xem (điện thoại) | 390×844 |

### Man_GV16 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV16.dc.html | Màn · GV-16 Giờ dạy của tôi (báo cáo theo tháng) | 1440×160 |
| Man_GV16_bs_dt.dc.html | Màn · GV-16 Giờ dạy của tôi (báo cáo theo tháng) (dùng chung, bản sao) | 1440×160 |

### GV16 (12)

| File | Tên khung | w×h |
|---|---|---|
| GV16_pc.dc.html | GV-16 · Giờ dạy của tôi (laptop) | 1440×900 |
| GV16_trong_bs_pc.dc.html | GV-16 · Giờ dạy của tôi · tháng chưa có buổi (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV16_tai_bs_pc.dc.html | GV-16 · Giờ dạy của tôi · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV16_quyen_bs_pc.dc.html | GV-16 · Giờ dạy của tôi · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV16_loi_bs_pc.dc.html | GV-16 · Giờ dạy của tôi · lỗi mạng (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV16_da_chot_pc.dc.html | GV-16 · Giờ dạy của tôi · tháng đã chốt (laptop) | 1440×900 |
| GV16_dt.dc.html | GV-16 · Giờ dạy của tôi (điện thoại) | 390×844 |
| GV16_trong.dc.html | GV-16 · Giờ dạy của tôi · tháng chưa có buổi (điện thoại) | 390×844 |
| GV16_tai.dc.html | GV-16 · Giờ dạy của tôi · đang tải (điện thoại) | 390×844 |
| GV16_quyen.dc.html | GV-16 · Giờ dạy của tôi · không có quyền (điện thoại) | 390×844 |
| GV16_loi.dc.html | GV-16 · Giờ dạy của tôi · lỗi mạng (điện thoại) | 390×844 |
| GV16_da_chot_dt.dc.html | GV-16 · Giờ dạy của tôi · tháng đã chốt (điện thoại) | 390×844 |

### Man_BUOI03 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_BUOI03.dc.html | Màn · BUOI-03 Điểm danh vận hành trong buổi | 1440×100 |
| Man_BUOI03_bs_dt.dc.html | Màn · BUOI-03 Điểm danh vận hành trong buổi (dùng chung, bản sao) | 1440×100 |

### BUOI03 (8)

| File | Tên khung | w×h |
|---|---|---|
| BUOI03_nhap.dc.html | BUOI-03 · Điểm danh vận hành · đang nhập | 1440×1000 |
| BUOI03_tai.dc.html | BUOI-03 · Điểm danh vận hành · đang tải | 1440×1000 |
| BUOI03_quyen.dc.html | BUOI-03 · Điểm danh vận hành · không có quyền | 1440×1000 |
| BUOI03_done.dc.html | BUOI-03 · Điểm danh vận hành · buổi Hoàn thành (chỉ đọc) | 1440×1000 |
| BUOI03_chua_chot.dc.html | BUOI-03 · Điểm danh vận hành · buổi chưa chốt danh sách | 1440×1000 |
| BUOI03_dt.dc.html | BUOI-03 · Điểm danh vận hành · điện thoại | 390×844 |
| BUOI03_tai_bs_dt.dc.html | BUOI-03 · Điểm danh vận hành · đang tải (dùng chung, bản sao) | 1440×1000 |
| BUOI03_quyen_bs_dt.dc.html | BUOI-03 · Điểm danh vận hành · không có quyền (dùng chung, bản sao) | 1440×1000 |

### Man_LOP08 (2)

| File | Tên khung | w×h |
|---|---|---|
| Man_LOP08.dc.html | Màn · LOP-08 Lịch tuần cơ sở (theo phòng, giáo viên) | 1440×100 |
| Man_LOP08_bs_dt.dc.html | Màn · LOP-08 Lịch tuần cơ sở (theo phòng, giáo viên) (dùng chung, bản sao) | 1440×100 |

### LOP08 (9)

| File | Tên khung | w×h |
|---|---|---|
| LOP08.dc.html | LOP-08 · Lịch tuần cơ sở · ngày, theo phòng (cảnh báo trùng phòng) | 1440×1000 |
| LOP08_trong.dc.html | LOP-08 · Lịch tuần cơ sở · trống | 1440×1000 |
| LOP08_tai.dc.html | LOP-08 · Lịch tuần cơ sở · đang tải | 1440×1000 |
| LOP08_quyen.dc.html | LOP-08 · Lịch tuần cơ sở · không có quyền | 1440×1000 |
| LOP08_gv.dc.html | LOP-08 · Lịch tuần cơ sở · ngày, theo giáo viên (cảnh báo trùng giáo viên) | 1440×1000 |
| LOP08_tuan.dc.html | LOP-08 · Lịch tuần cơ sở · xem tuần | 1440×1000 |
| LOP08_trong_bs_dt.dc.html | LOP-08 · Lịch tuần cơ sở · trống (dùng chung, bản sao) | 1440×1000 |
| LOP08_tai_bs_dt.dc.html | LOP-08 · Lịch tuần cơ sở · đang tải (dùng chung, bản sao) | 1440×1000 |
| LOP08_quyen_bs_dt.dc.html | LOP-08 · Lịch tuần cơ sở · không có quyền (dùng chung, bản sao) | 1440×1000 |

### GV07b (12)

| File | Tên khung | w×h |
|---|---|---|
| GV07b_cap2_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới Cấp 2, 7 tiêu chí (điện thoại, bản nháp) | 390×844 |
| GV07b_cap2_du_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới Cấp 2 · đủ mục bắt buộc (điện thoại, bản nháp) | 390×844 |
| GV07b_cap1_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới Cấp 1, 9 tiêu chí theo file (điện thoại, bản nháp) | 390×844 |
| GV07b_cap3_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới Cấp 3, 9 tiêu chí (điện thoại, bản nháp) | 390×844 |
| GV07b_mo_ta_dt.dc.html | GV-07 · Chấm nhận xét · ngăn xem mô tả 5 mức (điện thoại, bản nháp) | 390×844 |
| GV07b_tai_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · đang tải tiêu chí (điện thoại, bản nháp) | 390×844 |
| GV07b_loi_mang_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · lỗi mạng, thử lại (điện thoại, bản nháp) | 390×844 |
| GV07b_bo_qua_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · một tiêu chí đang Bỏ qua (điện thoại, bản nháp) | 390×844 |
| GV07b_luu_thieu_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · bấm Lưu khi còn thiếu (điện thoại, bản nháp) | 390×844 |
| GV07b_loi_nhan_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · cuối danh sách, lời nhắn phụ huynh (điện thoại, bản nháp) | 390×844 |
| GV07b_dang_luu_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · đang lưu (điện thoại, bản nháp) | 390×844 |
| GV07b_loi_luu_dt.dc.html | GV-07 · Chấm nhận xét · bộ mới · lỗi khi lưu, thử lại (điện thoại, bản nháp) | 390×844 |

### GV08b (11)

| File | Tên khung | w×h |
|---|---|---|
| GV08b_ds_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · danh sách em theo trạng thái (điện thoại, bản nháp) | 390×844 |
| GV08b_cap3_dt.dc.html | GV-08 · Chấm BTVN · bộ mới Cấp 3, 15 tiêu chí, còn thiếu điểm bài làm (điện thoại, bản nháp) | 390×844 |
| GV08b_cap3_du_dt.dc.html | GV-08 · Chấm BTVN · bộ mới Cấp 3 · đủ mục bắt buộc, nộp muộn có gia hạn (điện thoại, bản nháp) | 390×844 |
| GV08b_o_rieng_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · ba ô riêng cuối danh sách (điện thoại, bản nháp) | 390×844 |
| GV08b_tu_xep_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · ngăn dưới giải thích cách xếp mức Thời gian nộp (điện thoại, bản nháp) | 390×844 |
| GV08b_gia_han_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · ghi nhận gia hạn nộp bài, chờ luật (điện thoại, bản nháp) | 390×844 |
| GV08b_cap2_dt.dc.html | GV-08 · Chấm BTVN · bộ mới Cấp 2, 8 tiêu chí (điện thoại, bản nháp) | 390×844 |
| GV08b_khong_giao_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · buổi trước không giao BTVN (điện thoại, bản nháp) | 390×844 |
| GV08b_tai_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · đang tải (điện thoại, bản nháp) | 390×844 |
| GV08b_loi_mang_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · lỗi mạng, thử lại (điện thoại, bản nháp) | 390×844 |
| GV08b_khong_cham_dt.dc.html | GV-08 · Chấm BTVN · bộ mới · Không làm, Nộp sau, Không áp dụng: không chấm tiêu chí (điện thoại, bản nháp) | 390×844 |
