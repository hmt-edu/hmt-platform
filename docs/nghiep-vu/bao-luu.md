# Bảo lưu ghi danh (migration 215)

Code D, 16/11/2026. Luật: R-GD-09, R-CS-02, R-CS-03, R-CS-07, R-V2-24. Chưa có giao diện (PR sau). Dừng học (R-GD-16) làm cùng hoàn phí ở PR riêng.

Công tắc `BAO_LUU` theo cơ sở, **mặc định TẮT**. Bản ghi `app.enrollment_hold`: `NHAP` → `CHO_DUYET` → `DANG_BAO_LUU` → `KET_THUC`; nhánh `TU_CHOI` (bắt buộc lý do), `HUY`. Loại: `MOI` (bảo lưu mới) và `GIA_HAN` (nối tiếp bản đang chạy). Lý do là danh mục `HOLD_REASON` (mở).

| Hàm                                                                  | Ai                                                  | Luật           |
| -------------------------------------------------------------------- | --------------------------------------------------- | -------------- |
| `create_enrollment_hold(ghi danh, số tháng, lý do, ghi chú, ticket, bản gia hạn)` | Ghi danh · Sửa                         | R-GD-09        |
| `submit_enrollment_hold(id)`, `cancel_enrollment_hold(id)`           | Ghi danh · Sửa                                      | R-V2-24        |
| `approve_enrollment_hold(id)`, `reject_enrollment_hold(id, lý do)`   | Ghi danh · Duyệt; người tạo không tự duyệt (trừ Admin) | R-CS-07    |
| `end_enrollment_hold(id)`                                            | Ghi danh · Duyệt: học lại sớm hoặc tới hạn          | R-CS-03        |
| `end_expired_enrollment_holds()`                                     | Nội bộ, **chưa đăng ký lịch pg_cron** (chờ anh duyệt) | R-GD-09      |

- Duyệt xong bảo lưu **bắt đầu ngay** (ngày duyệt, giờ Việt Nam): ghi danh sang Bảo lưu, giờ còn lại giữ nguyên (không đụng sổ giờ). Hết hạn = ngày bắt đầu + số tháng.
- Một lần không quá `reservation_max_months` (mặc định 6, đọc theo cơ sở). Gia hạn là bản mới nối tiếp từ ngày hết hạn của bản đang chạy, cũng không quá mức đó mỗi lần.
- Bảo lưu loại em khỏi danh sách buổi: đã có sẵn trong `build_session_roster` (loại ghi danh `BAO_LUU`).
- Kết thúc (học lại sớm hoặc hết hạn) trả ghi danh về tình trạng trước bảo lưu (Đã xếp lớp hoặc Đang học).

Chưa làm: dừng sinh phiếu tái tục khi bảo lưu (R-GD-13: chưa có bảng phiếu tái tục), khoá ngoại tới ticket (#18), giao diện.

## Cập nhật (migration 234)

`apply_enrollment_hold(...)`: hàm nội bộ cho phiếu nghiệp vụ Aftersale, tạo bản ghi bảo lưu (mới hoặc gia hạn) ở trạng thái Đang bảo lưu, bắt đầu ngay (không duyệt lần hai). Xem `ap-dung-phieu-cho-code-b.md`.

## Gia hạn bảo lưu từ phiếu (C30, migration 423, CSN-06b)

`get_task_form_options` trả thêm ghi danh đang Bảo lưu và khoá `holds` (bảo lưu đang chạy: id, ghi danh, từ ngày, đến ngày). Hộp thoại tạo phiếu Bảo lưu có ô «Hình thức»: Bảo lưu mới (ghi danh chưa bảo lưu) hoặc Gia hạn bảo lưu (ghi danh có bản đang chạy, gửi `extends_hold_id`). Hàm áp dụng (234) kiểm lại. Chỗ vênh canvas: canvas ghi «ngày quay lại mới», luật và hàm dùng **số tháng** (R-GD-09, tối đa `reservation_max_months` mỗi lần), nên giao diện hỏi số tháng gia hạn.
Chưa làm (chờ Chat): phiếu **Tiếp tục học** (quay lại sớm, chọn lớp quay lại), nâng cấp ticket lên Quản lý cơ sở/Ban giám đốc (CS-13), khung `GD02_bao_luu` (không có trong canvas 9189).
