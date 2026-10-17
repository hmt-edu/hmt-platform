# P5a: Bán hàng và Thu chi

(Dán sau brief chung.)

Canvas: **"P5a Bán hàng và Thu chi"**. Giai đoạn 1 (máy tính). Mã màn lấy từ bản đồ: **BH-01 đến BH-11, TC-01 đến TC-09, TC-10 đến TC-16.**

**Mức A (vẽ đủ trạng thái):** BH-02 Báo giá (bản ghi), BH-05 Đơn hàng (bản ghi), BH-08 Chọn lớp và ngày vào lớp, TC-02 Phiếu thu (bản ghi), TC-05 Kế toán duyệt, từ chối.
**Mức B (một trạng thái chính, danh sách có thêm trống, đang tải, không có quyền):** BH-01, BH-03 (bản in K13), BH-06, BH-07, BH-09; TC-01, TC-03, TC-04, TC-07 (bản in), TC-08, TC-09, TC-10, TC-11, TC-13, TC-15.
**Mức C: không vẽ**, chỉ ghi trong ghi chú canvas dựng từ khuôn nào: BH-04, BH-10, BH-11, TC-06, TC-12, TC-14, TC-16.

**Chú ý riêng**
- **Không có nút Tạo tay** báo giá, đơn, phiếu thu trên danh sách (R-TIEN-02): chỉ tạo từ cơ hội, từ báo giá, từ đơn. Bản đồ ghi rõ ở từng màn.
- **Dòng đơn (BH-05): mỗi dòng một lớp, một ghi danh** (R-GD-01, 14): học sinh (chọn hồ sơ có sẵn), gói, hình thức, lớp, ngày vào lớp, giờ, giá, chiết khấu cộng dồn, giờ tặng. **Sale tự nhập giờ cho từng dòng; không có ô phân bổ, không chia đều.** Toán khối 7+ học cả Đại và Hình: **hai dòng riêng**; khi mới có một dòng, hiện nhắc mềm "thường học cả Đại và Hình, thêm dòng cho lớp còn lại?" (không chặn, không làm mờ nút Trình). Đơn đã duyệt thì khoá toàn bộ. Nút "Trình duyệt" báo đúng dòng, ô còn thiếu.
- **BH-08 Chọn lớp (cho từng dòng):** chỉ lớp đã duyệt, còn chỗ, đúng môn, khối, cơ sở, không trùng giờ (R-GD-15); lớp trùng vẫn hiện nhưng không chọn được, kèm lý do. Không còn "gợi ý một lớp Đại + một lớp Hình" trong hộp này (gợi ý đã chuyển thành nhắc mềm ở BH-05).
- **TC-02, TC-05:** phiếu thu cấn vào dòng đơn (để trống = chia tỉ lệ). Kế toán duyệt sinh khoản tiền vào và ghi danh (nếu đủ cọc, mỗi dòng đơn một ghi danh); cảnh báo "đã qua N buổi" khi vào lớp trước ngày duyệt. **Admin không duyệt phiếu thu** (R-HT-01): nút Duyệt chỉ cho Kế toán, vai trò khác chỉ xem.
- **TC-08, TC-09:** khoản tiền vào chỉ đọc; đảo khoản chỉ Kế toán, thêm khoản âm, chặn đảo hai lần, báo giờ cấp sẽ tính lại.
- **TC-10, TC-11 Phiếu chi:** chỉ lập từ ticket hoàn tiền đã duyệt (R-TIEN-28), kèm bảng tính hoàn: giờ đã học × giá gốc, bỏ chiết khấu, trừ phí xử lý, giờ tặng không hoàn.
- Công nợ (TC-13): theo lịch đóng từng đợt, sắp đến hạn, quá hạn; lọc theo cơ sở, sale.

Nối với: nhóm A, B, C, G, I trong bản đồ liên quan. Báo anh khi xong cụm Báo giá → Đơn hàng, rồi cụm Phiếu thu, rồi Phiếu chi, công nợ, đối soát.
