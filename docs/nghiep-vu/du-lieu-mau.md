# Dữ liệu mẫu staging (đợt 1, migration 648)

Chỉ môi trường thử nghiệm. Nút «Dữ liệu mẫu của tôi» ở menu tài khoản (mọi cổng) mở trang tạo, xem, xoá bộ.

## Khoá
- Bảng `app.deployment_env` (không ai ghi qua giao diện): dòng `STAGING` do seed riêng của staging đặt. **Không có dòng = coi là chạy thật = từ chối** (`HMT_DEMO_TAT`).
- Tham số `demo_data_enabled` (mặc định tắt), `demo_data_max_per_user` (3), `demo_data_max_per_branch` (10).
- **Việc còn lại cho anh Trường/Chat:** đặt dòng STAGING và bật công tắc trên `hmt-staging` (chạy một lần bằng quy trình duyệt trên GitHub), tuyệt đối không ở `hmt-prod`.

## Hàm
| Hàm | Ai gọi | Việc |
|---|---|---|
| `app.demo_data_available()` | đăng nhập | nút có hiện không (staging và công tắc bật) |
| `app.create_demo_data_set()` | đăng nhập | tạo bộ cho cơ sở trong token; kiểm khoá và hạn mức. Đợt 1 chưa đổ chuỗi dữ liệu |
| `app.delete_demo_data_set(id)` | chủ bộ hoặc Admin | đổi trạng thái `DA_XOA` |
| `app.list_demo_data_sets(limit, offset)` | đăng nhập | bộ của mình; Admin thấy mọi bộ |

Lỗi: `HMT_DEMO_TAT`, `HMT_DEMO_QUA_HAN_MUC_NGUOI`, `HMT_DEMO_QUA_HAN_MUC_CO_SO`, `HMT_DEMO_KHONG_DU_QUYEN`, `HMT_DEMO_KHONG_THAY_BO`, `HMT_DEMO_DA_XOA`.

## Cờ `is_demo`
Thêm trên lead, opportunity, sales_order, student, class, class_session, ticket (chỉ mục từng phần `where is_demo`) để bộ lọc báo cáo «Ẩn dữ liệu mẫu» (đợt 2) rẻ.

## Đợt 2 (chưa làm)
Chuỗi dữ liệu cố định, dừng ở trạng thái chờ duyệt; SĐT dải 0999 000 001–999, email `@example.invalid`, loại khỏi mọi gửi tin thật.

### Đợt 2, mảnh lead và cơ hội (migration 655)
- `app.demo_tag(bộ, loại, id)`: đặt `is_demo` và ghi `demo_data_item`; chỉ gọi từ hàm mẫu.
- `app.demo_make_leads(bộ, cơ sở)`: 10 lead [MẪU] (giai đoạn C1 đến C4, nguồn lấy từ danh mục đang dùng) và 4 cơ hội [MẪU] (L1, L1, L2A, L4A) của cơ sở người tạo bộ; SĐT 0999 000 001-999 từ bộ đếm `DEMO_PHONE` (không tái dùng; hết dải báo `HMT_DEMO_HET_SO_DIEN_THOAI`). Chèn trực tiếp, không cần quyền tạo lead; mã cấp bằng `issue_crm_code`.
- `app.create_demo_data_set` thêm một dòng gọi `demo_make_leads`.

### Đợt 2, mảnh báo giá, đơn hàng, phiếu thu (migration 656, CAO: đụng `app.assert_can` và tiền)
- `app.demo_make_sales(bộ, cơ sở)`: từ các cơ hội mẫu, gọi **hàm thật** `save_quotation`, `send_quotation`, `create_order_from_quotation`, `order_approve_core`, `create_receipt` để mã, giá, luật giống bản thật. Bộ đủ 4 cơ hội cho: **6 báo giá** (5 Đã gửi, 1 Nháp), **4 đơn** (2 đã duyệt, 2 Nháp), **2 phiếu thu Nháp** (một đủ, một thiếu một phần). Phiếu thu không duyệt nên không sinh khoản tiền vào và không vào đối chiếu thật. Gói bán, điều khoản, hình thức thanh toán lấy từ cấu hình đang dùng (không viết cứng mã).
- Hồ sơ học sinh do duyệt đơn mẫu tạo ra được gắn vào bộ (loại `STUDENT`). `app.demo_tag` thêm hai loại `QUOTATION`, `RECEIPT`; thêm cờ `is_demo` cho báo giá và phiếu thu.
- `app.demo_data_is_allowed()`: khoá dữ liệu mẫu dạng đúng/sai; `assert_demo_data_allowed` dùng lại hàm này.
- **Bốn ràng buộc an toàn** (Chat chốt 24/11): (1) cờ giao dịch `hmt.demo_sales` chỉ do `demo_make_sales` đặt và xoá ngay sau khi xong (kể cả khi lỗi); (2) `app.assert_can` chỉ bỏ qua kiểm quyền khi cờ bật **và** `demo_data_is_allowed()` đúng (STAGING + công tắc bật), mọi trường hợp khác giữ nguyên; (3) pgTAP 656 kiểm: thiếu STAGING hoặc công tắc tắt thì cờ bật vẫn bị chặn, người không quyền gọi thẳng hàm vẫn bị chặn, Kế toán/Giáo viên/Trợ giảng tạo được bộ, hết giao dịch cờ không còn; (4) cơ hội nâng lên L8 bằng cập nhật trực tiếp, chỉ cơ hội `is_demo` của bộ.
