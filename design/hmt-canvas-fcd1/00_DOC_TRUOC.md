# HMT Đào tạo & Giáo viên · gói canvas cho Code

- **Số bản canvas:** `1793782759-fcd1` (v41, đăng 04/11/2026 sau "OK ĐĂNG" 15:57)
- **Bản mốc quay lại:** v40 `1793782081-f258`; xa hơn là v38 `1793778252-2119`
- **Ngày xuất gói:** 04/11/2026
- **Canvas:** HMT Đào tạo & Giáo viên (claude.ai/artifact/2o4UUZQ7YSJH1f9EiUaxvY).
- **Nội dung gói:** 339 file khung `*.dc.html` + `canvas.json` + `assets/hmt-logo.svg` + 3 file token/CSS của hệ thiết kế (`ds/hmt/`).
- **Đối chiếu:** `canvas.json` (trong gói, đã bỏ 23 khung nháp) sha256 `a2a4451678237ac850dd92720872ee1757824cb083b3ba9cd1bf6b6fd93ef297`.
- **Không nằm trong gói:** 23 khung nháp GV07b, GV08b (xem dưới). Canvas có 362 khung; gói có 339.

## Phạm vi
Cổng Giáo viên GV-01..16, BUOI-03, BUOI-07..09, LOP-08, bộ khuôn KG, nhóm Aftersale CSN (CSN01..09), và nhóm **GV07X** (xuất nhận xét cho phụ huynh, 15 khung, mới).
Không có: GV-17, GV-18 (chưa dựng). Các màn khác nằm ở canvas HMT Platform.

## Điểm cần Code biết (chốt đến 04/11/2026)
1. **GV07X xuất nhận xét gửi phụ huynh (phase này):** giáo viên xuất PDF hoặc ảnh rồi **tự gửi tay** vào group Zalo lớp chung (có tất cả phụ huynh). Không có nút Chia sẻ/mở Zalo trên điện thoại. Không có dòng "chỉ gửi riêng".
2. **File xuất tạo ngay trên trình duyệt, không lưu lên máy chủ.**
3. Buổi thường: không hiện điểm trung bình tiêu chí. Buổi kiểm tra: không hiện điểm trung bình lớp, không xếp hạng.
4. Xuất được ngay khi em đó đã lưu đủ, không chờ Done. Dấu "Đã xuất" chỉ để nhìn, không ràng buộc nghiệp vụ.
5. Xuất từng em, và cả lớp (PDF một file; ảnh nén một file).
6. **Lời nhắn phụ huynh:** mẫu câu cố định, giáo viên sửa tay, **không dùng AI**. Mỗi loại buổi có 4 mức × 3 câu (giọng trung tính vì group Zalo lớp chung có tất cả phụ huynh). Khung mẫu thấy ở `GV07X_hop_thoai_pc` và `GV07X_xem_truoc_dt`. Bộ câu đầy đủ ghi trong `NHAT_KY_BAN_GIAO_v41.md`.
   - **Mức gợi ý (anh chốt 04/11):** buổi thường: trung bình điểm các tiêu chí đã đánh giá (thang 1–5; không tính Chưa đánh giá, Chưa đủ căn cứ, Không áp dụng): Xuất sắc từ 4,5; Tốt từ 3,5 đến dưới 4,5; Đạt từ 2,5 đến dưới 3,5; Cần cố gắng dưới 2,5. Buổi kiểm tra: điểm tổng ÷ điểm tối đa: Xuất sắc từ 90%; Tốt từ 75% đến dưới 90%; Đạt từ 50% đến dưới 75%; Cần cố gắng dưới 50%.
   - Mức chỉ để gợi ý 3 câu; giáo viên chọn mức khác và sửa tay. **Điểm trung bình chỉ dùng nội bộ, không hiện cho phụ huynh.**
7. **Gửi tự động từng phụ huynh: phase sau, chưa vẽ, chưa làm.**
8. **CS-16 "Nhận xét chờ gửi PH" đã bỏ** (anh 04/11, CSKH không tham gia): 7 khung CS16 và 2 khung CSN06f đã gỡ khỏi canvas và khỏi gói.
9. Công tắc tiêu chí (GV-07) chỉ là **ô tick tạm**, chưa có kiểu công tắc riêng.
10. **GV07b, GV08b (bản nháp, CHƯA LÀM):** chờ đổi luật R-GV-01 / R-GV-04. Còn trên canvas, tên khung có tiền tố "NHÁP, CHƯA LÀM", **không nằm trong gói**.
11. Điều chỉnh học phí trong nhóm CSN: không có trong tài liệu gốc, đã gỡ.

## Tình trạng duyệt (theo Mục lục `Main.dc.html`)
| Mã | Tình trạng |
|---|---|
| LOP-08, BUOI-03 | đợt 1 |
| GV-01..04, 09 | duyệt 23/10; sửa 24/10 |
| GV-05..08 | duyệt 24/10; sửa 24/10 |
| GV-10..14 | duyệt 24/10 |
| GV-15 | theo QĐ-Đ25, duyệt 24/10 |
| GV-16 | chờ duyệt (12 khung) |
| KG | duyệt 23/10 và 24/10 |
| GV07X | anh duyệt hướng 04/11, khung đăng v40, chờ anh xem |
| CSN | xem Mục lục; CS-16 đã bỏ |

## Cách đọc
1. Mỗi file `.dc.html` là một khung. Cần `support.js` của Claude Design để mở đúng hình (không nằm trong gói); không có thì đọc mã HTML/CSS. CSS dùng chung ở `ds/hmt/...`, logo ở `assets/`.
2. `canvas.json` ghi tên, vị trí (x, y), kích thước (w, h). Hậu tố `_pc` là laptop, `_dt` là điện thoại, `_quyen` là không có quyền, `_tai` là đang tải, `_trong` là trống.
3. **Nhóm GV07X nằm cuối canvas**, từ y ≈ 101.614 trở xuống: hàng 1 là 4 mẫu file xuất (A4 thường, A4 kiểm tra, ảnh thường, ảnh kiểm tra); hàng 2 là các khung laptop; hàng 3 là các khung điện thoại.
4. `Main.dc.html` là Mục lục mã màn. `Man_*` là nhãn từng màn.
5. Dữ liệu trong khung là dữ liệu giả.

## Danh sách khung (339)

### Main (1)

| File | Tên khung | w×h |
|---|---|---|
| Main.dc.html | Mục lục mã màn theo canvas | 1440×1200 |

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

### Man (36)

| File | Tên khung | w×h |
|---|---|---|
| Man_GV01.dc.html | Màn · GV-01 Khung cổng giáo viên | 1440×100 |
| Man_GV02.dc.html | Màn · GV-02 Hôm nay | 1440×130 |
| Man_GV03.dc.html | Màn · GV-03 Lịch dạy | 1440×100 |
| Man_GV04.dc.html | Màn · GV-04 Buổi dạy (các bước cần làm) | 1440×160 |
| Man_GV05.dc.html | Màn · GV-05 Điểm danh (4 trạng thái) | 1440×130 |
| Man_GV06.dc.html | Màn · GV-06 Nội dung buổi và giao BTVN | 1440×160 |
| Man_GV07.dc.html | Màn · GV-07 Chấm nhận xét từng em | 1440×130 |
| Man_GV08.dc.html | Màn · GV-08 Chấm BTVN của buổi trước (5 trạng thái) | 1440×160 |
| Man_GV09.dc.html | Màn · GV-09 Kiểm còn thiếu, dấu thời hạn (hộp thoại) | 1440×130 |
| Man_GV10.dc.html | Màn · GV-10 Lớp của tôi (danh sách thẻ) | 1440×100 |
| Man_GV11.dc.html | Màn · GV-11 Lớp chi tiết cho giáo viên | 1440×100 |
| Man_GV12.dc.html | Màn · GV-12 Cần làm, quá hạn | 1440×130 |
| Man_GV13.dc.html | Màn · GV-13 Học sinh, hồ sơ rút gọn | 1440×100 |
| Man_GV14.dc.html | Màn · GV-14 Tạo ticket và ticket lớp tôi | 1440×100 |
| Man_GV15.dc.html | Màn · GV-15 Chấm kiểm tra đầu vào (bản tối giản giai đoạn 1) | 1440×130 |
| Man_GV16.dc.html | Màn · GV-16 Giờ dạy của tôi (báo cáo theo tháng) | 1440×160 |
| Man_BUOI03.dc.html | Màn · BUOI-03 Điểm danh vận hành trong buổi | 1440×100 |
| Man_LOP08.dc.html | Màn · LOP-08 Lịch tuần cơ sở (theo phòng, giáo viên) | 1440×100 |
| Man_GV01_bs_dt.dc.html | Màn · GV-01 Khung cổng giáo viên (dùng chung, bản sao) | 1440×100 |
| Man_GV02_bs_dt.dc.html | Màn · GV-02 Hôm nay (dùng chung, bản sao) | 1440×130 |
| Man_GV03_bs_dt.dc.html | Màn · GV-03 Lịch dạy (dùng chung, bản sao) | 1440×100 |
| Man_GV04_bs_dt.dc.html | Màn · GV-04 Buổi dạy (các bước cần làm) (dùng chung, bản sao) | 1440×160 |
| Man_GV05_bs_dt.dc.html | Màn · GV-05 Điểm danh (4 trạng thái) (dùng chung, bản sao) | 1440×130 |
| Man_GV06_bs_dt.dc.html | Màn · GV-06 Nội dung buổi và giao BTVN (dùng chung, bản sao) | 1440×160 |
| Man_GV07_bs_dt.dc.html | Màn · GV-07 Chấm nhận xét từng em (dùng chung, bản sao) | 1440×130 |
| Man_GV08_bs_dt.dc.html | Màn · GV-08 Chấm BTVN của buổi trước (5 trạng thái) (dùng chung, bản sao) | 1440×160 |
| Man_GV09_bs_dt.dc.html | Màn · GV-09 Kiểm còn thiếu, dấu thời hạn (hộp thoại) (dùng chung, bản sao) | 1440×130 |
| Man_GV10_bs_dt.dc.html | Màn · GV-10 Lớp của tôi (danh sách thẻ) (dùng chung, bản sao) | 1440×100 |
| Man_GV11_bs_dt.dc.html | Màn · GV-11 Lớp chi tiết cho giáo viên (dùng chung, bản sao) | 1440×100 |
| Man_GV12_bs_dt.dc.html | Màn · GV-12 Cần làm, quá hạn (dùng chung, bản sao) | 1440×130 |
| Man_GV13_bs_dt.dc.html | Màn · GV-13 Học sinh, hồ sơ rút gọn (dùng chung, bản sao) | 1440×100 |
| Man_GV14_bs_dt.dc.html | Màn · GV-14 Tạo ticket và ticket lớp tôi (dùng chung, bản sao) | 1440×100 |
| Man_GV15_bs_dt.dc.html | Màn · GV-15 Chấm kiểm tra đầu vào (bản tối giản giai đoạn 1) (dùng chung, bản sao) | 1440×130 |
| Man_GV16_bs_dt.dc.html | Màn · GV-16 Giờ dạy của tôi (báo cáo theo tháng) (dùng chung, bản sao) | 1440×160 |
| Man_BUOI03_bs_dt.dc.html | Màn · BUOI-03 Điểm danh vận hành trong buổi (dùng chung, bản sao) | 1440×100 |
| Man_LOP08_bs_dt.dc.html | Màn · LOP-08 Lịch tuần cơ sở (theo phòng, giáo viên) (dùng chung, bản sao) | 1440×100 |

### GV01 (4)

| File | Tên khung | w×h |
|---|---|---|
| GV01_pc.dc.html | GV-01 · Khung cổng giáo viên · laptop, menu trái thu gọn | 1440×900 |
| GV01_quyen_bs_pc.dc.html | GV-01 · Khung cổng giáo viên · điện thoại, không có quyền (dùng chung, bản sao) | 390×844 |
| GV01_dt.dc.html | GV-01 · Khung cổng giáo viên · điện thoại, thanh tab dưới | 390×844 |
| GV01_quyen.dc.html | GV-01 · Khung cổng giáo viên · điện thoại, không có quyền | 390×844 |

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

### GV06 (13)

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
| GV06_btvn_de_trong_dt.dc.html | GV-06 · Nội dung buổi và BTVN · để trống BTVN vẫn lưu (điện thoại) | 390×844 |
| GV06_sau_cham_dt.dc.html | GV-06 · Nội dung buổi và BTVN · đã chấm vận dụng, sửa nội dung (điện thoại) | 390×844 |
| GV06_kiem_tra_dt.dc.html | GV-06 · Buổi kiểm tra: phạm vi kiến thức (điện thoại) | 390×844 |
| GV06_kiem_tra_pc.dc.html | GV-06 · Buổi kiểm tra: phạm vi kiến thức (laptop) | 1440×900 |

### GV07 (19)

| File | Tên khung | w×h |
|---|---|---|
| GV07_pc.dc.html | GV-07 · Chấm nhận xét (laptop, danh sách em + thẻ chấm) | 1440×900 |
| GV07_trong_bs_pc.dc.html | GV-07 · Chấm nhận xét · chưa có em có mặt (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV07_tai_bs_pc.dc.html | GV-07 · Chấm nhận xét · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV07_quyen_bs_pc.dc.html | GV-07 · Chấm nhận xét · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV07_chua_dd_pc.dc.html | GV-07 · Chấm nhận xét · em chưa điểm danh (laptop, danh sách em + thẻ chấm) | 1440×900 |
| GV07_xung_dot_pc.dc.html | GV-07 · Chấm nhận xét · hai người cùng sửa một ô (laptop, danh sách em + thẻ chấm) | 1440×900 |
| GV07_dt.dc.html | GV-07 · Chấm nhận xét · từng em (điện thoại) | 390×844 |
| GV07_trong.dc.html | GV-07 · Chấm nhận xét · chưa có em có mặt (điện thoại) | 390×844 |
| GV07_tai.dc.html | GV-07 · Chấm nhận xét · đang tải (điện thoại) | 390×844 |
| GV07_quyen.dc.html | GV-07 · Chấm nhận xét · không có quyền (điện thoại) | 390×844 |
| GV07_vang_dt.dc.html | GV-07 · Chấm nhận xét · em vắng, không chấm (điện thoại) | 390×844 |
| GV07_chua_dd_dt.dc.html | GV-07 · Chấm nhận xét · em chưa điểm danh (điện thoại) | 390×844 |
| GV07_xung_dot_dt.dc.html | GV-07 · Chấm nhận xét · hai người cùng sửa một ô (điện thoại) | 390×844 |
| GV07_tieu_chi_dt.dc.html | GV-07 · Chấm nhận xét · công tắc tiêu chí của buổi (điện thoại) | 390×844 |
| GV07_cot_dt.dc.html | GV-07 · Chấm nhận xét · chấm theo cột + Cả lớp mức 3 (điện thoại) | 390×844 |
| GV07_o_4_trang_thai_dt.dc.html | GV-07 · Chấm nhận xét · từng em, 4 trạng thái ô (điện thoại) | 390×844 |
| GV07_tieu_chi_pc.dc.html | GV-07 · Chấm nhận xét · công tắc tiêu chí của buổi (laptop) | 1440×900 |
| GV07_cot_pc.dc.html | GV-07 · Chấm nhận xét · chấm theo cột + Cả lớp mức 3 (laptop) | 1440×900 |
| GV07_o_4_trang_thai_pc.dc.html | GV-07 · Chấm nhận xét · từng em, 4 trạng thái ô (laptop) | 1440×900 |

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

### GV09 (6)

| File | Tên khung | w×h |
|---|---|---|
| GV09_thieu_pc.dc.html | GV-09 · Kiểm còn thiếu · còn thiếu, laptop | 1440×900 |
| GV09_du_pc.dc.html | GV-09 · Kiểm còn thiếu · đủ, đóng dấu Trễ hạn, laptop | 1440×900 |
| GV09_thieu_btvn_pc.dc.html | GV-09 · Kiểm còn thiếu · chưa chọn BTVN giao mới (laptop) | 1440×900 |
| GV09_thieu_dt.dc.html | GV-09 · Kiểm còn thiếu · còn thiếu, điện thoại | 390×844 |
| GV09_du_dt.dc.html | GV-09 · Kiểm còn thiếu · đủ, đóng dấu Đúng hạn, điện thoại | 390×844 |
| GV09_thieu_btvn_dt.dc.html | GV-09 · Kiểm còn thiếu · chưa chọn BTVN giao mới (điện thoại) | 390×844 |

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

### GV14 (10)

| File | Tên khung | w×h |
|---|---|---|
| GV14_pc.dc.html | GV-14 · Tạo ticket và ticket lớp tôi, 3 loại (laptop) | 1440×900 |
| GV14_trong_bs_pc.dc.html | GV-14 · Ticket · trống (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV14_tai_bs_pc.dc.html | GV-14 · Ticket · đang tải (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV14_quyen_bs_pc.dc.html | GV-14 · Ticket · không có quyền (điện thoại) (dùng chung, bản sao) | 390×844 |
| GV14_dt.dc.html | GV-14 · Tạo ticket và ticket lớp tôi, 3 loại (điện thoại) | 390×844 |
| GV14_trong.dc.html | GV-14 · Ticket · trống (điện thoại) | 390×844 |
| GV14_tai.dc.html | GV-14 · Ticket · đang tải (điện thoại) | 390×844 |
| GV14_quyen.dc.html | GV-14 · Ticket · không có quyền (điện thoại) | 390×844 |
| GV14_tk_giao_vien_dt.dc.html | GV-14 · Tạo Ticket giáo viên, có Tính chất chỉ đọc (điện thoại) | 390×844 |
| GV14_tk_giao_vien_pc.dc.html | GV-14 · Tạo Ticket giáo viên, có Tính chất chỉ đọc (laptop) | 1440×900 |

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

### GV07K (12)

| File | Tên khung | w×h |
|---|---|---|
| GV07K_3nhom_dt.dc.html | GV-07K · Chấm kiểm tra, 3 nhóm điểm, vượt điểm tối đa (điện thoại) | 390×844 |
| GV07K_3nhom_pc.dc.html | GV-07K · Chấm kiểm tra, 3 nhóm điểm (laptop) | 1440×900 |
| GV07K_chua_dd_dt.dc.html | GV-07K · Chấm kiểm tra, chưa điểm danh (điện thoại) | 390×844 |
| GV07K_chua_dd_pc.dc.html | GV-07K · Chấm kiểm tra, chưa điểm danh (laptop) | 1440×900 |
| GV07K_done_dt.dc.html | GV-07K · Buổi kiểm tra đã Done, chỉ xem (điện thoại) | 390×844 |
| GV07K_done_pc.dc.html | GV-07K · Buổi kiểm tra đã Done, chỉ xem (laptop) | 1440×900 |
| GV07K_loi_luu_dt.dc.html | GV-07K · Chấm kiểm tra, lỗi lưu (điện thoại) | 390×844 |
| GV07K_loi_luu_pc.dc.html | GV-07K · Chấm kiểm tra, lỗi lưu (laptop) | 1440×900 |
| GV07K_tong_dt.dc.html | GV-07K · Chấm kiểm tra, điểm tổng (điện thoại) | 390×844 |
| GV07K_tong_pc.dc.html | GV-07K · Chấm kiểm tra, điểm tổng (laptop) | 1440×900 |
| GV07K_vang_dt.dc.html | GV-07K · Chấm kiểm tra, em vắng (điện thoại) | 390×844 |
| GV07K_xong_pc.dc.html | GV-07K · Chấm kiểm tra, đã chấm đủ (laptop) | 1440×900 |

### BUOI07 (3)

| File | Tên khung | w×h |
|---|---|---|
| BUOI07_bs_loai_buoi_thuong.dc.html | BUOI-07 bổ sung · Loại buổi · loại Buổi học | 1440×1250 |
| BUOI07_bs_loai_kiem_tra.dc.html | BUOI-07 bổ sung · Loại buổi · loại Kiểm tra, 3 nhóm điểm | 1440×1250 |
| BUOI07_bs_loai_kiem_tra_loi_tong.dc.html | BUOI-07 bổ sung · Loại buổi · Kiểm tra, lỗi lệch tổng 3 nhóm | 1440×1250 |

### BUOI08 (3)

| File | Tên khung | w×h |
|---|---|---|
| BUOI08_bs_loai_buoi_thuong.dc.html | BUOI-08 bổ sung · Loại buổi · loại Buổi học | 1440×1250 |
| BUOI08_bs_loai_kiem_tra.dc.html | BUOI-08 bổ sung · Loại buổi · loại Kiểm tra, 3 nhóm điểm | 1440×1250 |
| BUOI08_bs_loai_kiem_tra_loi_tong.dc.html | BUOI-08 bổ sung · Loại buổi · Kiểm tra, lỗi lệch tổng 3 nhóm | 1440×1250 |

### BUOI09 (3)

| File | Tên khung | w×h |
|---|---|---|
| BUOI09_bs_loai_buoi_thuong.dc.html | BUOI-09 bổ sung · Loại buổi · loại Buổi học | 1440×1250 |
| BUOI09_bs_loai_kiem_tra.dc.html | BUOI-09 bổ sung · Loại buổi · loại Kiểm tra, 3 nhóm điểm | 1440×1250 |
| BUOI09_bs_loai_kiem_tra_loi_tong.dc.html | BUOI-09 bổ sung · Loại buổi · Kiểm tra, lỗi lệch tổng 3 nhóm | 1440×1250 |

### DM (1)

| File | Tên khung | w×h |
|---|---|---|
| DM_loai_buoi_form.dc.html | Danh mục chung · Form thêm/sửa loại buổi (chọn form nhận xét) | 1440×900 |

### CSN01 (9)

| File | Tên khung | w×h |
|---|---|---|
| CSN01_cho_dong.dc.html | CSN-01 · Danh sách ticket · Chờ đóng (Đã xử lý quá 3 ngày) | 1440×1000 |
| CSN01_cua_toi.dc.html | CSN-01 · Danh sách ticket · Tất cả, đang lọc Của tôi | 1440×1000 |
| CSN01_ds.dc.html | CSN-01 · Danh sách ticket · Tất cả | 1440×1000 |
| CSN01_dt.dc.html | CSN-01 · Danh sách ticket (điện thoại) | 390×844 |
| CSN01_loi.dc.html | CSN-01 · Danh sách ticket · lỗi mạng | 1440×1000 |
| CSN01_qua_han.dc.html | CSN-01 · Danh sách ticket · Quá hạn | 1440×1000 |
| CSN01_quyen.dc.html | CSN-01 · Danh sách ticket · không có quyền | 1440×1000 |
| CSN01_tai.dc.html | CSN-01 · Danh sách ticket · đang tải | 1440×1000 |
| CSN01_trong.dc.html | CSN-01 · Danh sách ticket · trống | 1440×1000 |

### CSN02 (3)

| File | Tên khung | w×h |
|---|---|---|
| CSN02_kanban.dc.html | CSN-02 · Kanban ticket | 1440×1000 |
| CSN02_tai.dc.html | CSN-02 · Kanban ticket · đang tải | 1440×1000 |
| CSN02_trong.dc.html | CSN-02 · Kanban ticket · trống | 1440×1000 |

### CSN03 (17)

| File | Tên khung | w×h |
|---|---|---|
| CSN03_cho_dong.dc.html | CSN-03 · Form ticket · Đã xử lý, chờ đóng | 1440×1000 |
| CSN03_da_dong.dc.html | CSN-03 · Form ticket · Đã đóng, chỉ xem | 1440×1000 |
| CSN03_de_nghi.dc.html | CSN-03 · Form ticket · Đề nghị thường | 1440×1000 |
| CSN03_dn_nv_chua_phieu.dc.html | CSN-03 · Form ticket · Đề nghị có nghiệp vụ, chưa có phiếu | 1440×1000 |
| CSN03_dn_nv_co_phieu.dc.html | CSN-03 · Form ticket · Đề nghị có nghiệp vụ, đã có phiếu | 1440×1000 |
| CSN03_dt.dc.html | CSN-03 · Form ticket · Ticket giáo viên (điện thoại) | 390×844 |
| CSN03_gv.dc.html | CSN-03 · Form ticket · Ticket giáo viên (Tính chất) | 1440×1000 |
| CSN03_khieu_nai.dc.html | CSN-03 · Form ticket · Khiếu nại | 1440×1000 |
| CSN03_loi_luu.dc.html | CSN-03 · Form ticket · Lỗi lưu | 1440×1000 |
| CSN03_quyen.dc.html | CSN-03 · Form ticket · không có quyền | 1440×1000 |
| CSN03_tai.dc.html | CSN-03 · Form ticket · đang tải | 1440×1000 |
| CSN03_tai_tuc.dc.html | CSN-03 · Form ticket · Đề nghị Tái tục (nút Tạo đơn hàng) | 1440×1000 |
| CSN03_tao_moi.dc.html | CSN-03 · Form ticket · Tạo mới | 1440×1000 |
| CSN03_chuyen_phi.dc.html | CSN-03 · Form ticket · Đề nghị Chuyển phí (nút Tạo đơn hàng) | 1440×1000 |
| CSN03_dn_nv_lam_tay.dc.html | CSN-03 · Form ticket · Đề nghị có nghiệp vụ, làm tay (phiếu chưa làm kịp) | 1440×1000 |
| CSN03_khieu_nai_co_con.dc.html | CSN-03 · Form ticket · Khiếu nại có Đề nghị con (hai ticket liên kết) | 1440×1000 |
| CSN03_de_nghi_con.dc.html | CSN-03 · Form ticket · Đề nghị con, sinh từ Khiếu nại | 1440×1000 |

### CSN04 (6)

| File | Tên khung | w×h |
|---|---|---|
| CSN04_doi_loai.dc.html | CSN-04 · Hộp thoại · Đổi loại ticket khi tiếp nhận | 1440×1000 |
| CSN04_doi_nhom_con.dc.html | CSN-04 · Hộp thoại · Đổi nhóm con, tính chất đổi theo | 1440×1000 |
| CSN04_dong_khieu_nai.dc.html | CSN-04 · Hộp thoại · Đóng khiếu nại (mức hài lòng 1–5) | 1440×1000 |
| CSN04_huy.dc.html | CSN-04 · Hộp thoại · Huỷ ticket (bắt buộc lý do) | 1440×1000 |
| CSN04_mo_lai.dc.html | CSN-04 · Hộp thoại · Mở lại ticket (trong 7 ngày) | 1440×1000 |
| CSN04_lam_tay.dc.html | CSN-04 · Hộp thoại · Đóng ticket làm tay (bắt buộc ghi chú) | 1440×1000 |

### CSN05 (5)

| File | Tên khung | w×h |
|---|---|---|
| CSN05_cho_toi.dc.html | CSN-05 · Phiếu nghiệp vụ · Chờ tôi duyệt | 1440×1000 |
| CSN05_ds.dc.html | CSN-05 · Phiếu nghiệp vụ · Tất cả | 1440×1000 |
| CSN05_quyen.dc.html | CSN-05 · Phiếu nghiệp vụ · không có quyền | 1440×1000 |
| CSN05_tai.dc.html | CSN-05 · Phiếu nghiệp vụ · đang tải | 1440×1000 |
| CSN05_trong.dc.html | CSN-05 · Phiếu nghiệp vụ · trống | 1440×1000 |

### CSN06 (10)

| File | Tên khung | w×h |
|---|---|---|
| CSN06_cho_kt.dc.html | CSN-06 · Phiếu nghiệp vụ · Chờ kế toán duyệt | 1440×1000 |
| CSN06_cho_ql.dc.html | CSN-06 · Phiếu nghiệp vụ · Chờ quản lý cơ sở duyệt | 1440×1000 |
| CSN06_da_duyet.dc.html | CSN-06 · Phiếu nghiệp vụ · Đã duyệt | 1440×1000 |
| CSN06_da_thuc_hien.dc.html | CSN-06 · Phiếu nghiệp vụ · Đã thực hiện | 1440×1000 |
| CSN06_huy.dc.html | CSN-06 · Phiếu nghiệp vụ · Huỷ | 1440×1000 |
| CSN06_loi_luu.dc.html | CSN-06 · Phiếu nghiệp vụ · Lỗi lưu | 1440×1000 |
| CSN06_nhap.dc.html | CSN-06 · Phiếu nghiệp vụ · Nháp (phần chung) | 1440×1000 |
| CSN06_quyen.dc.html | CSN-06 · Phiếu nghiệp vụ · không có quyền | 1440×1000 |
| CSN06_tai.dc.html | CSN-06 · Phiếu nghiệp vụ · đang tải | 1440×1000 |
| CSN06_tu_choi.dc.html | CSN-06 · Phiếu nghiệp vụ · Từ chối (có lý do) | 1440×1000 |

### CSN06a (2)

| File | Tên khung | w×h |
|---|---|---|
| CSN06a_chuyen_co_so.dc.html | CSN-06a · Phần riêng · Chuyển cơ sở | 1440×1000 |
| CSN06a_chuyen_lop.dc.html | CSN-06a · Phần riêng · Chuyển lớp | 1440×1000 |

### CSN06b (3)

| File | Tên khung | w×h |
|---|---|---|
| CSN06b_bao_luu.dc.html | CSN-06b · Phần riêng · Bảo lưu | 1440×1000 |
| CSN06b_gia_han.dc.html | CSN-06b · Phần riêng · Gia hạn bảo lưu | 1440×1000 |
| CSN06b_tiep_tuc.dc.html | CSN-06b · Phần riêng · Tiếp tục học | 1440×1000 |

### CSN06c (2)

| File | Tên khung | w×h |
|---|---|---|
| CSN06c_hoan_phi_cho_kt.dc.html | CSN-06c · Phần riêng · Hoàn học phí đang chờ kế toán | 1440×1000 |
| CSN06c_hoan_phi_tinh.dc.html | CSN-06c · Phần riêng · Hoàn học phí (bảng tính) | 1440×1000 |

### CSN06d (3)

| File | Tên khung | w×h |
|---|---|---|
| CSN06d_chuyen_phi_em.dc.html | CSN-06d · Phần riêng · Chuyển phí sang anh chị em (cùng phụ huynh) | 1440×1000 |
| CSN06d_chuyen_phi_gia.dc.html | CSN-06d · Phần riêng · Chuyển phí sang gói khác (cùng em) | 1440×1000 |
| CSN06d_chuyen_phi_phu_huynh.dc.html | CSN-06d · Phần riêng · Chuyển phí sang anh chị em khác phụ huynh (bắt buộc xác nhận) | 1440×1000 |

### CSN06e (3)

| File | Tên khung | w×h |
|---|---|---|
| CSN06e_cap_nhat_ho_so.dc.html | CSN-06e · Phiếu đơn giản · Cập nhật hồ sơ (không duyệt) | 1440×1000 |
| CSN06e_doi_lich_hoc_bu.dc.html | CSN-06e · Phiếu đơn giản · Đổi lịch / học bù | 1440×1000 |
| CSN06e_dung_hoc.dc.html | CSN-06e · Phiếu đơn giản · Dừng học | 1440×1000 |

### CSN07 (2)

| File | Tên khung | w×h |
|---|---|---|
| CSN07_duyet.dc.html | CSN-07 · Hộp thoại · Duyệt phiếu (cấp 2 kế toán) | 1440×1000 |
| CSN07_tu_choi.dc.html | CSN-07 · Hộp thoại · Từ chối phiếu (bắt buộc lý do) | 1440×1000 |

### CSN08 (7)

| File | Tên khung | w×h |
|---|---|---|
| CSN08_ds.dc.html | CSN-08 · Cấu hình ticket · Danh mục Đề nghị (cây nhóm, sửa ngay trên dòng) | 1440×1000 |
| CSN08_form_nhom_con.dc.html | CSN-08 · Form nhóm con (sửa nhóm con thường) | 1440×1000 |
| CSN08_gv.dc.html | CSN-08 · Cấu hình ticket · Danh mục Ticket giáo viên (tính chất gắn sẵn) | 1440×1000 |
| CSN08_nv_khoa.dc.html | CSN-08 · Form nhóm con NV (khoá loại phiếu, không Ngừng) | 1440×1000 |
| CSN08_quyen.dc.html | CSN-08 · Cấu hình ticket · không có quyền | 1440×1000 |
| CSN08_tai.dc.html | CSN-08 · Cấu hình ticket · đang tải | 1440×1000 |
| CSN08_trong.dc.html | CSN-08 · Cấu hình ticket · trống | 1440×1000 |

### CSN09 (5)

| File | Tên khung | w×h |
|---|---|---|
| CSN09_chua_luu.dc.html | CSN-09 · Cấu hình SLA · có thay đổi chưa lưu | 1440×1000 |
| CSN09_loi_luu.dc.html | CSN-09 · Cấu hình SLA · lỗi lưu | 1440×1000 |
| CSN09_quyen.dc.html | CSN-09 · Cấu hình SLA · không có quyền | 1440×1000 |
| CSN09_sla.dc.html | CSN-09 · Cấu hình SLA | 1440×1000 |
| CSN09_tai.dc.html | CSN-09 · Cấu hình SLA · đang tải | 1440×1000 |

### GV07X (15)

| File | Tên khung | w×h |
|---|---|---|
| GV07X_mau_a4_thuong.dc.html | GV-07X · Mẫu xuất PDF A4 · buổi thường (dữ liệu giả) | 794×1123 |
| GV07X_mau_a4_kiem_tra.dc.html | GV-07X · Mẫu xuất PDF A4 · buổi kiểm tra (dữ liệu giả) | 794×1123 |
| GV07X_mau_anh_thuong.dc.html | GV-07X · Mẫu ảnh gửi Zalo · buổi thường (vẽ nửa cỡ, ra file 1080 px) | 540×1120 |
| GV07X_mau_anh_kiem_tra.dc.html | GV-07X · Mẫu ảnh gửi Zalo · buổi kiểm tra (vẽ nửa cỡ, ra file 1080 px) | 540×1030 |
| GV07X_nut_pc.dc.html | GV-07 · Chấm nhận xét (laptop) · nút Xuất nhận xét, Xuất em này, nhãn Đã xuất | 1440×900 |
| GV07X_hop_thoai_pc.dc.html | GV-07 · Xuất nhận xét · hộp thoại, một em (laptop) | 1440×900 |
| GV07X_ca_lop_pc.dc.html | GV-07 · Xuất nhận xét · hộp thoại, cả lớp, em bị bỏ qua (laptop) | 1440×900 |
| GV07X_dang_tao_pc.dc.html | GV-07 · Xuất nhận xét · đang tạo file (laptop) | 1440×900 |
| GV07X_loi_pc.dc.html | GV-07 · Xuất nhận xét · lỗi tạo file, thử lại (laptop) | 1440×900 |
| GV07X_chua_luu_pc.dc.html | GV-07 · Xuất nhận xét · em còn chưa lưu đủ (laptop) | 1440×900 |
| GV07X_nut_kt_pc.dc.html | GV-07K · Chấm kiểm tra (laptop) · nút Xuất kết quả (mẫu Kết quả buổi kiểm tra) | 1440×900 |
| GV07X_nut_dt.dc.html | GV-07 · Chấm nhận xét (điện thoại) · nút Xuất em này, menu ⋯ Xuất cả lớp, nhãn Đã xuất | 390×844 |
| GV07X_sheet_dt.dc.html | GV-07 · Xuất nhận xét · ngăn chọn phạm vi và định dạng (điện thoại) | 390×844 |
| GV07X_xem_truoc_dt.dc.html | GV-07 · Xuất nhận xét · xem trước toàn màn hình (điện thoại) | 390×844 |
| GV07X_loi_dt.dc.html | GV-07 · Xuất nhận xét · lỗi tạo file, thử lại (điện thoại) | 390×844 |
