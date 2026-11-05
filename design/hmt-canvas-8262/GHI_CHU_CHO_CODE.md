# Ghi chú cho Code: chỗ canvas vênh luật

Canvas HMT Platform v68 (`1793844909-31f7`) là bản chuẩn, anh Trường đã duyệt. Những chỗ dưới đây trên canvas **vênh luật** hoặc **chưa vẽ theo quyết định mới**. **Code làm theo luật**, không làm theo canvas.

## 1. Vượt trần chiết khấu: luật là chỉ cảnh báo, không chặn
Trần 20% mỗi dòng, tính trên giá niêm yết (gồm % ưu đãi, giờ tặng quy ra %, phần voucher chia về dòng) (theo mục 2, chưa vào luật). Vượt trần chỉ cảnh báo (R-TIEN-29).
Canvas còn ghi khác:
- `BH07_duyet`, `BH07_dt`, `BH07_dt_tu_choi`: ô tích "Đồng ý chiết khấu vượt trần", "cần quản lý cơ sở duyệt".
- `BH02_ck`, `BH02_dang_luu`, `BH02_dong`: "Vượt trần 20%, cần duyệt".
- Chữ "Chiết khấu cộng dồn không quá 20%": các khung `BH05_*` (có bảng Dòng đơn), `BH07_duyet`, `BH08_*`, `BH09_bat`, `TC03_tao`, `TC03_loi`.

## 2. Chiết khấu chip, ưu đãi linh hoạt, voucher: quy tắc dưới đây do anh Trường chốt trong bình luận, CHƯA vào luật. Code đối chiếu với luật hiện có; chỗ nào khác luật thì hỏi Chat trước khi làm
- Cột "Chiết khấu": chip chọn nhiều, "+ Thêm", ✕ trên từng chip; cột "Tổng %" cộng dồn.
- Chip "Ưu đãi linh hoạt": nhân viên nhập % tay, không ghi % trong ngoặc, không cần lý do; hạn mức do anh Trường cấu hình sau; ai có quyền lên đơn đều dùng được.
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
