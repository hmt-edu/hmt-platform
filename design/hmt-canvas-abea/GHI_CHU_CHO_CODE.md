# Ghi chú cho Code: chỗ canvas vênh luật

Canvas HMT Platform v146 (`1793854902-9933`) là bản chuẩn, anh Trường đã duyệt. Những chỗ dưới đây trên canvas **vênh luật** hoặc **chưa vẽ theo quyết định mới**. **Code làm theo luật**, không làm theo canvas.

## 1. Vượt trần chiết khấu: chỉ cảnh báo, không chặn, không cần Trưởng cơ sở duyệt (R-V2-11, chốt 04/11/2026)
R-V2-11 **thay** R-TIEN-29 ("vượt trần phải quản lý cơ sở duyệt") và ô tích "Đồng ý chiết khấu vượt trần" khi duyệt (Đ102). Trần 20% mỗi dòng, tính trên giá niêm yết (gồm % ưu đãi, giờ tặng quy ra %, phần voucher chia về dòng) (theo mục 2, chưa vào luật). Vượt trần ở mọi bước (Báo giá, Đơn hàng lúc trình và duyệt, Phiếu thu): **chỉ hiện cảnh báo**; vẫn lưu, vẫn gửi, trình, duyệt được; **không** cần Trưởng cơ sở hay quản lý duyệt thêm vì vượt trần; **không** có ô tích đồng ý.
- Khung Tạo báo giá (`BH02_tao_moi`), chữ theo Q-113: "Trần chiết khấu mỗi dòng 20%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được."
- Chữ dưới bảng Dòng đơn của mọi khung `BH05_*` trong canvas này: "Chiết khấu cộng dồn; giờ tặng quy ra % tính vào trần 20%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được." (chữ tạm của Design theo Q-113; thay chữ cũ "không quá 20%", R-TIEN-29). Khung ở canvas chính không sửa trong đợt này; Code làm theo R-V2-11 ở mọi màn.

## 2. Chiết khấu chip, ưu đãi linh hoạt, voucher: quy tắc dưới đây do anh Trường chốt trong bình luận, CHƯA vào luật. Code đối chiếu với luật hiện có; chỗ nào khác luật thì hỏi Chat trước khi làm
- Cột "Chiết khấu": chip chọn nhiều, "+ Thêm", ✕ trên từng chip; cột "Tổng %" cộng dồn.
- Chip "Ưu đãi linh hoạt" (R-V2-45, Q-144, anh OK): nhân viên **tự gõ %** ngay trong chip (chip ghi "Ưu đãi linh hoạt 3%", không ghi % trong ngoặc), không cần lý do, ai có quyền lên đơn đều dùng. **Hạn mức mỗi dòng mặc định 5%**, Admin sửa ở Cài đặt (0–20%; tham số "Ưu đãi linh hoạt tối đa mỗi dòng", nhóm Bán hàng, không ghi đè cơ sở). % này **cộng vào trần 20% tổng**. **Vượt hạn mức dòng: không cho lưu** (chữ đỏ ngay dưới chip của dòng đó: "Ưu đãi linh hoạt tối đa 5%", nút Lưu mờ). **Vượt trần 20% tổng: chỉ cảnh báo** (R-V2-11), vẫn lưu và gửi được.
- Khung chip (08/11/2026, đợt 5): `BH02_chip_linh_hoat`, `BH02_chip_vuot_han_muc`, `BH02_chip_vuot_tran`, `BH05_chip_linh_hoat`, `BH05_chip_vuot_han_muc`, `BH05_chip_vuot_tran`, `BH05_log_tao_truc_tiep`, `BH05_log_tao_tu_bao_gia`. Ô Chiết khấu **một hàng, không xuống dòng**, bảng cuộn ngang; mỗi chip có ✕ (bỏ chip), cuối ô có "+ Thêm", cột "Tổng %" cộng dồn (gồm giờ tặng quy ra %). Ở khung Đơn đang sửa, Tổng % của dòng đổi ngay, còn Giảm và Thành tiền vẫn "chưa tính lại, bấm Lưu" như các khung sửa khác. Số 5 trong câu lỗi "Ưu đãi linh hoạt tối đa 5%" là hạn mức đang cấu hình; Code thay theo giá trị thật. Khung vượt trần dùng đúng câu đã có ở BH02 và BH05, đặt trong hộp cảnh báo vàng.
- Nhật ký Đơn: sự kiện TAO và SUA có thêm dòng "Ưu đãi linh hoạt X% ở dòng N". Đơn tạo từ báo giá: dòng ở sự kiện TAO có thêm cuối dòng "(nhập ở báo giá BG-CS1-2610-0007)". Ví dụ trong khung: TAO ghi 3% ở dòng 2; SUA ghi 5% ở dòng 2 (SUA không có hậu tố). **Chữ tạm của Design:** "Đơn nháp tạo trực tiếp." và "Dòng 2 chiết khấu: 13% → 15%". Ví dụ SUA đổi 3% thành 5% để hai sự kiện khác nhau, Code ghi theo dữ liệu thật.
- Đồng bộ: các khung có cột chiết khấu trong canvas này (15 khung BH05 xem hoặc sửa, gồm `BH05_vao_tai_tuc_sua`, cộng `BH05_tao_moi`, `BH05_tao_trang_moi`, `BH02_tao_moi`: tổng 18 khung) đã đổi hai cột "Loại chiết khấu, %" thành "Chiết khấu" (chip) và "Tổng %". Khung cùng loại ở canvas chính vẫn kiểu cũ: canvas bổ sung thắng, Code làm theo canvas này. **Giữ nguyên (Q-152, anh OK 08/11/2026):** hộp thoại "Duyệt đơn hàng" (bh07) vẫn bảng tóm tắt cột "Chiết khấu" dạng số %, không đổi sang chip; `BH05_co_don_nhap` không có cột chiết khấu nên giữ. Tên chip trong khung (Giảm anh chị em, Ưu đãi đóng sớm, Khuyến mãi tháng 10) là số mẫu.
- Voucher: một dòng đơn loại "Voucher", gắn một em, số lượng 1, đơn giá và thành tiền âm. Bên trong chia về các dòng học của em theo tỉ lệ thành tiền (làm tròn, dòng cuối nhận phần dư), lưu lúc tạo đơn; màn chỉ hiện một dòng. Hoàn tiền theo dòng học, voucher không hoàn. Ghi nhận giảm trừ doanh thu; trên hoá đơn là một dòng giảm giá riêng.
- Tính: % trên giá niêm yết trước, rồi trừ voucher. Đơn chỉ có voucher không lưu được ("Thêm ít nhất một dòng học"); tổng đơn không được âm.
- Áp dụng cho Đơn hàng (BH05) và Báo giá (BH02).
- Bản in báo giá (`BH03_in`): cột Chiết khấu chỉ in %, 0% in 0%; voucher một dòng riêng, số âm.
- Khung còn kiểu cũ (có "+ Chính sách" hoặc cột "Loại chiết khấu", chọn một %), liệt kê từng tên:
  - Báo giá: BH02_chon, BH02_tao, BH02_sua, BH02_tinh, BH02_gui_thieu_ns, BH02_loi_mang, BH02_bh11, BH02_chan_dong, BH02_chan_l8, BH02_don, BH02_gui, BH02_mot_phan, BH02_nhap, BH02_nhieu_don, BH02_tu_choi
  - Khác: K06c
  - Đơn hàng: BH05_tao, BH05_tao_trang, BH05_nhap, BH05_nhap_loi, BH05_trinh, BH05_chua_ql, BH05_duyet, BH05_duyet_ht, BH05_duyet_thay, BH05_tu_duyet, BH05_tu_choi, BH05_huy, BH05_huy_chan, BH05_chan_em, BH05_tran, BH05_thu
  - Phiếu thu: TC03_tao, TC03_loi

## 3. Hai ô "Hình thức thanh toán" và "Cơ sở thu tiền"
Thuộc phiếu thu (Đ258), không thuộc đơn hàng. Đã bỏ ở các khung Đơn hàng (`BH05_*`, `BH07_duyet`, `BH08_*`, `BH09_bat`). Phiếu thu, phiếu chi (TC02_*, gồm cả TC02_no_dau_ky_* là phiếu thu loại nợ đầu kỳ, TC03_*, TC05_*, TC11, TC17_*) giữ nguyên, kể cả hai ô Hình thức thanh toán và Cơ sở thu tiền. Đơn hàng giữ "Kiểu thanh toán".

## 4. Thu nợ đầu kỳ
Khung ở canvas "HMT Bán hàng & Thu chi · bổ sung". Nợ từng em, ô Em bắt buộc. Luồng Nháp → Chờ kế toán → Đã duyệt.
- CSKH tạo, kế toán duyệt (không qua quản lý), không cần đơn hàng.
- Số tiền không vượt nợ còn lại của em đó.
- Tổng nợ phụ huynh bằng tổng nợ các em.
- Ô Mã giao dịch ở khung đang bắt buộc kể cả khi chọn Tiền mặt, và danh sách hình thức (Chuyển khoản, Tiền mặt, Quẹt thẻ) là chữ gõ sẵn: Code làm theo luật phiếu thu và danh mục cấu hình, không theo khung.

## 5. Bản in báo giá (`BH03_in`): v68 chưa đúng quyết định của anh Trường
Code làm theo quyết định (thread 9233dbe0), không làm theo canvas:
- Cột Chiết khấu chỉ in **%** (ví dụ 10%), không in tên chính sách ("Giảm anh chị em · 10%" là sai). Không có chiết khấu thì in 0%.
- Số tiền giảm in ở cột **Giảm** riêng, số căn phải; không ghi dấu "−" ở dòng học.
- Dòng quà tặng và voucher: cột Giờ mua in "—", không in "1 cuốn" hay "1 giờ".
- Voucher in **một dòng riêng**, số âm (ví dụ − 1.500.000), tổng tiền đã trừ voucher.
- Bố cục v68 lệch cột (số, chữ không thẳng hàng); in theo cột cố định: số căn phải, chữ căn trái.

## 6. Đơn hàng (BH05) và Phiếu thu (TC02): nút, dòng thời gian khi sửa (anh Trường chốt 07/11/2026, Q-49 đến Q-53; bổ sung 08/11/2026, Q-90 đến Q-95)
Chỉ áp dụng họ BH05 và TC02. **Không đụng Báo giá (BH02)** và các họ khác, **trừ** khung Tạo báo giá (`BH02_tao_moi`, Q-94), 4 khung Sửa báo giá `BH02_sua*` (Q-161, mục 8) và việc bỏ hai nút ở điểm 12. Khung mới ở canvas này **thay** khung cũ cùng loại (khung cũ ở canvas HMT Platform giữ nguyên, không sửa); khi Code dựng màn, dùng khung mới:

| Khung mới | Quan hệ với khung cũ |
|---|---|
| `BH05_nhap_xem` | mới (chưa có khung xem Nháp) |
| `BH05_nhap_sua` | thay BH05_nhap |
| `BH05_nhap_loi_xem` | thay BH05_nhap_loi (chuyển sang trạng thái xem) |
| `BH05_tu_choi_xem` | thay BH05_tu_choi |
| `BH05_tu_choi_xac_nhan` | mới |
| `BH05_trinh_lai_chua_sua` | mới |
| `BH05_chan_em_sua` | thay BH05_chan_em |
| `BH05_chua_ql_sua` | thay BH05_chua_ql |
| `BH05_vao_tai_tuc_sua` | thay BH05_vao_tai_tuc |
| `TC02_nhap_xem` | thay TC02_nhap |
| `TC02_nhap_sua` | mới (TC02_nhap và TC02_nhap_loi cũ vẽ nút Sửa/Lưu sai chỗ) |
| `TC02_nhap_loi_xem` | thay TC02_nhap_loi |
| `TC02_tu_choi_xem` | thay TC02_tu_choi |
| `TC02_tu_choi_xac_nhan` | mới |
| `TC02_trinh_lai_chua_sua` | mới |
| `BH05_nhap_xem_ql_khoa`, `BH05_nhap_xem_ql_thieu_quyen`, `BH05_nhap_xem_chua_ql` | mới (dòng chặn trình, mục 9); `BH05_nhap_xem_chua_ql` **sửa** 08/11 đợt 2 (mục 9 điểm c) |
| `TC02_nhap_xem_ql_khoa`, `TC02_nhap_xem_ql_thieu_quyen`, `TC02_nhap_xem_chua_ql` | mới (dòng chặn trình, mục 9); `TC02_nhap_xem_chua_ql` **sửa** 08/11 đợt 2 |
| `BH05_nhap_xem_chua_ql_nguoi_khac`, `BH05_nhap_xem_chua_ql_khong_tcs`, `BH05_da_trinh_cho_tcs` | mới 08/11 đợt 2 (mục 9 điểm c, d) |
| `TC02_nhap_xem_chua_ql_nguoi_khac`, `TC02_nhap_xem_chua_ql_khong_tcs`, `TC02_da_trinh_cho_tcs` | mới 08/11 đợt 2 (mục 9 điểm c, d) |
| `BH05_tao_moi` | thay BH05_tao (khuôn bản ghi chung, mục 11) |
| `BH05_tao_trang_moi` | thay BH05_tao_trang (mục 11) |
| `BH02_tao_moi` | thay BH02_tao (mục 11; Q-94 thay Q-53 cho riêng khung Tạo báo giá) |
| `BH05_co_don_nhap` | mới (hộp BH-11, mục 10) |

Luật vẽ:
1. **Xem**: thanh tiêu đề có **Sửa đơn** (Phiếu thu: **Sửa**) và **Hành động**. Hàng dưới thanh giai đoạn chỉ có nút chuyển giai đoạn (Trình duyệt, Trình quản lý, Trình lại).
2. **Đang sửa**: thanh tiêu đề có **Lưu** (nút chính) và **Huỷ**. Nút chuyển giai đoạn bị khoá, ghi "Lưu hoặc Huỷ rồi mới trình".
3. **Cột bảng khi sửa** giữ đủ như khi xem (11 cột và cột bỏ dòng). Khi người dùng đổi số giờ, các số tiền (Đơn giá, Giảm, Thành tiền, Tổng đơn) **hiện mờ** kèm dòng "Chưa tính lại, bấm Lưu để cập nhật." đặt **ngay trên bảng dòng đơn** (luôn thấy, không phụ thuộc cuộn ngang; độ rộng cột và thanh cuộn ngang giữ như khung cũ, Q-56). Áp dụng cho mọi khung BH05 ở trạng thái sửa (`BH05_nhap_sua`, `BH05_chan_em_sua`, `BH05_chua_ql_sua`, `BH05_vao_tai_tuc_sua`). Phiếu thu không có bảng dòng tính tiền nên không có dòng này. **Không tính tiền ở trình duyệt, kể cả xem trước**; số tiền do hàm DB tính khi Lưu.
4. **Không có khối "Lịch sử xử lý" ở cuối trang.** Mọi sự kiện nằm ở cột phải "Ghi chú & hoạt động" (dòng thời gian). Khối cuối trang trong code là phần Code tự thêm, bỏ đi.
5. **Dòng thời gian, mục Sửa đơn**: một mục mỗi lần Lưu, ghi từng trường đổi dạng "Dòng 1 (học sinh · gói) số giờ ~~20~~ → 24", tối đa 5 dòng đổi rồi nút "và N thay đổi khác". Đơn tạo từ báo giá mà nội dung đã khác báo giá thì tiêu đề mục là "Sửa đơn (đã sửa so với báo giá BG-xxx)". Không có chip "Khác báo giá" và không có mục riêng "Đơn khác báo giá". Các số liệu trong mục (số giờ, % chiết khấu, tổng) là số minh hoạ.
6. **Trình lại khi chưa sửa từ lần bị từ chối** (anh chốt Q-29): bấm Trình lại thì hiện hộp xác nhận (khuôn K08) "Đơn chưa sửa từ lần bị từ chối. Vẫn trình?" với hai nút Quay lại sửa và Vẫn trình. **Không chặn.** Nếu vẫn trình, dòng thời gian ghi mục Trình duyệt kèm dòng cảnh báo vàng "Gửi lại, chưa sửa từ lần bị từ chối" (chữ anh chốt Q-60). Khung: `*_tu_choi_xac_nhan` và `*_trinh_lai_chua_sua`. **Khối đỏ "Đơn bị từ chối" / "Phiếu bị từ chối" / "Kế toán từ chối" bỏ ở cả `*_tu_choi_xem` và `*_tu_choi_xac_nhan`** (Q-90): lý do từ chối đã nằm ở dòng thời gian. Riêng Phiếu thu giữ câu "Chia tiền vào dòng được mở khoá vì phiếu đã về Nháp" thành chữ nhỏ cạnh "Chia tiền vào dòng đơn".
7. **Cột phải Phiếu thu** dùng cột chuẩn "Ghi chú & hoạt động" (Q-52), giống Đơn hàng.
8. Các khung cùng họ không nằm trong bảng trên (BH05_trinh, BH05_duyet, BH05_huy, BH05_thu, TC02_trinh, TC02_duyet, TC02_cho_kt, TC02_no_dau_ky_*…) **không đổi**.
9. **Dòng chặn trình (Q-91)**, chỉ Đơn hàng và Phiếu thu. Khi người lập chưa trình được vì người duyệt, hàng nút nghiệp vụ chỉ có **một dòng chữ cạnh nút Trình, nút Trình hiện mờ**. Không còn hai khối đỏ và vàng riêng. Ba biến thể (khung `*_nhap_xem_ql_khoa`, `*_nhap_xem_ql_thieu_quyen`, `*_nhap_xem_chua_ql`), chữ theo câu thật trong app của Code:
   - (a) quản lý trực tiếp **bị khoá**: "Lê Văn Phong đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đổi quản lý trực tiếp." (phần "Nhờ Admin…" do Design viết, Code đối chiếu).
   - (b) quản lý trực tiếp **chưa có quyền duyệt** (`NGUOI_DUYET_THIEU_QUYEN`, Q-62/Q-63): "Lê Văn Phong chưa có quyền Duyệt đơn hàng" (Phiếu thu: "…chưa có quyền Duyệt phiếu thu"). Chỉ vẽ phần Chat đã biết, không thêm ý; phần sau câu này chờ Chat gửi.
   - **Chữ do Design suy ra, chưa Chat xác nhận, Code đối chiếu với hệ thống thật**: chữ dòng chặn của **Phiếu thu** (tên quyền "Duyệt phiếu thu") và đoạn "mở khoá hoặc đổi quản lý trực tiếp" ở (a). Chỉ câu (b) của Đơn hàng và các câu ở (c), (d) là câu của Code.
   - (c) **người lập chưa có quản lý trực tiếp** (R-V2-41; đợt 08/11/2026, Chat chuyển chữ từ Code): người duyệt dự phòng là **Trưởng cơ sở** của cơ sở (**R-V2-41**: không chốt tên người, chữ chỉ ghi "Trưởng cơ sở"). **Không chặn**: nút Trình dùng được (không mờ), một dòng chữ cạnh nút:
     - Người lập xem: "Người duyệt: Trưởng cơ sở · bạn chưa có quản lý trực tiếp" (khung `BH05_nhap_xem_chua_ql`, `TC02_nhap_xem_chua_ql`, **sửa** khung cũ).
     - Người khác xem: "Người duyệt: Trưởng cơ sở · người lập chưa có quản lý trực tiếp" (khung mới `BH05_nhap_xem_chua_ql_nguoi_khac`, `TC02_nhap_xem_chua_ql_nguoi_khac`).
     - Đơn Đã trình: "Đơn đã trình, chờ Trưởng cơ sở duyệt. Trong lúc chờ không sửa được dòng." (khung mới `BH05_da_trinh_cho_tcs`). Cột "Người xử lý và cơ sở" có thêm ô "Người duyệt: Trưởng cơ sở" (đơn do Trưởng cơ sở duyệt thì ghi "Trưởng cơ sở"; đơn có quản lý trực tiếp thì ghi tên người đã chốt, như `BH05_trinh_lai_chua_sua` ghi "Lê Văn Phong"; mọi khung đơn Đã trình hoặc Đã duyệt có ô này). Nhật ký: "Trình duyệt đơn, chờ Trưởng cơ sở duyệt."
     - Phiếu thu Đã trình: "Đã trình, chờ Trưởng cơ sở duyệt." rồi giữ phần sau như khung phiếu thu hiện có: "Trong lúc chờ không sửa được; còn Huỷ được khi phiếu chưa duyệt." (khung mới `TC02_da_trinh_cho_tcs`). Nhật ký: "Trình duyệt phiếu, chờ Trưởng cơ sở duyệt." (chữ tạm của Design). **Phiếu thu giữ tên nút "Trình quản lý"**, cạnh nút có "Người duyệt: Trưởng cơ sở" (Q-130); nếu Code làm khác thì khung theo Code.
   - (d) **người lập chưa có quản lý trực tiếp và cơ sở chưa có Trưởng cơ sở nào đang hoạt động**: nút Trình **mờ**, dòng lý do, chữ chính thức của Code: "Người lập chưa có Quản lý trực tiếp và cơ sở này chưa có Trưởng cơ sở nào đang hoạt động để duyệt. Nhờ Admin đặt Quản lý trực tiếp hoặc Trưởng cơ sở rồi trình lại." (khung mới `BH05_nhap_xem_chua_ql_khong_tcs`, `TC02_nhap_xem_chua_ql_khong_tcs`).
   - Chữ cũ "Người duyệt: chưa có · bạn chưa có quản lý trực tiếp" **bỏ** ở các khung `*_nhap_xem_chua_ql`.

   Khung `BH05_chua_ql_sua` (đang sửa): **chỉ giữ trường hợp có Trưởng cơ sở** (Q-133, anh OK 08/11/2026). Dòng cạnh nút khoá: "Người duyệt: Trưởng cơ sở · bạn chưa có quản lý trực tiếp" và "Đơn vẫn ở Nháp, các dòng không mất." **Bỏ hộp "Chưa trình được"** ở khung này (trường hợp cơ sở chưa có Trưởng cơ sở xem `BH05_nhap_xem_chua_ql_khong_tcs`). Khối đỏ "Chưa trình được" của lỗi thiếu ngày vào lớp hoặc thiếu mã giao dịch (`BH05_nhap_loi_xem`, `TC02_nhap_loi_xem`) là lỗi khác, không đổi.
10. **BH-11 · cơ hội đã có đơn nháp (Q-92)**: nâng từ Mức C lên **Mức B**, khung `BH05_co_don_nhap` (hộp K08 trên màn Cơ hội). BH-11 đã vào luật R-TIEN-39 (Q-181). Nút 'Vẫn tạo' là lần xác nhận thứ hai (Q-202): bấm là tạo, không thêm hộp nào. Hộp không chặn: Mở đơn cũ hoặc Vẫn tạo. Code làm phần máy chủ trước (Q-201). Nền là cơ hội ở **L8A** (R-CRM-16: chỉ cơ hội ở L8 mới tạo được đơn từ cơ hội, nên cơ hội chưa tới L8 không có đơn nháp). Mã đơn, tổng tiền, ngày trong hộp là số minh hoạ, không chép vào test.
11. **Khung Tạo theo khuôn bản ghi chung (Q-94)**: mọi khung Tạo giữ khuôn K06 (Giai đoạn + Ghi chú & hoạt động). Khung `BH05_tao_moi`, `BH05_tao_trang_moi`, `BH02_tao_moi`:
    - Giai đoạn hiện đủ các bước, **không bước nào được chọn** (chưa có bản ghi): "Chưa lưu: bấm Lưu để tạo ở giai đoạn Nháp". Nút chuyển giai đoạn mờ, ghi "Lưu rồi mới trình duyệt" (báo giá: "Lưu rồi mới gửi").
    - Cột phải "Ghi chú & hoạt động" **hiện mờ**, kèm dòng "Lưu để bắt đầu ghi chú" (chưa có bản ghi, R-CRM-19).
    - Lưu và Huỷ ở thanh tiêu đề. Dải tổng tiền là dải thường, **không còn thanh dính**. Không vẽ hàng nút liên quan (Cơ hội, Phụ huynh…) vì bản ghi chưa có.
    - Bảng dòng giữ một hàng, cuộn ngang, độ rộng cột như khung cũ. Ô chọn gói vẫn chọn **trong ô** như app đang chạy, không đổi thành hộp thoại. Thanh cuộn ngang **luôn hiện (dày 12px)**, có vệt mờ ở mép phải bảng và dòng "Kéo thanh ngang để xem các cột bên phải." (Q-80, Q-82). Bảng đủ cột: đơn 14 cột, báo giá 11 cột; cột nào không vừa thì cuộn ngang. Báo giá có dòng "Trần chiết khấu mỗi dòng 20%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được." (Q-113, R-V2-11) Lưới trường 2 cột (đơn), 3 cột (báo giá); không vẽ hàng số đếm (Cơ hội, Phụ huynh…) (Q-98).
    - Khung Tạo ở họ khác còn lệch khuôn, **chưa vẽ lại**, Code làm theo khuôn chung: `TT03_tao` (thiếu Giai đoạn và cột Ghi chú), `LOP03_tao` (có cột Ghi chú, thiếu Giai đoạn).
12. **Bỏ "+ Thêm cả nhà" và "Nhân bản dòng" ở mọi khung (Q-67, Q-93).** Luật không có hai nút này, bản thật không làm. Khung canvas mới đã bỏ. Khung ở canvas chính còn vẽ, **Code không làm theo**:
    - "+ Thêm cả nhà": `BH05_tao`, `BH05_tao_trang`, `BH02_chon`, `BH02_ck`, `BH02_dang_luu`, `BH02_dong`, `BH02_gui_thieu_ns`, `BH02_loi_mang`, `BH02_sua`, `BH02_tao`, `BH02_tinh`.
    - Nút "Nhân bản" (biểu tượng sao chép cuối dòng): `BH02_chon`, `BH02_ck`, `BH02_dang_luu`, `BH02_dong`, `BH02_gui_thieu_ns`, `BH02_loi_mang`, `BH02_sua`, `BH02_tao`, `BH02_tinh`.
13. **K06c (thẻ hai tầng) bỏ (Q-95)**: bảng một hàng cuộn ngang thắng cho mọi lưới dòng. Không có khung nào dùng bố cục K06c (chỉ `K06c` tự dùng, `BH03_in` nhắc tên ở ghi chú cột in). Code không làm. Khung `K06c` ở canvas chính giữ nguyên, chỉ đánh dấu bỏ ở đây.


14. **Chữ tạm của Design (đợt 08/11/2026)**: Code đổi theo câu thật trong app. Các chữ sau do Design viết, không phải câu Chat chuyển:
    - Dòng thời gian khung `TC02_da_trinh_cho_tcs`: "Trình duyệt phiếu, chờ Trưởng cơ sở duyệt." (theo mẫu câu của đơn; chưa rõ Code ghi thế nào).
    - Dòng thời gian cả hai khung `*_da_trinh_cho_tcs`: mục "Đơn nháp / Phiếu thu nháp tạo từ …" và giờ, ngày là số minh hoạ.
    - Chữ phản hồi khi bấm nút (ví dụ "Chưa trình được: chưa có người duyệt.") (nhãn nút phiếu thu giữ "Trình quản lý" theo Q-130).
    - Khung "người khác xem": Design vẽ nút Trình vẫn dùng được như người lập; Code quyết nút có hiện cho người khác không (theo quyền).
    - Tên "Lê Văn Phong" là dữ liệu giả. Khung có quản lý trực tiếp thật (`*_trinh_lai_chua_sua`, `*_tu_choi_*`) vẫn ghi "Trình duyệt đơn cho Lê Văn Phong (Trưởng cơ sở)" trong nhật ký; chưa đổi theo R-V2-41, chờ Chat.
    - Chữ dưới bảng Dòng đơn về trần chiết khấu (mục 1) là chữ tạm.
    - Chữ ở (c) và (d) mục 9 là chữ Chat chuyển từ Code, không phải chữ tạm.


Đã chốt (anh Trường 07/11/2026):
- Ba khung `BH05_chan_em_sua`, `BH05_chua_ql_sua`, `BH05_vao_tai_tuc_sua` được giữ.
- "Chưa sửa từ lần bị từ chối" = chưa có mục Sửa nào sau lần từ chối gần nhất. Code đã làm đúng định nghĩa này cho đơn.
- Phiếu thu bị từ chối dùng hộp xác nhận như đơn. Khi **kế toán** từ chối, hộp thêm dòng "Trình lại sẽ đi từ bước quản lý duyệt." (khung `TC02_tu_choi_xac_nhan`). Logic phía DB của phiếu thu do Code làm.
- Nút "Sửa" của `TC02_nhap_xem` giữ màu chính như Báo giá.
- Chữ dòng cảnh báo vàng ở Phiếu thu là "Gửi lại, chưa sửa từ lần bị từ chối" (Q-60), khớp Đơn hàng.
- **Số liệu trong dòng thời gian (số giờ 20 → 24, chiết khấu 5% → 10%, tổng 11.780.000 → 13.608.000, số tiền phiếu thu, mã giao dịch) là số minh hoạ.** Không chép vào bài kiểm thử (số minh hoạ, không chép vào test).

## 7. Bản đăng 08/11/2026 (đợt 5, chip Ưu đãi linh hoạt): thay bản nào, khung nào đổi, câu chữ mới
**Bản này thay Version 8 (`1794119754-f1f3`).** Version 8 là mốc quay lại nếu cần. Anh Trường đã "OK ĐĂNG" (Q-144, Q-150, Q-151, Q-152).

**9 khung mới:** `Man_Chip_uu_dai` (nhãn màn), `BH02_chip_linh_hoat`, `BH02_chip_vuot_han_muc` (nút Lưu mờ, Q-151), `BH02_chip_vuot_tran`, `BH05_chip_linh_hoat`, `BH05_chip_vuot_han_muc` (nút Lưu mờ), `BH05_chip_vuot_tran`, `BH05_log_tao_truc_tiep`, `BH05_log_tao_tu_bao_gia`.

**18 khung đổi cột "Loại chiết khấu, %" sang chip "Chiết khấu" và cột "Tổng %":**
`BH05_chan_em_sua`, `BH05_chua_ql_sua`, `BH05_da_trinh_cho_tcs`, `BH05_nhap_loi_xem`, `BH05_nhap_sua`, `BH05_nhap_xem`, `BH05_nhap_xem_chua_ql`, `BH05_nhap_xem_chua_ql_khong_tcs`, `BH05_nhap_xem_chua_ql_nguoi_khac`, `BH05_nhap_xem_ql_khoa`, `BH05_nhap_xem_ql_thieu_quyen`, `BH05_trinh_lai_chua_sua`, `BH05_tu_choi_xac_nhan`, `BH05_tu_choi_xem`, `BH05_vao_tai_tuc_sua` (Q-150), `BH05_tao_moi`, `BH05_tao_trang_moi`, `BH02_tao_moi`.
Không đổi: hộp thoại "Duyệt đơn hàng" (bh07) và `BH05_co_don_nhap` (Q-152).

**Câu chữ mới do Design tự đặt (Code đối chiếu, chưa phải chữ chốt):**
- "Đơn nháp tạo trực tiếp." (khung `BH05_log_tao_truc_tiep`).
- "Dòng 2 chiết khấu: 13% → 15%" và dòng log SUA ví dụ "Ưu đãi linh hoạt 5% ở dòng 2".
- Dòng log TAO "Ưu đãi linh hoạt 3% ở dòng 2"; từ báo giá thêm "(nhập ở báo giá BG-CS1-2610-0007)".
- Câu lỗi "Ưu đãi linh hoạt tối đa 5%" (số 5% lấy từ tham số).
- Tên chip và số trong ví dụ (Giảm anh chị em 10%, Ưu đãi đóng sớm 5%, Khuyến mãi tháng 10 10%, giờ tặng quy ra %) là số mẫu.
- Ở khung Tái tục, chip "Giảm anh chị em 10%" là ví dụ; chính sách thật lấy từ phiếu tái tục.

## 8. Báo giá Sửa nháp (`BH02_sua*`, Q-161, anh OK 08/11/2026)
- 4 khung Sửa báo giá, vẽ theo kiểu chip như `BH02_tao_moi`: cột "Chiết khấu" (chip tên chính sách có ✕, cuối ô "+ Thêm") và cột "Tổng %", thay cho cột "Loại chiết khấu", "%", "Giảm". Cột Thành tiền giữ. Mỗi dòng một hàng, không xuống dòng, bảng cuộn ngang. Tổng chiết khấu vẫn ở khối tổng cuối trang.
- `BH02_sua`: **thay** khung cùng tên ở canvas chính (trạng thái lỗi thiếu số lượng, dòng 1), đã đổi sang chip. Nút Lưu giữ như khung cũ (bấm ra câu "Chưa lưu: dòng 1 thiếu số giờ").
- `BH02_sua_chip_linh_hoat`: dòng 2 có chip "Ưu đãi linh hoạt 3%" (ô gõ %), Tổng % 13%.
- `BH02_sua_chip_vuot_han_muc`: chip "Ưu đãi linh hoạt" gõ 8%, vượt hạn mức 5%: chữ đỏ ngay dưới chip "Ưu đãi linh hoạt tối đa 5%", **nút Lưu mờ, không bấm được** (Code kiểm hạn mức ở màn trước khi lưu, Q-151). Thành tiền dòng và tổng hiện "—".
- `BH02_sua_chip_vuot_tran`: cộng dồn 25% vượt trần 20%: hộp vàng "Trần chiết khấu mỗi dòng 20%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được." (R-V2-11), nút Lưu bấm được.
- Cả 4 khung đã bỏ "+ Thêm cả nhà" và nút "Nhân bản" (Q-93), và chữ trần chiết khấu cũ ("Vượt trần cần Trưởng cơ sở duyệt", R-TIEN-29) đã đổi theo R-V2-11.
- Số liệu mẫu: 3 dòng, chip Giảm anh chị em 10%, Ưu đãi đóng sớm 5%, Khuyến mãi tháng 10 10%; tổng và thành tiền là số mẫu, hệ thống tính thật. Câu "% giảm" ở dòng chú thích dưới bảng là câu Design đặt.

- **Bản này thay Version 9 (`1794124718-c531`)**; Version 9 là mốc quay lại. Anh Trường đã "OK ĐĂNG" (Q-161).
- Code đã làm màn Báo giá Sửa **giữ kiểu cũ** ở PR chip: **PR sau làm đồng bộ theo 4 khung này** (cột Chiết khấu chip, Tổng %, hạn mức, trần).
- Câu chữ do Design đặt, Code đối chiếu: "% giảm" ở dòng chú thích dưới bảng ("Số lượng do nhân viên điền; đơn giá, % giảm, thành tiền do hệ thống tính."); số mẫu (3 dòng, chip, tổng, thành tiền); câu lỗi "Ưu đãi linh hoạt tối đa 5%" (5% theo tham số); câu trần theo R-V2-11.

## 9. Khung Tái tục sửa (`BH05_vao_tai_tuc_sua`): câu chờ PR Tái tục (Q-159)
- Câu "Học sinh và lớp lấy từ phiếu tái tục TT…" (dưới tiêu đề Gói học) và các ô, liên kết nhắc phiếu tái tục TT… **chờ PR Tái tục**: DB chưa có bảng phiếu tái tục. **Code bỏ qua câu này ở PR hiện tại** (không làm, không báo thiếu).


## 10. Phiếu thu đang "Đã trình": hộp "Người duyệt" (Q-182, Q-191 đến Q-193, anh OK 10/11/2026) — BẢN NHÁP, chưa đăng
- Phiếu thu ở trạng thái Đã trình hiện ô **Người duyệt** ở phần đầu phiếu, như Đơn hàng: tên quản lý trực tiếp của người lập phiếu, người đang chờ duyệt. Admin thấy thêm nút **Chuyển người duyệt**, Admin không duyệt thay (R-TIEN-01, R-HT-01): khung `TC02_quan_ly_ad`, `TC17_admin`.
- **Tên hiển thị:** khung vẫn ghi chữ "Đã trình" (Q-191, không đổi hàng loạt). **Code hiển thị "Đã gửi" theo R-V2-14.**
- **Trưởng cơ sở lập phiếu thì tự duyệt bước quản lý:** ô Người duyệt ghi "tự duyệt" và lịch sử ghi "tự duyệt". **Không có khung vẽ riêng**; Code làm theo luật R-TIEN-01, không chờ khung.
- Khung đổi: `TC02_trinh`, `TC02_quan_ly`, `TC02_quan_ly_ad`, `TC17_admin`, `TC17_duyet`, `TC17_tu_choi`, `TC02_da_trinh_cho_tcs`, `TC02_trinh_lai_chua_sua`. `TC17_admin` được thêm ô Người nhận tiền cho giống các khung khác.
- **Danh sách `TC01` (Q-193):** thêm **cột** "Người duyệt" (trước cột Tình trạng); dòng Đã trình ghi tên người duyệt, dòng khác ghi "—". Mỗi hàng một dòng, không xuống dòng; bảng rộng thì cuộn ngang.
- 7 khung canvas chính (`TC01`, `TC02_trinh`, `TC02_quan_ly`, `TC02_quan_ly_ad`, `TC17_admin`, `TC17_duyet`, `TC17_tu_choi`) được chép sang canvas bổ sung; canvas bổ sung thắng khi trùng tên.
- Mọi tên người trong khung là tên giả (Q-192); Lê Văn Phong là quản lý mẫu, hệ thống lấy quản lý trực tiếp thật. 3 khung `BH05_trinh_lai_chua_sua`, `BH05_tu_choi_xem`, `BH05_tu_choi_xac_nhan` giữ tên như bản đang đăng. `BH05_co_don_nhap` (BH-11) giữ nguyên khung; luật xem mục 6 điểm 10 (R-TIEN-39, Q-181, Q-202).


## 11. Luật chung (Q-204, Q-212, anh Trường chốt 10/11/2026) — KHÔNG vẽ lại khung cũ, Code làm một lần ở thành phần dùng chung
1. **Bảng rộng hơn khung chứa** (danh sách K03 và bảng dòng): thanh cuộn ngang **luôn hiện, dày 12px**; **vệt mờ ở mép phải** bảng; dòng chữ **"Kéo thanh ngang để xem các cột bên phải."** dưới bảng; mỗi hàng một dòng, không xuống dòng; giữ nguyên thứ tự cột. Mẫu: `TC01` (canvas bổ sung) và các khung Tạo (`BH05_tao_moi`, `BH02_tao_moi`…).
   - Áp cho **24 khung `BH05_*`** có bảng dòng đơn (xem, sửa, nhật ký, Tái tục sửa…), **4 khung `BH02_sua*`**, và các khung danh sách ở canvas chính bị cắt cột: `BH01`, `BH06`, `GD07`, `LOP01`, `LOP01_admin`, `TC04`, `TC04_admin`, `TC08`, `TC09_chan`, `TC09_dao`, `TS01`, `TS04`, `TS07_K1`, `BUOI15` (và 2 khung hộp thoại cùng họ), cùng các khung `K1_*`, `K07b`, `K07c` vẽ trên bảng rộng. Các khung này **chưa vẽ thanh cuộn**; Code làm theo luật này.
2. **12 khung `BH02` ở canvas chính còn cột "Loại chiết khấu"** (`BH02_bh11`, `BH02_chan_dong`, `BH02_chan_l8`, `BH02_don`, `BH02_gui`, `BH02_gui_thieu_ns`, `BH02_loi_mang`, `BH02_mot_phan`, `BH02_nhap`, `BH02_nhieu_don`, `BH02_tinh`, `BH02_tu_choi`): **Code làm theo chip** (R-V2-45), cột "Chiết khấu" và "Tổng %" như `BH02_sua*` ở canvas bổ sung. **Không vẽ lại** các khung này.
