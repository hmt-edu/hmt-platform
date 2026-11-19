// TC-16 «Dùng số dư khách hàng cho đơn mới» (hộp K08): Kế toán (Kế toán · Duyệt) cấn số dư của phụ huynh vào đơn Đã duyệt; sinh một khoản tiền vào không phiếu thu
// (R-CS-03, R-TIEN-33). Không có khung canvas riêng: dựng từ khuôn hộp thoại K08 (FormDialog) như hộp Tạo phiếu thu. Số tiền ≤ số dư và ≤ phần còn thu của đơn;
// máy chủ (app.apply_customer_balance_to_order) kiểm lại, kèm công tắc customer_balance_apply_enabled và quyền.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { FormDialog } from '../../ui/Dialogs';
import { MoneyInput } from '../../ui/Inputs';
import { Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import type { BalanceHistory } from '../so-du/balanceTypes';
import { maxApplicable } from './useBalance';

export function UseBalanceDialog({
  open,
  onOpenChange,
  orderId,
  orderCode,
  parentId,
  remaining,
  onDone,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  orderId: string;
  orderCode: string;
  parentId: string;
  /** Phần còn thu của đơn (đồng). */
  remaining: number;
  onDone: () => void;
}) {
  const supabase = useDb();
  const toast = useToast();
  const client = useQueryClient();
  const [amount, setAmount] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const history = useQuery({
    queryKey: ['balance-history', parentId],
    enabled: open,
    queryFn: () =>
      rpc<BalanceHistory>(supabase, 'get_customer_balance_history', { p_parent_id: parentId }),
  });
  const balance = history.data?.balance ?? 0;
  const max = maxApplicable(balance, remaining);
  const value = amount ?? max;
  const invalid =
    value <= 0 ? 'Nhập số tiền lớn hơn 0.' : value > max ? `Tối đa ${formatMoney(max)}.` : null;

  const submit = () => {
    setBusy(true);
    setError(null);
    rpc(supabase, 'apply_customer_balance_to_order', { p_order_id: orderId, p_amount: value })
      .then(async () => {
        await client.invalidateQueries({ queryKey: ['balance-history', parentId] });
        onOpenChange(false);
        setAmount(null);
        onDone();
        toast({ title: `Đã dùng ${formatMoney(value)} số dư cho đơn ${orderCode}.` });
      })
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  return (
    <FormDialog
      open={open}
      onOpenChange={(next) => {
        if (!busy) {
          if (!next) {
            setError(null);
            setAmount(null);
          }
          onOpenChange(next);
        }
      }}
      title="Dùng số dư cho đơn"
      subtitle={`Đơn ${orderCode}`}
      confirmLabel="Xác nhận dùng số dư"
      canSubmit={history.data !== undefined && invalid === null}
      busy={busy}
      error={error}
      onSubmit={submit}
    >
      {history.isPending ? (
        <Spinner label="Đang tải số dư…" />
      ) : history.isError ? (
        <p role="alert" className="text-danger">
          {errorOf(history.error).message}
        </p>
      ) : (
        <div className="flex flex-col gap-3">
          <dl className="grid grid-cols-2 gap-2 text-body">
            <dt className="text-fg-muted">Số dư hiện có</dt>
            <dd className="tabular text-right font-semibold">{formatMoney(balance)}</dd>
            <dt className="text-fg-muted">Còn thu của đơn</dt>
            <dd className="tabular text-right font-semibold">{formatMoney(remaining)}</dd>
          </dl>
          <MoneyInput
            label="Số tiền dùng"
            required
            value={value}
            onChange={setAmount}
            error={invalid}
            help="Trừ số dư của phụ huynh và ghi vào đơn như một khoản tiền vào (không có phiếu thu). Đơn vị: đồng."
          />
        </div>
      )}
    </FormDialog>
  );
}
