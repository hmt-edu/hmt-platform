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
