# Ghi chú cho Code · cổng Học tập (HT) và Phụ huynh (PH) · 23/11/2026

Nguồn: canvas **HMT Đào tạo & Giáo viên** (v60 sau sửa PH-04 ngày 23/11; HMT Platform v152 cho khung đăng nhập DN; khung HT, PH đăng từ v53, v54, v55). Zip này chỉ có khung HT, PH để đọc riêng; `canvas.json` trong zip là bản lọc.
**Số lượng thực tế: HT 41 khung, PH 29 khung (không phải 28).** 28 khung PH đăng ở v54, thêm PH04_khong_dong_y ở v55 = 29. Tổng 70 khung.
Số trong khung (giờ còn, tiền, mã DH/PT, ngày, tên con Minh Anh, Gia Bảo, số tệp, dung lượng) là **số minh hoạ, không chép vào code hay test**; giới hạn tệp, ngưỡng giờ thấp đọc từ tham số.
Cả hai cổng ưu tiên điện thoại 390×844. Khổ máy tính 1440×900 chỉ có 2 khung ở HT (HT04_pc, HT09_pc). PH không có khổ máy tính.

## Nhãn
- **NHÁP / CHƯA LÀM / BẢN CŨ: không có khung nào** trong 70 khung này. Khung nào có trong zip đều là bản để làm.
- Hai khung chỉ có trong canvas khác, không thuộc zip này nhưng liên quan: DN02_* (đăng nhập học sinh/phụ huynh, canvas HMT Platform); DN06_* gắn nhãn HOÃN (đặt mật khẩu mới).
- Khuôn: dùng lại khuôn KG (tiêu đề + nội dung + thanh dưới), thẻ `cardrow`, nhãn `hmt-tag`. Ba kiểu nhỏ chỉ có trong khung HT (`hs-seg` chip chọn nhóm, `hs-ph` ô giữ chỗ ảnh, `hs-kv` hàng nhãn–giá trị) là kiểu tạm; Code dùng thành phần chuẩn tương đương.
- Tên vai trò: các khung HT, PH không có tên vai trò nhân viên nên không có chỗ nào cần «Tư vấn tuyển sinh»; em đã quét, 0 chỗ «Tuyển sinh» / «Tư vấn» trong 70 khung. Quy ước chung vẫn là: vai trò hiển thị «Tư vấn tuyển sinh» (9933 v151, abea v16), «Tuyển sinh» giữ ở menu và tên phân hệ.

## 1. Cổng Học tập (HT), 41 khung
Cột «Loại»: **Màn** = trạng thái chính để dựng; **Trạng thái** = chỉ là biến thể của màn (đang tải, lỗi, rỗng, hộp thoại).

| Mã màn | Khung | Loại |
|---|---|---|
| HT-01 Trang chủ | HT01_ds | Màn |
| | HT01_tai, HT01_trong (không có bài cần làm), HT01_loi | Trạng thái |
| HT-02 Bài tập (3 tab Cần làm / Đã nộp / Đã chấm) | HT02_can_lam, HT02_da_nop, HT02_da_cham | Màn (mỗi tab) |
| | HT02_tai, HT02_trong, HT02_loi | Trạng thái |
| HT-03 Chi tiết bài tập | HT03_ds (còn hạn) | Màn |
| | HT03_muon (quá hạn, vẫn nhận), HT03_het_han (quá hạn, không nhận, nút khoá) | Trạng thái nghiệp vụ |
| | HT03_tai, HT03_loi | Trạng thái |
| HT-04 Nộp bài (điện thoại) | HT04_dt_trong, HT04_dt_da_chon, HT04_dt_xem_lai, HT04_dt_da_nop | Các bước của màn |
| | HT04_dt_dang_nop, HT04_dt_loi_tep, HT04_dt_loi_mang | Trạng thái |
| HT-04 Nộp bài (máy tính) | HT04_pc (kéo thả, xem trước nhiều ảnh) | Màn, khổ 1440×900 |
| HT-05 Kết quả bài | HT05_cham (đã chấm), HT05_chua_xong (làm chưa xong) | Màn / trạng thái nghiệp vụ |
| | HT05_tai, HT05_loi | Trạng thái |
| HT-06 Lịch học | HT06_ds | Màn |
| | HT06_tai, HT06_trong (tuần không có buổi), HT06_loi | Trạng thái |
| HT-07 Kết quả học tập | HT07_ds | Màn |
| | HT07_khong_btvn (lớp không có BTVN: ẩn phần BTVN) | Trạng thái nghiệp vụ |
| | HT07_tai, HT07_loi | Trạng thái |
| HT-08 Nhận xét các buổi | HT08_ds | Màn |
| | HT08_tai, HT08_trong, HT08_loi | Trạng thái |
| HT-09 Khung cổng | HT09_dt (thanh dưới 5 mục), HT09_pc (menu trái, một cột giữa) | Khung chung, 2 khổ |

Tóm: 9 màn (HT-01..09). Khung HT04 (7 khung điện thoại) là các bước của một luồng nộp bài, không phải 7 màn.

## 2. Cổng Phụ huynh (PH), 29 khung
Thanh dưới 5 tab: Trang chủ, Kết quả, Học phí, Lịch, Đề nghị. Chip chọn con. **Chỉ xem**: phụ huynh không thanh toán, không sửa dữ liệu (trừ gửi đề nghị ở PH-04).

| Mã màn (khuôn) | Khung | Loại |
|---|---|---|
| PH-01 Trang chủ (K09) | PH01_ds | Màn |
| | PH01_tai, PH01_trong (không có việc cần chú ý), PH01_loi | Trạng thái |
| PH-02 Kết quả và nhận xét (K09) | PH02_ds, PH02_nhan_xet (tất cả nhận xét) | Màn |
| | PH02_tai, PH02_trong (chưa có kết quả), PH02_loi | Trạng thái |
| PH-03 Học phí và giờ học (K06) | PH03_ds, PH03_don (chi tiết đơn) | Màn |
| | PH03_gio_thap (giờ còn thấp) | Trạng thái nghiệp vụ |
| | PH03_tai, PH03_trong (chưa có đơn), PH03_loi | Trạng thái |
| PH-04 Đề nghị và khiếu nại (K07) | PH04_ds, PH04_gui, PH04_chi_tiet (theo dõi 4 bước), PH04_phuong_an (xác nhận phương án), PH04_hai_long (chấm hài lòng) | Màn |
| | PH04_khong_dong_y (hộp thoại nhập lý do mở trên nền màn phương án; **không phải màn riêng**) | Trạng thái (hộp thoại) |
| | PH04_tai, PH04_trong (chưa có), PH04_loi, PH04_loi_gui (lỗi khi gửi) | Trạng thái |
| PH-05 Lịch học của con (K05) | PH05_ds | Màn |
| | PH05_tai, PH05_trong (tuần không có buổi), PH05_loi | Trạng thái |

Tóm: 5 màn (PH-01..05). PH-02 dùng chung dữ liệu HT-07, HT-08; PH-05 giống HT-06.
**Trùng mã:** PH-01, PH-03, HS-02 cũng là mã tab Phụ huynh/Học sinh trong CRM (KH02_*, KH05_hoc_tap). Khung cổng ghi «(cổng Học sinh)» hoặc «(cổng Phụ huynh)» trong tiêu đề để khỏi nhầm.

## 3. Luật anh Trường đã chốt 23/11 (áp cho HT, PH)
1. **Học sinh đăng nhập lần đầu KHÔNG bắt buộc đổi mật khẩu.** Khung DN02 (đăng nhập học sinh) vào thẳng trang chủ. DN07 «Đổi mật khẩu lần đầu» chỉ cho nhân viên.
2. **Học sinh nhỏ không có email hay số điện thoại:** CSKH hoặc phụ huynh đặt lại mật khẩu (DN02 ghi «Nhờ phụ huynh hoặc CSKH đặt lại»).
3. **Phụ huynh đăng nhập bằng SỐ ĐIỆN THOẠI của phụ huynh + mật khẩu** (khung DN11_mb_ok, DN11_mb_err, DN11_pc_ok, DN11_pc_err, canvas HMT Platform, mới ở v152). Không dùng mã PH hay OTP. Quên mật khẩu: **CSKH ở cơ sở đặt lại.** Mọi lỗi (sai số điện thoại, sai mật khẩu, định dạng sai...) dùng chung khung «Sai thông tin». Không thêm link «Phụ huynh» ở DN01, DN02.
4. **PH-04 «Không đồng ý phương án»:** hộp thoại ngay trên màn phương án (PH04_phuong_an), lý do bắt buộc. Gửi xong: tạo ticket mới nếu chưa có, mở lại nếu đã có. Không có màn riêng.
5. Đã chốt trước đó: tab «Tài khoản» HT chưa vẽ; HT-04 tắt «Cho nộp lại» chỉ ẩn nút; HT-05 ba trạng thái còn lại chỉ đổi nhãn; HT-07 hai lớp dùng chip; HT-02 quá hạn ở «Cần làm»; PH-03 chỉ xem; chip chọn con ẩn khi có một con; PH-04 giữ 4 bước.

Khung đăng nhập liên quan (ở canvas HMT Platform, không nằm trong zip này): DN02_* đăng nhập học sinh (4), **DN11_* đăng nhập phụ huynh (4, mới)**, DN07_* đổi mật khẩu lần đầu (4, chỉ nhân viên). Bản chép của 12 khung này nằm trong thư mục `dang_nhap_lien_quan/`.
**DN10 Chọn cổng:** là màn của nhân viên có nhiều cổng (thẻ CRM, Giáo viên). Học sinh, phụ huynh vào thẳng cổng của mình sau đăng nhập nên **không có thẻ Phụ huynh, Học tập** ở DN10; em chưa thêm (xem mục 3a).

## 3a. Còn mở, cần anh chốt (em KHÔNG tự chọn)
1. **DN10 và thẻ Phụ huynh:** anh dặn «chưa có thì thêm». Em chưa thêm vì DN10 chỉ hiện cho tài khoản nhân viên («Tài khoản của bạn vào được hai cổng»); phụ huynh đăng nhập bằng DN11 rồi vào thẳng cổng PH. Nếu anh vẫn muốn có thẻ (ví dụ tài khoản nhân viên đồng thời là phụ huynh), xin anh nói để em vẽ.
2. **Tài khoản** (mục 5 thanh dưới HT): chỉ có nút, chưa có màn; nút dẫn tới đâu khi có màn thì anh chốt.
3. **Một phụ huynh nhiều con, hoặc một số điện thoại gắn nhiều phụ huynh:** chip chọn con vẽ cho 2 con; chưa có luật khi một số điện thoại gắn nhiều hồ sơ phụ huynh.
4. **HT-03 bài quá hạn không nhận muộn:** đang ở «Cần làm» với nút khoá (đã chốt); chưa có luật quá bao lâu thì ẩn.
5. **PH-03 «Ngày hết dự kiến», ngưỡng «giờ còn thấp»:** Design chỉ vẽ chỗ hiển thị; công thức và tham số bên code chốt.
6. **Ảnh bài nộp:** HT-04 vẽ chọn nhiều ảnh, kéo thả; chưa có nơi lưu tệp (R2, giai đoạn 4); giới hạn đọc từ tham số theo R-LMS-04.
7. **PH-04 quy tắc ticket:** «mở lại nếu đã có» cần code định nghĩa «đã có» (cùng đề nghị, cùng học sinh?); đối chiếu R-CS-06/09/14, lệch thì báo.
8. **Chưa kiểm tận mắt:** em xem ảnh xem trước dựng từ file khung, không mở được canvas thật. Hộp thoại PH-04 chạy bằng script nên chưa kiểm khi bấm thật. Độ tương phản chữ nhỏ, vùng chạm 44px chưa đo.

## 4. Luật đã áp
R-LMS-02 (quá hạn, nhãn «Nộp muộn», tắt nhận muộn thì khoá nút), R-LMS-03 (nộp lại tới khi chấm), R-LMS-04 (số tệp, dung lượng là tham số), R-LMS-05 (sao, chuỗi chỉ hiện khi cơ sở bật; không xếp hạng), R-GV-11, R-GV-12 (trạng thái BTVN), R-V2-35 (lớp không có BTVN thì ẩn phần BTVN).
