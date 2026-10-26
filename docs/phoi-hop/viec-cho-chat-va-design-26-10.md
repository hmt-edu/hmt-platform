# Việc cho Claude Chat và Claude Design (ghi 26/10/2026, anh Trường chuyển)

Anh Trường đã quyết các điểm dưới đây; Claude Code chỉ làm phần cơ sở dữ liệu và giao diện khi luật, khuôn đã có. Chỗ nào ghi "Chat" là luật cần Chat soạn chữ; "Design" là màn cần vẽ. Chữ luật chỉ vào `docs/spec/` khi anh nói "OK ĐƯA VÀO LUẬT <mã>".

## Đã chốt (Claude Code làm khi tới lượt)
- **Nguồn:** ba ô **Source type → Source → Medium**; Medium = Sub-source đổi tên (kênh hiện tại). Chỉ còn 4 Source type: Marketing, Telemarketing, Event, Ban Giám Đốc. **Upsale** là một nguồn dưới Marketing, Medium chỉ còn **Cross-Sale** (bỏ New Opp, Renew Lost). **Referral** là một nguồn dưới Marketing, giữ Medium By Customer, By HMT. Medium bắt buộc khi nguồn có Medium con.
- **Lead đổi giai đoạn:** chuyển sang C2, C3, C4 thì bắt buộc chọn nhóm con (C4D do hệ thống gắn); hộp thoại giống cơ hội, cả Kanban.
- **Lead tạo cơ hội:** chỉ khi lead ở **C4C**; lead đã ở C4D vẫn tạo thêm được (R-CRM-01, xác nhận lần hai).
- **Tạo cơ hội trực tiếp (không cần lead gốc):** cách A, `lead_id` cho phép trống; mọi nguồn đều tạo thẳng được.
- **Lead đã có cơ hội, hộp tạo cơ hội:** thêm nút "Thêm em vào cơ hội cũ" (cách B, gộp danh sách em) cạnh "Mở cơ hội cũ" và "Vẫn tạo thêm".
- **Ghi chú của lead:** trang Cơ hội hiện thêm ghi chú của lead gốc (nhãn "Từ lead LD…"), đọc xuyên, không sao chép.

## Cho Claude Design
1. **TS-06** (Tạo cơ hội từ lead khi lead đã có cơ hội): thêm nút **"Thêm em vào cơ hội cũ"**. Bấm thì các em được chọn trong danh sách em của lead (mặc định chọn hết, được chọn 0 em; Đ81, Đ92) đưa vào danh sách em của cơ hội cũ, không tạo cơ hội mới. Dùng khuôn K08c "Thêm em" và K06b thẻ chọn em. Vẽ các trạng thái: chọn em; vượt `prospect_max_students` (Đ88); em trùng tên và năm sinh gộp một dòng (Đ81); thành công thì mở cơ hội cũ.
2. **TS-07 thêm hành động "Tạo cơ hội"** (khuôn K07 biểu mẫu): Phụ huynh (SĐT, họ tên, tỉnh/thành, phường/xã); danh sách em (K08c, tối đa `prospect_max_students`); **Source type → Source → Medium** (ba ô nối nhau, Medium bắt buộc khi Source có Medium con); Chiến dịch; Người phụ trách; Nhu cầu. Gõ SĐT xong kiểm trùng như TS-14 (đã có phụ huynh hoặc cơ hội: mở hồ sơ cũ, hoặc "Thêm em vào cơ hội cũ", hoặc vẫn tạo). Cơ hội mới luôn bắt đầu ở L1.
3. **Nhãn nguồn** trên mọi màn Lead, Cơ hội đổi thành "Source type", "Source", "Medium" (bỏ "Sub-source"); thêm ô **Source type** riêng ở bản ghi (hiện chỉ là chữ trong ngoặc sau Source).
4. **Lead đổi giai đoạn:** hộp thoại chọn nhóm con bắt buộc (giống hộp đổi giai đoạn của cơ hội), cho trang Lead và Kanban.
5. **Tái tục → báo giá, đơn hàng** (TT-01, TT-02, TT-04, GD-07, Đ157): nút tạo báo giá, tạo đơn trên phiếu tái tục; đơn tái tục không có cơ hội gốc nên bản ghi đơn (BH-05) hiện "Phiếu tái tục TT…" thay vì "Cơ hội CO…".

## Cho Claude Chat
1. **Tái tục thành đơn hàng:** phiếu tái tục L8 thành công thì lên đơn hàng bằng đường nào khi không có cơ hội? (a) Bấm ở đâu, ai tạo, đơn gắn vào đâu (phiếu tái tục? ghi danh cũ?). (b) Đơn tái tục có qua R-CRM-16 (cơ hội phải ở L8) không hay là ngoại lệ (R-CRM-16 hiện ghi "tính sau")? (c) Khi đơn duyệt và đóng đủ thì sinh ghi danh mới cùng lớp (R-GD-13) ra sao, dùng chung `on_receipt_approved_enrolment` không? Câu trả lời quyết định thiết kế `sales_order.opportunity_id` (hiện bắt buộc, phải L8) ở P5a-DB1b.
2. **Nguồn Upsale (Medium Cross-Sale):** chỉ dùng cho bán thêm không phải tái tục. Rà các luật nhắc "Renew Lost", "New Opp".
3. **Chữ luật cần soạn** (anh sẽ nói "OK ĐƯA VÀO LUẬT <mã>" sau khi đọc): spec 06 mục 1.1 (4 Source type, Upsale và Referral thành nguồn dưới Marketing, tên tầng Medium); spec 04 các câu "kênh (sub-source)" và lỗi `HMT_THIEU_NGUON`; luật mới "đổi giai đoạn lead bắt chọn nhóm con"; luật mới "lead chỉ tạo cơ hội khi ở C4C" (bổ sung R-CRM-01); R-CRM-01 chữ "hoặc chọn gộp" thành "Thêm em vào cơ hội cũ"; cơ hội không cần lead gốc (R-CRM-01, R-CRM-19).
4. **P5a-DB1a (#91):** Đ172 (tiền chiết khấu làm tròn xuống đồng) là luật mới chờ "OK ĐƯA VÀO LUẬT"; Đ173 (công tắc BAN_HANG): spec 06 chưa có tên công tắc, cần anh quyết tên và ghi vào spec 06.
5. **Kiểm #90** (luật nháp) và **#91** trước khi anh OK.
