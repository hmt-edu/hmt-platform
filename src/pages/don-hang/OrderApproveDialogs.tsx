// BH-07 Duyệt / Từ chối đơn hàng (hộp thoại K08, canvas BH07_duyet, BH07_dt, BH07_dt_tu_choi). Người duyệt đã chốt lúc trình (hoặc Admin duyệt thay)
// xem tóm tắt, từng dòng (hồ sơ học sinh "dùng HS… / sẽ tạo hồ sơ mới"), cảnh báo vượt trần, rồi Duyệt hoặc Từ chối. Giao diện KHÔNG tính tiền, không
// tự đoán quyền: nút hiện theo get_order.can_approve, can_reject; luật, công tắc Bán hàng máy chủ kiểm lại.
// R-V2-11 (anh chốt 06/11, A4): vượt trần chiết khấu chỉ CẢNH BÁO, không có ô tích đồng ý; nhật ký ghi người duyệt và tổng % lúc duyệt.
import { useState } from 'react';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatMoney } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { ReasonDialog } from '../../ui/Dialogs';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { capPercentText, overCapLines } from './orderApprove';
import type { OrderRecord } from './orderTypes';
import { approveOrder, rejectOrder } from './useOrderData';

type Props = {
  record: OrderRecord;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Gọi sau khi duyệt hoặc từ chối xong (tải lại đơn, báo toast). */
  onDone: (message: string) => void;
  /** Mở hộp Từ chối từ hộp Duyệt (nút Từ chối trong hộp). */
  onReject?: () => void;
};

export function ApproveOrderDialog({ record, open, onOpenChange, onDone, onReject }: Props) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const cap = useIntSetting('discount_total_cap_percent');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const over = overCapLines(record.lines);
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;

  async function approve() {
    setBusy(true);
    setError(null);
    try {
      await approveOrder(supabase, record.id);
      onOpenChange(false);
      onDone('Đã duyệt đơn hàng.');
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => !busy && onOpenChange(next)}
      title="Duyệt đơn hàng"
      wide
      dismissible={!busy}
      footer={
        <>
          {onReject && (
            <Button onClick={onReject} disabled={busy}>
              Từ chối
            </Button>
          )}
          <Button onClick={() => onOpenChange(false)} disabled={busy}>
            Đóng
          </Button>
          <Button variant="primary" loading={busy} onClick={() => void approve()}>
            Duyệt
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {error && (
          <Alert tone="danger" title="Chưa duyệt được.">
            {error}
          </Alert>
        )}
        <dl className="grid grid-cols-2 gap-x-6 gap-y-1 text-body">
          <dt className="text-fg-muted">Mã đơn</dt>
          <dd className="font-medium">{record.code}</dd>
          <dt className="text-fg-muted">Người lập</dt>
          <dd>{record.created_by_name ?? '—'}</dd>
          <dt className="text-fg-muted">Phụ huynh</dt>
          <dd>{`${record.parent_name} (${record.parent_code})`}</dd>
          <dt className="text-fg-muted">Tổng thành tiền</dt>
          <dd className="tabular font-semibold">{formatMoney(record.total_amount)}</dd>
        </dl>
        {over.length > 0 && (
          <Alert tone="warning" title={`Chiết khấu vượt trần ${capPercentText(cap)}.`}>
            {over.map((l) => (
              <span key={l.line_no} className="block">
                {`Dòng ${l.line_no}${l.student_name ? ` (${l.student_name})` : ''}: cộng dồn ${l.total_percent_text}% so với trần ${capPercentText(cap)}.`}
              </span>
            ))}
            <span className="block">
              Chỉ cảnh báo, không chặn: xem xét rồi Duyệt hoặc Từ chối. Nhật ký ghi lại người duyệt
              và tổng % lúc duyệt.
            </span>
          </Alert>
        )}
        <ul
          aria-label="Dòng đơn"
          className="flex flex-col divide-y divide-border rounded-control border border-border"
        >
          {record.lines.map((l) => (
            <li key={l.id} className="flex flex-wrap items-start justify-between gap-2 px-3 py-2">
              <span className="flex min-w-0 flex-col">
                <span className="font-medium">
                  {l.student_name ?? 'Chưa có học sinh'}
                  {l.over_cap && (
                    <b className="ml-2 text-caption text-on-warning-subtle">Vượt trần</b>
                  )}
                </span>
                <span className="text-caption text-fg-muted">
                  {l.student_name
                    ? l.student_code
                      ? `dùng ${l.student_code}`
                      : 'sẽ tạo hồ sơ mới'
                    : ''}
                </span>
                <span className="text-caption text-fg-muted">
                  {`${l.package_code} · ${l.line_kind === 'GIFT' ? 'Quà tặng' : modeName(l.delivery_mode_code)}`}
                </span>
              </span>
              <span className="tabular text-right">
                <span className="block">{formatMoney(l.line_total)}</span>
                <span className="block text-caption text-fg-muted">
                  {`Giờ ${l.quantity} + ${l.gifted_quantity} · giảm ${l.discount_percent + l.gift_percent}%`}
                </span>
              </span>
            </li>
          ))}
        </ul>
        <p className="text-caption text-fg-muted">
          Duyệt thì đơn tự khoá: không sửa dòng, giá, lớp, ngày vào nữa.
        </p>
      </div>
    </Dialog>
  );
}

/** Từ chối đơn: lý do từ danh mục "Lý do từ chối" áp dụng cho đơn; "Khác" bắt buộc ghi chú. Đơn về Nháp, người lập sửa rồi trình lại. */
export function RejectOrderDialog({ record, open, onOpenChange, onDone }: Props) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <ReasonDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Từ chối đơn hàng"
      description={`${record.code} · ${record.parent_name} · ${formatMoney(record.total_amount)}. Đơn về Nháp, người lập sửa rồi trình lại. Lịch sử giữ lần từ chối và lý do.`}
      options={catalogs.optionsFor('REJECT_REASON', 'DON').map((o) => ({
        value: o.value,
        label: o.label,
        needsNote: catalogs.requiresNote('REJECT_REASON', o.value),
      }))}
      reasonLabel="Lý do"
      noteLabel="Ghi chú"
      notePlaceholder="Bắt buộc khi chọn “Khác”"
      confirmLabel="Xác nhận từ chối"
      confirmIcon="close"
      cancelLabel="Giữ lại"
      busy={busy}
      error={error}
      onConfirm={(r) => {
        setBusy(true);
        setError(null);
        rejectOrder(supabase, record.id, r.option, r.note.trim() === '' ? null : r.note.trim())
          .then(() => {
            onOpenChange(false);
            onDone('Đã từ chối đơn, đơn về Nháp.');
          })
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    />
  );
}
