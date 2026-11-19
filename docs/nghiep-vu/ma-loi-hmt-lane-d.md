# Mã lỗi HMT_* của lane D (tiền ra, số dư, hoàn phí, dừng học)

Thẻ D21, 18/11/2026. Quét `raise_error` trong các migration 212, 231, 232, 235, 450, 451, 452, 453, 455, 458 trên `main`: **mọi lỗi đều có mã `HMT_*` và câu tiếng Việt** (không còn `raise exception` trần hay mã không có tiền tố). Giao diện hiện thẳng câu này. Cột «Migration» ghi số tiền tố của file khai báo (000231 là migration 231…).

| Mã | Câu hiển thị (bản mới nhất) | Migration |
| --- | --- | --- |
| `HMT_CHI_KE_TOAN_DUYET_TIEN` | Chỉ vai trò Kế toán được có quyền Kế toán · Duyệt (Admin và các vai trò khác không duyệt tiền). Gán vai trò Kế toán cho người cụ thể khi cần. | 000455 |
| `HMT_CUNG_NGUOI_DUYET_HAI_BUOC` | Một người không duyệt cả bước quản lý và bước kế toán của cùng một yêu cầu. | 000455 |
| `HMT_DON_CO_GHI_DANH` | Đơn đã có ghi danh còn hiệu lực (cho học trước), không huỷ được. Dừng học hoặc hoàn phí ghi danh trước. | 000451 |
| `HMT_DON_DA_CO_PHIEU_THU` | Đơn đã có phiếu thu, không huỷ được. | 000451 |
| `HMT_DUNG_HOC_DANG_MO` | Ghi danh này đã có một yêu cầu dừng học chưa xong. | 000232, 000235 |
| `HMT_DUNG_HOC_GHI_DANH_SAI` | Ghi danh này không còn hiệu lực để dừng học. | 000232, 000235 |
| `HMT_DUNG_HOC_KHONG_CO_DON` | Ghi danh này không có dòng đơn nên chưa tính được số dư (cần giá). | 000232 |
| `HMT_DUNG_HOC_KHONG_DUOC_SUA` | Yêu cầu dừng học đang ở trạng thái không cho thao tác này. | 000232 |
| `HMT_DUNG_HOC_SO_LIEU_DOI` | Số liệu đã thay đổi từ lúc tạo yêu cầu (giờ đã học hoặc tiền đã đóng). Hãy huỷ và tạo yêu cầu mới. | 000232, 000235 |
| `HMT_DUNG_HOC_THIEU_LY_DO` | Từ chối phải ghi lý do. | 000232 |
| `HMT_DUNG_HOC_TU_DUYET` | Người tạo yêu cầu không tự duyệt yêu cầu của mình. | 000232, 000458 |
| `HMT_HOAN_PHI_DANG_MO` | Ghi danh này đã có một yêu cầu hoàn phí chưa xong. | 000231, 000235 |
| `HMT_HOAN_PHI_GHI_DANH_SAI` | Ghi danh này không còn hiệu lực để hoàn phí. | 000231, 000235 |
| `HMT_HOAN_PHI_GIO_SAI` | Giờ hoàn phải lớn hơn 0 và không quá số giờ còn lại (không tính giờ tặng). | 000212, 000450 |
| `HMT_HOAN_PHI_KHONG_CON_TIEN` | Không còn tiền để hoàn sau khi trừ giờ đã học và phí xử lý. | 000212, 000450 |
| `HMT_HOAN_PHI_KHONG_CO_DON` | Ghi danh này không có dòng đơn nên chưa tính được tiền hoàn (cần giá). | 000212, 000450 |
| `HMT_HOAN_PHI_KHONG_DUOC_SUA` | Yêu cầu hoàn phí đang ở trạng thái không cho thao tác này. | 000231 |
| `HMT_HOAN_PHI_LOAI_SAI` | Loại hoàn phí không hợp lệ: chọn hoàn toàn bộ hoặc hoàn một phần. | 000212, 000450 |
| `HMT_HOAN_PHI_SO_LIEU_DOI` | Số liệu đã thay đổi từ lúc tạo yêu cầu (giờ đã học hoặc tiền đã đóng). Hãy huỷ và tạo yêu cầu mới. | 000231, 000235 |
| `HMT_HOAN_PHI_THIEU_LY_DO` | Từ chối phải ghi lý do. | 000231 |
| `HMT_HOAN_PHI_TU_DUYET` | Người tạo yêu cầu không tự duyệt yêu cầu của mình. | 000231, 000458 |
| `HMT_KHONG_CO_QUYEN` | Bạn không có quyền xem số dư khách hàng. | 000452, 000453 |
| `HMT_KHONG_DUOC_HUY_DON` | Đơn đã trình hoặc đã duyệt chỉ người duyệt đã chốt lúc trình huỷ được (Admin huỷ thay khi vắng). | 000451 |
| `HMT_KHONG_TIM_THAY` | Không tìm thấy phụ huynh. | 000212, 000231, 000232, 000235, 000450, 000451, 000452, 000453 |
| `HMT_LY_DO_THIEU` | Chọn "Khác" thì ghi chú lý do. | 000451 |
| `HMT_PHIEU_CHI_DA_CHI` | Phiếu chi này đã chi rồi. | 000231 |
| `HMT_SAI_TRANG_THAI` | Đơn này đã huỷ. | 000451 |
## Mã lỗi nằm trong PR chưa gộp (cập nhật khi gộp)

| Mã | Ý | PR |
| --- | --- | --- |
| `HMT_CAN_TICKET`, `HMT_TICKET_KHONG_TON_TAI`, `HMT_TICKET_SAI_LOAI`, `HMT_TICKET_SAI_NHOM`, `HMT_TICKET_SAI_HOC_SINH`, `HMT_TICKET_SAI_CO_SO` | Hoàn phí, dừng học bắt buộc qua ticket Aftersale (R-V2-24A) | #135 (459) |
| `HMT_SO_DU_KHONG_DU`, `HMT_SO_TIEN_SAI`, `HMT_SO_TIEN_VUOT`, `HMT_TINH_NANG_TAT`, `HMT_SAI_TRANG_THAI` | Cấn số dư khách hàng vào đơn (cờ `customer_balance_apply_enabled`) | #110 (454) |

## Quy ước

- Hàm đọc (`list_*`, `get_*`) ngoài phạm vi báo `HMT_KHONG_TIM_THAY`; không có quyền xem báo `HMT_KHONG_CO_QUYEN`.
- Lỗi từ kiểm tra khoá chủ yếu chỉ lộ ở hàm nội bộ gọi qua hàm giao diện; hàm nội bộ gọi thẳng từ giao diện báo `42501` (không cấp quyền).

- `HMT_AP_DUNG_CHO_SAI` (migration 476, `app.save_discount_policy`): «Áp dụng cho» của chính sách chiết khấu trống hoặc có giá trị ngoài Báo giá, Đơn, Phiếu thu. Cột `app.discount_policy.applies_to` mặc định cả ba; `app.list_applicable_discount_policies` chỉ trả chính sách áp dụng cho Báo giá hoặc Đơn và có thêm khoá `applies_to`.

## LOP-09 Học sinh của lớp (migration 477)

- `app.list_class_students(lớp, bộ lọc, sắp xếp, số dòng, bỏ qua)`: mọi dòng xếp lớp (đang học và đã rời), phân trang máy chủ, quyền như `get_class_record`. Chỉ mục `enrollment_class_class_idx (class_id, start_date)`. Màn `/crm/lop/:id/hoc-sinh`. «Xuất» chưa làm: ma trận chưa có quyền Xuất cho phân hệ Lớp.
