// QT-14 Ngày nghỉ lễ (bản đồ màn hình: Cấu hình · K10, Admin và Trưởng cơ sở, máy tính). Bảng ngày nghỉ theo năm: Thêm, Sửa, Ngừng/Dùng lại, Xem buổi bị ảnh hưởng.
// Không có khung canvas riêng cho QT-14 (BAN-DO-VIEC: «Thiếu khung canvas»): dựng từ khuôn K10 và các thành phần dùng chung, chữ từ bản đồ màn hình.
// Luật R-LOP-12: ngày nghỉ chung hoặc theo cơ sở; thêm sau khi đã sinh buổi thì XEM các buổi bị ảnh hưởng. Việc DỜ buổi làm ở màn buổi (không làm ở đây).
// Quyền: module HOLIDAY; ngày nghỉ chung chỉ Admin (DB kiểm, giao diện hiện lỗi của DB).
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { fromIso, scopeLabel, SESSION_STATUS_LABEL, toIso, type Holiday } from './holidayLogic';
import {
  saveHoliday,
  setHolidayActive,
  useHolidays,
  useHolidaySessions,
  useRefreshHolidays,
} from './useHolidayData';
import { PageFrame, PageHeader } from '../../ui/PageHeader';

type Editing = { holiday: Holiday | null };

export function HolidayPage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshHolidays();
  const thisYear = new Date().getFullYear();
  const [year, setYear] = useState(thisYear);
  const holidays = useHolidays(year);
  const [editing, setEditing] = useState<Editing | null>(null);
  const [viewing, setViewing] = useState<Holiday | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const canCreate = access.can('HOLIDAY', 'TAO');
  const canEdit = access.can('HOLIDAY', 'SUA');
  const branches = access.teachingBranches;
  const branchCode = (id: string) => branches.find((b) => b.id === id)?.code ?? id;

  const toggle = async (h: Holiday) => {
    setBusyId(h.id);
    try {
      await setHolidayActive(supabase, h.id, !h.is_active);
      await refresh();
      toast({ title: h.is_active ? 'Đã ngừng ngày nghỉ.' : 'Đã dùng lại ngày nghỉ.' });
    } catch (e) {
      toast({ title: errorOf(e).message, tone: 'danger' });
    } finally {
      setBusyId(null);
    }
  };

  const columns: LineColumn<Holiday>[] = [
    {
      key: 'date',
      header: 'Ngày',
      width: 'w-32',
      cell: (h) => <b>{formatDate(h.holiday_date)}</b>,
    },
    { key: 'name', header: 'Tên ngày nghỉ', cell: (h) => h.name },
    {
      key: 'scope',
      header: 'Áp dụng cho',
      width: 'w-36',
      cell: (h) => scopeLabel(h, branchCode),
    },
    {
      key: 'status',
      header: 'Tình trạng',
      width: 'w-32',
      cell: (h) => (
        <Tag tone={h.is_active ? 'success' : 'neutral'}>{h.is_active ? 'Đang dùng' : 'Ngừng'}</Tag>
      ),
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-72',
      cell: (h) => (
        <div className="flex flex-wrap gap-1">
          <Button variant="text" onClick={() => setViewing(h)}>
            Xem buổi bị ảnh hưởng
          </Button>
          {canEdit && (
            <>
              <Button variant="text" onClick={() => setEditing({ holiday: h })}>
                Sửa
              </Button>
              <Button variant="text" loading={busyId === h.id} onClick={() => void toggle(h)}>
                {h.is_active ? 'Ngừng' : 'Dùng lại'}
              </Button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <PageFrame>
      <PageHeader
        title="Ngày nghỉ lễ"
        description="Ngày nghỉ dùng để tính ngày kết thúc lớp. Thêm ngày nghỉ sau khi đã sinh buổi thì xem các buổi bị ảnh hưởng, rồi dời ở màn Buổi học."
        actions={
          <>
            <Select
              label="Năm"
              value={String(year)}
              onChange={(v) => setYear(Number(v))}
              options={[thisYear - 1, thisYear, thisYear + 1, thisYear + 2].map((y) => ({
                value: String(y),
                label: `Năm ${y}`,
              }))}
            />
            {canCreate && (
              <Button variant="primary" icon="plus" onClick={() => setEditing({ holiday: null })}>
                Thêm ngày nghỉ
              </Button>
            )}
          </>
        }
      />
      <section
        aria-label="Danh sách ngày nghỉ"
        className="min-w-0 rounded-box border border-border bg-surface"
      >
        {holidays.isError ? (
          <div className="p-4">
            <StateView
              kind="error"
              title="Không tải được ngày nghỉ"
              actions={<Button onClick={() => void holidays.refetch()}>Thử lại</Button>}
            >
              {errorOf(holidays.error).message}
            </StateView>
          </div>
        ) : holidays.data ? (
          <LineTable
            wrap
            caption={`Ngày nghỉ năm ${year}`}
            columns={columns}
            rows={holidays.data}
            rowKey={(h) => h.id}
            rowLabel={(h) => h.name}
            empty={<p className="p-4 text-body text-fg-muted">Năm {year} chưa có ngày nghỉ nào.</p>}
          />
        ) : (
          <div className="p-4">
            <Spinner label="Đang tải ngày nghỉ…" />
          </div>
        )}
      </section>
      {editing && (
        <HolidayForm
          key={editing.holiday?.id ?? 'new'}
          holiday={editing.holiday}
          branches={branches}
          onClose={() => setEditing(null)}
          onSaved={async (message) => {
            setEditing(null);
            await refresh();
            toast({ title: message });
          }}
        />
      )}
      {viewing && <SessionsDialog holiday={viewing} onClose={() => setViewing(null)} />}
    </PageFrame>
  );
}

function HolidayForm({
  holiday,
  branches,
  onClose,
  onSaved,
}: {
  holiday: Holiday | null;
  branches: { id: string; code: string; name: string }[];
  onClose: () => void;
  onSaved: (message: string) => Promise<void>;
}) {
  const supabase = useDb();
  const [date, setDate] = useState<Date | null>(holiday ? fromIso(holiday.holiday_date) : null);
  const [name, setName] = useState(holiday?.name ?? '');
  const [branchId, setBranchId] = useState(holiday?.branch_id ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title={holiday ? 'Sửa ngày nghỉ' : 'Thêm ngày nghỉ'}
      confirmLabel={holiday ? 'Lưu' : 'Thêm'}
      canSubmit={date !== null && name.trim() !== ''}
      busy={busy}
      error={error}
      onSubmit={() => {
        if (!date) return;
        setBusy(true);
        setError(null);
        void saveHoliday(supabase, {
          id: holiday?.id ?? null,
          date: toIso(date),
          name,
          branchId: branchId === '' ? null : branchId,
        })
          .then((r) =>
            onSaved(
              r.affected_sessions > 0
                ? `Đã lưu. Có ${r.affected_sessions} buổi chưa diễn ra trùng ngày này: bấm «Xem buổi bị ảnh hưởng».`
                : 'Đã lưu ngày nghỉ.',
            ),
          )
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <DateInput label="Ngày nghỉ" required value={date} onChange={setDate} />
        <TextField
          label="Tên ngày nghỉ"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <Field
          label="Áp dụng cho"
          help={holiday ? 'Không đổi được; ngừng ngày này rồi thêm ngày mới.' : undefined}
        >
          {(field) => (
            <Select
              id={field.id}
              label="Áp dụng cho"
              value={branchId}
              disabled={holiday !== null}
              onChange={setBranchId}
              options={[
                { value: '', label: 'Mọi cơ sở' },
                ...branches.map((b) => ({ value: b.id, label: `${b.code} · ${b.name}` })),
              ]}
            />
          )}
        </Field>
      </div>
    </FormDialog>
  );
}

function SessionsDialog({ holiday, onClose }: { holiday: Holiday; onClose: () => void }) {
  const sessions = useHolidaySessions(holiday.id);
  return (
    <Dialog
      open
      onOpenChange={(open) => !open && onClose()}
      title="Buổi bị ảnh hưởng"
      description={`${formatDate(holiday.holiday_date)} · ${holiday.name}`}
      wide
      footer={<Button onClick={onClose}>Đóng</Button>}
    >
      {sessions.isError ? (
        <StateView
          kind="error"
          title="Không tải được danh sách buổi"
          actions={<Button onClick={() => void sessions.refetch()}>Thử lại</Button>}
        >
          {errorOf(sessions.error).message}
        </StateView>
      ) : !sessions.data ? (
        <Spinner label="Đang tải buổi…" />
      ) : sessions.data.total === 0 ? (
        <p className="text-body">Không có buổi nào chưa diễn ra trùng ngày này.</p>
      ) : (
        <>
          <p className="mb-2 text-body">
            <b>{sessions.data.total}</b> buổi chưa diễn ra trùng ngày nghỉ. Dời buổi ở màn Buổi học.
          </p>
          <LineTable
            wrap
            caption="Buổi bị ảnh hưởng"
            columns={[
              { key: 'class', header: 'Lớp', cell: (s) => s.class_code },
              { key: 'branch', header: 'Cơ sở', width: 'w-24', cell: (s) => s.branch_code },
              {
                key: 'time',
                header: 'Giờ',
                width: 'w-36',
                cell: (s) => `${s.start_time.slice(0, 5)}–${s.end_time.slice(0, 5)}`,
              },
              {
                key: 'status',
                header: 'Tình trạng',
                width: 'w-28',
                cell: (s) => SESSION_STATUS_LABEL[s.status_code] ?? s.status_code,
              },
            ]}
            rows={sessions.data.rows}
            rowKey={(s) => s.id}
          />
        </>
      )}
    </Dialog>
  );
}
