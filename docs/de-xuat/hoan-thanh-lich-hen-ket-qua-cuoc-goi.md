# Đề xuất DB: Hoàn thành lịch hẹn kèm «Kết quả cuộc gọi» (D-23-21, bước 1)

Code D, 23/11/2026. Anh OK 15:54 hộp «Hoàn thành lịch hẹn». **Chỉ phân tích, chưa viết migration.** Luật: R-CRM-04 (hoàn thành, không đổi giai đoạn, không tạo việc, không báo ai), TS-13. Mức VỪA, cần pgTAP và Tester.

## 1. Hiện trạng (đã đọc code)
- Bảng `app.appointment` (migration 024, mở rộng 028, 030): trạng thái `CHUA_LAM | HOAN_THANH | HUY`, cột `completed_at`, `completed_by`, `note` (ghi chú lúc tạo), lý do huỷ từ danh mục `APPOINTMENT_CANCEL_REASON`, thuộc `lead_id` hoặc `opportunity_id` (hoặc phiếu test).
- `app.complete_appointment(p_id uuid)` (migration 025, bản 046): kiểm quyền `SUA`, chỉ khi `CHUA_LAM`, đặt `HOAN_THANH`, ghi dòng lịch sử hệ thống. **Không nhận kết quả, không tạo lịch hẹn kế.**
- `app.reopen_appointment(p_id)` xoá `completed_*`, về `CHUA_LAM`.
- Giao diện gọi qua `src/features/appointments/appointmentApi.ts`; pgTAP hiện gọi `complete_appointment(id)` một tham số ở các bài 017, 020, 026, 033, 038.

## 2. Thiết kế đề xuất

### 2.1 Danh mục «Kết quả cuộc gọi»
Danh mục mở `APPOINTMENT_RESULT` (kiểu `MO`, quản trị ở QT-07, có `code`, `name`, `sort_order`, `is_active`; không xoá, chỉ Ngừng). Seed (mã giữ cố định, tên đổi được):

| code | name |
| --- | --- |
| `DA_TU_VAN_QUAN_TAM` | Đã tư vấn, quan tâm |
| `HEN_GOI_LAI` | Hẹn gọi lại |
| `KHONG_NGHE_MAY` | Không nghe máy |
| `KHACH_TU_CHOI` | Khách từ chối |
| `SAI_SO` | Sai số |
| `DA_CHOT_DANG_KY` | Đã chốt đăng ký |

### 2.2 Cột mới trên `app.appointment`
- `result_catalog text not null default 'APPOINTMENT_RESULT' check (...)`, `result_code text`, khoá ngoại ghép `(result_catalog, result_code) → catalog_item` (cùng kiểu cột lý do huỷ).
- `result_note text` (ghi chú kết quả, tối đa độ dài đọc từ tham số hoặc `check` như `payout_account_note`).
- `next_appointment_id uuid references app.appointment (id)` (lịch hẹn kế do hộp này tạo, để truy ngược).
- Ràng buộc: `status = 'HOAN_THANH'` thì được có `result_code`; không hoàn thành thì `result_code` null (mở lại xoá, như lý do huỷ).
- Chỉ mục: **chưa thêm** (cột chưa dùng để lọc, sắp xếp). Khi báo cáo cần lọc theo kết quả thì thêm `(branch_id, result_code)` kèm lý do.

### 2.3 Hàm
`app.complete_appointment(p_id uuid, p_result_code text default null, p_result_note text default null, p_next_at timestamptz default null, p_next_activity_code text default null, p_next_title text default null)`:
1. Như bản cũ: quyền `SUA`, chỉ `CHUA_LAM`.
2. **Kết quả:** kiểm `p_result_code` đang dùng trong `APPOINTMENT_RESULT` (lỗi `HMT_KET_QUA_KHONG_HOP_LE`); bắt buộc theo quy tắc ở mục 3 (lỗi `HMT_THIEU_KET_QUA`).
3. **Ghi chú:** cắt khoảng trắng, độ dài giới hạn (`HMT_GHI_CHU_DAI`).
4. **Hẹn lần sau (tuỳ chọn):** nếu có `p_next_at`: phải sau hiện tại (`HMT_HEN_LAN_SAU_QUA_KHU`); tạo lịch hẹn mới bằng chính `app.create_appointment` cho **cùng lead/cơ hội**, loại hoạt động mặc định = loại của lịch vừa làm, tiêu đề mặc định «Gọi lại: <tiêu đề cũ>», chủ = người hoàn thành. Một giao dịch: lỗi ở bước tạo thì không hoàn thành.
5. Ghi lịch sử hệ thống (`add_appointment_note`): «Hoàn thành lịch hẹn "…". Kết quả: <tên>. Ghi chú: … Hẹn lần sau: … (mã)». Không đổi giai đoạn, không báo ai (R-CRM-04 giữ nguyên).
6. Hàm cũ một tham số vẫn chạy (các tham số mới có mặc định) nên không vỡ pgTAP hiện có và các luồng tự nhắc.

`reopen_appointment`: xoá `result_code`, `result_note` (giữ `next_appointment_id`, lịch kế vẫn sống; ghi vào dòng lịch sử mở lại).

### 2.4 Chỗ bị ảnh hưởng
- `list_appointments`, `get_*` của lead/cơ hội (khối lịch hẹn bên phải), `export_appointments`: thêm cột kết quả (đọc thêm, không đổi lọc).
- `appointment_group_counts`/Group By: có thể thêm nhóm «Kết quả» sau (chưa làm).
- `docs/nghiep-vu/`: ghi hàm mới; `audit_log` ghi đổi cột bình thường (kết quả, ghi chú không nhạy cảm).
- RLS: không đổi (cột mới theo chính sách bảng cũ).
- Bước 2 (giao diện) chờ khung Design: hộp K08 `FormDialog` «Hoàn thành lịch hẹn» (Kết quả bắt buộc, Ghi chú, Hẹn lần sau).

## 3. Cần anh/Chat chốt trước khi viết migration
1. **Kết quả bắt buộc cho loại hoạt động nào?** Đề xuất: bắt buộc khi hoạt động là **Gọi điện** (`GOI_DIEN`), tuỳ chọn với loại khác (Zalo, Gặp trực tiếp, Test…) để không ép chọn «Không nghe máy» cho cuộc hẹn gặp. Lịch tự nhắc (`is_auto_reminder`) hoàn thành bằng đường tự động thì bỏ qua.
2. **«Đã chốt đăng ký»:** chỉ là nhãn kết quả, **không** tự đổi giai đoạn/tạo cơ hội (R-CRM-04). Đồng ý?
3. **Hẹn lần sau:** mặc định cùng loại hoạt động và chủ = người hoàn thành. Với kết quả «Hẹn gọi lại», giao diện gợi ý bật sẵn hẹn lần sau, nhưng DB không ép. Đồng ý?
4. **Ghi chú:** bắt buộc khi kết quả «Khách từ chối» hoặc «Sai số»? (đề xuất: không bắt buộc ghi chú).
5. **Số migration** cho D (từ 624; Chat cấp).
