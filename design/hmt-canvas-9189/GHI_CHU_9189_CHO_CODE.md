# GHI CHÚ CHO CODE: canvas Đào tạo & Giáo viên (design/hmt-canvas-9189)

Gói này xuất từ bản đang đăng **Version 45, version id 1794295687-73e6** (đăng 10/11/2026 sau "OK ĐĂNG" Q-232). Bản lùi: Version 44 `1794293583-d882` (trước đó 1794278144-9189). 371 khung, canvas.json, ds/, assets/. Kiểm bằng file, chưa xem trên trình duyệt thật.

**Từ Version 45 trở đi, đọc mục «Cập nhật Q-232, Q-233» ở cuối file này trước.** Các mục A đến D bên dưới viết cho Version 44; v45 chỉ thêm 9 khung mới và sửa 6 khung (không đổi gì khác).

So với 1794278144-9189, bản này đổi 20 khung và 2 tiêu đề trong canvas.json (chi tiết ở mục B).

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

## B. Đã sửa cho khớp luật trong bản 1794293583-d882 (Code làm theo luật, khung nay khớp)

Hai luật (đối chiếu spec 04, Chat xác nhận):
- **R-V2-37:** GV-02 chỉ hiện buổi trong ngày và việc sắp trễ hạn của các buổi đó. Buổi quá hạn không hiện ở GV-02, xem ở GV-12.
- **R-V2-35:** BTVN là tuỳ giáo viên. Để trống = không giao. Không có ô tích «không giao BTVN». Bước 2 (nội dung buổi) chỉ cần có ít nhất một dòng nội dung, không còn điều kiện BTVN. Dòng tóm tắt bước 2 do hệ thống tự ghi: «BTVN đã nhập» khi có BTVN, «Không giao BTVN» khi để trống (không phải ô tích).

20 khung đã sửa:
- GV-02: GV02_dt, GV02_pc (bỏ thẻ buổi quá hạn, nhóm «VIỆC SẮP TRỄ HẠN»), GV02_trong, GV02_trong_bs_pc, ghi chú Man_GV02, Man_GV02_bs_dt.
- GV-06: GV06_trong, GV06_trong_bs_pc (bỏ dấu *, bỏ ô tích, nhãn «Không bắt buộc»), ghi chú Man_GV06, Man_GV06_bs_dt.
- GV-04: ghi chú Man_GV04, Man_GV04_bs_dt.
- GV-08: ghi chú Man_GV08, Man_GV08_bs_dt; GV08_trong, GV08_trong_bs_pc («Done» thành «Hoàn thành»).
- GV-09: GV09_thieu_btvn_dt, GV09_thieu_btvn_pc (bước 2 ghi «Không giao BTVN»; hộp «Còn thiếu» không có dòng BTVN), ghi chú Man_GV09, Man_GV09_bs_dt.
- canvas.json: tiêu đề 2 khung GV09_thieu_btvn thành «…BTVN để trống thì bước 2 vẫn Xong (điện thoại/laptop)».

Chưa sửa, Code lưu ý khi làm: tiêu đề GV07K_done_dt, GV07K_done_pc còn chữ «Done» (làm màn thì dùng chữ «Hoàn thành»).

## C. Chưa so

Chưa so với fcd1: GV-03, GV-09 (chỉ rà riêng phần BTVN theo R-V2-35, đã sửa), GV-10, GV-11, GV-12, GV-13, GV-14, GV-15, GV-16, và canvas.json ngoài tiêu đề. Các màn này làm theo luật và `docs/design/ban-do-man-hinh.md`; khung chỉ để tham khảo giao diện.

## D. So với fcd1

(Dán nguyên văn danh sách từ file DS_khac_biet_GV_9189_vs_fcd1.md.)

LƯU Ý: danh sách này lập cho bản 1794278144-9189, trước đợt sửa Q-226. Nếu mâu thuẫn với mục B thì theo mục B (ví dụ thẻ buổi quá hạn ở GV-02 và ô tích «không giao BTVN» ở GV-06 mà danh sách ghi là đổi/thêm, nay đã bỏ).

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

## Cập nhật Q-232, Q-233: Version 45 `1794295687-73e6` (10/11/2026)
- 9 khung mới (GV05_vang_xac_nhan_dt/pc, GV06_xung_dot_dt/pc, GV04_chua_chot_pc, GV05_chua_chot_pc, GV07_vang_da_nhap_dt/pc, GV07_vang_pc) đã vào canvas.
- «Done» → «Hoàn thành» ở GV07K_done_dt/pc (tiêu đề và chữ trong khung).
- Q-233: ô «Ảnh» ở GV-14 (GV14_dt, GV14_pc, GV14_tk_giao_vien_dt, GV14_tk_giao_vien_pc) giữ chỗ, nhãn «Làm sau», nút «Chọn ảnh» mờ, chữ «Làm sau: bản 17/11 chưa tải ảnh, ticket chỉ gõ chữ.» Code không làm tải ảnh ở bản 17/11. Nội dung giữ nguyên theo R-V2-23, R-CS-10.
- Khung đổi trong v45 so với v44: 9 khung mới ở trên (nằm cuối canvas), GV07K_done_dt/pc (chữ), GV14_dt, GV14_pc, GV14_tk_giao_vien_dt, GV14_tk_giao_vien_pc (ô Ảnh). Còn lại giữ nguyên.
- Gói này CHƯA gồm hai việc vẽ nháp (hộp BH-11 nhiều đơn, GV-14 ô Tính chất tự chọn). Hai việc đó sẽ có gói riêng sau khi anh nói "OK ĐĂNG".
- R-V2-36 (GV-05, đổi Có mặt sang Vắng): hộp xác nhận ở `GV05_vang_xac_nhan_dt/pc`. R-V2-36 chưa có trong `docs/spec/04` của repo, khung vẽ theo lời anh Trường qua Chat.
