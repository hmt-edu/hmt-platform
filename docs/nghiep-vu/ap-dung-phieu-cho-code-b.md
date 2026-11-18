# Lời gọi hai hàm «áp dụng» cho `execute_ticket_task` (dành cho Code B)

Code D, 16/11/2026. Chat chấp thuận phương án (thư 18:40): sau khi PR #75 (migration 234) vào `main`, `execute_ticket_task` của phiếu nghiệp vụ gọi hai hàm nội bộ dưới đây cho loại **Bảo lưu** và **Chuyển lớp**; phiếu đã duyệt đủ cấp ở `ticket_task` thì **không duyệt lần hai** ở bản ghi bảo lưu hoặc chuyển lớp.

## Hàm (nội bộ, không cấp cho giao diện; gọi từ hàm `security definer` của B)

```sql
app.apply_enrollment_hold(
  p_enrollment_id uuid, p_months integer, p_reason_code text,
  p_note text default null, p_ticket_ref text default null, p_extends_hold_id uuid default null)
returns uuid   -- id bản ghi app.enrollment_hold, đã ở DANG_BAO_LUU

app.apply_class_transfer(
  p_enrollment_id uuid, p_to_class_id uuid, p_start_date date, p_kind_code text,
  p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid   -- id bản ghi app.class_transfer, đã ở DA_CHUYEN
```

## Dữ liệu phiếu → tham số (đề xuất khoá trong `ticket_task.payload`)

| Loại phiếu | Khoá trong `payload` | Tham số |
| --- | --- | --- |
| `BAO_LUU` | `enrollment_id`, `months`, `reason_code` (danh mục `HOLD_REASON`), `note`, `extends_hold_id` (gia hạn) | `p_enrollment_id`, `p_months`, `p_reason_code`, `p_note`, `p_extends_hold_id`; `p_ticket_ref` = mã phiếu `PNV-...` |
| `CHUYEN_LOP` | `enrollment_id`, `to_class_id`, `start_date`, `kind` (`DOI_GIO`, `DOI_TRINH_DO`, `DOI_GIAO_VIEN`, `CHUYEN_CO_SO`), `reason_code` (danh mục `TRANSFER_REASON`), `note` | `p_enrollment_id`, `p_to_class_id`, `p_start_date`, `p_kind_code`, `p_reason_code`, `p_note`; `p_ticket_ref` = mã phiếu |

Gợi ý khung gọi trong `execute_ticket_task` (sau các kiểm hiện có: cờ `AFTERSALE`, `assert_can('TICKET','SUA')`, trạng thái `DA_DUYET`):

```sql
if k.task_type = 'BAO_LUU' then
  v_result := jsonb_build_object('hold_id', app.apply_enrollment_hold(
    (k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'months')::integer, k.payload ->> 'reason_code',
    k.payload ->> 'note', k.code, nullif(k.payload ->> 'extends_hold_id', '')::uuid));
elsif k.task_type = 'CHUYEN_LOP' then
  v_result := jsonb_build_object('transfer_id', app.apply_class_transfer(
    (k.payload ->> 'enrollment_id')::uuid, (k.payload ->> 'to_class_id')::uuid, (k.payload ->> 'start_date')::date,
    k.payload ->> 'kind', k.payload ->> 'reason_code', k.payload ->> 'note', k.code));
end if;
```

## Điều cần biết

- **Cờ riêng:** hai hàm kiểm cờ `BAO_LUU` và `CHUYEN_LOP` của cơ sở (tắt thì lỗi `HMT_TINH_NANG_TAT`), ngoài cờ `AFTERSALE`. Bật cả hai khi bật nghiệp vụ.
- **Lỗi có mã** (giao diện hiện thẳng): `HMT_BAO_LUU_QUA_THOI_GIAN`, `HMT_BAO_LUU_GHI_DANH_SAI`, `HMT_BAO_LUU_GIA_HAN_SAI`, `HMT_BAO_LUU_DANG_MO`, `HMT_CHUYEN_LOP_TRUNG_LOP`, `HMT_CHUYEN_LOP_KHAC_MON` (khác môn là chuyển phí, chưa làm), `HMT_CHUYEN_LOP_LOAI_SAI`, `HMT_CHUYEN_LOP_DANG_MO`, cùng các mã của kiểm lớp (`HMT_LOP_HET_CHO`, `HMT_NGAY_VAO_LOP_SAI`, `HMT_LOP_TRUNG_GIO`...). Lỗi làm cả giao dịch lùi, phiếu giữ nguyên `DA_DUYET` để thử lại.
- **Người duyệt:** hai hàm ghi người gọi (`auth.uid()`) làm người duyệt trên bản ghi; người duyệt thật nằm ở các cấp của `ticket_task`.
- **Chuyển cơ sở:** phiếu nên có cấp duyệt «quản lý cả hai cơ sở» (R-CS-07); `ticket_task_rule` hiện chỉ có một cấp cho `CHUYEN_LOP`. Nếu phiếu `CHUYEN_LOP` dùng cho `CHUYEN_CO_SO`, B thêm cấp hoặc loại phiếu riêng.
- **Hoàn phí và Dừng học** (thêm cấp kế toán): bản ghi của D (`refund_request`, `enrollment_stop`) còn bước kế toán duyệt kèm ghi sổ giờ, phiếu chi, số dư. Hàm «áp dụng» cho hai loại này sẽ làm ở PR riêng sau khi Chat chốt, để không đụng quyền kế toán.

## Hoàn phí và Dừng học (migration 235, thêm 18/11/2026)

```sql
app.apply_refund_request(
  p_enrollment_id uuid, p_kind text,            -- 'TOAN_BO' | 'MOT_PHAN'
  p_hours numeric,                              -- giờ hoàn (chỉ MOT_PHAN)
  p_reason_code text,                           -- danh mục REFUND_REASON
  p_note text default null, p_ticket_ref text default null)
returns uuid   -- id phiếu chi (payment_voucher)

app.apply_enrollment_stop(
  p_enrollment_id uuid, p_reason_code text,
  p_note text default null, p_ticket_ref text default null)
returns uuid   -- id bản ghi app.enrollment_stop
```

- Nội bộ (đã thu hồi quyền gọi của giao diện). Phiếu đã qua cấp quản lý và kế toán ở `ticket_task` (R-CS-07), nên hai hàm tạo bản ghi ở trạng thái «Chờ kế toán» với người duyệt quản lý là người gọi, rồi gọi lõi kế toán (`app.finish_refund_request`, `app.finish_enrollment_stop`): kiểm lại số liệu, ghi sổ giờ ngược dấu, đổi tình trạng ghi danh, lập phiếu chi hoặc số dư. Hai hàm duyệt cũ (231, 232) gọi cùng lõi, hành vi không đổi.
- Kiểm cờ `HOAN_PHI` của cơ sở. Lỗi có mã làm cả giao dịch lùi.
