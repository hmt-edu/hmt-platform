# Dừng học giữ thành số dư khách hàng (migration 217)

Code D, 16/11/2026. Luật: R-GD-16, R-TIEN-33, R-TIEN-01, R-CS-02, R-CS-07, R-V2-24. Chưa có giao diện. Công tắc `DUNG_HOC` theo cơ sở, **mặc định TẮT**.

R-GD-16: dừng học chọn **hoàn tiền** (yêu cầu Hoàn phí loại `TOAN_BO`, xem `hoan-phi-ban-ghi.md`) hoặc **giữ thành số dư** (bản ghi này). Không có «giữ nguyên giờ» (nghỉ tạm dùng Bảo lưu, `bao-luu.md`).

**Bảng:** `app.enrollment_stop` (yêu cầu; số liệu chụp lúc tạo: giờ còn lại, giờ mua còn lại, giờ tặng bị huỷ, giá sau chiết khấu, số tiền giữ) và `app.customer_balance_entry` (sổ số dư khách hàng của phụ huynh, chỉ thêm dòng, không sửa, không hết hạn). Trạng thái: `NHAP` → `CHO_QL` → `CHO_KE_TOAN` → `DA_DUYET`; nhánh `TU_CHOI` (bắt buộc lý do), `HUY`.

| Hàm                                                  | Ai                                                      |
| ---------------------------------------------------- | ------------------------------------------------------- |
| `create_enrollment_stop(ghi danh, lý do, ghi chú, ticket)` | Ghi danh · Sửa                                    |
| `submit_enrollment_stop(id)`, `cancel_enrollment_stop(id)` | Ghi danh · Sửa                                    |
| `approve_stop_manager(id)`                           | Ghi danh · Duyệt; người tạo không tự duyệt (trừ Admin) |
| `approve_stop_accountant(id)`                        | Đối soát kế toán · Duyệt (chỉ Kế toán)                  |
| `reject_enrollment_stop(id, lý do)`                  | Bước quản lý: Ghi danh · Duyệt; bước kế toán: Đối soát kế toán · Duyệt |
| `customer_balance(phụ huynh)`                        | Phiếu thu · Xem ở cơ sở của phụ huynh                   |

Kế toán duyệt: kiểm lại số liệu (lệch thì chặn `HMT_DUNG_HOC_SO_LIEU_DOI`); ghi sổ giờ ngược dấu cho mọi giờ còn lại (giờ tặng bị huỷ); ghi danh sang **Dừng**; đóng dòng xếp lớp; ghi dòng số dư `TU_DUNG_HOC` (+).

**Chỗ tự chọn (chờ Chat):** giờ mua còn lại = nhỏ nhất của (giờ mua đã cấp − giờ đã học, giờ còn lại), không âm (coi giờ tặng dùng sau cùng nên không làm thiệt khách); tiền giữ = giờ mua còn lại × (thành tiền dòng ÷ giờ mua), không trừ phí.

Chưa làm: «Dùng số dư» cho đơn mới (ghi như khoản tiền vào của đơn, đụng lõi tiền); kiểm chéo với yêu cầu Hoàn phí đang mở (bảng ở migration 216); giao diện.
