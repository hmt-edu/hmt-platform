// TC-02 «Thu nợ đầu kỳ» (canvas abea TC02_no_dau_ky_tao; khuôn K4 ③ FormDialog): CSKH chọn phụ huynh, chọn em (nợ tính từng em, ô Em bắt buộc), nhập số tiền và hình thức.
// Phiếu tạo ở trạng thái Nháp rồi mở trang phiếu để điền người nhận, cơ sở thu, mã giao dịch. KHÔNG cần đơn. Mọi số tiền (nợ còn lại của em, tổng nợ phụ huynh) do hàm DB tính;
// luật (số tiền không vượt nợ còn lại của em, cờ, quyền) do hàm tạo kiểm; hộp chỉ hiện lỗi của hàm.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { Combobox, MoneyInput, type ComboOption } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { useRefreshReceipts } from './useReceiptData';
import { useNavigateFrom } from '../../layout/crumbTrail';

type ParentHit = { id: string; code: string; full_name: string; phone?: string | null };
type DebtByStudent = {
  students: { id: string; code: string; name: string; remaining: number; credit: number }[];
  parent_remaining: number;
  parent_credit: number;
};

type Props = { open: boolean; onOpenChange: (open: boolean) => void };

/** Mỗi lần mở là một biểu mẫu mới. */
export function OpeningDebtDialog(props: Props) {
  return props.open ? <OpeningDebtForm {...props} /> : null;
}

function OpeningDebtForm({ open, onOpenChange }: Props) {
  const supabase = useDb();
  const openFrom = useNavigateFrom();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const refresh = useRefreshReceipts();
  const limit = useIntSetting('list_page_size_default');
  const [parentQuery, setParentQuery] = useState('');
  const q = useDebounced(parentQuery).trim();
  const [parentId, setParentId] = useState('');
  const [studentId, setStudentId] = useState('');
  const [amount, setAmount] = useState<number | null>(null);
  const [method, setMethod] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const parents = useQuery({
    queryKey: ['opening-debt-parents', q, limit],
    enabled: limit !== null,
    queryFn: () =>
      rpc<{ rows: ParentHit[] }>(supabase, 'list_parents', {
        p_filters: q === '' ? {} : { search: q },
        p_limit: limit,
        p_offset: 0,
      }),
  });
  const debts = useQuery({
    queryKey: ['opening-debt-by-student', parentId],
    enabled: parentId !== '',
    queryFn: () =>
      rpc<DebtByStudent>(supabase, 'opening_debt_by_student', { p_parent_id: parentId }),
  });

  const parentOptions: ComboOption[] = (parents.data?.rows ?? []).map((p) => ({
    value: p.id,
    label: p.full_name,
    hint: [p.code, p.phone].filter(Boolean).join(' · '),
    keywords: p.code,
  }));
  const students = debts.data?.students ?? [];
  const student = students.find((s) => s.id === studentId);

  async function submit() {
    if (amount === null) return;
    setBusy(true);
    setError(null);
    try {
      const result = await rpc<{ id: string; code: string }>(
        supabase,
        'create_opening_debt_receipt',
        {
          p_parent_id: parentId,
          p_data: { amount, payment_method_code: method, student_id: studentId },
        },
      );
      await refresh();
      onOpenChange(false);
      toast({ title: `Đã tạo phiếu thu nợ đầu kỳ ${result.code}.` });
      openFrom(`/crm/phieu-thu/${result.id}`);
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
      title="Thu nợ đầu kỳ"
      subtitle="Phiếu thu không cần đơn hàng; Kế toán duyệt, không qua quản lý."
      confirmLabel="Tạo phiếu nháp"
      canSubmit={
        parentId !== '' && studentId !== '' && amount !== null && amount > 0 && method !== ''
      }
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <Field label="Phụ huynh" required>
          {() => (
            <Combobox
              label="Phụ huynh"
              options={parentOptions}
              value={parentId ? [parentId] : []}
              onChange={(v) => {
                setParentId(v[0] ?? '');
                setStudentId('');
                setAmount(null);
              }}
              onSearch={setParentQuery}
              loading={parents.isFetching}
              placeholder="Tìm phụ huynh theo tên, số điện thoại, mã"
            />
          )}
        </Field>
        <Field
          label="Học sinh"
          required
          error={debts.isError ? errorOf(debts.error).message : null}
          help={
            debts.data
              ? `Tổng nợ đầu kỳ còn lại của phụ huynh: ${formatMoney(debts.data.parent_remaining)} (cộng nợ các học sinh).`
              : 'Chọn phụ huynh trước.'
          }
        >
          {(f) => (
            <Select
              id={f.id}
              label="Học sinh"
              value={studentId}
              onChange={(v) => {
                setStudentId(v);
                setAmount(null);
              }}
              options={students.map((s) => ({
                value: s.id,
                label: `${s.name} · nợ còn ${formatMoney(s.remaining)}${s.credit > 0 ? ` · thu thừa ${formatMoney(s.credit)}` : ''}`,
              }))}
              placeholder={debts.isPending && parentId !== '' ? 'Đang tải…' : 'Chọn học sinh'}
              disabled={parentId === '' || debts.isPending}
              className="w-full"
            />
          )}
        </Field>
        <MoneyInput
          label="Số tiền"
          required
          value={amount}
          onChange={setAmount}
          help={
            student
              ? `Không vượt nợ còn lại của học sinh: ${formatMoney(student.remaining)}. Đơn vị: đồng.`
              : 'Không vượt nợ còn lại của học sinh. Đơn vị: đồng.'
          }
        />
        <Field label="Hình thức" required>
          {(f) => (
            <Select
              id={f.id}
              label="Hình thức"
              value={method}
              onChange={setMethod}
              options={catalogs.options('PAYMENT_METHOD')}
              placeholder="Chọn hình thức"
              className="w-full"
            />
          )}
        </Field>
      </div>
    </FormDialog>
  );
}
