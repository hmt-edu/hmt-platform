# HMT Platform · gói canvas cho Code

- **Số bản canvas:** `1793759210-6f57` (đăng 04/11/2026 09:26, giờ Hà Nội)
- **Ngày xuất gói:** 04/11/2026
- **Canvas:** HMT Platform (claude.ai/artifact/KvsUknP8PTirpsVh8utRTR)
- **Nội dung gói:** 485 file khung `*.dc.html` + `canvas.json` + logo + 3 file token/CSS của hệ thiết kế. Không có ảnh PNG.
- **Đối chiếu:** `canvas.json` có sha256 `f9d877c2b5d041c4800e37cf197f455d1771ce18ce3d99a015d57ce65b3e5ce4`, trùng byte với bản `1793163092-bfd4` (28/10/2026, bản em đăng BH-03 và khuôn K13). Số khung trong canvas.json và số file khung khớp nhau (485).

## Cách đọc
1. Mỗi file `.dc.html` là một khung (màn hoặc trạng thái). Mở bằng trình duyệt cần file `support.js` của Claude Design (không nằm trong gói); khi không có, đọc thẳng mã HTML/CSS bên trong. Đường dẫn CSS, logo trong khung đã đặt đúng theo cây thư mục của gói (`ds/hmt/...`, `assets/...`).
2. `canvas.json` ghi tên, vị trí (x, y) và kích thước (w, h) từng khung. Khung cùng hàng ngang (cùng y) là các trạng thái của cùng một màn. Mã màn (BH-01, TC-07...) nằm ở đầu tên khung.
3. Khuôn chung (P0): `P0_v5.dc.html`. Danh mục khuôn K1–K13 nằm trong khung này (K13 là bản in A4/A5).
4. Nhãn màn theo phân hệ: `Man_BH`, `Man_BUOI`, `Man_GD`, `Man_LOP`, `Man_TC`, `Man_TC17`, `Man_TT`. Mục lục: `Muc_luc`, `Muc_luc_man`. Ghi chú đọc: `Cach_doc_BH_TC_GD`, `Ghi_chu_cuoi`.
5. Khi nguồn vênh nhau, theo luật trong CLAUDE.md của repo (spec > quyết định thiết kế 13/10 > bản đồ màn hình > canvas). Canvas là bản vẽ, không phải luật.

## Những điểm cần biết ở bản này
- BH-03 (`BH03_in`) là một khung A4 duy nhất, nút chip trạng thái bên phải chỉ để xem 5 trạng thái (Đã gửi, quá hạn, Nháp, Từ chối, Huỷ), không in ra. Đã chốt Đ273, Đ274.
- `Man_BH` còn ghi "BH-03 · 1 trạng thái" (nhãn cũ, chưa sửa); tên khung trong canvas.json đã đúng là 5 trạng thái.
- `TC07_in` (biên nhận A5) còn in số điện thoại cơ sở và khẩu hiệu, chưa theo ghi chú K13. Chờ sửa.
- BH-05, BH-06, BH02_bh11 trong gói là bản đang đăng (bản đã thống nhất trước đó). Bản vẽ lại đã dừng, không nằm trong canvas, không nằm trong gói.
- Dữ liệu trong khung là dữ liệu giả.

## Danh sách khung (485)


### MUC (2)

| File | Tên khung | w×h |
|---|---|---|
| Muc_luc.dc.html | HMT Platform · Mục lục | 1440×1000 |
| Muc_luc_man.dc.html | HMT Platform · Mục lục các màn | 1440×1150 |

### LOP (36)

| File | Tên khung | w×h |
|---|---|---|
| LOP01_admin.dc.html |  | 1440×1000 |
| LOP01.dc.html | LOP-01 · Lớp học · danh sách | 1440×1000 |
| LOP01_trong.dc.html | LOP-01 · Lớp học · danh sách (trống) | 1440×1000 |
| LOP01_tai.dc.html | LOP-01 · Lớp học · danh sách (đang tải) | 1440×1000 |
| LOP01_khong_quyen.dc.html | LOP-01 · Lớp học · danh sách (không có quyền) | 1440×1000 |
| LOP01_kanban.dc.html | LOP-01 · Lớp học · kanban theo bước duyệt | 1440×1000 |
| LOP03_tao.dc.html | LOP-03 · Tạo / sửa lớp · Tạo lớp mới (nhóm lớp luân phiên Đại, Hình) | 1440×1000 |
| LOP03_rieng.dc.html | LOP-03 · Tạo / sửa lớp · Tạo lớp riêng (khung chương trình tuỳ chọn) | 1440×1000 |
| LOP03_sua.dc.html | LOP-03 · Tạo / sửa lớp · Sửa lớp bị từ chối | 1440×1000 |
| LOP03_loi.dc.html | LOP-03 · Tạo / sửa lớp · Lỗi nhập liệu (thông tin lớp, thời khoá biểu) | 1440×1000 |
| LOP03_tai.dc.html | LOP-03 · Tạo / sửa lớp · Đang tải | 1440×1000 |
| LOP03_quyen.dc.html | LOP-03 · Tạo / sửa lớp · Không có quyền | 1440×1000 |
| LOP03_trung_phong.dc.html | LOP-03 · Tạo / sửa lớp · Cảnh báo trùng phòng (thời khoá biểu) | 1440×1000 |
| LOP03_trung_gv.dc.html | LOP-03 · Tạo / sửa lớp · Cảnh báo trùng giáo viên (không chặn) | 1440×1000 |
| LOP02_nhap.dc.html | LOP-02 · Lớp · Nháp (chưa có Time Table, chưa trình được) | 1440×1000 |
| LOP02_da_trinh.dc.html | LOP-02 · Lớp · Đã trình | 1440×1000 |
| LOP02_da_xac_nhan.dc.html | LOP-02 · Lớp · Đã xác nhận (đã có Time Table, chờ duyệt) | 1440×1000 |
| LOP02_da_duyet.dc.html | LOP-02 · Lớp · Đã duyệt, đang học (nhóm luân phiên Đại, Hình) | 1440×1000 |
| LOP02_tu_choi.dc.html | LOP-02 · Lớp · Từ chối | 1440×1000 |
| LOP02_da_dong.dc.html | LOP-02 · Lớp · Đã đóng (chỉ đọc) | 1440×1000 |
| LOP02_huy.dc.html | LOP-02 · Lớp · Huỷ (chỉ đọc) | 1440×1000 |
| LOP02_tai.dc.html | LOP-02 · Lớp · Đang tải | 1440×1000 |
| LOP02_quyen.dc.html | LOP-02 · Lớp · Không có quyền | 1440×1000 |
| LOP05_trinh.dc.html | LOP-05 · Trình lớp (hộp thoại) | 1440×1000 |
| LOP05_xacnhan.dc.html | LOP-05 · Xác nhận lớp (hộp thoại) | 1440×1000 |
| LOP05_duyet.dc.html | LOP-05 · Duyệt lớp, xem trước buổi sẽ sinh (hộp thoại) | 1440×1000 |
| LOP05_thieu_tkb.dc.html | LOP-05 · Trình lớp bị chặn: thiếu Time Table (hộp thoại) | 1440×1000 |
| LOP05_tuchoi.dc.html | LOP-05 · Từ chối lớp (hộp thoại) | 1440×1000 |
| LOP05_venhap.dc.html | LOP-05 · Đưa lớp về Nháp (hộp thoại) | 1440×1000 |
| LOP06_dong_chan.dc.html | LOP-06 · Đóng lớp bị chặn: còn học sinh còn giờ (hộp thoại) | 1440×1000 |
| LOP06_huy_chan.dc.html | LOP-06 · Huỷ lớp bị chặn: đã có buổi hoàn thành (hộp thoại) | 1440×1000 |
| LOP06_huy.dc.html | LOP-06 · Huỷ lớp (hộp thoại) | 1440×1000 |
| LOP03_da_duyet.dc.html | LOP-03 · Sửa lớp đã duyệt · Chỉ sửa Time Table, CSKH, sĩ số (bấm Lưu thay đổi để xem trước) | 1440×1000 |
| LOP03_da_duyet_loi.dc.html | LOP-03 · Sửa lớp đã duyệt · Lỗi sĩ số, cảnh báo trùng phòng | 1440×1000 |
| LOP09.dc.html | LOP-09 · Học sinh của lớp · lớp thuộc nhóm | 1440×1000 |
| LOP09_khong_nhom.dc.html | LOP-09 · Học sinh của lớp · lớp không thuộc nhóm (ẩn cột Đại/Hình) | 1440×1000 |

### NHOM (21)

| File | Tên khung | w×h |
|---|---|---|
| Nhom_P0.dc.html | Nhóm · P0 Khuôn chung | 1440×220 |
| Nhom_P1.dc.html | Nhóm · P1 Đăng nhập | 1440×220 |
| Nhom_P2.dc.html | Nhóm · P2 Cấu hình và phân quyền | 1440×220 |
| Nhom_P3.dc.html | Nhóm · P3 Tuyển sinh | 1440×220 |
| Nhom_P3_Lead.dc.html | Nhóm con · Lead | 1440×140 |
| Nhom_P3_LichHen.dc.html | Nhóm con · Lịch hẹn | 1440×140 |
| Nhom_P3_CoHoi.dc.html | Nhóm con · Cơ hội | 1440×140 |
| Nhom_P3_PhieuKT.dc.html | Nhóm con · Phiếu kiểm tra | 1440×140 |
| Nhom_P3_GopTrung.dc.html | Nhóm con · Gộp trùng và Nhập lô | 1440×140 |
| Nhom_P4.dc.html | Nhóm · P4 Khách hàng | 1440×220 |
| Nhom_P5.dc.html | Nhóm · P5 · Bán hàng, thu chi, đào tạo | 1440×220 |
| Nhom_P5a.dc.html | Nhóm con · Bán hàng (BH) | 1440×140 |
| Nhom_P5a_TC.dc.html | Nhóm con · Thu chi (TC) | 1440×140 |
| Nhom_P5b.dc.html | Nhóm con · Đào tạo | 1440×140 |
| Nhom_P5b_GD.dc.html | Nhóm con · Ghi danh (GD) | 1440×140 |
| Nhom_P5b_LOP.dc.html | Nhóm con · Lớp (LOP) | 1440×140 |
| Nhom_P5b_BUOI.dc.html | Nhóm con · Buổi (BUOI) | 1440×140 |
| Nhom_P5b_TT.dc.html | Nhóm con · Tái tục (TT) | 1440×140 |
| Nhom_Sau.dc.html | Nhóm · Giai đoạn sau (chưa vẽ) | 1440×220 |
| Nhom_GhiChu.dc.html | Nhóm · Ghi chú cuối | 1440×220 |
| Nhom_CH.dc.html | Nhóm con · Cấu hình bán hàng (CH) | 1440×140 |

### K (48)

| File | Tên khung | w×h |
|---|---|---|
| K1.dc.html | K1 Tổng quan dạng List (Cơ hội) | 1440×1000 |
| K2.dc.html | K2 Tổng quan dạng Kanban (Cơ hội) | 1440×1000 |
| K3.dc.html | K3 Chi tiết Cơ hội CO000121 | 1440×1000 |
| K4.dc.html | K4 Hộp thoại, 5 biến thể | 1440×1000 |
| K5.dc.html | K5 Calendar (Lịch hẹn, tuần) | 1440×1000 |
| K4b.dc.html | K4b · Hộp thoại nhiều bước (Nhập lead từ file) | 1440×1000 |
| K4c.dc.html | K4c · Hộp thoại xem trước tác động | 1440×1000 |
| K4d.dc.html | K4d · Hộp thoại chọn từ danh sách có kiểm tra | 1440×1000 |
| K07b.dc.html | K07b · Biểu mẫu dạng ngăn kéo (Tạo nhanh lead) | 1440×1000 |
| K07c.dc.html | K07c · Hộp thoại cảnh báo trùng khách hàng (đè lên ngăn kéo) | 1440×1000 |
| K09b.dc.html | K09b · Trang chủ theo vai trò (CHUNG-14) | 1440×1000 |
| K0x.dc.html | K0x · Trạng thái chung (tải, rỗng, thông báo) | 1440×1000 |
| K4e1.dc.html | K4e1 · K4e · Bottom sheet: Duyệt đơn hàng (điện thoại) | 390×844 |
| K4e3.dc.html | K4e3 · K4e · Bottom sheet: Từ chối đơn hàng, bước 2 (điện thoại) | 390×844 |
| K4e2.dc.html | K4e2 · K4e · Bottom sheet: Từ chối ticket (điện thoại) | 390×844 |
| K4e4.dc.html | K4e4 · K4e · Bottom sheet: Mật khẩu tạm (điện thoại) | 390×844 |
| K1_loc.dc.html | K1_loc · K1 · Filters (khung thả xuống, đã tick vài lọc) | 1440×1000 |
| K1_loc_chip.dc.html | K1_loc_chip · K1 · Filters (đã áp dụng, chip lọc trên thanh tìm) | 1440×1000 |
| K1_loc_nc.dc.html | K1_loc_nc · K1 · Lọc nâng cao (có 3 dòng điều kiện) | 1440×1000 |
| K1_loc_nc0.dc.html | K1_loc_nc0 · K1 · Lọc nâng cao (rỗng, chưa có điều kiện) | 1440×1000 |
| K1_nhom.dc.html | K1_nhom · K1 · Group By (khung thả xuống, đã chọn 2 cấp) | 1440×1000 |
| K1_nhom_bang.dc.html | K1_nhom_bang · K1 · Group By (bảng đã nhóm 2 cấp, gập/mở) | 1440×1000 |
| K1_nhom0.dc.html | K1_nhom0 · K1 · Group By (rỗng, chưa chọn cấp nào) | 1440×1000 |
| K1_cot.dc.html | K1_cot · K1 · Cột (chọn cột hiển thị, kéo đổi thứ tự) | 1440×1000 |
| K1_fav.dc.html | K1_fav · K1 · Favorites (danh sách bộ lọc đã lưu) | 1440×1000 |
| K1_fav_luu.dc.html | K1_fav_luu · K1 · Favorites (lưu bộ lọc hiện tại) | 1440×1000 |
| K1_fav0.dc.html | K1_fav0 · K1 · Favorites (rỗng) | 1440×1000 |
| K1_tim.dc.html | K1_tim · K1 · Thanh trên: ô tìm kiếm toàn hệ thống (đóng) | 1440×1000 |
| K1_tim_go.dc.html | K1_tim_go · K1 · Tìm kiếm: đang gõ, kết quả nhóm theo loại | 1440×1000 |
| K1_tim0.dc.html | K1_tim0 · K1 · Tìm kiếm: không tìm thấy | 1440×1000 |
| K1_chuong.dc.html | K1_chuong · K1 · Chuông thông báo: danh sách ngắn (3 dòng) | 1440×1000 |
| K1_chuong0.dc.html | K1_chuong0 · K1 · Chuông thông báo: rỗng | 1440×1000 |
| K1m_loc.dc.html | K1m_loc · K1 · Filters (điện thoại, bottom sheet) | 390×844 |
| K1m_nhom.dc.html | K1m_nhom · K1 · Group By (điện thoại, bottom sheet) | 390×844 |
| K1m_cot.dc.html | K1m_cot · K1 · Cột (điện thoại, bottom sheet) | 390×844 |
| K1m_fav.dc.html | K1m_fav · K1 · Favorites (điện thoại, bottom sheet) | 390×844 |
| K1m_tim_dong.dc.html | K1m_tim_dong · K1 · Điện thoại: ô tìm thu thành biểu tượng | 390×844 |
| K1m_tim.dc.html | K1m_tim · K1 · Điện thoại: tìm kiếm toàn màn hình (đang gõ) | 390×844 |
| K1m_tim0.dc.html | K1m_tim0 · K1 · Điện thoại: tìm kiếm toàn màn hình (không tìm thấy) | 390×844 |
| K4f.dc.html | K4f · Hộp thoại gộp trùng | 1440×1000 |
| K5b.dc.html | K5b · Lịch theo phòng, giáo viên (khuôn cho LOP-08, anh duyệt 23/10 · QĐ-Đ7) | 1440×1000 |
| K12_pc.dc.html | K12 · Tác vụ từng bước · máy tính (khuôn cho BUOI-03, chờ duyệt) | 1440×1000 |
| K12.dc.html | K12 · Tác vụ từng bước · điện thoại (khuôn cho BUOI-03, chờ duyệt) | 390×844 |
| K4g.dc.html | K4g · Hộp thoại mật khẩu tạm (hiện một lần) | 1440×1000 |
| K6b.dc.html | K06b · Thẻ chọn đối tượng (khuôn mới đề xuất, chờ duyệt) | 1440×1000 |
| K8b.dc.html | K08b · Danh sách tick chọn nhiều dòng trong hộp thoại (khuôn mới đề xuất, chờ duyệt) | 1440×1000 |
| K8c.dc.html | K08c · Hộp thoại Thêm em (khuôn mới đề xuất, chờ duyệt) | 1440×1000 |
| K06c.dc.html | K06c · Lưới dòng chỉnh sửa trực tiếp (khuôn mới đề xuất, chờ duyệt) | 1440×2450 |

### P (4)

| File | Tên khung | w×h |
|---|---|---|
| P0_v5.dc.html | P0 v5 · Đổi gì so với v4 (gom từ P3 và P4) | 1440×1000 |
| P5a_Tong_quan.dc.html | Bán hàng, Thu chi · Tổng quan | 1440×1000 |
| P5b_Tong_quan.dc.html | Đào tạo · Tổng quan | 1440×1000 |
| P5a_Ghi_chu.dc.html | P5 · Ghi chú | 1440×1000 |

### CHUNG (1)

| File | Tên khung | w×h |
|---|---|---|
| CHUNG_trang_thai.dc.html | P0 · Các trạng thái chung (Đang tải, Không có quyền, Trống, Lỗi mạng, Nút khoá, Hộp xác nhận) | 1440×1000 |

### DN (32)

| File | Tên khung | w×h |
|---|---|---|
| DN01_pc_err.dc.html | DN01_pc_err · Đăng nhập nhân viên · Máy tính · Sai thông tin | 1440×1000 |
| DN01_pc_ok.dc.html | DN01_pc_ok · Đăng nhập nhân viên · Máy tính · Bình thường | 1440×1000 |
| DN01_mb_err.dc.html | DN01_mb_err · Đăng nhập nhân viên · Điện thoại · Sai thông tin | 390×844 |
| DN01_mb_ok.dc.html | DN01_mb_ok · Đăng nhập nhân viên · Điện thoại · Bình thường | 390×844 |
| DN02_pc_err.dc.html | DN02_pc_err · Đăng nhập học sinh · Máy tính · Sai thông tin | 1440×1000 |
| DN02_pc_ok.dc.html | DN02_pc_ok · Đăng nhập học sinh · Máy tính · Bình thường | 1440×1000 |
| DN02_mb_err.dc.html | DN02_mb_err · Đăng nhập học sinh · Điện thoại · Sai thông tin | 390×844 |
| DN02_mb_ok.dc.html | DN02_mb_ok · Đăng nhập học sinh · Điện thoại · Bình thường | 390×844 |
| DN03_pc_code.dc.html | DN03_pc_code · Xác thực hai bước · Máy tính · Mã từ ứng dụng | 1440×1000 |
| DN03_pc_code_err.dc.html | DN03_pc_code_err · Xác thực hai bước · Máy tính · Mã từ ứng dụng · Sai mã | 1440×1000 |
| DN03_mb_code.dc.html | DN03_mb_code · Xác thực hai bước · Điện thoại · Mã từ ứng dụng | 390×844 |
| DN03_mb_code_err.dc.html | DN03_mb_code_err · Xác thực hai bước · Điện thoại · Mã từ ứng dụng · Sai mã | 390×844 |
| DN04_pc_s1.dc.html | DN04_pc_s1 · Thiết lập 2FA · Máy tính · Bước 1/2 | 1440×1000 |
| DN04_pc_s2.dc.html | DN04_pc_s2 · Thiết lập 2FA · Máy tính · Bước 2/2 (Hoàn tất) | 1440×1000 |
| DN04_mb_s1.dc.html | DN04_mb_s1 · Thiết lập 2FA · Điện thoại · Bước 1/2 | 390×844 |
| DN04_mb_s2.dc.html | DN04_mb_s2 · Thiết lập 2FA · Điện thoại · Bước 2/2 (Hoàn tất) | 390×844 |
| DN05_pc_form.dc.html | DN05_pc_form · Quên mật khẩu · Máy tính · Liên hệ quản trị viên | 1440×1000 |
| DN05_mb_form.dc.html | DN05_mb_form · Quên mật khẩu · Điện thoại · Liên hệ quản trị viên | 390×844 |
| DN07_pc_new.dc.html | DN07_pc_new · Đổi mật khẩu lần đầu · Máy tính · Mới mở, chưa nhập | 1440×1000 |
| DN07_pc_ok.dc.html | DN07_pc_ok · Đổi mật khẩu lần đầu · Máy tính · Đủ điều kiện | 1440×1000 |
| DN07_mb_new.dc.html | DN07_mb_new · Đổi mật khẩu lần đầu · Điện thoại · Mới mở, chưa nhập | 390×844 |
| DN07_mb_ok.dc.html | DN07_mb_ok · Đổi mật khẩu lần đầu · Điện thoại · Đủ điều kiện | 390×844 |
| DN08_pc_lock.dc.html | DN08_pc_lock · Không thể đăng nhập · Máy tính · Một câu chung | 1440×1000 |
| DN08_mb_lock.dc.html | DN08_mb_lock · Không thể đăng nhập · Điện thoại · Một câu chung | 390×844 |
| DN09_pc_end.dc.html | DN09_pc_end · Hộp thoại phiên đăng nhập · Máy tính · Hết phiên | 1440×1000 |
| DN09_mb_end.dc.html | DN09_mb_end · Hộp thoại phiên đăng nhập · Điện thoại · Hết phiên | 390×844 |
| DN10_pc_ok.dc.html | DN10_pc_ok · Chọn cổng · Máy tính · Chọn cổng | 1440×1000 |
| DN10_mb_ok.dc.html | DN10_mb_ok · Chọn cổng · Điện thoại · Chọn cổng | 390×844 |
| DN06_pc_new.dc.html | HOÃN · DN06_pc_new · Đặt mật khẩu mới · Máy tính · Mới mở, chưa nhập | 1440×1000 |
| DN06_pc_ok.dc.html | HOÃN · DN06_pc_ok · Đặt mật khẩu mới · Máy tính · Đủ điều kiện | 1440×1000 |
| DN06_mb_new.dc.html | HOÃN · DN06_mb_new · Đặt mật khẩu mới · Điện thoại · Mới mở, chưa nhập | 390×844 |
| DN06_mb_ok.dc.html | HOÃN · DN06_mb_ok · Đặt mật khẩu mới · Điện thoại · Đủ điều kiện | 390×844 |

### CAUHINH (1)

| File | Tên khung | w×h |
|---|---|---|
| CauHinh.dc.html | CauHinh · K5 · Cấu hình | 1440×1000 |

### MATRANQUYEN (3)

| File | Tên khung | w×h |
|---|---|---|
| MaTranQuyen.dc.html | MaTranQuyen · Đ1 · Ma trận quyền | 1440×1000 |
| MaTranQuyen_ls.dc.html | MaTranQuyen_ls · Đ1 · Ma trận quyền: lịch sử phiên bản (danh sách) | 1440×1000 |
| MaTranQuyen_ct.dc.html | MaTranQuyen_ct · Đ1 · Ma trận quyền: lịch sử phiên bản (chi tiết một phiên bản) | 1440×1000 |

### TS (55)

| File | Tên khung | w×h |
|---|---|---|
| TS01.dc.html | TS-01 · Lead · danh sách | 1440×1000 |
| TS01b.dc.html | TS-01 · Lead · chế độ xem kanban (không cấp mã riêng) | 1440×1000 |
| TS01b_nhom_con.dc.html | TS-01b · Lead · kanban · Kéo thẻ sang C3: bắt buộc chọn nhóm con | 1440×1000 |
| TS03.dc.html | TS-03 · Tạo lead (cảnh báo trùng SĐT) | 1440×1000 |
| TS13.dc.html | TS-13 · Hộp thoại tạo / dời lịch hẹn | 1440×1000 |
| TS11_K5.dc.html | TS-11 · K5 Calendar (Lịch hẹn) | 1440×1000 |
| TS11b.dc.html | TS-11 · Lịch hẹn · chế độ xem danh sách (không cấp mã riêng) | 1440×1000 |
| TS11c.dc.html | TS-11 · Lịch hẹn · chế độ xem kanban, cột = trạng thái (không cấp mã riêng) | 1440×1000 |
| TS07_tao.dc.html | TS-07 · Cơ hội · Tạo cơ hội (Source type, Source, Medium; danh sách em; kiểm trùng SĐT) | 1440×1000 |
| TS07_K1.dc.html | TS-07 · Cơ hội · danh sách (K1) | 1440×1000 |
| TS07_K2.dc.html | TS-07 · K2 Tổng quan dạng Kanban (Cơ hội) | 1440×1000 |
| TS07_tao_trung.dc.html | TS-07 · Cơ hội · Tạo cơ hội · SĐT trùng: hộp cảnh báo (TS-14) | 1440×1000 |
| TS09.dc.html | TS-09 · Chuyển CO000121 từ L6A sang L7 (phiếu đã Hoàn thành) | 1440×1000 |
| TS09a.dc.html | TS-09a · Chuyển L7/L8 bị chặn: còn phiếu test dang dở | 1440×1000 |
| TS09b.dc.html | TS-09b · Chuyển L7/L8 khi chưa có phiếu (hoặc phiếu đều Huỷ): lý do bỏ qua test | 1440×1000 |
| TS09c.dc.html | TS-09c · Chuyển L8: chọn L8A/L8B/L8C, không hoàn tác | 1440×1000 |
| TS09d.dc.html | TS-09d · Chuyển sang L5 khi thiếu thông tin học sinh | 1440×1000 |
| TS16.dc.html | TS-16 · Phiếu kiểm tra · danh sách | 1440×1000 |
| TS16b.dc.html | TS-16 · Phiếu kiểm tra · chế độ xem kanban (không cấp mã riêng) | 1440×1000 |
| TS16c.dc.html | TS-16 · Phiếu kiểm tra · chế độ xem lịch (không cấp mã riêng) | 1440×1000 |
| TS17.dc.html | TS-17 · Phiếu kiểm tra · chi tiết | 1440×1000 |
| TS04.dc.html | TS-04 · Nhập lead từ file | 1440×1000 |
| TS10.dc.html | TS-10 · Gộp lead / cơ hội trùng | 1440×1000 |
| TS10b.dc.html | TS-02 · Lead ở trạng thái Đã gộp (LD000241) · trạng thái của bản ghi Lead | 1440×1000 |
| TS10c.dc.html | TS-10c · Gộp bị khoá: hai lead khác cơ sở | 1440×1000 |
| TS08_em1.dc.html | TS-08 · Cơ hội · Một em: thẻ em và + Thêm em, tiêu đề không có +N em | 1440×1000 |
| TS08_em2.dc.html | TS-08 · Cơ hội · Hai em: tiêu đề +1 em, bấm thẻ thứ hai thì các ô đổi theo em đó | 1440×1000 |
| TS08_sua.dc.html | TS-08 · Cơ hội · Sửa một ô và Lưu (nút khoá khi đang lưu, báo Đã lưu) | 1440×1000 |
| TS08_dang_luu.dc.html | TS-08 · Cơ hội · Đang lưu (nút Lưu và Huỷ khoá) | 1440×1000 |
| TS08_loi_mang.dc.html | TS-08 · Cơ hội · Lưu lỗi mạng: báo và có nút Thử lại | 1440×1000 |
| TS08_them.dc.html | TS-08 · Cơ hội · Bấm + Thêm em: hộp K08c, chế độ Em mới | 1440×1000 |
| TS08_them_chon.dc.html | TS-08 · Cơ hội · Bấm + Thêm em: hộp K08c, chế độ Chọn con có sẵn | 1440×1000 |
| TS08_nhieu_phieu.dc.html | TS-08 · Cơ hội · Có 2 phiếu test (một Huỷ, một Hoàn thành), nút Tạo lịch Test mở hộp TS-15 | 1440×1000 |
| TS08_ho_so.dc.html | TS-08 · Cơ hội · Em đã có hồ sơ hiện mã HS, em chưa có hồ sơ không có mã | 1440×1000 |
| TS08_da_hoc.dc.html | TS-08 · Cơ hội · Em đã học (có ghi danh): tên, ngày sinh, năm sinh chỉ xem | 1440×1000 |
| TS08_du5.dc.html | TS-08 · Cơ hội · Đủ 5 em: thẻ + Thêm em bị khoá, lý do Đã đủ 5 em | 1440×1000 |
| TS08_l5_thieu.dc.html | TS-08 · Cơ hội · Chuyển sang L5 khi có em thiếu năm sinh: hộp TS-09d, Đi tới ô cần điền | 1440×1000 |
| TS08_trong.dc.html | TS-08 · Cơ hội · Chưa có em (trống, có hướng dẫn Thêm em) | 1440×1000 |
| TS08_tai.dc.html | TS-08 · Cơ hội · Đang tải | 1440×1000 |
| TS08_quyen.dc.html | TS-08 · Cơ hội · Không có quyền | 1440×1000 |
| TS02_em1.dc.html | TS-02 · Lead · Một em: thẻ em và + Thêm em (không có mã hồ sơ) | 1440×1000 |
| TS02_em2.dc.html | TS-02 · Lead · Hai em: tiêu đề +1 em, bấm thẻ thì các ô đổi theo em đó | 1440×1000 |
| TS02_them.dc.html | TS-02 · Lead · Bấm + Thêm em: hộp K08c chỉ có chế độ em mới, không có công tắc | 1440×1000 |
| TS02_tao.dc.html | TS-02 · Lead · Bấm Tạo cơ hội: mở hộp TS-06 (lead chưa có cơ hội) | 1440×1000 |
| TS06_hop.dc.html | TS-06 · Tạo cơ hội từ lead · Danh sách em, mặc định tick hết, Đã chọn 2/2 em | 1440×1000 |
| TS06_khong_chon.dc.html | TS-06 · Tạo cơ hội từ lead · Bỏ tick hết: nút Tạo vẫn bật, có dòng nhắc, tạo ra cơ hội 0 em | 1440×1000 |
| TS06_da_co.dc.html | TS-06 · Tạo cơ hội từ lead · Lead đã có cơ hội CO000121 (cảnh báo) và em đã ở CO000121 vẫn chọn được | 1440×1000 |
| TS06_them_em.dc.html | TS-06 · Thêm em vào cơ hội cũ · Chọn em (mặc định chọn hết; em trùng họ tên và năm sinh gộp một dòng) | 1440×1000 |
| TS06_vuot.dc.html | TS-06 · Thêm em vào cơ hội cũ · Vượt tối đa 5 em (nút Thêm bị khoá, báo số em) | 1440×1000 |
| TS02_nhom_con.dc.html | TS-02 · Lead · Chuyển giai đoạn C3: bắt buộc chọn nhóm con | 1440×1000 |
| TS02_chua_c4c.dc.html | TS-02 · Lead · Chưa ở C4C: nút Tạo cơ hội mờ, có lý do | 1440×1000 |
| TS02_xac_nhan.dc.html | TS-02 · Lead · C4D: bấm Tạo cơ hội hiện hộp xác nhận tạo thêm | 1440×1000 |
| TS15_hop.dc.html | TS-15 · Tạo phiếu kiểm tra · Ô Em và dòng hướng dẫn, không có nút Thêm em | 1440×1000 |
| TS15_chon_em.dc.html | TS-15 · Tạo phiếu kiểm tra · Danh sách Em: em thiếu năm sinh hiện mờ kèm lý do Thiếu năm sinh | 1440×1000 |
| TS15_hai_phieu.dc.html | TS-15 · Tạo phiếu kiểm tra · Cơ hội hai em: tạo hai phiếu, mỗi phiếu một em | 1440×1000 |

### KH (46)

| File | Tên khung | w×h |
|---|---|---|
| KH01.dc.html | KH-01 · Phụ huynh · danh sách | 1440×1000 |
| KH01_admin.dc.html | KH-01 · Phụ huynh · danh sách · Admin (có Xuất) | 1440×1000 |
| KH01_trong.dc.html | KH-01 · Phụ huynh · danh sách · trống | 1440×1000 |
| KH01_tai.dc.html | KH-01 · Phụ huynh · danh sách · đang tải | 1440×1000 |
| KH01_khong_ket_qua.dc.html | KH-01 · Phụ huynh · danh sách · không có kết quả tìm | 1440×1000 |
| KH01_khong_quyen.dc.html | KH-01 · Phụ huynh · danh sách · không có quyền | 1440×1000 |
| KH04.dc.html | KH-04 · Học sinh · danh sách | 1440×1000 |
| KH04_admin.dc.html | KH-04 · Học sinh · danh sách · Admin (có Xuất) | 1440×1000 |
| KH04_trong.dc.html | KH-04 · Học sinh · danh sách · trống | 1440×1000 |
| KH04_tai.dc.html | KH-04 · Học sinh · danh sách · đang tải | 1440×1000 |
| KH04_khong_ket_qua.dc.html | KH-04 · Học sinh · danh sách · không có kết quả tìm | 1440×1000 |
| KH04_khong_quyen.dc.html | KH-04 · Học sinh · danh sách · không có quyền | 1440×1000 |
| KH02.dc.html | PH-01 · Phụ huynh · Tổng quan (giai đoạn 1) | 1440×1000 |
| KH02_cac_con.dc.html | PH-01 · Phụ huynh · Các con | 1440×1000 |
| KH02_tai_chinh.dc.html | PH-03 · Phụ huynh · Tài chính | 1440×1000 |
| KH02_tai_chinh_mo.dc.html | PH-03 · Phụ huynh · Tài chính (giai đoạn 1: mờ) | 1440×1000 |
| KH02_don.dc.html | PH-01 · Phụ huynh · tab Đơn hàng | 1440×1000 |
| KH02_phieu_thu.dc.html | PH-01 · Phụ huynh · tab Phiếu thu | 1440×1000 |
| KH02_ticket.dc.html | PH-01 · Phụ huynh · tab Ticket | 1440×1000 |
| KH02_tai.dc.html | KH-02 · Phụ huynh · đang tải | 1440×1000 |
| KH02_khong_quyen.dc.html | KH-02 · Phụ huynh · không có quyền | 1440×1000 |
| KH02_kt.dc.html | KH-02 · Phụ huynh · Kế toán xem (chỉ đọc) | 1440×1000 |
| KH03.dc.html | KH-03 · Phụ huynh · Sửa | 1440×1000 |
| KH03_loi.dc.html | KH-03 · Phụ huynh · Sửa · lỗi bắt buộc nhập | 1440×1000 |
| KH03_trung_sdt.dc.html | KH-03 · Phụ huynh · Sửa · lỗi trùng số điện thoại | 1440×1000 |
| KH05.dc.html | HS-01 · Học sinh · Tổng quan (giai đoạn 1) | 1440×1000 |
| KH05_day_du.dc.html | HS-01 · Học sinh · Tổng quan (đầy đủ) | 1440×1000 |
| KH05_trong.dc.html | HS-01 · Học sinh · Tổng quan · hồ sơ mới sinh, chưa có hoạt động | 1440×1000 |
| KH05_hoc_tap.dc.html | HS-02 · Học sinh · Học tập | 1440×1000 |
| KH05_hoc_tap_mo.dc.html | HS-02 · Học sinh · Học tập (giai đoạn 1: mờ) | 1440×1000 |
| KH05_diem_danh.dc.html | HS-03 · Học sinh · Điểm danh, tổng quan các lớp | 1440×1000 |
| KH05_diem_danh_chi_tiet.dc.html | HS-04 · Học sinh · Điểm danh, chi tiết một lớp | 1440×1000 |
| KH05_diem_kiem_tra.dc.html | HS-05 · Học sinh · Điểm kiểm tra (chỉ bảng điểm, biểu đồ làm giai đoạn 3) | 1440×1000 |
| KH05_cham_soc.dc.html | HS-06 · Học sinh · Chăm sóc | 1440×1000 |
| KH05_de_nghi.dc.html | HS-07 · Học sinh · Đề nghị và khiếu nại | 1440×1000 |
| KH05_tai.dc.html | KH-05 · Học sinh · đang tải | 1440×1000 |
| KH05_khong_quyen.dc.html | KH-05 · Học sinh · không có quyền | 1440×1000 |
| KH06.dc.html | KH-06 · Học sinh · Sửa | 1440×1000 |
| KH06_loi.dc.html | KH-06 · Học sinh · Sửa · lỗi bắt buộc nhập | 1440×1000 |
| KH06_trung.dc.html | KH-06 · Học sinh · Sửa · lỗi trùng học sinh | 1440×1000 |
| KH07.dc.html | KH-07 · Gộp trùng · phụ huynh / học sinh | 1440×1000 |
| KH07_trong.dc.html | KH-07 · Gộp trùng · chưa chọn hồ sơ trùng | 1440×1000 |
| KH07_tai.dc.html | KH-07 · Gộp trùng · đang kiểm tra xung đột | 1440×1000 |
| KH07_hs.dc.html | KH-07 · Gộp trùng · học sinh | 1440×1000 |
| KH07_chan.dc.html | KH-07 · Gộp trùng · bị chặn: hai phụ huynh cùng có đơn đang sống (KD7) | 1440×1000 |
| KH07_khac_co_so.dc.html | KH-07 · Gộp trùng · hai hồ sơ khác cơ sở | 1440×1000 |

### CACH (1)

| File | Tên khung | w×h |
|---|---|---|
| Cach_doc_BH_TC_GD.dc.html | Cách đọc Bán hàng, Thu chi, Đào tạo | 1440×720 |

### MAN (7)

| File | Tên khung | w×h |
|---|---|---|
| Man_BH.dc.html | Nhãn màn · BH (gộp 8 nhãn) | 1440×8000 |
| Man_TC.dc.html | Nhãn màn · TC (gộp 12 nhãn) | 1440×8000 |
| Man_TC17.dc.html | Màn · TC-17 Quản lý duyệt, từ chối phiếu thu | 1440×100 |
| Man_GD.dc.html | Nhãn màn · GD (gộp 7 nhãn) | 1440×7840 |
| Man_LOP.dc.html | Nhãn màn · LOP (gộp 8 nhãn) | 1440×8000 |
| Man_BUOI.dc.html | Nhãn màn · BUOI (gộp 13 nhãn) | 1440×8000 |
| Man_TT.dc.html | Nhãn màn · TT (gộp 3 nhãn) | 1440×2690 |

### BH (60)

| File | Tên khung | w×h |
|---|---|---|
| BH01.dc.html | BH-01 · Báo giá · danh sách | 1440×1000 |
| BH01_trong.dc.html | BH-01 · Báo giá · danh sách (trống) | 1440×1000 |
| BH01_tai.dc.html | BH-01 · Báo giá · danh sách (đang tải) | 1440×1000 |
| BH01_khong_quyen.dc.html | BH-01 · Báo giá · danh sách (không có quyền) | 1440×1000 |
| BH02_vao.dc.html | BH-02 · Báo giá · Đường vào: bấm Tạo báo giá trên Cơ hội | 1440×1000 |
| BH02_tao.dc.html | BH-02 · Báo giá · Tạo mới (form trắng, chưa có mã) | 1440×1600 |
| BH02_chon.dc.html | BH-02 · Báo giá · Thêm dòng: chọn gói | 1440×1600 |
| BH02_dong.dc.html | BH-02 · Báo giá · Đã chọn gói (chiết khấu vượt trần) | 1440×1600 |
| BH02_nhap.dc.html | BH-02 · Báo giá · Nháp | 1440×1600 |
| BH02_sua.dc.html | BH-02 · Báo giá · Sửa nháp (có lỗi) | 1440×1600 |
| BH02_gui.dc.html | BH-02 · Báo giá · Đã gửi | 1440×1600 |
| BH02_don.dc.html | BH-02 · Báo giá · Đã chuyển đơn (một đơn) | 1440×1600 |
| BH02_tu_choi.dc.html | BH-02 · Báo giá · Từ chối | 1440×1600 |
| BH02_nhieu_don.dc.html | BH-02 · Báo giá · Đã chuyển đơn, nhiều đơn (mỗi dòng ghi đơn đang giữ nó) | 1440×1600 |
| BH02_tai.dc.html | BH-02 · Báo giá · Đang tải | 1440×1000 |
| BH02_quyen.dc.html | BH-02 · Báo giá · Không có quyền | 1440×1000 |
| BH02_mot_phan.dc.html | BH-02 · Báo giá · Đã gửi, mới có một dòng vào đơn (còn nút Chuyển thành đơn) | 1440×1600 |
| BH02_chan_dong.dc.html | BH-02 · Báo giá · Chặn: dòng đang ở đơn khác (nói rõ dòng số mấy, đơn nào) | 1440×1600 |
| BH02_bh11.dc.html | BH-11 · Cảnh báo cơ hội đã có đơn nháp (hộp thoại trên BH-02) | 1440×1600 |
| BH02_chan_l8.dc.html | BH-02 · Báo giá · Chặn: cơ hội chưa L8, chưa tạo được đơn | 1440×1600 |
| BH02_ck.dc.html | BH-02 · Báo giá · Chọn chính sách chiết khấu (cộng dồn, tối đa một chính sách tặng giờ) | 1440×1600 |
| BH02_tinh.dc.html | BH-02 · Báo giá · Sửa nháp, một dòng đang tính giá (hệ thống chưa trả) | 1440×1600 |
| BH02_loi_mang.dc.html | BH-02 · Báo giá · Sửa nháp, lỗi mạng khi tính giá (có Thử lại) | 1440×1600 |
| BH02_dang_luu.dc.html | BH-02 · Báo giá · Đang lưu (nút Lưu khoá, các ô khoá) | 1440×1600 |
| BH03_in.dc.html | BH-03 · Bản in báo giá (khuôn K13, A4; xem được 5 trạng thái) | 1440×1000 |
| BH05_vao.dc.html | BH-05 · Đơn hàng · Đường vào: bấm Chuyển thành đơn trên Báo giá | 1440×1000 |
| BH05_tao.dc.html | BH-05 · Đơn hàng · Tạo mới từ báo giá (mặc định lấy hết dòng, bỏ bớt được) | 1440×1000 |
| BH05_nhap.dc.html | BH-05 · Đơn hàng · Nháp (hiện tên người duyệt, chọn học sinh 3 cách) | 1440×1000 |
| BH05_nhap_loi.dc.html | BH-05 · Đơn hàng · Nháp (trình bị chặn: báo đúng dòng, ô thiếu) | 1440×1000 |
| BH05_trinh.dc.html | BH-05 · Đơn hàng · Đã trình (chờ duyệt) | 1440×1000 |
| BH05_tran.dc.html | BH-05 · Đơn hàng · Đã trình, chiết khấu vượt trần (Quản lý duyệt) | 1440×1000 |
| BH05_tu_choi.dc.html | BH-05 · Đơn hàng · Bị từ chối (về Nháp) | 1440×1000 |
| BH05_duyet.dc.html | BH-05 · Đơn hàng · Đã duyệt (khoá) | 1440×1000 |
| BH05_duyet_ht.dc.html | BH-05 · Đơn hàng · Đã duyệt, cho học trước | 1440×1000 |
| BH05_thu.dc.html | BH-05 · Đơn hàng · Đã duyệt, đã có phiếu thu và ghi danh | 1440×1000 |
| BH05_huy.dc.html | BH-05 · Đơn hàng · Huỷ | 1440×1000 |
| BH05_tai.dc.html | BH-05 · Đơn hàng · Đang tải | 1440×1000 |
| BH05_quyen.dc.html | BH-05 · Đơn hàng · Không có quyền | 1440×1000 |
| BH05_tao_trang.dc.html | BH-05 · Đơn hàng · Tạo mới từ cơ hội, không qua báo giá (form trắng) | 1440×1000 |
| BH05_chua_ql.dc.html | BH-05 · Đơn hàng · Nháp, người lập chưa có quản lý trực tiếp (không trình được) | 1440×1000 |
| BH05_tu_duyet.dc.html | BH-05 · Đơn hàng · Đã duyệt, Trưởng cơ sở tự duyệt (lịch sử ghi tự duyệt) | 1440×1000 |
| BH05_duyet_thay.dc.html | BH-05 · Đơn hàng · Đã duyệt, Admin duyệt thay (lịch sử ghi Admin duyệt thay) | 1440×1000 |
| BH05_huy_chan.dc.html | BH-05 · Đơn hàng · Huỷ bị chặn: đã cho học trước và em đã học buổi (đi qua ticket) | 1440×1000 |
| BH05_vao_co_hoi.dc.html | BH-05 · Đơn hàng · Đường vào: bấm Tạo đơn hàng trên Cơ hội | 1440×1000 |
| BH05_vao_tai_tuc.dc.html | BH-05 · Đơn hàng · Đường vào: bấm Tạo đơn trên Phiếu tái tục (học sinh, lớp lấy từ phiếu) | 1440×1000 |
| BH06.dc.html | BH-06 · Đơn hàng · danh sách | 1440×1000 |
| BH06_trong.dc.html | BH-06 · Đơn hàng · danh sách (trống) | 1440×1000 |
| BH06_tai.dc.html | BH-06 · Đơn hàng · danh sách (đang tải) | 1440×1000 |
| BH06_khong_quyen.dc.html | BH-06 · Đơn hàng · danh sách (không có quyền) | 1440×1000 |
| BH07_duyet.dc.html | BH-07 · Duyệt hoặc từ chối đơn hàng (máy tính) | 1440×1000 |
| BH07_dt.dc.html | BH-07 · Duyệt đơn hàng (điện thoại, tấm trượt K4e) | 390×844 |
| BH07_dt_tu_choi.dc.html | BH-07 · Từ chối đơn hàng, bước 2 (điện thoại, tấm trượt K4e) | 390×844 |
| BH08_co_buoi.dc.html | BH-08 · Chọn lớp và ngày vào lớp · Lớp đã có buổi | 1440×1000 |
| BH08_luan_phien.dc.html | BH-08 · Chọn lớp và ngày vào lớp · Lớp Đại, Hình luân phiên: chọn được, không báo trùng | 1440×1000 |
| BH08_chua_buoi.dc.html | BH-08 · Chọn lớp và ngày vào lớp · Lớp chưa có buổi, ngày sai thứ | 1440×1000 |
| BH08_trong.dc.html | BH-08 · Chọn lớp và ngày vào lớp · Không có lớp phù hợp | 1440×1000 |
| BH08_tai.dc.html | BH-08 · Chọn lớp và ngày vào lớp · Đang tải | 1440×1000 |
| BH09_bat.dc.html | BH-09 · Bật cho học trước, đóng tiền sau | 1440×1000 |
| BH02_gui_thieu_ns.dc.html | BH-02 · Báo giá · Nháp có em thiếu năm sinh: vẫn lưu và gửi được | 1440×1600 |
| BH05_chan_em.dc.html | BH-05 · Đơn hàng · Trình bị chặn: dòng 2 em Phạm Bảo Nam thiếu năm sinh | 1440×1000 |

### TC (58)

| File | Tên khung | w×h |
|---|---|---|
| TC01.dc.html | TC-01 · Phiếu thu · danh sách | 1440×1000 |
| TC01_trong.dc.html | TC-01 · Phiếu thu · danh sách (trống) | 1440×1000 |
| TC01_tai.dc.html | TC-01 · Phiếu thu · danh sách (đang tải) | 1440×1000 |
| TC01_khong_quyen.dc.html | TC-01 · Phiếu thu · danh sách (không có quyền) | 1440×1000 |
| TC03_tao.dc.html | TC-03 · Tạo phiếu thu từ đơn hàng | 1440×1000 |
| TC03_loi.dc.html | TC-03 · Tạo phiếu thu · Chặn khi quá số tiền còn lại | 1440×1000 |
| TC02_nhap.dc.html | TC-02 · Phiếu thu · Nháp | 1440×1000 |
| TC02_nhap_loi.dc.html | TC-02 · Phiếu thu · Nháp (trình bị chặn: báo đúng ô thiếu) | 1440×1000 |
| TC02_trinh.dc.html | TC-02 · Phiếu thu · Đã trình (người lập xem) | 1440×1000 |
| TC02_trinh_kt.dc.html | TC-02 · Phiếu thu · Đã trình (Kế toán) | 1440×1000 |
| TC02_trinh_ad.dc.html | TC-02 · Phiếu thu · Đã trình (Admin chỉ xem) | 1440×1000 |
| TC02_duyet.dc.html | TC-02 · Phiếu thu · Đã duyệt | 1440×1000 |
| TC02_tu_choi.dc.html | TC-02 · Phiếu thu · Bị từ chối (về Nháp) | 1440×1000 |
| TC02_huy.dc.html | TC-02 · Phiếu thu · Huỷ | 1440×1000 |
| TC02_tai.dc.html | TC-02 · Phiếu thu · Đang tải | 1440×1000 |
| TC02_quyen.dc.html | TC-02 · Phiếu thu · Không có quyền | 1440×1000 |
| TC02_quan_ly.dc.html | TC-02 · Phiếu thu · Đã trình (Quản lý xem) | 1440×1000 |
| TC02_quan_ly_ad.dc.html | TC-02 · Phiếu thu · Đã trình (Admin: chỉ Chuyển người duyệt) | 1440×1000 |
| TC02_cho_kt.dc.html | TC-02 · Phiếu thu · Chờ kế toán (người lập xem) | 1440×1000 |
| TC02_tu_duyet.dc.html | TC-02 · Phiếu thu · Chờ kế toán (Trưởng cơ sở lập, tự duyệt) | 1440×1000 |
| TC02_da_dao.dc.html | TC-02 · Phiếu thu · Đã duyệt, khoản tiền đã đảo | 1440×1000 |
| TC04.dc.html | TC-04 · Hàng chờ kế toán duyệt · danh sách | 1440×1000 |
| TC04_trong.dc.html | TC-04 · Hàng chờ kế toán duyệt · danh sách (trống) | 1440×1000 |
| TC04_tai.dc.html | TC-04 · Hàng chờ kế toán duyệt · danh sách (đang tải) | 1440×1000 |
| TC04_khong_quyen.dc.html | TC-04 · Hàng chờ kế toán duyệt · danh sách (không có quyền) | 1440×1000 |
| TC04_admin.dc.html | TC-04 · Hàng chờ kế toán duyệt · danh sách | 1440×1000 |
| TC05_du_coc.dc.html | TC-05 · Kế toán duyệt, từ chối phiếu thu · Duyệt, đủ cọc: sinh khoản tiền vào và ghi danh | 1440×1000 |
| TC05_chua_du.dc.html | TC-05 · Kế toán duyệt, từ chối phiếu thu · Duyệt, chưa đủ cọc: chưa sinh ghi danh | 1440×1000 |
| TC05_qua_buoi.dc.html | TC-05 · Kế toán duyệt, từ chối phiếu thu · Cảnh báo đã qua N buổi | 1440×1000 |
| TC05_tu_choi.dc.html | TC-05 · Kế toán duyệt, từ chối phiếu thu · Từ chối, thiếu lý do | 1440×1000 |
| TC05_admin.dc.html | TC-05 · Kế toán duyệt, từ chối phiếu thu · Admin chỉ xem, không có nút Duyệt | 1440×1000 |
| TC05_tai.dc.html | TC-05 · Kế toán duyệt, từ chối phiếu thu · Đang tải | 1440×1000 |
| TC17_duyet.dc.html | TC-17 · Quản lý duyệt phiếu thu (hộp thoại) | 1440×1000 |
| TC17_tu_choi.dc.html | TC-17 · Quản lý từ chối phiếu thu (chưa chọn lý do) | 1440×1000 |
| TC17_admin.dc.html | TC-17 · Admin chỉ có Chuyển người duyệt | 1440×1000 |
| TC07_in.dc.html | TC-07 · Bản in biên nhận (khuôn K13, A5) | 1440×1000 |
| TC08.dc.html | TC-08 · Khoản tiền vào · danh sách | 1440×1000 |
| TC08_trong.dc.html | TC-08 · Khoản tiền vào · danh sách (trống) | 1440×1000 |
| TC08_tai.dc.html | TC-08 · Khoản tiền vào · danh sách (đang tải) | 1440×1000 |
| TC08_khong_quyen.dc.html | TC-08 · Khoản tiền vào · danh sách (không có quyền) | 1440×1000 |
| TC08_bm.dc.html | TC-08 · Khoản tiền vào · danh sách | 1440×1000 |
| TC09_dao.dc.html | TC-09 · Đảo khoản tiền | 1440×1000 |
| TC09_chan.dc.html | TC-09 · Đảo khoản tiền · đã đảo, chặn đảo hai lần | 1440×1000 |
| TC10.dc.html | TC-10 · Phiếu chi · danh sách | 1440×1000 |
| TC10_trong.dc.html | TC-10 · Phiếu chi · danh sách (trống) | 1440×1000 |
| TC10_tai.dc.html | TC-10 · Phiếu chi · danh sách (đang tải) | 1440×1000 |
| TC10_khong_quyen.dc.html | TC-10 · Phiếu chi · danh sách (không có quyền) | 1440×1000 |
| TC11.dc.html | TC-11 · Phiếu chi · Đã trình (Kế toán) | 1440×1000 |
| TC11_tai.dc.html | TC-11 · Phiếu chi · Đang tải | 1440×1000 |
| TC11_khong_quyen.dc.html | TC-11 · Phiếu chi · Không có quyền | 1440×1000 |
| TC13.dc.html | TC-13 · Công nợ · danh sách | 1440×1000 |
| TC13_trong.dc.html | TC-13 · Công nợ · danh sách (trống) | 1440×1000 |
| TC13_tai.dc.html | TC-13 · Công nợ · danh sách (đang tải) | 1440×1000 |
| TC13_khong_quyen.dc.html | TC-13 · Công nợ · danh sách (không có quyền) | 1440×1000 |
| TC15.dc.html | TC-15 · Đối soát thu tiền | 1440×1000 |
| TC15_trong.dc.html | TC-15 · Đối soát thu tiền · trống | 1440×1000 |
| TC15_tai.dc.html | TC-15 · Đối soát thu tiền · đang tải | 1440×1000 |
| TC15_khong_quyen.dc.html | TC-15 · Đối soát thu tiền · không có quyền | 1440×1000 |

### GD (32)

| File | Tên khung | w×h |
|---|---|---|
| GD01.dc.html | GD-01 · Ghi danh · danh sách | 1440×1000 |
| GD01_trong.dc.html | GD-01 · Ghi danh · danh sách (trống) | 1440×1000 |
| GD01_tai.dc.html | GD-01 · Ghi danh · danh sách (đang tải) | 1440×1000 |
| GD01_khong_quyen.dc.html | GD-01 · Ghi danh · danh sách (không có quyền) | 1440×1000 |
| GD02_dang_hoc.dc.html | GD-02 · Ghi danh · Đang học (quỹ giờ, chuyển lớp) | 1440×1000 |
| GD02_da_xep.dc.html | GD-02 · Ghi danh · Đã xếp lớp, chưa có buổi hoàn thành | 1440×1000 |
| GD02_cho_xep.dc.html | GD-02 · Ghi danh · Chờ xếp lớp | 1440×1000 |
| GD02_bao_luu.dc.html | GD-02 · Ghi danh · Bảo lưu | 1440×1000 |
| GD02_het_gio.dc.html | GD-02 · Ghi danh · Hết giờ (chặn điểm danh trừ giờ) | 1440×1000 |
| GD02_hoc_truoc.dc.html | GD-02 · Ghi danh · Học trước, quỹ âm trong hạn mức | 1440×1000 |
| GD02_hoan_phi.dc.html | GD-02 · Ghi danh · Hoàn phí (chỉ đọc) | 1440×1000 |
| GD02_tai.dc.html | GD-02 · Ghi danh · Đang tải | 1440×1000 |
| GD02_quyen.dc.html | GD-02 · Ghi danh · Không có quyền | 1440×1000 |
| GD03_nhom.dc.html | GD-03 · Xếp lớp cho ghi danh · Xếp theo nhóm lớp (luân phiên Đại, Hình) | 1440×1000 |
| GD03_le.dc.html | GD-03 · Xếp lớp cho ghi danh · Xếp một lớp lẻ | 1440×1000 |
| GD03_trung_gio.dc.html | GD-03 · Xếp lớp cho ghi danh · Lớp trùng buổi: hiện mờ kèm lý do | 1440×1000 |
| GD03_nhac_mem.dc.html | GD-03 · Xếp lớp cho ghi danh · Nhắc mềm: mới có ghi danh Hình | 1440×1000 |
| GD03_trong.dc.html | GD-03 · Xếp lớp cho ghi danh · Không có lớp phù hợp | 1440×1000 |
| GD03_tai.dc.html | GD-03 · Xếp lớp cho ghi danh · Đang tải | 1440×1000 |
| GD04.dc.html | GD-04 · Sổ giờ · danh sách | 1440×1000 |
| GD04_trong.dc.html | GD-04 · Sổ giờ · danh sách (trống) | 1440×1000 |
| GD04_tai.dc.html | GD-04 · Sổ giờ · danh sách (đang tải) | 1440×1000 |
| GD04_khong_quyen.dc.html | GD-04 · Sổ giờ · danh sách (không có quyền) | 1440×1000 |
| GD05_dieu_chinh.dc.html | GD-05 · Điều chỉnh giờ (dòng ngược dấu, bắt buộc lý do) | 1440×1000 |
| GD06.dc.html | GD-06 · Hàng chờ xếp lớp · danh sách | 1440×1000 |
| GD06_trong.dc.html | GD-06 · Hàng chờ xếp lớp · danh sách (trống) | 1440×1000 |
| GD06_tai.dc.html | GD-06 · Hàng chờ xếp lớp · danh sách (đang tải) | 1440×1000 |
| GD06_khong_quyen.dc.html | GD-06 · Hàng chờ xếp lớp · danh sách (không có quyền) | 1440×1000 |
| GD07.dc.html | GD-07 · Sắp hết giờ · danh sách | 1440×1000 |
| GD07_trong.dc.html | GD-07 · Sắp hết giờ · danh sách (trống) | 1440×1000 |
| GD07_tai.dc.html | GD-07 · Sắp hết giờ · danh sách (đang tải) | 1440×1000 |
| GD07_khong_quyen.dc.html | GD-07 · Sắp hết giờ · danh sách (không có quyền) | 1440×1000 |

### BUOI (50)

| File | Tên khung | w×h |
|---|---|---|
| BUOI01.dc.html | BUOI-01 · Buổi học · danh sách | 1440×1000 |
| BUOI01_trong.dc.html | BUOI-01 · Buổi học · danh sách (trống) | 1440×1000 |
| BUOI01_tai.dc.html | BUOI-01 · Buổi học · danh sách (đang tải) | 1440×1000 |
| BUOI01_khong_quyen.dc.html | BUOI-01 · Buổi học · danh sách (không có quyền) | 1440×1000 |
| BUOI02_nhap.dc.html | BUOI-02 · Buổi học · Nháp (chưa chốt danh sách) | 1440×1000 |
| BUOI02_da_chot.dc.html | BUOI-02 · Buổi học · Đã chốt (điểm danh hai phía) | 1440×1000 |
| BUOI02_chua_done.dc.html | BUOI-02 · Buổi học · Đã chốt, chưa hoàn thành (lý do chưa hoàn thành) | 1440×1000 |
| BUOI02_done.dc.html | BUOI-02 · Buổi học · Hoàn thành (đã trừ giờ) | 1440×1000 |
| BUOI02_huy_co_phi.dc.html | BUOI-02 · Buổi học · Huỷ có tính phí (lớp riêng) | 1440×1000 |
| BUOI02_huy_khong_phi.dc.html | BUOI-02 · Buổi học · Huỷ không tính phí (trung tâm huỷ) | 1440×1000 |
| BUOI02_tai.dc.html | BUOI-02 · Buổi học · Đang tải | 1440×1000 |
| BUOI02_quyen.dc.html | BUOI-02 · Buổi học · Không có quyền | 1440×1000 |
| BUOI04_trung_tam.dc.html | BUOI-04 · Huỷ buổi · trung tâm huỷ (hộp thoại) | 1440×1000 |
| BUOI04_lop_rieng.dc.html | BUOI-04 · Huỷ buổi · học sinh huỷ lớp riêng (hộp thoại) | 1440×1000 |
| BUOI04_loi.dc.html | BUOI-04 · Huỷ buổi · thiếu lý do (hộp thoại) | 1440×1000 |
| BUOI05_doi.dc.html | BUOI-05 · Dời một buổi (hộp thoại) | 1440×1000 |
| BUOI06_hoc_thu.dc.html | BUOI-06 · Thêm học sinh học thử (hộp thoại) | 1440×1000 |
| BUOI07_tao.dc.html | BUOI-07 · Yêu cầu học bù · Biểu mẫu | 1440×1000 |
| BUOI07_loi.dc.html | BUOI-07 · Yêu cầu học bù · Lỗi nhập liệu | 1440×1000 |
| BUOI07_tai.dc.html | BUOI-07 · Yêu cầu học bù · Đang tải | 1440×1000 |
| BUOI07_quyen.dc.html | BUOI-07 · Yêu cầu học bù · Không có quyền | 1440×1000 |
| BUOI08_tao.dc.html | BUOI-08 · Yêu cầu buổi củng cố · Biểu mẫu | 1440×1000 |
| BUOI08_loi.dc.html | BUOI-08 · Yêu cầu buổi củng cố · Lỗi nhập liệu | 1440×1000 |
| BUOI08_tai.dc.html | BUOI-08 · Yêu cầu buổi củng cố · Đang tải | 1440×1000 |
| BUOI08_quyen.dc.html | BUOI-08 · Yêu cầu buổi củng cố · Không có quyền | 1440×1000 |
| BUOI09_tao.dc.html | BUOI-09 · Yêu cầu học bổ trợ · Biểu mẫu | 1440×1000 |
| BUOI09_loi.dc.html | BUOI-09 · Yêu cầu học bổ trợ · Lỗi nhập liệu | 1440×1000 |
| BUOI09_tai.dc.html | BUOI-09 · Yêu cầu học bổ trợ · Đang tải | 1440×1000 |
| BUOI09_quyen.dc.html | BUOI-09 · Yêu cầu học bổ trợ · Không có quyền | 1440×1000 |
| BUOI10.dc.html | BUOI-10 · Duyệt yêu cầu buổi · danh sách | 1440×1000 |
| BUOI10_cskh.dc.html | BUOI-10 · Duyệt yêu cầu buổi · danh sách | 1440×1000 |
| BUOI10_trong.dc.html | BUOI-10 · Duyệt yêu cầu buổi · danh sách (trống) | 1440×1000 |
| BUOI10_tai.dc.html | BUOI-10 · Duyệt yêu cầu buổi · danh sách (đang tải) | 1440×1000 |
| BUOI10_khong_quyen.dc.html | BUOI-10 · Duyệt yêu cầu buổi · danh sách (không có quyền) | 1440×1000 |
| BUOI11.dc.html | BUOI-11 · Học sinh vắng / chưa đến · danh sách | 1440×1000 |
| BUOI11_trong.dc.html | BUOI-11 · Học sinh vắng / chưa đến · danh sách (trống) | 1440×1000 |
| BUOI11_tai.dc.html | BUOI-11 · Học sinh vắng / chưa đến · danh sách (đang tải) | 1440×1000 |
| BUOI11_khong_quyen.dc.html | BUOI-11 · Học sinh vắng / chưa đến · danh sách (không có quyền) | 1440×1000 |
| BUOI12.dc.html | BUOI-12 · Buổi chưa hoàn tất · danh sách | 1440×1000 |
| BUOI12_trong.dc.html | BUOI-12 · Buổi chưa hoàn tất · danh sách (trống) | 1440×1000 |
| BUOI12_tai.dc.html | BUOI-12 · Buổi chưa hoàn tất · danh sách (đang tải) | 1440×1000 |
| BUOI12_khong_quyen.dc.html | BUOI-12 · Buổi chưa hoàn tất · danh sách (không có quyền) | 1440×1000 |
| BUOI13_doi_gv.dc.html | BUOI-13 · Sửa buổi: giáo viên, trợ giảng, thời gian (hộp thoại) | 1440×1000 |
| BUOI14_sua.dc.html | BUOI-14 · Sửa điểm danh sau khi buổi hoàn thành (hộp thoại) | 1440×1000 |
| BUOI15.dc.html | BUOI-15 · Điểm danh · tất cả buổi, mặc định hôm nay | 1440×1000 |
| BUOI15_bao_nghi.dc.html | BUOI-15 · Điểm danh · hộp thoại Báo nghỉ trước | 1440×1000 |
| BUOI15_trong.dc.html | BUOI-15 · Điểm danh · trống | 1440×1000 |
| BUOI15_tai.dc.html | BUOI-15 · Điểm danh · đang tải | 1440×1000 |
| BUOI15_khong_quyen.dc.html | BUOI-15 · Điểm danh · không có quyền | 1440×1000 |
| BUOI15_diem_danh.dc.html | BUOI-15 · Điểm danh · hộp thoại điểm danh từng buổi | 1440×1000 |

### TT (18)

| File | Tên khung | w×h |
|---|---|---|
| TT01.dc.html | TT-01 · Tái tục · danh sách | 1440×1000 |
| TT01_trong.dc.html | TT-01 · Tái tục · danh sách (trống) | 1440×1000 |
| TT01_tai.dc.html | TT-01 · Tái tục · danh sách (đang tải) | 1440×1000 |
| TT01_khong_quyen.dc.html | TT-01 · Tái tục · danh sách (không có quyền) | 1440×1000 |
| TT01_kanban.dc.html | TT-01 · Tái tục · kanban theo giai đoạn | 1440×1000 |
| TT02_l1.dc.html | TT-02 · Phiếu tái tục · L1 Chờ tái tục | 1440×1000 |
| TT02_l3.dc.html | TT-02 · Phiếu tái tục · L3 Đang tư vấn | 1440×1000 |
| TT02_l7.dc.html | TT-02 · Phiếu tái tục · L7 Dự thu | 1440×1000 |
| TT02_l5.dc.html | TT-02 · Phiếu tái tục · L5 Không tái tục | 1440×1000 |
| TT02_chuyen.dc.html | TT-02 · Chuyển giai đoạn (hộp thoại, lý do không tái tục) | 1440×1000 |
| TT02_tai.dc.html | TT-02 · Phiếu tái tục · Đang tải | 1440×1000 |
| TT02_quyen.dc.html | TT-02 · Phiếu tái tục · Không có quyền | 1440×1000 |
| TT02_l6.dc.html | TT-02 · Phiếu tái tục · L6 Đồng ý tái tục (Tạo báo giá, Tạo đơn) | 1440×1000 |
| TT04.dc.html | TT-04 · Đối chiếu tái tục theo tháng · danh sách | 1440×1000 |
| TT04_trong.dc.html | TT-04 · Đối chiếu tái tục theo tháng · trống | 1440×1000 |
| TT04_tai.dc.html | TT-04 · Đối chiếu tái tục theo tháng · đang tải | 1440×1000 |
| TT04_khong_quyen.dc.html | TT-04 · Đối chiếu tái tục theo tháng · không có quyền | 1440×1000 |
| TT03_tao.dc.html | TT-04 · Hộp thoại tạo phiếu tái tục thủ công (TT-03) | 1440×1000 |

### BAOCAO (1)

| File | Tên khung | w×h |
|---|---|---|
| BaoCao.dc.html | TC-15 · Báo cáo trong app (Đối soát thu tiền) | 1440×1000 |

### TIMKIEM (1)

| File | Tên khung | w×h |
|---|---|---|
| TimKiem.dc.html | CHUNG-11/12 · Tìm kiếm + thông báo | 1440×1000 |

### CHUA (1)

| File | Tên khung | w×h |
|---|---|---|
| Chua_ve.dc.html | Mã màn chưa có khung (Giai đoạn sau, mức C) | 1440×1000 |

### GHI (1)

| File | Tên khung | w×h |
|---|---|---|
| Ghi_chu_cuoi.dc.html | Ghi chú cuối · chỗ lệch, câu hỏi, màn dừng | 1440×1000 |

### CH (6)

| File | Tên khung | w×h |
|---|---|---|
| CH03_chinh.dc.html | CH-03 · Bảng giá có ngày hiệu lực · Danh sách bản và giá | 1440×1000 |
| CH03_loi.dc.html | CH-03 · Bảng giá có ngày hiệu lực · Lỗi nhập liệu | 1440×1000 |
| CH04_chinh.dc.html | CH-04 · Chính sách chiết khấu · Hai tab Chiết khấu, Quà tặng | 1440×1000 |
| CH04_loi.dc.html | CH-04 · Chính sách chiết khấu · Lỗi nhập liệu | 1440×1000 |
| CH09_chinh.dc.html | CH-09 · Điều khoản thanh toán · Danh sách và các đợt | 1440×1000 |
| CH09_loi.dc.html | CH-09 · Điều khoản thanh toán · Lỗi chia đợt | 1440×1000 |
