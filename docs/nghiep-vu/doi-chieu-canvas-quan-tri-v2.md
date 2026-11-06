# Đối chiếu canvas "HMT Quản trị và Nạp dữ liệu · bổ sung v2" (06/11/2026)

Gói `design/hmt-canvas-ca9b/` (bản `1793951729-ca9b`): 32 khung, 7 nhãn màn, mục lục, `canvas.json` (40 mục, khớp 40 file), `00_DOC_TRUOC.md`, `GHI_CHU_CHO_CODE.md`. Quy tắc: khung có ở cả hai canvas thì bản bổ sung thắng; **canvas vênh luật thì làm theo luật**, ghi vào PR. Dữ liệu và số trong khung chỉ là ví dụ.

## 1. Khung đã đủ để dựng

| Màn | Khung | Khuôn gần nhất | Đủ? |
|---|---|---|---|
| QT-18 Nhập dữ liệu | `QT18_chon_loai`, `_tai_file`, `_sai_dinh_dang`, `_xem_truoc`, `_dang_xu_ly`, `_ket_qua`, `_chan_loai`, `_mat_khau_hang_loat`, `_112`, `_dt` | K4b (hộp nhiều bước), K4g | Đủ, gồm nút **Tải file mẫu** và cột Cảnh báo |
| QT-02 Đặt lại mật khẩu | `QT02_hanh_dong_dat_lai`, `_xac_nhan_dat_lai`, `_dt` | K06, K4g, K4e4 | Đủ (đã làm, #172) |
| QT-03 Tạo người dùng, Sửa email | `QT03_tao`, `_tao_trung`, `_sua_email`, `_sua_email_trung` | K07 | Đủ |
| QT-07 Danh mục | `QT07_them_muc`, `_doi_ten`, `_ngung_dung_lai`, `_nhieu_cap` | K10 | Đủ |
| CH-03 Bảng giá, ô trống | `CH03_danh_sach_gia_trong`, `CH03_gia_trong` (cùng `CH03_chinh`, `CH03_loi` của v146) | K10 | Đủ |
| CH-01 Gói bán | `CH01_danh_sach`, `_tao`, `_sua_ten`, `_ngung` | K10 | Đủ |
| QT-08 Cơ sở và phòng | `QT08_danh_sach`, `_sua_co_so`, `_them_phong`, `_sua_phong`, `_ngung_phong` | K10 | Đủ |
| Chiết khấu (CH-04), Điều khoản (CH-09), Công tắc tính năng | `CH04_*`, `CH09_*` (v146), `CauHinh` (P2) | K10 | Đủ, không cần khung mới |

**Kết luận:** không màn nào thiếu khung. Không cần nhờ Design vẽ thêm.

## 2. Chỗ cần Code làm khác canvas hoặc cần quyết định (theo luật)

1. **Mục menu QT-18:** canvas đặt "Nhập dữ liệu" ở **cuối nhóm Quản trị** (sau Nhật ký). Bản hiện tại (T5) đặt trước Nhật ký đăng nhập: chuyển xuống cuối. Thêm dòng QT-18 vào `docs/design/ban-do-man-hinh.md` (đã thêm).
2. **8 loại nạp:** thứ tự canvas: Người dùng, Lớp, Phụ huynh, Học sinh, Ghi danh, Số dư, Cơ hội, Phiếu test. **Lớp, Ghi danh, Số dư, Phiếu test ghi "Sắp có", nút Nhập khoá.** Cột "Cần có trước" và "Trạng thái". Tên cột bắt buộc theo hàm nạp (Code chốt), không theo ví dụ.
3. **Ghi danh và Số dư: một dòng lỗi thì không nạp cả loại** (nút Nạp thật khoá, khung `QT18_chan_loai`). Các loại khác: dòng lỗi và trùng bị bỏ qua, nạp dòng hợp lệ. Hiện chỉ có kiểu thứ hai; kiểu "cả loại" làm cùng lúc có hàm nạp Ghi danh, Số dư.
4. **Báo lỗi:** canvas ghi *số dòng, chữ cái đầu tên (ví dụ N.T.L), tên cột lỗi*. Hiện kết quả chỉ có số dòng và **một** chữ cái đầu, chưa có tên cột lỗi. **Làm theo canvas** (chữ cái đầu mỗi từ, không in tên đầy đủ; thêm `column` vào lỗi từng dòng của các hàm nạp), cả trên màn lẫn file tải về; không vênh luật (vẫn không in họ tên, SĐT).
5. **Mật khẩu hàng loạt:** hộp chỉ **tóm tắt số người theo loại** (Giáo viên gồm trợ giảng; Nhân viên văn phòng), không liệt kê từng người; mật khẩu chỉ trong file tải một lần; nút Đóng khoá tới khi tải file (hoặc tick xác nhận); lối thoát khi mất file là Đặt lại mật khẩu từng người ở QT-02. Hiện hộp liệt kê số tổng, chưa tóm tắt theo loại: làm theo canvas.
6. **Nút Tải file mẫu** ở mọi bước: file CSV có dòng tên cột và một dòng ví dụ giả cho từng loại.
7. **QT-03 Tạo người dùng:** form có **tên đăng nhập** (hệ thống gợi ý theo họ tên, sửa được trước khi tạo, không đổi sau khi tạo) **và email**; mã nhân sự tự cấp; trùng báo ngay ở ô. Cần cột `username` riêng của tài khoản (hiện lưu ở `legacy_ref` khi nạp) và đăng nhập bằng tên đăng nhập; làm cùng đợt Người dùng, **cần anh duyệt migration trước khi viết**.
8. **Sửa email (QT-03):** luật hiện **chặn đổi `login_name`** (R-HT-02 và bài kiểm); canvas vẽ hộp Sửa email. **Chưa làm: hỏi anh qua Chat ghi luật** (cho Admin đổi email qua Edge Function, kiểm trùng, thu hồi phiên cũ, ghi nhật ký) rồi mới viết. Email quy ước thật là `<tên đăng nhập>@nv.hmt.invalid` (khung ghi `@example.test` chỉ minh hoạ).
9. **QT-07 Danh mục:** nút **Dùng lại** (mục Ngừng) chưa có trong spec: **ghi vào `docs/spec`** (anh duyệt giữ nút). Thêm mục, đổi tên hiển thị, đổi thứ tự, Ngừng; mã không đổi, không xoá; nhiều cấp làm từng cấp. Hàm DB đã có (`catalog_add_item`, `catalog_rename_item`, `catalog_reorder_item`, `catalog_set_item_active`).
10. **CH-03 ô trống:** hai trạng thái **Chưa có giá** (chip hổ phách, "Chờ cập nhật, không phải ngừng bán", R-TIEN-10) và **Không bán** (chip xám, "Gói không bán hình thức này", R-TIEN-15). Trong DB: **chưa có dòng giá nào** của hình thức đó = Chưa có giá; **dòng giá có đơn giá trống** (do `add_package_price` cho phép) = Không bán. Không thêm nhãn "Chưa cấu hình" riêng. Hộp Thêm bảng giá mới cho để trống ô giá.
11. **CH-01 Gói bán:** mã gói `Loại-Môn-Khối` (hoặc khối đầu, khối cuối), không chứa hình thức; **không có số giờ** (chốt 05/11); sửa gói chỉ đổi **tên** và **mã cũ** (`legacy_ref`, ô "Mã cũ (Sheet)"); mã khoá. Ngừng bán và **Dùng lại** (gói): cần hàm đổi trạng thái gói (hiện `save_sales_package` không bật, tắt gói): thêm hàm nhỏ, **cần anh duyệt migration**.
12. **QT-08 Cơ sở và phòng:** cơ sở là danh mục khoá: **không thêm, không ngừng**; chỉ sửa **tên hiển thị và địa chỉ**; CS3 Hội sở không có phòng (theo R-V2-10 CS3 nay là cơ sở dạy học thường: canvas ghi CS3 là văn phòng, **vênh luật, làm theo luật** (R-V2-10)). Phòng: thêm, sửa tên và sức chứa, Ngừng, Dùng lại. Cần hàm DB mới (thêm, sửa, đổi trạng thái phòng; sửa tên, địa chỉ cơ sở): **cần anh duyệt migration**.
13. **Ngoại lệ R-CRM-27:** màn Nhập chỉ Admin dùng, gọi hàm nạp riêng, không phải Tạo tay: ghi vào `docs/spec/04` (PR tài liệu cuối ngày).

## 3. Lịch (theo #176)
- Đợt 1 (Người dùng: Đặt lại mật khẩu đã xong; Tạo và Sửa email cần anh duyệt migration `username` và luật Sửa email) trước 09/11.
- Đợt 2 (Bảng giá, Gói bán) trước 11/11; Danh mục và Cơ sở, phòng trong cùng tuần.
- Chỉnh màn Nhập theo khung QT-18 và nút Tải file mẫu: 13 đến 14/11 như lịch.
