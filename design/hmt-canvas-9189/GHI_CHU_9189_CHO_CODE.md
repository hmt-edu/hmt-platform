# GHI CHÚ CHO CODE: canvas Đào tạo & Giáo viên, phiên bản 1794278144-9189

Gói này xuất từ bản đang đăng (version 1794278144-9189): 362 khung, canvas.json, ds/, assets/. Không khung nào bị sửa; chỉ thêm file ghi chú này. Kiểm bằng file, chưa xem trên trình duyệt.

Thứ tự đọc: (1) mục "NHÁP, CHƯA LÀM", (2) "Vênh luật, Code làm theo luật", (3) "So với fcd1", (4) "Chưa so". Khi khung vẽ vênh luật: làm theo luật (docs/spec/), ghi chỗ vênh vào PR, không tự chọn.

## A. NHÁP, CHƯA LÀM: Code KHÔNG làm 23 khung này

23 khung GV07b_* và GV08b_* tự ghi "NHÁP, CHƯA LÀM". Code không dựng màn theo các khung này:

- `GV07b_bo_qua_dt`
- `GV07b_cap1_dt`
- `GV07b_cap2_dt`
- `GV07b_cap2_du_dt`
- `GV07b_cap3_dt`
- `GV07b_dang_luu_dt`
- `GV07b_loi_luu_dt`
- `GV07b_loi_mang_dt`
- `GV07b_loi_nhan_dt`
- `GV07b_luu_thieu_dt`
- `GV07b_mo_ta_dt`
- `GV07b_tai_dt`
- `GV08b_cap2_dt`
- `GV08b_cap3_dt`
- `GV08b_cap3_du_dt`
- `GV08b_ds_dt`
- `GV08b_gia_han_dt`
- `GV08b_khong_cham_dt`
- `GV08b_khong_giao_dt`
- `GV08b_loi_mang_dt`
- `GV08b_o_rieng_dt`
- `GV08b_tai_dt`
- `GV08b_tu_xep_dt`

## B. Vênh luật, Code làm theo luật

1. **GV-02 không hiện buổi quá hạn** (R-V2-37: buổi quá hạn nằm ở GV-12). Khung GV02_dt, GV02_pc, GV02_trong và ghi chú Man_GV02 đang vẽ nhóm «VIỆC SẮP TRỄ HẠN / QUÁ HẠN» kèm buổi quá hạn 47 giờ: làm theo luật, GV-02 chỉ hiện việc sắp trễ hạn.
2. **BTVN ở GV-04, GV-06, GV-08 là tuỳ giáo viên** (R-V2-35): để trống = không giao. KHÔNG có ô tích «không giao BTVN». Không bắt buộc nhập BTVN để bước 2 tính Xong.
   - Khung `GV06_trong` vẽ theo luật cũ (có dấu *, «Nhập BTVN giao mới hoặc tích Buổi này không giao BTVN», «Phải nhập BTVN... (R-GIO-06)»): bỏ, làm theo R-V2-35.
   - Ghi chú của `Man_GV04`, `Man_GV06`, `Man_GV08` cũng viết theo luật cũ (ô «Buổi này không giao BTVN», «Mỗi buổi phải nhập BTVN giao mới hoặc tích không giao», chữ «BTVN đã nhập» / «Không giao BTVN»): làm theo R-V2-35.
   - Các khung GV04_*, GV06_*, GV08_* còn chữ hay nút theo luật cũ cũng làm theo R-V2-35. Khung GV04_khong_btvn*, GV04_khong_btvn_xong* và GV08_vang_giao_*, GV08_trong nói về «không giao BTVN»: đối chiếu R-V2-35 trước khi làm, vênh thì theo luật.

## C. Chưa so

Chưa so với fcd1: GV-03, GV-09, GV-10, GV-11, GV-12, GV-13, GV-14, GV-15, GV-16, và canvas.json ngoài tiêu đề. Các màn này làm theo luật và `docs/design/ban-do-man-hinh.md`; khung chỉ để tham khảo giao diện.

## D. So với fcd1

(Dán nguyên văn danh sách từ file DS_khac_biet_GV_9189_vs_fcd1.md.)

---

# So canvas Đào tạo & Giáo viên: bản hiện hành 1794278144-9189 với bản zip fcd1 (04/11), chỉ GV-01, 02, 04, 05, 06, 07, 08

Kiểm bằng file (so từng khung bằng máy), chưa xem trên trình duyệt. Chỉ liệt kê, không sửa.

- Khung giống hệt: 85. Khung đổi: 39. Khung thêm: 23. Khung bớt: 0.

## 1. Khung THÊM (23 khung, đều điện thoại, tiêu đề ghi "NHÁP, CHƯA LÀM")

- `GV07b_bo_qua_dt`: GV-07 · Chấm nhận xét · bộ mới · một tiêu chí đang Bỏ qua (điện thoại)
- `GV07b_cap1_dt`: GV-07 · Chấm nhận xét · bộ mới Cấp 1, 9 tiêu chí theo file (điện thoại)
- `GV07b_cap2_dt`: GV-07 · Chấm nhận xét · bộ mới Cấp 2, 7 tiêu chí (điện thoại)
- `GV07b_cap2_du_dt`: GV-07 · Chấm nhận xét · bộ mới Cấp 2 · đủ mục bắt buộc (điện thoại)
- `GV07b_cap3_dt`: GV-07 · Chấm nhận xét · bộ mới Cấp 3, 9 tiêu chí (điện thoại)
- `GV07b_dang_luu_dt`: GV-07 · Chấm nhận xét · bộ mới · đang lưu (điện thoại)
- `GV07b_loi_luu_dt`: GV-07 · Chấm nhận xét · bộ mới · lỗi khi lưu, thử lại (điện thoại)
- `GV07b_loi_mang_dt`: GV-07 · Chấm nhận xét · bộ mới · lỗi mạng, thử lại (điện thoại)
- `GV07b_loi_nhan_dt`: GV-07 · Chấm nhận xét · bộ mới · cuối danh sách, lời nhắn phụ huynh (điện thoại)
- `GV07b_luu_thieu_dt`: GV-07 · Chấm nhận xét · bộ mới · bấm Lưu khi còn thiếu (điện thoại)
- `GV07b_mo_ta_dt`: GV-07 · Chấm nhận xét · ngăn xem mô tả 5 mức (điện thoại)
- `GV07b_tai_dt`: GV-07 · Chấm nhận xét · bộ mới · đang tải tiêu chí (điện thoại)
- `GV08b_cap2_dt`: GV-08 · Chấm BTVN · bộ mới Cấp 2, 8 tiêu chí (điện thoại)
- `GV08b_cap3_dt`: GV-08 · Chấm BTVN · bộ mới Cấp 3, 15 tiêu chí, còn thiếu điểm bài làm (điện thoại)
- `GV08b_cap3_du_dt`: GV-08 · Chấm BTVN · bộ mới Cấp 3 · đủ mục bắt buộc, nộp muộn có gia hạn (điện thoại)
- `GV08b_ds_dt`: GV-08 · Chấm BTVN · bộ mới · danh sách em theo trạng thái (điện thoại)
- `GV08b_gia_han_dt`: GV-08 · Chấm BTVN · bộ mới · ghi nhận gia hạn nộp bài, chờ luật (điện thoại)
- `GV08b_khong_cham_dt`: GV-08 · Chấm BTVN · bộ mới · Không làm, Nộp sau, Không áp dụng: không chấm tiêu chí (điện thoại)
- `GV08b_khong_giao_dt`: GV-08 · Chấm BTVN · bộ mới · buổi trước không giao BTVN (điện thoại)
- `GV08b_loi_mang_dt`: GV-08 · Chấm BTVN · bộ mới · lỗi mạng, thử lại (điện thoại)
- `GV08b_o_rieng_dt`: GV-08 · Chấm BTVN · bộ mới · ba ô riêng cuối danh sách (điện thoại)
- `GV08b_tai_dt`: GV-08 · Chấm BTVN · bộ mới · đang tải (điện thoại)
- `GV08b_tu_xep_dt`: GV-08 · Chấm BTVN · bộ mới · ngăn dưới giải thích cách xếp mức Thời gian nộp (điện thoại)

**Lưu ý:** cả 23 khung này tự ghi "NHÁP, CHƯA LÀM", Code không làm theo. GV07b là bộ tiêu chí chấm nhận xét mới (Cấp 1: 9 tiêu chí, Cấp 2: 7, Cấp 3: 9; ngăn mô tả 5 mức). GV08b là bộ tiêu chí chấm BTVN mới (Cấp 2: 8, Cấp 3: 15; ba ô riêng cuối danh sách; gia hạn nộp bài "chờ luật").

## 2. Khung ĐỔI có thay đổi chữ, nút, trường (đã bỏ chi tiết kỹ thuật)

### GV02_dt
- -VIỆC SẮP TRỄ HẠN
- +VIỆC SẮP TRỄ HẠN / QUÁ HẠN
- +Mở buổi (màn GV-04).
- +Hình 9 · cơ bản A · Buổi 5
- +Kết thúc 22/10 15:30 · hạn 22/10 23:30
- +Quá hạn 47 giờ
### GV02_pc
- -VIỆC SẮP TRỄ HẠN
- +VIỆC SẮP TRỄ HẠN / QUÁ HẠN
- +Mở buổi (màn GV-04).
- +Hình 9 · cơ bản A · Buổi 5
- +Kết thúc 22/10 15:30 · hạn 22/10 23:30
- +Quá hạn 47 giờ
### GV02_trong
- -Không có việc sắp trễ hạn. Buổi tiếp theo: Thứ Hai 26/10 19:30.
- +Không có việc sắp trễ hạn hay quá hạn. Buổi tiếp theo: Thứ Hai 26/10 19:30.
### GV04_chua_chot
- -Chưa có dòng điểm danh nên chưa điểm danh, chưa chấm được. Giáo viên không tạo dòng điểm danh (R-GV-08, R-GIO-02).
- +Chưa có dòng điểm danh nên chưa điểm danh, chưa chấm được. Giáo viên không tạo dòng điểm danh (R-GV-08, R-GIO-02). Danh sách sẽ được hệ thống chốt trước giờ học.
### GV04_dt
- -Đã nhập 3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
- -3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
### GV04_dung_han
- -Đã nhập 3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
- -3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
### GV04_pc
- -Đại số 9 · cơ bản A · Buổi 5 · 24/10 18:00–19:30
- +ĐẠI SỐ 9 · CƠ BẢN A
- +Buổi 5
- +24/10 18:00–19:30
- -Đã nhập 3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
- -3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
### GV04_tre_han
- -Đã nhập 3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
- -3 dòng nội dung
- +3 dòng nội dung · BTVN đã nhập
### GV05_chua_chot
- -Danh sách tự chốt trước giờ học 2 giờ. Khi chốt xong, các em hiện ở đây.
- +Danh sách sẽ được hệ thống chốt trước giờ học. Khi chốt xong, các em hiện ở đây.
### GV05_done_dt
- -GV-05 · Điểm danh · buổi đã Done, chỉ xem (điện thoại)
- +GV-05 · Điểm danh · buổi đã Hoàn thành, chỉ xem (điện thoại)
- -Buổi đã Done: chỉ xem.
- +Buổi đã Hoàn thành: chỉ xem.
- +Đổi sang Vắng?
- +Đóng
- +Em này
- +Điểm đã nhập của em này sẽ không được tính. Đổi lại Có mặt thì hiện lại.
- +Đổi sang Vắng
- +Giữ nguyên
### GV05_dt
- +Đã chấm nhận xét ở bước 3. Đổi sang Vắng thì điểm không được tính.
- +Đã chấm nhận xét ở bước 3. Đổi sang Vắng thì điểm không được tính.
- +Đổi sang Vắng?
- +Đóng
- +Em này
- +Điểm đã nhập của em này sẽ không được tính. Đổi lại Có mặt thì hiện lại.
- +Đổi sang Vắng
- +Giữ nguyên
### GV05_pc
- -Điểm danh · Đại số 9 · cơ bản A · Buổi 5
- +ĐẠI SỐ 9 · CƠ BẢN A
- +Buổi 5 · Điểm danh
- +24/10 · 18:00–19:30
- +Đã chấm nhận xét
- +Đã chấm nhận xét
- +Đổi sang Vắng?
- +Đóng
- +Em này
- +Điểm đã nhập của em này sẽ không được tính. Đổi lại Có mặt thì hiện lại.
- +Đổi sang Vắng
- +Giữ nguyên
### GV06_dt
- +Loại buổi: Buổi học thường
- -Dòng nội dung 1
- +Dòng nội dung 1 Phương trình bậc nhất một ẩn
- -Dòng nội dung 2
- +Dòng nội dung 2 Giải bài toán bằng cách lập phương trình
- -Dòng nội dung 3
- +Dòng nội dung 3 Bất đẳng thức cơ bản
- +Không bắt buộc
- -Buổi này không giao BTVN
- +Giao bài về nhà là tuỳ giáo viên. Để trống nếu buổi này không giao; không ảnh hưởng việc hoàn thành bước 2.
- -Cần ít nhất một dòng nội dung. Không tự lưu.
- +Cần ít nhất một dòng nội dung. BTVN tuỳ giáo viên. Không tự lưu.
### GV06_pc
- -Nội dung buổi và BTVN · Đại số 9 · cơ bản A · Buổi 5
- +ĐẠI SỐ 9 · CƠ BẢN A
- +Buổi 5 · Nội dung buổi và BTVN
- +24/10 · 18:00–19:30
- +Loại buổi: Buổi học thường
- -Dòng nội dung 1
- +Dòng nội dung 1 Phương trình bậc nhất một ẩn
- -Dòng nội dung 2
- +Dòng nội dung 2 Giải bài toán bằng cách lập phương trình
- -Dòng nội dung 3
- +Dòng nội dung 3 Bất đẳng thức cơ bản
- +Không bắt buộc
- -Buổi này không giao BTVN
- +Giao bài về nhà là tuỳ giáo viên. Để trống nếu buổi này không giao; không ảnh hưởng việc hoàn thành bước 2.
### GV06_trong
- +*
- +Nhập BTVN giao mới hoặc tích Buổi này không giao BTVN
- +Phải nhập BTVN giao mới hoặc tích không giao thì bước 2 mới tính Xong (R-GIO-06).
- -Cần ít nhất một dòng nội dung. Không tự lưu.
- +Cần ít nhất một dòng nội dung và BTVN (hoặc tích không giao). Không tự lưu.
### GV08_dt
- -GV-08 · Chấm BTVN buổi trước (điện thoại)
- +GV-08 · Chấm BTVN buổi trước · (điện thoại)
### GV08_pc
- -Chấm BTVN buổi trước · Đại số 9 · cơ bản A · Buổi 5
- +ĐẠI SỐ 9 · CƠ BẢN A
- +Buổi 5 · Chấm BTVN buổi trước
- +24/10 · 18:00–19:30
- -Điểm BTVN, Trần Gia Hân
- +Điểm BTVN, Trần Gia Hân 4
- -Điểm BTVN, Đỗ Phương Thảo
- +Điểm BTVN, Đỗ Phương Thảo 3
### GV08_trong
- -Buổi trước đã đánh dấu không giao BTVN nên bước này tự bỏ qua, không cần làm gì và không chặn Done (QĐ-Đ22, R-GIO-06).
- +Buổi trước giáo viên không giao BTVN (giao bài là tuỳ giáo viên) nên không có bài để chấm. Bước này tự bỏ qua, không cần làm gì và không chặn Done (QĐ-Đ22).
### Man_GV02
- +Buổi đã quá hạn cũng hiện ở đây (Hình 9 · Buổi 5, quá hạn 47 giờ, tính lúc 22:30 như GV-12). Tiêu đề nhóm: «VIỆC SẮP TRỄ HẠN / QUÁ HẠN».
### Man_GV04
- +Chưa chốt danh sách: «Danh sách sẽ được hệ thống chốt trước giờ học», không hiện danh sách tạm (R-GIO-02, R-GIO-03). Bước 2 chỉ Xong khi có BTVN giao mới hoặc tích «không giao» (ghi «BTVN đã nhập» hoặc «Không giao BTVN»). Thêm 3 
### Man_GV05
- +Chưa chốt danh sách: «Danh sách sẽ được hệ thống chốt trước giờ học». Đổi em đã chấm nhận xét sang Vắng thì hỏi trước: «Điểm đã nhập của em này sẽ không được tính. Đổi lại Có mặt thì hiện lại.» Hai nút: Đổi sang Vắng · Giữ nguyên
### Man_GV06
- -QĐ-Đ22: giữ ô "Buổi này không giao BTVN"; buổi đánh dấu không giao thì buổi sau không phải chấm BTVN buổi trước (R-GIO-06). QĐ-Đ23: nội dung buổi phải có ít nhất một dòng.
- +QĐ-Đ22: giữ ô «Buổi này không giao BTVN»; buổi đánh dấu không giao thì buổi sau không phải chấm BTVN buổi trước (R-GIO-06). QĐ-Đ23: nội dung buổi phải có ít nhất một dòng. Mỗi buổi phải nhập BTVN giao mới hoặc tích không giao, th
### Man_GV08
- -QĐ-Đ22: buổi trước đánh dấu "không giao BTVN" thì bước này tự bỏ qua, không chặn Done (R-GIO-06). Đã vẽ ở khung "buổi trước không giao BTVN".
- +QĐ-Đ22: buổi trước đánh dấu «không giao BTVN» thì bước này tự bỏ qua, không chặn Hoàn thành (R-GIO-06). Thêm khung: em vắng buổi giao bài (đặt sẵn «Không áp dụng», đổi được, có chú thích), em vắng buổi chấm (không bắt buộc ở buổi

## 3. Khung ĐỔI chỉ ở script (không đổi giao diện nhìn thấy)

`GV01_dt`, `GV01_pc`, `GV01_quyen`, `GV02_quyen`, `GV02_tai`, `GV04_quyen`, `GV04_tai`, `GV05_quyen`, `GV05_tai`, `GV06_quyen`, `GV06_tai`, `GV07_quyen`, `GV07_tai`, `GV07_trong`, `GV08_quyen`, `GV08_tai`. Thêm đoạn script đặt giá trị ban đầu cho ô nhập (`data-val`); riêng GV06 có thêm kiểm tra "cần ít nhất một dòng nội dung".

## 4. Không đổi (85 khung)
Mọi khung GV-07 bản chính (`GV07_*`, `GV07K_*`, `GV07X_*`) giống hệt fcd1 về giao diện (3 khung `quyen`, `tai`, `trong` chỉ đổi script). GV-01, GV-04, GV-05, GV-08 bản `*_bs_pc`/`Man_*_bs_dt` giống hệt.

## 5. Đề xuất
Khác biệt vừa phải, tập trung ở GV-02, 04, 05, 06, 08 (chữ và vài nút/hộp thoại) cộng 23 khung nháp GV07b/GV08b chưa làm. Đề xuất **xuất gói 9189 vào repo** (cả canvas, để Code 2 làm đúng bản hiện hành), kèm dặn: bỏ qua 23 khung "NHÁP, CHƯA LÀM". Chưa so GV-03, GV-09 đến GV-16 và canvas.json ngoài tiêu đề.
