# Đề xuất: bản ghi nghiệp vụ Chuyển lớp và Hoàn phí (Code D, 16/11/2026)

**Trạng thái: ĐỀ XUẤT, chờ Chat chốt.** Luật gốc đã có, không đổi: R-GD-10, R-TIEN-28, R-TIEN-31, R-TIEN-34, R-CS-02, R-CS-03, R-CS-07, R-V2-24. Tài liệu này chỉ nói cách đặt bảng, trạng thái, người duyệt và mã lỗi. Mọi số dùng tham số có sẵn (`refund_processing_fee_percent`), không viết cứng.

## 1. Nguyên tắc chung (theo R-V2-24)

- Ticket đề nghị (Aftersale, PR #18 của Code B) chỉ ghi nhu cầu. **Việc duyệt nằm ở bản ghi nghiệp vụ.** Bản ghi nghiệp vụ gắn `ticket_id` (cho phép trống khi ticket chưa gộp; ràng buộc khoá ngoại thêm sau khi bảng ticket có trên `main`).
- Bản ghi chỉ thêm trạng thái, không xoá cứng. Huỷ là đổi trạng thái. Mọi chuyển trạng thái đi qua hàm Postgres, mỗi lần một giao dịch, ghi `audit_log`.
- Công tắc tính năng theo cơ sở `CHUYEN_LOP` và `HOAN_PHI`, mặc định TẮT cho CS5; kiểm ở giao diện và trong hàm.
- Chụp lại lúc tạo: giá, giờ còn lại, chiết khấu, phí xử lý % (R-TIEN-14). Duyệt xong không tính lại theo giá mới.

## 2. Chuyển lớp (`app.class_transfer`)

Phạm vi: cùng môn (đổi giờ, đổi trình độ, đổi giáo viên) và chuyển cơ sở. Chuyển lớp khác môn là chuyển phí, không nằm trong PR này (R-CS-03).

| Cột chính | Ý nghĩa |
|---|---|
| `enrollment_id`, `from_class_id`, `to_class_id`, `start_date` | Ghi danh, lớp cũ, lớp mới, ngày vào lớp mới (chọn từ buổi sắp tới, R-GD-06) |
| `kind_code` | `DOI_GIO`, `DOI_TRINH_DO`, `DOI_GIAO_VIEN`, `CHUYEN_CO_SO` (danh mục khoá) |
| `status_code` | `NHAP` → `CHO_DUYET` → `DA_DUYET` → `DA_CHUYEN`; nhánh `TU_CHOI` (bắt buộc lý do), `HUY` |
| `reason_code`, `note` | Lý do (danh mục) để báo cáo R-CS-12 |
| `hours_snapshot` | Giờ còn lại lúc tạo, chỉ để đối chiếu; giờ đi theo ghi danh (R-GD-10) |

Hàm (kiểm quyền bên trong, mỗi hàm một việc):
- `create_class_transfer(ghi danh, lớp mới, ngày vào, loại, lý do, ghi chú, mã ticket)`: kiểm bằng các hàm đã có `assert_class_fits`, `assert_enrol_start_date`, `assert_no_time_clash`; ghi danh phải `DA_XEP_LOP`, `DANG_HOC` hoặc `BAO_LUU`.
- `submit_class_transfer`, `approve_class_transfer`, `reject_class_transfer`, `cancel_class_transfer`.
- `execute_class_transfer`: gọi `move_enrollment_class` (đã có, migration 101), đổi trạng thái `DA_CHUYEN`, đóng phiếu tái tục theo R-GD-13. Kiểm lại toàn bộ luật lúc thực hiện vì lớp có thể đầy sau khi duyệt.

Người duyệt (R-CS-07, cấu hình được): cùng môn → quản lý cơ sở của lớp cũ; chuyển cơ sở → quản lý **cả hai** cơ sở (hai dòng duyệt, đủ cả hai mới sang `DA_DUYET`). Người tạo không tự duyệt bản ghi của mình trừ Admin.

Mã lỗi: `HMT_CHUYEN_LOP_TRUNG_LOP`, `HMT_CHUYEN_LOP_THIEU_QUYEN_DUYET`, `HMT_CHUYEN_LOP_KHONG_DUOC_SUA` (đã khoá), cùng các mã sẵn có của `assert_*`.

## 3. Hoàn phí (`app.refund_request`)

Phạm vi: hoàn một phần và hoàn toàn bộ. Dừng học (R-GD-16) dùng chung bản ghi này, chọn `outcome_code` = hoàn tiền hoặc giữ số dư.

| Cột chính | Ý nghĩa |
|---|---|
| `enrollment_id`, `order_id`, `ticket_id` | Gắn ghi danh, đơn gốc, ticket |
| `kind_code` | `TOAN_BO` (R-TIEN-28), `MOT_PHAN` (R-TIEN-31) |
| `outcome_code` | `HOAN_TIEN` hoặc `GIU_SO_DU` (R-TIEN-33; chỉ khi dừng học) |
| `hours_refund` | Giờ hoàn (một phần); toàn bộ thì bằng giờ còn lại |
| `paid_amount`, `unit_price_base`, `unit_price_net`, `hours_used`, `fee_percent`, `fee_amount`, `refund_amount` | Chụp lại và tính ở máy chủ (R-TIEN-13); `bigint` đồng |
| `status_code` | `NHAP` → `CHO_QL` → `CHO_KE_TOAN` → `DA_DUYET` → `DA_CHI`; nhánh `TU_CHOI`, `HUY` |

Công thức (đặt trong một hàm `compute_refund`, kiểm thử bằng ví dụ của R-TIEN-28: 48 giờ × 220.000, chiết khấu 10%, đóng 9.504.000, học 20 giờ → hoàn 4.593.600):
- Toàn bộ: `(tiền đã đóng − giờ đã học × giá gốc) × (1 − phí%)`.
- Một phần: `giờ hoàn × giá sau chiết khấu × (1 − phí%)`. **Cần Chat xác nhận:** R-TIEN-31 ghi «trừ phí xử lý» nhưng không nói phí tính trên số nào; đề xuất phí% tính trên `giờ hoàn × giá sau chiết khấu`, giống R-TIEN-28 tính trên số còn lại.
- Giờ tặng không hoàn, giờ tặng còn lại bị huỷ khi dừng học. Số tiền không âm; nếu âm thì chặn `HMT_HOAN_PHI_KHONG_CON_TIEN`.

Thực hiện: duyệt quản lý cơ sở rồi kế toán (R-CS-07). Khi `DA_DUYET`, kế toán lập phiếu chi `PC` (R-TIEN-34, danh mục `DOC_TYPE` đã có `PC`) và sổ giờ ghi dòng ngược dấu cho giờ hoàn (R-GD-04). `DA_CHI` khi phiếu chi đã chi. Ghi danh sang `HOAN_PHI` hoặc `DUNG` khi hoàn toàn bộ.

**Phụ thuộc chưa có trên `main`:** bảng phiếu chi, sổ số dư khách hàng (R-TIEN-33), bảng ticket (PR #18). Thứ tự làm: (1) Chuyển lớp, (2) phiếu chi + số dư + Hoàn phí sau khi #18 gộp.

## 4. Kiểm thử bắt buộc (pgTAP)

Mỗi luật một bài đúng và một bài bị chặn: lớp đầy, trùng giờ, khác môn, không đủ quyền duyệt, duyệt hai lần, thực hiện khi ghi danh đã Dừng, công tắc tắt, tính tiền theo ví dụ R-TIEN-28, giờ tặng không hoàn, phí tính đúng theo tham số, sổ giờ ngược dấu, RLS theo cơ sở.

## 5. Câu hỏi cho Chat

1. Chấp nhận chia việc: D làm Chuyển lớp + Hoàn phí; C giữ R-GD-09 (bảo lưu) và TC-09? (đã hỏi trong `code-d.md`.)
2. Phí xử lý của hoàn một phần tính trên số nào (mục 3)?
3. Chuyển cơ sở có làm chung bản ghi Chuyển lớp (đề xuất) hay tách?
