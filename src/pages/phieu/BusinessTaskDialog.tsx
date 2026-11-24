// Hộp thoại tạo phiếu Bảo lưu hoặc Chuyển lớp từ chi tiết ticket (CSN-06a, CSN-06b). Dữ liệu gửi app.create_ticket_task; luật chặn thật ở DB.
import { useState } from 'react';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { formatDate, formatMoney } from '../../lib/format';
import {
  buildBusinessPayload,
  classChoices,
  EMPTY_BUSINESS_DRAFT,
  FEE_TRANSFER_KINDS,
  HOLD_MODES,
  MONEY_MODES,
  REFUND_KINDS,
  type RefundKind,
  type MoneyMode,
  holdEnrollmentChoices,
  runningHold,
  type BusinessType,
  type HoldMode,
  TRANSFER_BRANCH_KIND,
  TRANSFER_KINDS,
  validateBusinessDraft,
  type BusinessDraft,
} from './businessTaskForm';
import { TASK_TYPE_LABEL } from './taskLabels';
import {
  useDestBranches,
  useFeeTransferOrders,
  useFeeTransferPreview,
  useRefundReasons,
  useTaskOptions,
} from './useTaskCreate';

export function BusinessTaskDialog({
  type,
  ticketId,
  ticketCode,
  ticketBranchId,
  hasStudent,
  open,
  onOpenChange,
  busy,
  error,
  onCreate,
}: {
  type: BusinessType;
  ticketId: string;
  ticketCode: string;
  /** Cơ sở của ticket: loại khỏi danh sách cơ sở mới. */
  ticketBranchId?: string;
  hasStudent: boolean;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  busy: boolean;
  error: string | null;
  onCreate: (reason: string, payload: unknown) => void;
}) {
  const options = useTaskOptions(ticketId, open && hasStudent);
  const refundReasons = useRefundReasons(open && type === 'HOAN_PHI');
  const branches = useDestBranches(open && type === 'CHUYEN_LOP');
  const [draft, setDraft] = useState<BusinessDraft>(EMPTY_BUSINESS_DRAFT);
  const [show, setShow] = useState(false);
  const set = (patch: Partial<BusinessDraft>) => setDraft((d) => ({ ...d, ...patch }));
  const errors = show ? validateBusinessDraft(type, draft, hasStudent) : {};
  const data = options.data;
  const reasons =
    (type === 'BAO_LUU'
      ? data?.hold_reasons
      : type === 'DUNG_HOC'
        ? data?.stop_reasons
        : type === 'HOAN_PHI'
          ? refundReasons.data
          : data?.transfer_reasons) ?? [];
  const enrollment = data?.enrollments.find((x) => x.id === draft.enrollmentId);
  const classes = data ? classChoices(data, draft.enrollmentId) : [];
  const enrollmentChoices = !data
    ? []
    : type === 'BAO_LUU'
      ? holdEnrollmentChoices(data, draft.holdMode)
      : type === 'DUNG_HOC' || type === 'CHUYEN_PHI' || type === 'HOAN_PHI'
        ? data.enrollments
        : data.enrollments.filter((x) => x.status_code !== 'BAO_LUU');
  const hold = data && type === 'BAO_LUU' ? runningHold(data, draft.enrollmentId) : null;
  const newClass = classes.find((c) => c.id === draft.toClassId);

  const feeOrders = useFeeTransferOrders(draft.enrollmentId, open && type === 'CHUYEN_PHI');
  const feePreview = useFeeTransferPreview(
    draft.enrollmentId,
    draft.orderId,
    open && type === 'CHUYEN_PHI',
  );

  const submit = () => {
    setShow(true);
    if (Object.keys(validateBusinessDraft(type, draft, hasStudent)).length > 0) return;
    onCreate(draft.reason.trim(), buildBusinessPayload(type, draft, hold?.id ?? null));
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={(o) => {
        if (o) {
          setDraft(EMPTY_BUSINESS_DRAFT);
          setShow(false);
        }
        onOpenChange(o);
      }}
      title={`Tạo phiếu ${TASK_TYPE_LABEL[type] ?? type}`}
      subtitle={ticketCode}
      confirmLabel="Tạo phiếu"
      canSubmit={!show || Object.keys(errors).length === 0}
      busy={busy || options.isLoading}
      error={error ?? (options.error ? 'Không tải được dữ liệu biểu mẫu. Thử lại sau.' : null)}
      onSubmit={submit}
    >
      {type === 'BAO_LUU' && (
        <OptionalSelect
          label="Hình thức"
          value={draft.holdMode}
          onChange={(v) => set({ holdMode: v as HoldMode, enrollmentId: '' })}
          options={HOLD_MODES.map((m) => ({ value: m.value, label: m.label }))}
          placeholder="Chọn hình thức"
        />
      )}
      <OptionalSelect
        label="Ghi danh"
        value={draft.enrollmentId}
        onChange={(v) => set({ enrollmentId: v, toClassId: '', startDate: '' })}
        options={enrollmentChoices.map((x) => ({
          value: x.id,
          label: `${x.code}${x.class_code ? ` · ${x.class_code}` : ''}`,
        }))}
        placeholder="Chọn ghi danh"
        invalid={errors.enrollmentId !== undefined}
      />
      {errors.enrollmentId && (
        <p className="text-caption text-on-danger-subtle">{errors.enrollmentId}</p>
      )}
      {hold && (
        <p className="text-caption text-fg-muted">
          Bảo lưu đang chạy từ {formatDate(hold.start_date)} đến {formatDate(hold.end_date)}. Gia
          hạn nối tiếp từ ngày {formatDate(hold.end_date)}.
        </p>
      )}
      {enrollment && (
        <p className="text-caption text-fg-muted">
          Giờ còn lại: {enrollment.remaining_hours} giờ
          {type === 'CHUYEN_LOP' &&
            ' · Chuyển lớp không đổi số giờ, giờ đã mua đi theo ghi danh sang lớp mới.'}
        </p>
      )}
      <OptionalSelect
        label="Lý do (danh mục)"
        value={draft.reasonCode}
        onChange={(v) => set({ reasonCode: v })}
        options={reasons.map((r) => ({ value: r.code, label: r.name }))}
        placeholder="Chọn lý do"
        invalid={errors.reasonCode !== undefined}
      />
      {errors.reasonCode && (
        <p className="text-caption text-on-danger-subtle">{errors.reasonCode}</p>
      )}
      {type === 'HOAN_PHI' ? (
        <>
          <OptionalSelect
            label="Hình thức hoàn"
            value={draft.refundKind}
            onChange={(v) => set({ refundKind: v as RefundKind, refundHours: '' })}
            options={REFUND_KINDS.map((k) => ({ value: k.value, label: k.label }))}
            placeholder="Chọn hình thức hoàn"
            invalid={errors.refundKind !== undefined}
          />
          {errors.refundKind && (
            <p className="text-caption text-on-danger-subtle">{errors.refundKind}</p>
          )}
          {draft.refundKind === 'MOT_PHAN' && (
            <TextField
              label="Số giờ hoàn"
              required
              inputMode="decimal"
              value={draft.refundHours}
              error={errors.refundHours ?? null}
              onChange={(e) => set({ refundHours: e.target.value })}
            />
          )}
          <p className="text-caption text-fg-muted">
            Hoàn toàn bộ: hoàn theo giá gốc, trừ giờ đã học và phí xử lý; giờ tặng không hoàn. Hoàn
            một phần: số giờ hoàn × giá sau chiết khấu, trừ phí xử lý. Số tiền do máy chủ tính và
            chụp lại lúc thực hiện. Cần quản lý cơ sở rồi kế toán duyệt; hoàn xong sinh phiếu chi.
          </p>
        </>
      ) : type === 'CHUYEN_PHI' ? (
        <>
          <OptionalSelect
            label="Kiểu chuyển"
            value={draft.kindCode}
            onChange={(v) => set({ kindCode: v })}
            options={FEE_TRANSFER_KINDS.map((k) => ({ value: k.value, label: k.label }))}
            placeholder="Chọn kiểu chuyển"
            invalid={errors.kindCode !== undefined}
          />
          {errors.kindCode && (
            <p className="text-caption text-on-danger-subtle">{errors.kindCode}</p>
          )}
          <OptionalSelect
            label="Đơn nhận (tham khảo)"
            value={draft.orderId}
            onChange={(v) => set({ orderId: v })}
            options={(feeOrders.data ?? []).map((o) => ({
              value: o.id,
              label: `${o.code} · ${formatMoney(o.total_amount)}`,
            }))}
            placeholder="Chọn đơn nhận"
            disabled={draft.enrollmentId === ''}
          />
          {feePreview.error && (
            <p className="text-caption text-on-danger-subtle">{feePreview.error.message}</p>
          )}
          {feePreview.data && (
            <table className="w-full text-caption" aria-label="Bảng tính chuyển phí">
              <tbody>
                <tr>
                  <td>Giờ mua</td>
                  <td className="text-right">{feePreview.data.hours_bought} giờ</td>
                </tr>
                <tr>
                  <td>Giờ đã học</td>
                  <td className="text-right">{feePreview.data.hours_used} giờ</td>
                </tr>
                <tr>
                  <td>Giá sau chiết khấu</td>
                  <td className="text-right">{formatMoney(feePreview.data.unit_price_net)}</td>
                </tr>
                <tr>
                  <td>Đã đóng</td>
                  <td className="text-right">{formatMoney(feePreview.data.paid_amount)}</td>
                </tr>
                <tr>
                  <td>Giá trị chuyển</td>
                  <td className="text-right">{formatMoney(feePreview.data.transfer_value)}</td>
                </tr>
                <tr>
                  <td>Giờ tặng bị huỷ</td>
                  <td className="text-right">{feePreview.data.hours_gift_cancelled} giờ</td>
                </tr>
                {feePreview.data.order_total !== null && (
                  <>
                    <tr>
                      <td>Giá trị đơn nhận</td>
                      <td className="text-right">{formatMoney(feePreview.data.order_total)}</td>
                    </tr>
                    <tr>
                      <td>Phụ huynh đóng thêm</td>
                      <td className="text-right">{formatMoney(feePreview.data.extra_to_pay)}</td>
                    </tr>
                  </>
                )}
              </tbody>
            </table>
          )}
          <p className="text-caption text-fg-muted">
            Chuyển phí: ghi danh cũ dừng; giờ mua còn lại × giá sau chiết khấu giữ thành số dư khách
            hàng, không trừ phí, không tự hoàn tiền; giờ tặng còn lại bị huỷ. Bảng trên chỉ tham
            khảo, số dư chưa trừ vào đơn nhận; tính lại khi thực hiện phiếu. Cần quản lý cơ sở rồi
            kế toán duyệt.
          </p>
        </>
      ) : type === 'DUNG_HOC' ? (
        <>
          <TextField
            label="Ngày dừng"
            required
            type="date"
            value={draft.stopDate}
            error={errors.stopDate ?? null}
            onChange={(e) => set({ stopDate: e.target.value })}
          />
          <OptionalSelect
            label="Xử lý tiền còn lại"
            value={draft.moneyMode}
            onChange={(v) => set({ moneyMode: v as MoneyMode })}
            options={MONEY_MODES.map((m) => ({ value: m.value, label: m.label }))}
            placeholder="Chọn cách xử lý"
            invalid={errors.moneyMode !== undefined}
          />
          {errors.moneyMode && (
            <p className="text-caption text-on-danger-subtle">{errors.moneyMode}</p>
          )}
          <p className="text-caption text-fg-muted">
            Dừng học đóng ghi danh; giờ tặng còn lại bị huỷ. Hoàn tiền: hoàn phí toàn bộ theo giá
            gốc, trừ phí xử lý. Giữ số dư: giờ mua còn lại × giá sau chiết khấu, không trừ phí. Ngày
            dừng chỉ ghi nhận, không đổi cách tính giờ. Cần quản lý cơ sở rồi kế toán duyệt.
          </p>
        </>
      ) : type === 'BAO_LUU' && draft.holdMode === 'TIEP_TUC' ? (
        <p className="text-caption text-fg-muted">
          Khi thực hiện, bảo lưu kết thúc và em về hàng chờ xếp lớp, giữ nguyên số giờ còn lại. CSKH
          xếp lớp như thường; em vào danh sách buổi sau khi được xếp lớp.
        </p>
      ) : type === 'BAO_LUU' ? (
        <TextField
          label={draft.holdMode === 'GIA_HAN' ? 'Số tháng gia hạn' : 'Số tháng bảo lưu'}
          required
          inputMode="numeric"
          value={draft.months}
          error={errors.months ?? null}
          onChange={(e) => set({ months: e.target.value })}
        />
      ) : (
        <>
          <OptionalSelect
            label="Loại chuyển"
            value={draft.kindCode}
            onChange={(v) => set({ kindCode: v })}
            options={TRANSFER_KINDS.map((k) => ({ value: k.value, label: k.label }))}
            placeholder="Chọn loại chuyển"
            invalid={errors.kindCode !== undefined}
          />
          {errors.kindCode && (
            <p className="text-caption text-on-danger-subtle">{errors.kindCode}</p>
          )}
          {draft.kindCode === TRANSFER_BRANCH_KIND ? (
            <>
              <OptionalSelect
                label="Cơ sở mới"
                value={draft.destBranchId}
                onChange={(v) => set({ destBranchId: v })}
                options={(branches.data ?? [])
                  .filter((b) => b.id !== ticketBranchId)
                  .map((b) => ({ value: b.id, label: `${b.code} ${b.name}` }))}
                placeholder="Chọn cơ sở"
                invalid={errors.destBranchId !== undefined}
              />
              {errors.destBranchId && (
                <p className="text-caption text-on-danger-subtle">{errors.destBranchId}</p>
              )}
              <p className="text-caption text-fg-muted">
                Chuyển cơ sở giữ nguyên số giờ. Quản lý cơ sở hiện tại duyệt trước, rồi quản lý cơ
                sở mới duyệt và chọn lớp mới, buổi bắt đầu ở bước của họ.
              </p>
            </>
          ) : (
            <>
              <OptionalSelect
                label="Lớp mới"
                value={draft.toClassId}
                onChange={(v) => set({ toClassId: v, startDate: '' })}
                options={classes.map((c) => ({ value: c.id, label: c.code }))}
                placeholder="Chọn lớp"
                disabled={draft.enrollmentId === ''}
                invalid={errors.toClassId !== undefined}
              />
              {errors.toClassId && (
                <p className="text-caption text-on-danger-subtle">{errors.toClassId}</p>
              )}
              <OptionalSelect
                label="Hiệu lực từ buổi"
                value={draft.startDate}
                onChange={(v) => set({ startDate: v })}
                options={(newClass?.upcoming ?? []).map((u) => ({
                  value: u.date,
                  label: `Buổi ${u.session_no} · ${formatDate(u.date)}`,
                }))}
                placeholder="Chọn buổi"
                disabled={newClass === undefined}
                invalid={errors.startDate !== undefined}
              />
              {errors.startDate && (
                <p className="text-caption text-on-danger-subtle">{errors.startDate}</p>
              )}
            </>
          )}
        </>
      )}
      <TextAreaField
        label="Lý do"
        required
        value={draft.reason}
        error={errors.reason ?? null}
        onChange={(e) => set({ reason: e.target.value })}
      />
      <p className="text-caption text-fg-muted">
        Phiếu tạo ở bước Nháp; trình duyệt ở màn Phiếu nghiệp vụ.
      </p>
    </FormDialog>
  );
}
