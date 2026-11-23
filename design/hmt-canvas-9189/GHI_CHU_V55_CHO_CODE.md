# GHI CHÚ CHO CODE · Bổ sung Aftersale 23/11/2026

Canvas: HMT Đào tạo & Giáo viên, bản `1795374185-3d23` (v51). Thêm 18 khung (373 → 391). Không sửa, không xoá khung cũ. Số trong khung là số minh hoạ, không chép vào code hay test.

## 1. Quyết định chính (anh Trường chọn hướng A, 23/11)

CS-07 Chuyển cơ sở, CS-10 Chuyển phí, CS-14 Dừng học **làm theo phiếu nghiệp vụ (PNV)**, đúng khung đã có:
- CS-07 → `CSN06a_chuyen_co_so`
- CS-10 → `CSN06d_chuyen_phi_em`, `CSN06d_chuyen_phi_gia`, `CSN06d_chuyen_phi_phu_huynh`
- CS-14 → `CSN06e_dung_hoc`

**Không dựng hộp thoại K08 cho ba màn này.** `docs/design/ban-do-man-hinh.md` còn ghi "Hộp thoại · K08" cho CS-05 đến CS-14, bản đồ này sẽ do Chat sửa. Khung nào thay khung nào: **không khung nào bị thay**, chỉ bổ sung.

## 2. Danh sách khung mới

| Mã màn | Khung | Nội dung |
|---|---|---|
| CS-16 (khuôn K03) | `CSN10_ds` | Danh sách Nhận xét chờ gửi phụ huynh, chip Chờ gửi / Đã gửi |
| CS-16 | `CSN10_xem` | Hộp thoại xem lời nhắn: Sao chép, Xuất ảnh, Đánh dấu đã gửi |
| CS-16 | `CSN10_tai`, `CSN10_trong`, `CSN10_loi`, `CSN10_quyen` | Đang tải, rỗng, lỗi tải (nút Thử lại), không có quyền |
| CS-12 (K08) | `CSN04_khach_huy` | Khách huỷ ticket: bắt buộc lý do (R-CS-05), nút khoá tới khi nhập lý do |
| CS-12 | `CSN04_khach_huy_loi`, `CSN04_khach_huy_luu` | Lỗi lưu (giữ lý do đã nhập), đang lưu |
| CS-07 | `CSN06a_chuyen_co_so_loi_luu`, `_tai`, `_dt` | Lỗi lưu, đang tải, điện thoại |
| CS-10 | `CSN06d_chuyen_phi_loi_luu`, `_tai`, `_dt` | Như trên (dựng từ kiểu "sang anh chị em", dùng chung cho ba kiểu chuyển) |
| CS-14 | `CSN06e_dung_hoc_loi_luu`, `_tai`, `_dt` | Như trên |

Khung rỗng không áp dụng cho CS-07, 10, 14 (đây là bản ghi, không phải danh sách).

## 3. Chi tiết cần biết khi dựng

**CS-16 (`CSN10_*`)**
- Cột: Học sinh, Lớp, Buổi, Phụ huynh, Lời nhắn (một dòng, cắt bằng "…"), Trạng thái, Thao tác. Thao tác mỗi dòng: Sao chép, Xuất ảnh, Đánh dấu đã gửi. Bấm tên học sinh mở hộp xem đầy đủ.
- Vai trò: CS, AD (theo bản đồ). Luật tham chiếu R-GV-04, R-CS-13.
- Khung dùng thành phần khuôn chung (K03 như `CSN05_ds`, hộp K08). Không thêm thành phần mới.
- Menu: thêm một mục «Nhận xét chờ gửi» dưới «Chăm sóc KH» để màn có chỗ mở (xem câu hỏi 1).
- Chưa vẽ: bản điện thoại (bản đồ ghi Máy tính), khung riêng cho chip Đã gửi (cùng bảng, trạng thái Đã gửi), hình ảnh xuất ra (dùng mẫu ảnh có sẵn `GV07X_mau_anh_thuong`, `GV07X_mau_anh_kiem_tra`, chờ anh xác nhận).

**CS-12 (`CSN04_khach_huy*`)**
- Hộp thoại K08 trên nền ticket đề nghị. Mở từ menu Hành động của ticket đề nghị (CS-02, nút "Khách huỷ"). Khung nền giữ như `CSN04_huy`, không thêm nút mới ngoài bản đồ.
- Từ chối ticket (bắt buộc lý do) đã có ở `CSN07_tu_choi`, `CSN06_tu_choi`. Huỷ ticket nội bộ ở `CSN04_huy`. Ba việc này khác nhau, không gộp.

**PNV (CS-07, 10, 14) khung lỗi, tải, điện thoại**
- `_loi_luu`: giống `CSN06_loi_luu` (nút Thử lại, báo "Chưa lưu được phiếu", nội dung nhập vẫn còn), áp lên đúng trang của từng loại phiếu.
- `_tai`: khung xương, đúng bố cục `CSN06_tai`, thêm thẻ loại phiếu.
- `_dt` (390 × 844): màn xem phiếu ở trạng thái Nháp, danh sách thông tin, mục Duyệt, hai nút cuối trang Lưu nháp và Gửi duyệt. Không có ô chọn. Sửa đổi số liệu làm trên máy tính.

## 4. Câu hỏi cho anh Trường (em tự chọn mặc định, chưa quyết thay anh)
1. **Menu CS-16:** bản đồ không ghi menu cho màn này. Em đặt «Nhận xét chờ gửi» dưới «Chăm sóc KH», sau «Phiếu nghiệp vụ». Anh OK hay đổi chỗ?
2. **Cột CS-16:** bản đồ không liệt kê cột. Em dùng Học sinh, Lớp, Buổi, Phụ huynh, Lời nhắn, Trạng thái. Cột «Phụ huynh» em thêm vì CSKH cần tên người nhận để gửi Zalo. Anh xác nhận.
3. **CS-16 điện thoại:** em không vẽ vì bản đồ ghi chỉ máy tính. Anh cần thì báo.
4. **Chuyển phí âm:** CSN06d ghi "Kết quả âm thì chặn" nhưng chưa có khung báo chặn riêng. Em chưa tự vẽ vì chưa có luật chữ báo lỗi. Anh muốn khung này không?
5. **Khách huỷ:** chỉ cho ticket loại Đề nghị (theo CS-02). Anh xác nhận khiếu nại không có "Khách huỷ".

## 5. Cần lưu ý: file chưa nằm trên canvas

Trong cùng artifact có **9 file đã tồn tại nhưng không có trong `canvas.json`** (không hiện trên canvas): `CS16_ds`, `CS16_da_gui`, `CS16_dt`, `CS16_loi`, `CS16_quyen`, `CS16_tai`, `CS16_trong` (một bản vẽ CS-16 khác, có cột Loại, Giáo viên, Buổi Done lúc, có bản điện thoại) và `CSN06f_dieu_chinh_cho_kt`, `CSN06f_dieu_chinh_hoc_phi`. Em không rõ ai vẽ và lúc nào, chưa duyệt. **Code đừng dùng các file này.** Khung hiện hành của CS-16 là `CSN10_*` ở bảng trên, cho tới khi anh chọn giữ bản nào.

## 6. Cách em đã kiểm
Đã render ảnh cả 18 khung bằng trình duyệt dựng thử (bỏ phần chạy của canvas) và xem. **Chưa mở trong trình xem thật của canvas**, nên các nút bấm (mở hộp xem, chuyển chip) chưa thử trên canvas thật.

---

# Đợt 2 (ƯU TIÊN 1 phần còn lại): QT-17, CHUNG-21, CHUNG-23. ĐÃ ĐĂNG (canvas Quản trị & Nạp dữ liệu v11, 80 khung). Anh Trường đã trả lời 10 câu 23/11, xem mục G

Dự kiến đăng vào canvas **HMT Quản trị và Nạp dữ liệu · bổ sung** (thêm 15 khung). Các khung hiện chỉ ở bản dựng thử của Design.

## A. Đã có khung, không vẽ lại
- **CHUNG-05 Đặt mật khẩu mới**: `DN06_pc_new`, `DN06_pc_ok`, `DN06_mb_new`, `DN06_mb_ok` (canvas HMT Platform, đang ghi HOÃN).
- **CHUNG-08 Không thể đăng nhập**: `DN08_pc_lock`, `DN08_mb_lock` (một câu chung, chốt 12/10).

## B. Chưa vẽ: CHUNG-23 Đăng nhập phụ huynh
Bản đồ ghi «cách đăng nhập chốt ở GĐ4». Em không tự chọn trường đăng nhập. Đề xuất mặc định để anh chốt: dùng khuôn `DN03` (đăng nhập bằng mã), mã là mã PH, vì QT-17 cấp tài khoản theo mã PH.

## C. QT-17 Tài khoản phụ huynh (K03, máy tính, CS và AD): 8 khung
`QT17_ds`, `QT17_tai`, `QT17_trong`, `QT17_loi`, `QT17_quyen`, `QT17_cap`, `QT17_khoa`, `QT17_dat_lai`.
- Cột: Mã PH, Phụ huynh, Số con, Tài khoản (Chưa cấp, Đang dùng, Đã khoá), Đăng nhập gần nhất, Thao tác. Chip lọc theo trạng thái tài khoản.
- Nút theo trạng thái: Chưa cấp → Cấp tài khoản; Đang dùng → Đặt lại mật khẩu, Khoá; Đã khoá → Đặt lại mật khẩu.
- Ba hộp xác nhận K08 theo mẫu `QT02_xac_nhan_dat_lai`. Cấp và Đặt lại mở tiếp hộp mật khẩu tạm **K4g có sẵn**, không vẽ lại.
- Menu dùng mục có sẵn «Tài khoản học sinh, phụ huynh». Tiêu đề màn là «Tài khoản phụ huynh». Phần học sinh chưa có màn nào, chưa vẽ.

## D. CHUNG-21 Đính kèm tệp (hộp K08, cả hai): 7 khung
`CHUNG21_trong`, `CHUNG21_co_tep`, `CHUNG21_dang_tai`, `CHUNG21_loi`, `CHUNG21_xem`, `CHUNG21_dt_trong`, `CHUNG21_dt_dang_tai`.
- Máy tính: hộp K08 trên nền ticket; điện thoại: ngăn kéo từ dưới lên (Chụp ảnh, Chọn tệp).
- Mỗi tệp: Xem, Gỡ; đang tải có thanh tiến độ và Huỷ tải; lỗi có Thử lại, Gỡ.
- Số trong khung (JPG, PNG, PDF; tối đa 10 MB mỗi tệp; 5 tệp mỗi lần) là **số minh hoạ**, Code đọc từ tham số, không viết cứng.

## E. Câu hỏi cho anh Trường
1. **CHUNG-23:** anh chốt cách đăng nhập của phụ huynh (đề xuất ở mục B).
2. **QT-17 Mở khoá:** bản đồ chỉ có Cấp, Khoá, Đặt lại mật khẩu, không có Mở khoá. Em không thêm nút. Hàng Đã khoá chỉ có Đặt lại mật khẩu. Anh có cần Mở khoá không?
3. **QT-17 cột:** bản đồ không liệt kê cột, em dùng 5 cột ở mục C. Khoá không bắt lý do (bản đồ không nói). Anh xác nhận.
4. **CHUNG-21:** giới hạn dung lượng, định dạng, số tệp, và nơi lưu tệp (CLAUDE.md ghi giai đoạn 4, Cloudflare R2). Em chỉ vẽ minh hoạ.

## F. Chỗ vênh bản đồ và canvas
Mã **PH-01, PH-03, HS-02** trên khung `KH02_*`, `KH05_hoc_tap` của canvas HMT Platform là tab Phụ huynh, Học sinh trong CRM, **trùng mã** với màn cổng Phụ huynh PH-01..05 và cổng Học sinh HT-01..09 của bản đồ. Khi vẽ cổng HS, PH em dùng mã HT-xx và PH-xx của bản đồ cho cổng, ghi rõ "(cổng)" trong tiêu đề khung để khỏi nhầm.

## G. Quyết định của anh Trường 23/11 (đợt 2)
Menu CS-16 dưới «Chăm sóc KH»; cột CS-16 như đã đề xuất; CS-16 không có bản điện thoại; chưa cần khung chuyển phí âm; Khách huỷ chỉ cho ticket Đề nghị. CHUNG-23 đăng nhập bằng mã PH, dựng như **DN02** (DN03 là OTP, em ghi nhầm lúc đầu). QT-17 không có Mở khoá, 5 cột, khoá không bắt lý do. CHUNG-21 giữ khung minh hoạ, giới hạn đọc từ tham số, chưa dựng trong đêm vì chưa có nơi lưu tệp. 9 file mồ côi (CS16_*, CSN06f_*) đã xoá khỏi canvas Đào tạo & GV (v52, 391 khung). Mã trùng PH-01, PH-03, HS-02: khung cổng ghi «(cổng …)» trong tiêu đề.

---

# ƯU TIÊN 2: Cổng Học sinh HT-01..09. ĐÃ ĐĂNG (canvas Đào tạo & GV v53, 432 khung; 5 câu trả lời của anh đã áp dụng)
Dự kiến thêm vào canvas **Đào tạo & Giáo viên** (391 → 432 khung, thêm 41). Điện thoại 390×844; hai khung máy tính 1440×900 (HT-04, HT-09). Dùng khuôn KG (tiêu đề + nội dung + thanh dưới `.tabbar`), thẻ `cardrow`, nhãn `hmt-tag`. Không thêm thành phần mới. Ba kiểu nhỏ chỉ có trong khung này (lớp `hs-seg` chip chọn nhóm, `hs-ph` ô giữ chỗ ảnh, `hs-kv` hàng nhãn–giá trị) là kiểu tạm trong khung, Code dùng thành phần chuẩn tương đương.

| Mã | Khung |
|---|---|
| HT-01 | HT01_ds, _tai, _trong, _loi |
| HT-02 | HT02_can_lam, _da_nop, _da_cham, _tai, _trong, _loi |
| HT-03 | HT03_ds (còn hạn), _muon (quá hạn, vẫn nhận), _het_han (quá hạn, không nhận), _tai, _loi |
| HT-04 | HT04_dt_trong, _da_chon, _xem_lai, _dang_nop, _loi_tep, _loi_mang, _da_nop; HT04_pc (kéo thả, xem trước nhiều ảnh) |
| HT-05 | HT05_cham, _chua_xong, _tai, _loi |
| HT-06 | HT06_ds, _tai, _trong, _loi |
| HT-07 | HT07_ds, _khong_btvn, _tai, _loi |
| HT-08 | HT08_ds, _tai, _trong, _loi |
| HT-09 | HT09_dt (thanh dưới 5 mục), HT09_pc (menu trái, một cột giữa) |

Luật đã áp: R-LMS-02 (quá hạn, nhãn Nộp muộn, tắt nhận muộn thì khoá nút), R-LMS-03 (nộp lại tới khi chấm), R-LMS-04 (số tệp, dung lượng là số minh hoạ, đọc từ tham số), R-LMS-05 (sao, chuỗi chỉ hiện khi cơ sở bật; không xếp hạng), R-GV-11 (trạng thái BTVN), R-GV-12, R-V2-35 (lớp không có BTVN thì ẩn phần BTVN, HT-02 rỗng giải thích).

## Câu hỏi cho anh Trường
1. **Tài khoản** (mục thứ 5 của thanh dưới): bản đồ có tab này nhưng không có màn nào. Em chưa vẽ nội dung, chỉ có nút trên thanh. Anh cần màn không?
2. **HT-04 trạng thái «Nộp lại»:** em vẽ nút «Nộp lại» ở màn đã nộp, chưa chấm. Sau khi giáo viên chấm, nút biến mất (R-LMS-03). Chưa có khung riêng cho trường hợp giáo viên tắt «Cho nộp lại». Anh muốn khung này không?
3. **HT-05 Không làm, Nộp sau, Không áp dụng:** em vẽ 2 trạng thái (Đã chấm 4/5, Làm chưa xong); ba trạng thái còn lại cùng bố cục, chỉ đổi nhãn. Anh OK không vẽ riêng?
4. **HT-07:** học sinh có hai lớp (Đại, Hình) em chọn bằng chip đổi lớp. Phụ huynh dùng chung khung (PH-02). Anh OK?
5. **HT-02 quá hạn:** bài quá hạn vẫn nằm ở «Cần làm» với nhãn đỏ «Quá hạn». Bài quá hạn mà không nhận muộn: ở HT-03 nút khoá. Em chưa chắc có nên ẩn khỏi «Cần làm»; anh chốt.


---

# ƯU TIÊN 3: Cổng Phụ huynh PH-01..05. 29 khung ĐÃ ĐĂNG (28 khung v54 + PH04_khong_dong_y v55; canvas Đào tạo & GV v55, 461 khung)
Dự kiến thêm 28 khung vào canvas **Đào tạo & Giáo viên** (432 → 461 sau khi thêm PH04_khong_dong_y). Toàn bộ điện thoại 390×844, dùng lại khuôn KG, thanh dưới 5 tab (Trang chủ, Kết quả, Học phí, Lịch, Đề nghị), chip chọn con. Không khuôn mới. Tiêu đề khung ghi «(cổng Phụ huynh)» để khỏi nhầm PH-01, PH-03 với tab CRM.

| Màn | Khung | Số |
|---|---|---|
| PH-01 Trang chủ (K09) | bình thường, đang tải, không có việc cần chú ý, lỗi | 4 |
| PH-02 Kết quả và nhận xét (K09) | bình thường, tất cả nhận xét, tải, chưa có, lỗi | 5 |
| PH-03 Học phí và giờ học (K06) | bình thường, giờ còn thấp, chi tiết đơn, tải, chưa có đơn, lỗi | 6 |
| PH-04 Đề nghị và khiếu nại (K07) | danh sách, gửi mới, theo dõi các bước, xác nhận phương án, chấm hài lòng, tải, chưa có, lỗi tải, lỗi khi gửi | 9 |
| PH-05 Lịch học (K05) | bình thường, tải, tuần không có buổi, lỗi | 4 |

Quy ước: chỉ xem, phụ huynh không thanh toán và không sửa dữ liệu trên cổng; PH-02 dùng chung dữ liệu HT-07/HT-08; PH-05 giống HT-06.

Số minh hoạ, không chép vào code hay test: giờ còn, ngày hết dự kiến, số tiền, mã DH/PT, ngày tháng, tên con (Minh Anh, Gia Bảo), tên nhóm đề nghị, các bước xử lý.

Anh Trường đã trả lời 23/11:
1. PH-03 «Ngày hết dự kiến» và ngưỡng «giờ còn thấp»: Design chỉ vẽ chỗ hiển thị; công thức và tham số bên code chốt.
2. PH-03 phụ huynh chỉ xem đơn và phiếu thu, không có nút thanh toán: đúng ý anh.
3. PH-04 nhóm đề nghị và số bước hiển thị: giữ 4 bước như đã vẽ; code đối chiếu R-CS-06/09/14, lệch thì báo lại.
4. PH-04 «Không đồng ý phương án»: có khung ô nhập lý do (bắt buộc, nút Gửi và Huỷ): PH04_khong_dong_y (+1 khung, ĐÃ ĐĂNG v55).
5. Chip chọn con: ẩn khi phụ huynh chỉ có một con (chỉ ghi chú, không vẽ khung riêng; anh chốt).

Cổng Học tập (HT) anh đã chốt: tab «Tài khoản» chưa vẽ (giữ nút trên thanh dưới); HT-04 khi giáo viên tắt «Cho nộp lại» chỉ ẩn nút «Nộp lại», không vẽ khung riêng; HT-05 ba trạng thái Không làm / Nộp sau / Không áp dụng chỉ đổi nhãn; HT-07 học sinh hai lớp dùng chip đổi lớp (phụ huynh dùng chung PH-02); HT-02 bài quá hạn nằm ở «Cần làm» nhãn đỏ «Quá hạn», bài không nhận muộn khoá nút ở HT-03.
