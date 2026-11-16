# Chuyển lớp, chuyển cơ sở (migration 210)

Code D, 16/11/2026. Luật: R-GD-10, R-CS-02, R-CS-03, R-CS-07, R-V2-24. Đề xuất: `docs/de-xuat/chuyen-lop-hoan-phi.md`. Chưa có giao diện (PR sau).

Công tắc `CHUYEN_LOP` theo cơ sở, **mặc định TẮT** (không có dòng = tắt); cơ sở nào cần thì Chat bật khi Tester ĐẠT. Chuyển lớp **khác môn** là chuyển phí, hàm chặn `HMT_CHUYEN_LOP_KHAC_MON`.

## Bảng `app.class_transfer`

Một bản ghi mỗi yêu cầu. Trạng thái: `NHAP` → `CHO_DUYET` → `DA_DUYET` → `DA_CHUYEN`; nhánh `TU_CHOI` (bắt buộc lý do), `HUY`. Mỗi ghi danh chỉ một yêu cầu còn mở (chỉ mục duy nhất từng phần). Loại: `DOI_GIO`, `DOI_TRINH_DO`, `DOI_GIAO_VIEN`, `CHUYEN_CO_SO` (phải khớp cơ sở lớp mới). Lý do là danh mục `TRANSFER_REASON` (mở, sửa được). Ghi chỉ qua hàm; đọc theo quyền Xem ghi danh, người của cơ sở cũ hoặc cơ sở mới thấy.

## Hàm giao diện được gọi (kiểm quyền bên trong)

| Hàm                                                                             | Ai                                     | Luật                      |
| ------------------------------------------------------------------------------- | -------------------------------------- | ------------------------- |
| `create_class_transfer(ghi danh, lớp mới, ngày vào, loại, lý do, ghi chú, ticket)` | Ghi danh · Sửa, cơ sở của ghi danh     | R-GD-10, R-GD-06, 08, 15  |
| `submit_class_transfer(id)`                                                     | Ghi danh · Sửa                         | R-V2-24                   |
| `approve_class_transfer(id)`                                                    | Ghi danh · Duyệt; người tạo không tự duyệt (trừ Admin) | R-CS-07 |
| `reject_class_transfer(id, lý do)`                                              | Ghi danh · Duyệt                       | R-CS-05                   |
| `cancel_class_transfer(id)`                                                     | Ghi danh · Sửa                         | R-V2-24                   |
| `execute_class_transfer(id)`                                                    | Ghi danh · Sửa, cơ sở cũ               | R-GD-10                   |

Chuyển cơ sở cần quản lý **cả hai** cơ sở duyệt (mỗi người duyệt phần cơ sở mình; Admin duyệt cả hai một lần). `execute_class_transfer` kiểm lại luật lớp mới (chỗ, ngày, trùng giờ) rồi gọi `move_enrollment_class` (migration 101): đóng dòng xếp lớp cũ, mở dòng mới, giờ đi theo ghi danh, chuyển cơ sở thì đổi cơ sở của ghi danh.

Hàm nội bộ: `class_transfer_for_update(id, trạng thái cho phép)` (không cấp cho giao diện).

## Chưa làm

- Phiếu tái tục đang mở chuyển theo lớp mới (R-GD-13): bảng tái tục chưa có trên `main`.
- Gắn khoá ngoại tới ticket CS (PR #18 chưa gộp); hiện chỉ lưu `ticket_ref` dạng chữ.
- Giao diện.

## Cập nhật (migration 234)

`apply_class_transfer(...)`: hàm nội bộ cho phiếu nghiệp vụ Aftersale, tạo bản ghi ở trạng thái Đã chuyển và thực hiện ngay (không duyệt lần hai). Xem `ap-dung-phieu-cho-code-b.md`. Khoá ngoại tới ticket vẫn chưa có (chỉ lưu mã `ticket_ref`); phiếu nghiệp vụ của Code B (`ticket_task`) là nơi duyệt khi đi qua ticket.
