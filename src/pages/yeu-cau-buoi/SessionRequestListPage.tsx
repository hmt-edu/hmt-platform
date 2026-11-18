// BUOI-10 Yêu cầu buổi (danh sách và duyệt, khuôn K03 giản lược): mỗi dòng một yêu cầu; Trưởng cơ sở (Admin duyệt thay) Duyệt hoặc Từ chối ở dòng Chờ duyệt;
// người tạo Huỷ yêu cầu Nháp hoặc Chờ duyệt. Máy chủ quyết quyền và trạng thái (app.list_session_requests, can_approve); phân trang ở máy chủ (50 dòng).
// Loại Củng cố (BUOI-08) và Bổ trợ (BUOI-09; tạo từ bản ghi lớp). Chưa có khung chỉ riêng cho bản lọc giản lược này: dựng theo K03, ghi vào PR. Điện thoại: thẻ từng yêu cầu (R-HT-05).
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button, ButtonLink } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { NARROW_TABLE, useMedia } from '../../ui/useMedia';
import { formatDate } from '../../lib/format';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  kindName,
  statusName,
  statusTone,
  targetText,
  whenText,
  type RequestRow,
} from './requestLogic';
import {
  useApproveRequest,
  useCancelRequest,
  useRejectRequest,
  useRequestPage,
} from './useRequestData';

const PAGE_SIZE = 50; // allow-number: mặc định phân trang danh sách (quy ước hiệu năng, tối đa 100)
const FILTERS: { key: string; label: string; status: string[] | null }[] = [
  { key: 'cho', label: 'Chờ duyệt', status: ['CHO_DUYET'] },
  { key: 'tat-ca', label: 'Tất cả', status: null },
];

export function SessionRequestListPage() {
  const access = useAccess();
  const narrow = useMedia(NARROW_TABLE);
  const toast = useToast();
  const [filter, setFilter] = useState('cho');
  const [page, setPage] = useState(0);
  const status = FILTERS.find((f) => f.key === filter)?.status ?? null;
  const query = useRequestPage(status, page * PAGE_SIZE, PAGE_SIZE);
  const approve = useApproveRequest();
  const cancel = useCancelRequest();
  const [rejecting, setRejecting] = useState<RequestRow | null>(null);
  const [cancelling, setCancelling] = useState<RequestRow | null>(null);
  const [error, setError] = useState<string | null>(null);
  const canCreate = access.can('SESSION', 'TAO');

  async function doApprove(r: RequestRow) {
    setError(null);
    try {
      const res = await approve.mutateAsync(r.id);
      toast({
        tone: res.warnings.length > 0 ? 'warning' : 'success',
        title:
          res.warnings.length > 0
            ? `Đã duyệt ${r.code}, kèm cảnh báo: ${res.warnings.join(' ')}`
            : `Đã duyệt ${r.code}`,
      });
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  async function doCancel() {
    if (!cancelling) return;
    setError(null);
    try {
      await cancel.mutateAsync(cancelling.id);
      toast({ tone: 'success', title: `Đã huỷ ${cancelling.code}` });
      setCancelling(null);
    } catch (e) {
      setCancelling(null);
      setError(errorOf(e).message);
    }
  }

  const actions = (r: RequestRow) => (
    <span className="flex flex-wrap gap-2">
      {r.can_approve && (
        <>
          <Button
            size="sm"
            variant="primary"
            disabled={approve.isPending}
            onClick={() => void doApprove(r)}
          >
            Duyệt
          </Button>
          <Button size="sm" onClick={() => setRejecting(r)}>
            Từ chối
          </Button>
        </>
      )}
      {canCreate && (r.status_code === 'NHAP' || r.status_code === 'CHO_DUYET') && (
        <Button size="sm" variant="text" onClick={() => setCancelling(r)}>
          Huỷ
        </Button>
      )}
      {r.status_code === 'CHO_DUYET' && !r.can_approve && (
        <span className="text-caption text-fg-muted">chỉ Trưởng cơ sở duyệt</span>
      )}
      {r.status_code === 'DA_DUYET' && r.created_session_id && (
        <Link className="text-link underline" to={`/crm/buoi-hoc/${r.created_session_id}`}>
          Mở buổi
        </Link>
      )}
    </span>
  );

  return (
    <div className="mx-auto flex max-w-6xl flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-h2">Yêu cầu buổi</h1>
        {canCreate && (
          <ButtonLink to="/crm/yeu-cau-buoi/tao-cung-co" variant="primary">
            Tạo yêu cầu buổi củng cố
          </ButtonLink>
        )}
      </div>
      <div role="group" aria-label="Tình trạng" className="flex gap-2">
        {FILTERS.map((f) => (
          <Button
            key={f.key}
            variant={filter === f.key ? 'primary' : 'secondary'}
            aria-pressed={filter === f.key}
            onClick={() => {
              setFilter(f.key);
              setPage(0);
            }}
          >
            {f.label}
          </Button>
        ))}
      </div>
      {error !== null && <Alert tone="danger">{error}</Alert>}
      {query.isPending ? (
        <Spinner />
      ) : query.isError ? (
        <Alert tone="danger">{errorOf(query.error).message}</Alert>
      ) : query.data.rows.length === 0 ? (
        <StateView
          kind="empty"
          title={filter === 'cho' ? 'Không có yêu cầu buổi nào chờ duyệt' : 'Chưa có yêu cầu buổi'}
          headingLevel={2}
        >
          Yêu cầu học bù, củng cố, bổ trợ do CSKH gửi sẽ hiện ở đây.
        </StateView>
      ) : narrow ? (
        <ul className="flex flex-col gap-2">
          {query.data.rows.map((r) => (
            <li key={r.id} className="rounded-control border border-border bg-surface p-3">
              <p className="font-semibold">{r.code}</p>
              <p className="text-body">
                {kindName(r.kind)} · {targetText(r)}
              </p>
              <p className="text-caption text-fg-muted">
                {r.class_code} · {whenText(r)} · đề nghị {formatDate(r.created_at)}
              </p>
              <p className="py-1">
                <Tag tone={statusTone(r.status_code)}>{statusName(r.status_code)}</Tag>
              </p>
              {actions(r)}
            </li>
          ))}
        </ul>
      ) : (
        <div className="overflow-x-auto rounded-control border border-border">
          <table aria-label="Yêu cầu buổi" className="w-full text-body">
            <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
              <tr>
                <th className="px-3 py-2">Mã</th>
                <th className="px-3 py-2">Loại</th>
                <th className="px-3 py-2">Học sinh</th>
                <th className="px-3 py-2">Lớp</th>
                <th className="px-3 py-2">Ngày giờ</th>
                <th className="px-3 py-2">Ngày đề nghị</th>
                <th className="px-3 py-2">Người tạo</th>
                <th className="px-3 py-2">Tình trạng</th>
                <th className="px-3 py-2">Xử lý</th>
              </tr>
            </thead>
            <tbody>
              {query.data.rows.map((r) => (
                <tr key={r.id} className="border-t border-border">
                  <td className="px-3 py-2">{r.code}</td>
                  <td className="px-3 py-2">{kindName(r.kind)}</td>
                  <td className="px-3 py-2">{targetText(r)}</td>
                  <td className="px-3 py-2">{r.class_code}</td>
                  <td className="px-3 py-2">{whenText(r)}</td>
                  <td className="px-3 py-2">{formatDate(r.created_at)}</td>
                  <td className="px-3 py-2">{r.created_by_name ?? '—'}</td>
                  <td className="px-3 py-2">
                    <Tag tone={statusTone(r.status_code)}>{statusName(r.status_code)}</Tag>
                    {r.status_code === 'TU_CHOI' && r.reject_note && (
                      <span className="block text-caption text-fg-muted">{r.reject_note}</span>
                    )}
                  </td>
                  <td className="px-3 py-2">{actions(r)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {query.data && query.data.total > PAGE_SIZE && (
        <div className="flex items-center gap-2">
          <Button disabled={page === 0} onClick={() => setPage(page - 1)}>
            Trang trước
          </Button>
          <span className="text-caption text-fg-muted">
            {page * PAGE_SIZE + 1}–{Math.min((page + 1) * PAGE_SIZE, query.data.total)} /{' '}
            {query.data.total}
          </span>
          <Button
            disabled={(page + 1) * PAGE_SIZE >= query.data.total}
            onClick={() => setPage(page + 1)}
          >
            Trang sau
          </Button>
        </div>
      )}
      <RejectDialog row={rejecting} onClose={() => setRejecting(null)} />
      <ConfirmDialog
        open={cancelling !== null}
        onOpenChange={(o) => !o && setCancelling(null)}
        title="Huỷ yêu cầu buổi?"
        description={
          cancelling ? `Huỷ ${cancelling.code}? Yêu cầu sẽ không còn xử lý được nữa.` : undefined
        }
        confirmLabel="Xác nhận huỷ"
        cancelLabel="Giữ lại"
        busy={cancel.isPending}
        onConfirm={() => void doCancel()}
      />
    </div>
  );
}

function RejectDialog({ row, onClose }: { row: RequestRow | null; onClose: () => void }) {
  // Khoá theo yêu cầu đang từ chối để dựng lại trạng thái nhập, không dùng effect.
  return row ? <RejectBody key={row.id} row={row} onClose={onClose} /> : null;
}

function RejectBody({ row, onClose }: { row: RequestRow; onClose: () => void }) {
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const reject = useRejectRequest();
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const needsNote = reason !== '' && catalogs.requiresNote('REJECT_REASON', reason);
  async function submit() {
    setError(null);
    try {
      await reject.mutateAsync({
        id: row.id,
        reason,
        note: note.trim() === '' ? null : note.trim(),
      });
      toast({ tone: 'success', title: `Đã từ chối ${row.code}` });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }
  return (
    <FormDialog
      open
      onOpenChange={(o) => !o && onClose()}
      title="Từ chối yêu cầu buổi"
      subtitle={row.code}
      confirmLabel="Từ chối"
      cancelLabel="Đóng"
      canSubmit={reason !== '' && (!needsNote || note.trim() !== '')}
      busy={reject.isPending}
      error={error}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <OptionalSelect
          label="Lý do"
          value={reason}
          onChange={setReason}
          options={catalogs.optionsFor('REJECT_REASON', 'YEU_CAU_BUOI')}
          placeholder="Chọn lý do"
        />
        <TextAreaField
          label="Ghi chú"
          required={needsNote}
          value={note}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
