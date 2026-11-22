# Báo cáo BC-02..07 và BC-10: làm ở Looker Studio, không dựng màn trong CRM

Anh Trường duyệt 23/11/2026 (thẻ D-23-06). Căn cứ: R-BC-01 (`docs/spec/04`), `docs/spec/01` (Looker Studio nối bảng/view chỉ đọc), `docs/design/quyet-dinh-thiet-ke-13-10.md` (báo cáo trong app chỉ có 4 màn).

## Quyết định
1. Bảy báo cáo **BC-02** (tuyển sinh), **BC-03** (doanh thu ghi nhận theo buổi Done), **BC-04** (thu tiền và giờ chưa dạy), **BC-05** (tái tục), **BC-06** (sĩ số, lấp đầy, chuyên cần), **BC-07** (BTVN), **BC-10** (ticket) vẽ ở Looker Studio. **Không dựng màn trong CRM**, không viết giao diện cho các màn này.
2. Trong CRM chỉ giữ BC-01 (tổng quan), BC-08 (giáo viên trễ hạn), BC-09 (giờ dạy giáo viên) và các danh sách theo dõi vận hành.
3. **Sau go-live** tạo một **vai trò DB chỉ đọc riêng cho Looker** (ví dụ `looker_reader`):
   - Không dùng lại vai trò sẵn có (`anon`, `authenticated`, `service_role`, vai người dùng).
   - Chỉ được `select` trên các view báo cáo đã duyệt; **không thấy bảng tiền chi tiết** (phiếu thu, phiếu chi, số dư, tài khoản nhận) và không thấy tên, số điện thoại học sinh, phụ huynh nếu báo cáo không cần.
   - Mật khẩu không nằm trong repo; cấp qua quy trình duyệt trên GitHub, chạy thật do anh Trường.
   - Việc tạo vai trò là migration riêng, rủi ro CAO, xin số migration trước; chưa làm ở PR này.
4. Các hàm báo cáo DB đã có (nếu có) giữ nguyên; không thêm giao diện.

## Việc kế (chưa làm)
- Sau go-live: migration vai trò `looker_reader` + view báo cáo + pgTAP (vai này đọc được view, bị chặn ở bảng tiền).
