// TC-03 Tạo phiếu thu từ đơn Đã duyệt: nhập số tiền (gợi ý phần còn thu được) và hình thức, tạo phiếu Nháp rồi mở trang phiếu (TC-02) để điền
// phần còn lại. Hàm DB create_receipt kiểm quyền, công tắc Bán hàng, số tiền không vượt phần còn thu của đơn (khung vẽ tạo phiếu rỗng rồi điền:
// DB cần số tiền > 0 ngay lúc tạo nên hộp này hỏi trước hai ô cốt lõi).
import { useState } from 'react';
import { useNavigate } from 'react-router';
import { errorOf, useDb } from '../../lib/db';
import { FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { MoneyInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { createReceipt, useRefreshReceipt } from './useReceiptData';

type Props = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  orderId: string;
  orderCode: string;
  /** Phần còn thu được của đơn (do hàm DB tính). */
  receivable: number | null;
};

export function CreateReceiptDialog(props: Props) {
  return props.open ? <CreateForm {...props} /> : null;
}

function CreateForm({ open, onOpenChange, orderId, orderCode, receivable }: Props) {
  const supabase = useDb();
  const navigate = useNavigate();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const refresh = useRefreshReceipt('', orderId);
  const methods = catalogs.options('PAYMENT_METHOD');
  const [amount, setAmount] = useState<number | null>(
    receivable !== null && receivable > 0 ? receivable : null,
  );
  const [method, setMethod] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (amount === null) return;
    setBusy(true);
    setError(null);
    try {
      const result = await createReceipt(supabase, orderId, {
        amount,
        payment_method_code: method,
      });
      await refresh();
      onOpenChange(false);
      toast({ title: `Đã tạo phiếu thu nháp ${result.code}.` });
      void navigate(`/crm/phieu-thu/${result.id}`);
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
      title="Tạo phiếu thu"
      subtitle={`Đơn ${orderCode}`}
      confirmLabel="Tạo phiếu nháp"
      canSubmit={amount !== null && amount > 0 && method !== ''}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <MoneyInput
          label="Số tiền"
          required
          value={amount}
          onChange={setAmount}
          help="Gợi ý phần còn thu được của đơn. Đơn vị: đồng."
        />
        <Field label="Hình thức" required>
          {(f) => (
            <Select
              id={f.id}
              label="Hình thức"
              value={method}
              onChange={setMethod}
              options={methods}
              placeholder="Chọn hình thức"
              className="w-full"
            />
          )}
        </Field>
        <p className="text-caption text-fg-muted">
          Phiếu tạo ở trạng thái Nháp; người nhận tiền, cơ sở thu, mã giao dịch điền ở trang phiếu
          trước khi trình.
        </p>
      </div>
    </FormDialog>
  );
}
