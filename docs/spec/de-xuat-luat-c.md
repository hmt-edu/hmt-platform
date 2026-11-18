# Đề xuất luật của Code C (chưa chốt)

Trạng thái: **ĐỀ XUẤT**, chưa phải luật. Chat chốt (hoặc đổi) rồi mới chép vào `04-luat-nghiep-vu.md` và mở việc làm mã. Căn cứ: canvas 9933 khung `TC17_admin`, `TC17_duyet`, `TC17_tu_choi`; luật R-HT-01, R-HT-06, R-V2-12, R-V2-41; R-V2-44 đang `[CHỜ]`.

## R-V2-44 Đường thay người duyệt khi người đã chốt bị khoá (đề xuất)

**Vấn đề (Q-120, 08/11):** đơn hoặc bước quản lý của phiếu thu đã trình có người duyệt đã chốt lúc trình (R-HT-06, chụp lại). Nếu người đó bị khoá tài khoản, nghỉ việc hoặc mất quyền thì chứng từ kẹt: Admin duyệt đơn thay được (R-HT-01) nhưng **không được duyệt tiền** nên phiếu thu kẹt hẳn.

**Đề xuất (an toàn nhất, không cho Admin duyệt tiền):**
1. Thêm thao tác **«Chuyển người duyệt»** cho **Admin** trên phiếu thu và đơn **đang chờ bước quản lý** (phiếu `DA_GUI`, đơn `DA_TRINH`). Admin **chỉ đổi người được giao duyệt**, không duyệt, không từ chối thay.
2. **Người nhận phải đủ điều kiện duyệt bước quản lý** của đúng chứng từ: là quản lý trực tiếp của người lập, hoặc Trưởng cơ sở của cơ sở đó (R-V2-41), còn hoạt động, không bị khoá, thuộc đúng cơ sở. Không chuyển cho chính người lập, không chuyển cho Admin, không chuyển cho Kế toán (tách quyền tiền, R-TIEN-01).
3. **Chỉ chuyển được khi người đã chốt hiện không duyệt được:** bị khoá, đã thôi (không còn quyền Duyệt trong cơ sở), hoặc quá hạn xử lý do tham số `approver_reassign_after_hours` (mặc định 48 giờ, đề xuất, Admin sửa). Nếu người đã chốt còn hoạt động và chưa quá hạn thì chặn (`HMT_NGUOI_DUYET_CON_HIEU_LUC`).
4. **Bắt buộc lý do** (danh mục mới `REASSIGN_REASON`: Nghỉ việc, Nghỉ phép dài, Bị khoá, Quá hạn xử lý, Khác; «Khác» cần ghi chú) và **ghi lịch sử** của chứng từ (ai chuyển, từ ai sang ai, lý do, lúc nào); mọi lần chuyển ghi `audit_log`.
5. **Không đổi route đã chốt:** chuyển vẫn trong cùng `approval_route`; người nhận trở thành `assigned_approver_id`. Route `TRUONG_CS` (R-V2-41: mọi Trưởng cơ sở duyệt được) **không cần** chuyển.
6. Có **cờ tắt mặc định** theo cơ sở (`approver_reassign_enabled`) cho tới khi anh bật; kiểm cả ở giao diện và trong hàm DB.

**Phương án khác (không chọn):** (i) cho Admin duyệt thay bước quản lý: trái R-HT-01 («Admin không duyệt tiền»). (ii) tự động chuyển cho Trưởng cơ sở khi người chốt bị khoá: ít thao tác nhưng thay đổi người duyệt không có người quyết, khó giải thích khi kiểm toán.
**Việc mã sau khi chốt:** migration (hàm `reassign_approver(chứng từ, người nhận, lý do, ghi chú)`, danh mục, tham số, cờ), pgTAP (đúng, bị chặn từng điều kiện), nút «Chuyển người duyệt» ở khung TC17_admin (phiếu thu) và bản ghi đơn; ghi vào TC-17 và BH-07.
**Câu hỏi cho chủ dự án (qua Chat):** (a) có cần điều kiện «quá hạn xử lý» hay chỉ khi người chốt bị khoá, nghỉ? (b) mặc định bao nhiêu giờ nếu có?
