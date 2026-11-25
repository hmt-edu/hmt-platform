// QT-15 Cấu hình người duyệt ticket theo nhóm con (khuôn K10, như ma trận quyền): mỗi loại phiếu nghiệp vụ có cấp duyệt hiện hành, phiên bản sắp hiệu lực và lịch sử.
// Admin thêm phiên bản mới có NGÀY HIỆU LỰC (R-CS-11); phiếu đã lập giữ cấp duyệt lúc lập. Không có khung canvas: dựng từ khuôn K10 và hộp K08.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Table } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Checkbox, TextField } from '../../ui/Field';
import { useToast } from '../../ui/toastContext';
import { TASK_TYPE_LABEL } from '../phieu/taskLabels';
import {
  LEVEL_LABEL,
  formError,
  levelsText,
  orderedLevels,
  saveApproverRule,
  useApproverConfig,
  useRefreshApproverConfig,
  type ApproverRule,
  type LevelCode,
} from './approverConfig';
import { PageFrame, PageHeader } from '../../ui/PageHeader';

export function ApproverConfigPage() {
  const access = useAccess();
  const query = useApproverConfig();
  const [editing, setEditing] = useState<ApproverRule | null>(null);
  const [history, setHistory] = useState<ApproverRule | null>(null);
  const canEdit = access.can('ADMIN', 'SUA');

  if (query.isPending) return <Spinner label="Đang tải cấu hình người duyệt…" />;
  if (query.isError)
    return (
      <Alert tone="danger">
        {errorOf(query.error).message} <Button onClick={() => void query.refetch()}>Thử lại</Button>
      </Alert>
    );
  const rules = query.data;
  return (
    <PageFrame>
      <PageHeader
        title="Người duyệt ticket"
        description="Ai duyệt phiếu nghiệp vụ của từng nhóm con ticket, theo thứ tự duyệt. Sửa có ngày hiệu lực; phiếu đã lập giữ cấp duyệt lúc lập."
      />
      {rules.length === 0 ? (
        <StateView kind="empty" title="Chưa có loại phiếu nào">
          Cấu hình do hệ thống khai báo.
        </StateView>
      ) : (
        <Table
          caption="Người duyệt theo loại phiếu"
          rows={rules}
          rowKey={(r) => r.task_type}
          rowLabel={(r) => TASK_TYPE_LABEL[r.task_type] ?? r.task_type}
          empty={null}
          columns={[
            {
              key: 'type',
              header: 'Loại phiếu',
              cell: (r) => <b>{TASK_TYPE_LABEL[r.task_type] ?? r.task_type}</b>,
            },
            {
              key: 'cats',
              header: 'Nhóm con áp dụng',
              cell: (r) =>
                r.categories.length === 0 ? '—' : r.categories.map((c) => c.name).join(', '),
            },
            {
              key: 'now',
              header: 'Người duyệt hiện hành',
              cell: (r) => levelsText(r.current_levels),
            },
            {
              key: 'next',
              header: 'Sắp hiệu lực',
              cell: (r) =>
                r.upcoming.length === 0
                  ? '—'
                  : r.upcoming
                      .map((u) => `${levelsText(u.levels)} từ ${formatDate(u.valid_from)}`)
                      .join('; '),
            },
            {
              key: 'actions',
              header: 'Thao tác',
              cell: (r) => (
                <div className="flex gap-1">
                  {canEdit && (
                    <Button variant="text" onClick={() => setEditing(r)}>
                      Sửa
                    </Button>
                  )}
                  <Button variant="text" onClick={() => setHistory(r)}>
                    Lịch sử
                  </Button>
                </div>
              ),
            },
          ]}
        />
      )}
      {editing && <EditDialog rule={editing} onClose={() => setEditing(null)} />}
      {history && (
        <FormDialog
          open
          onOpenChange={(open) => {
            if (!open) setHistory(null);
          }}
          title={`Lịch sử: ${TASK_TYPE_LABEL[history.task_type] ?? history.task_type}`}
          confirmLabel="Đóng"
          canSubmit
          onSubmit={() => setHistory(null)}
        >
          <ul className="flex flex-col gap-1 text-body">
            {history.history.map((h) => (
              <li key={h.valid_from}>
                Từ {formatDate(h.valid_from)}: {levelsText(h.levels)}
                {h.created_by_name ? ` · ${h.created_by_name}` : ''}
              </li>
            ))}
          </ul>
        </FormDialog>
      )}
    </PageFrame>
  );
}

function EditDialog({ rule, onClose }: { rule: ApproverRule; onClose: () => void }) {
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshApproverConfig();
  const today = vnDayBounds().dateKey;
  const [picked, setPicked] = useState<Set<LevelCode>>(new Set(rule.current_levels));
  const [validFrom, setValidFrom] = useState(today);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const levels = orderedLevels(picked);
  const invalid = formError(levels, validFrom, today);
  const toggle = (l: LevelCode) =>
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(l)) next.delete(l);
      else next.add(l);
      return next;
    });
  return (
    <FormDialog
      open
      onOpenChange={(open) => {
        if (!open && !busy) onClose();
      }}
      title="Sửa người duyệt"
      subtitle={TASK_TYPE_LABEL[rule.task_type] ?? rule.task_type}
      confirmLabel="Lưu phiên bản mới"
      canSubmit={invalid === null}
      busy={busy}
      error={error}
      onSubmit={() => {
        setBusy(true);
        setError(null);
        saveApproverRule(supabase, rule.task_type, levels, validFrom)
          .then(async () => {
            await refresh();
            toast({ title: 'Đã lưu phiên bản người duyệt mới.' });
            onClose();
          })
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <fieldset className="flex flex-col gap-1">
          <legend className="text-caption font-semibold text-fg-label">
            Cấp duyệt (theo thứ tự: Quản lý cơ sở trước, Kế toán sau)
          </legend>
          {(['QUAN_LY_CO_SO', 'KE_TOAN'] as const).map((l) => (
            <Checkbox
              key={l}
              label={LEVEL_LABEL[l]}
              checked={picked.has(l)}
              onChange={() => toggle(l)}
            />
          ))}
        </fieldset>
        <TextField
          label="Ngày hiệu lực"
          type="date"
          required
          value={validFrom}
          min={today}
          onChange={(e) => setValidFrom(e.target.value)}
          error={invalid && invalid.startsWith('Ngày') ? invalid : undefined}
          help="Từ hôm nay trở đi. Phiếu đã lập giữ cấp duyệt lúc lập."
        />
      </div>
    </FormDialog>
  );
}
