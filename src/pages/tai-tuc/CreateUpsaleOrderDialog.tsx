// «Tạo đơn» từ phiếu tái tục ở L6 (khuôn K4 ③ FormDialog; canvas 9933 TT02_l6): chọn gói, số giờ, điều khoản thanh toán, ngày vào lớp (một buổi sắp tới của lớp).
// Học sinh, lớp, hình thức học lấy từ phiếu và ghi danh cũ (R-GD-13), KHÔNG chọn ở đây. Tiền tính ở máy chủ khi tạo (giá hiện chỉ để xem, đơn vị đồng mỗi giờ).
// Hàm create_order_from_upsale_ticket kiểm hai quyền (Đơn hàng · Tạo, Phiếu tái tục · Sửa), một giao dịch; hộp chỉ hiện lỗi của hàm.
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { errorOf, useDb } from '../../lib/db';
import { formatDate, formatMoney } from '../../lib/format';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import type { UpsaleTicketDetail } from './upsaleTypes';
import { createUpsaleOrder, useUpsaleOrderOptions } from './useUpsaleData';
import { useOrderEditOptions } from '../don-hang/useOrderData';
import { termLabel } from '../dieu-khoan/termLogic';

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  ticket: UpsaleTicketDetail;
  onDone: () => Promise<void> | void;
};

/** Mỗi lần mở là một biểu mẫu mới. */
export function CreateUpsaleOrderDialog(props: Props) {
  return props.open ? <OrderForm {...props} /> : null;
}

function OrderForm({ open, onOpenChange, ticket, onDone }: Props) {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const options = useUpsaleOrderOptions(ticket.id, true);
  const [packageId, setPackageId] = useState('');
  const [hoursText, setHoursText] = useState('');
  const parsed = Number(hoursText.trim().replace(',', '.'));
  const hours = hoursText.trim() !== '' && Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  const [termId, setTermId] = useState('');
  const [start, setStart] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const data = options.data;
  const editOptions = useOrderEditOptions(true);
  const mode = data?.delivery_mode_code ?? null;
  const pkg = data?.packages.find((p) => p.id === packageId);

  async function submit() {
    if (hours === null) return;
    setBusy(true);
    setError(null);
    try {
      const result = await createUpsaleOrder(
        supabase,
        ticket.id,
        { package_id: packageId, quantity: hours },
        termId || null,
        start || null,
      );
      await onDone();
      onOpenChange(false);
      toast({ title: `Đã tạo đơn nháp ${result.code}.` });
      void navigate(`/crm/don-hang/${result.id}`);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Tạo đơn tái tục"
      subtitle={`${ticket.code} · ${ticket.student_name} · ${ticket.class_code}`}
      confirmLabel="Tạo đơn nháp"
      cancelLabel="Đóng"
      canSubmit={packageId !== '' && hours !== null}
      busy={busy}
      error={options.isError ? errorOf(options.error).message : error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-4">
        <Field label="Gói" required>
          {(f) => (
            <Select
              id={f.id}
              label="Gói"
              value={packageId}
              onChange={setPackageId}
              options={(data?.packages ?? []).map((p) => ({
                value: p.id,
                label: `${p.code} · ${p.name}`,
              }))}
              placeholder={options.isPending ? 'Đang tải…' : 'Chọn gói'}
              disabled={options.isPending}
              className="w-full"
            />
          )}
        </Field>
        <TextField
          label="Số giờ"
          required
          inputMode="decimal"
          value={hoursText}
          onChange={(e) => setHoursText(e.target.value)}
          help={
            pkg && mode && pkg.prices[mode] !== undefined
              ? `Đơn giá ${formatMoney(pkg.prices[mode])} mỗi giờ (hình thức ${mode}); tổng tiền do hệ thống tính khi tạo đơn.`
              : 'Tổng tiền do hệ thống tính khi tạo đơn.'
          }
        />
        <Field label="Ngày vào lớp" help="Để trống: buổi sắp tới gần nhất của lớp.">
          {(f) => (
            <Select
              id={f.id}
              label="Ngày vào lớp"
              value={start}
              onChange={setStart}
              options={[
                { value: '', label: 'Buổi sắp tới gần nhất' },
                ...(data?.sessions ?? []).map((d) => ({ value: d, label: formatDate(d) })),
              ]}
              className="w-full"
            />
          )}
        </Field>
        <Field label="Điều khoản thanh toán">
          {(f) => (
            <Select
              id={f.id}
              label="Điều khoản thanh toán"
              value={termId}
              onChange={setTermId}
              options={[
                { value: '', label: 'Chưa chọn' },
                ...(data?.terms ?? []).map((t) => ({
                  value: t.id,
                  // Lịch đợt lấy từ cùng nguồn với ô chọn của đơn hàng; chưa tải xong thì hiện tên.
                  label: termLabel(editOptions.data?.terms.find((x) => x.id === t.id) ?? t),
                })),
              ]}
              className="w-full"
            />
          )}
        </Field>
        <p className="text-caption text-fg-muted">
          Học sinh, lớp và hình thức học lấy từ phiếu. Đơn tạo ở trạng thái Nháp rồi mở trang đơn;
          phiếu sang L7B.
        </p>
      </div>
    </FormDialog>
  );
}
