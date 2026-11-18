// CH-05 Khung chương trình, danh sách phiên bản (khuôn K10, canvas 1aab CH05_*; Admin tạo, Trưởng cơ sở và các vai trò khác chỉ xem, máy tính).
// Luật R-LOP-07 (18/11/2026): mã Môn-Khối-Cấpđộ-Năm, bản kế thêm -v2, -v3; Tạo bản mới sao chép TOÀN BỘ bài từ bản trước; trạng thái chỉ Đang dùng, Ngừng; không xoá khung.
// Máy chủ quyết quyền và mã (app.list_curriculum_frames, create_curriculum_frame, create_curriculum_version, set_curriculum_frame_active); trang chỉ hiện và gọi.
// Màn danh sách bài (CH-06) làm ở PR sau; thanh chuyển «Rubric nhận xét, Ngày nghỉ» đã có ở menu trái nên không lặp lại ở đây.
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { Spinner, StateView } from '../../ui/Feedback';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  LEVEL_OPTIONS,
  STATUS_NAME,
  frameCodePreview,
  nextVersion,
  yearLabel,
  yearOptions,
  type FrameFilters,
  type FrameRow,
} from './frameLogic';
import {
  FRAME_PAGE_SIZE,
  createFrame,
  createVersion,
  setFrameActive,
  useFrames,
  useRefreshFrames,
} from './useFrameData';

const STATUS_FILTER = [
  { value: 'DANG_DUNG', label: 'Đang dùng' },
  { value: 'NGUNG', label: 'Ngừng' },
];

export function CurriculumFramePage() {
  const access = useAccess();
  const toast = useToast();
  const supabase = useDb();
  const refresh = useRefreshFrames();
  const catalogs = useLeadCatalogs();
  const thisYear = new Date().getFullYear();
  const [filters, setFilters] = useState<FrameFilters>({});
  const [page, setPage] = useState(0);
  const [creating, setCreating] = useState(false);
  const [stopping, setStopping] = useState<FrameRow | null>(null);
  const [stopBusy, setStopBusy] = useState(false);
  const [stopError, setStopError] = useState<string | null>(null);
  const canView = access.can('CONFIG_TRAINING', 'XEM');
  const canCreate = access.can('CONFIG_TRAINING', 'TAO');
  const canStop = access.can('CONFIG_TRAINING', 'HUY');
  const frames = useFrames(filters, page, canView);

  const setFilter = (key: keyof FrameFilters, value: string) => {
    setPage(0);
    setFilters((cur) => {
      const next = { ...cur };
      if (value === '') delete next[key];
      else if (key === 'status') next.status = [value];
      else next[key] = value;
      return next;
    });
  };

  async function confirmStop() {
    if (!stopping) return;
    setStopBusy(true);
    setStopError(null);
    try {
      await setFrameActive(supabase, stopping.id, false);
      await refresh();
      toast({ title: `Đã ngừng khung ${stopping.code}.` });
      setStopping(null);
    } catch (e) {
      setStopError(errorOf(e).message);
    } finally {
      setStopBusy(false);
    }
  }

  const columns: LineColumn<FrameRow>[] = [
    { key: 'code', header: 'Mã khung', cell: (f) => <b className="tabular">{f.code}</b> },
    { key: 'subject', header: 'Môn', cell: (f) => f.subject_name },
    { key: 'grade', header: 'Khối', cell: (f) => f.grade_name },
    { key: 'level', header: 'Cấp độ', cell: (f) => f.level_name },
    { key: 'year', header: 'Năm học', cell: (f) => yearLabel(f.year_code) },
    {
      key: 'status',
      header: 'Trạng thái',
      cell: (f) => (
        <Tag tone={f.status_code === 'DANG_DUNG' ? 'success' : 'neutral'}>
          {STATUS_NAME[f.status_code]}
        </Tag>
      ),
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-28',
      cell: (f) =>
        canStop && f.status_code === 'DANG_DUNG' ? (
          <Button variant="text" onClick={() => setStopping(f)}>
            Ngừng
          </Button>
        ) : null,
    },
  ];

  if (!canView) {
    return (
      <div className="mx-auto max-w-[1280px] p-4 md:p-6">
        <StateView
          kind="forbidden"
          title="Bạn không có quyền xem màn này"
          actions={
            <Link className="text-link underline" to="/crm">
              Về Trang chủ
            </Link>
          }
        >
          Khung chương trình dành cho Admin và Trưởng cơ sở (chỉ xem). Liên hệ quản trị viên nếu bạn
          cần quyền.
        </StateView>
      </div>
    );
  }

  const total = frames.data?.total ?? 0;
  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-h1">Khung chương trình</h1>
        {canCreate && (
          <Button variant="primary" icon="plus" onClick={() => setCreating(true)}>
            Tạo bản mới
          </Button>
        )}
      </div>
      <div className="grid grid-cols-2 gap-2 md:grid-cols-5" role="group" aria-label="Bộ lọc">
        <OptionalSelect
          label="Môn"
          placeholder="Môn"
          value={filters.subject ?? ''}
          onChange={(v) => setFilter('subject', v)}
          options={catalogs.options('SUBJECT')}
        />
        <OptionalSelect
          label="Khối"
          placeholder="Khối"
          value={filters.grade ?? ''}
          onChange={(v) => setFilter('grade', v)}
          options={catalogs.options('GRADE')}
        />
        <OptionalSelect
          label="Cấp độ"
          placeholder="Cấp độ"
          value={filters.level ?? ''}
          onChange={(v) => setFilter('level', v)}
          options={LEVEL_OPTIONS}
        />
        <OptionalSelect
          label="Năm học"
          placeholder="Năm học"
          value={filters.year ?? ''}
          onChange={(v) => setFilter('year', v)}
          options={yearOptions(thisYear)}
        />
        <OptionalSelect
          label="Trạng thái"
          placeholder="Trạng thái"
          value={filters.status?.[0] ?? ''}
          onChange={(v) => setFilter('status', v)}
          options={STATUS_FILTER}
        />
      </div>
      <section
        aria-label="Danh sách khung chương trình"
        className="min-w-0 rounded-box border border-border bg-surface"
      >
        {frames.isError ? (
          <div className="p-4">
            <StateView
              kind="error"
              title="Không tải được khung chương trình"
              actions={<Button onClick={() => void frames.refetch()}>Thử lại</Button>}
            >
              {errorOf(frames.error).message}
            </StateView>
          </div>
        ) : frames.data ? (
          <LineTable
            caption="Khung chương trình"
            columns={columns}
            rows={frames.data.rows}
            rowKey={(f) => f.id}
            rowLabel={(f) => f.code}
            empty={
              <div className="p-4">
                <StateView kind="empty" title="Chưa có khung chương trình nào" headingLevel={2}>
                  Lớp chung cần khung chương trình. Tạo bản đầu tiên để bắt đầu.
                </StateView>
              </div>
            }
          />
        ) : (
          <div className="p-4">
            <Spinner label="Đang tải khung chương trình…" />
          </div>
        )}
      </section>
      {frames.data && total > 0 && (
        <div className="flex items-center gap-2">
          <Button disabled={page === 0} onClick={() => setPage(page - 1)}>
            Trang trước
          </Button>
          <span className="text-caption text-fg-muted">
            {page * FRAME_PAGE_SIZE + 1}–{Math.min((page + 1) * FRAME_PAGE_SIZE, total)} / {total}
          </span>
          <Button
            disabled={(page + 1) * FRAME_PAGE_SIZE >= total}
            onClick={() => setPage(page + 1)}
          >
            Trang sau
          </Button>
        </div>
      )}
      {creating && (
        <CreateDialog
          thisYear={thisYear}
          onClose={() => setCreating(false)}
          onCreated={async (code) => {
            setCreating(false);
            await refresh();
            toast({ title: `Đã tạo khung ${code}.` });
          }}
        />
      )}
      <ConfirmDialog
        open={stopping !== null}
        onOpenChange={(open) => {
          if (!open) {
            setStopping(null);
            setStopError(null);
          }
        }}
        title={`Ngừng khung ${stopping?.code ?? ''}?`}
        summary={
          stopping
            ? [{ label: 'Môn · Khối', value: `${stopping.subject_name} · ${stopping.grade_name}` }]
            : undefined
        }
        description="Ngừng thì khung không hiện ở chỗ chọn khi tạo lớp mới. Lớp đang dùng khung này giữ nguyên khung. Không xoá khung."
        confirmLabel="Ngừng khung"
        cancelLabel="Giữ lại"
        tone="danger"
        busy={stopBusy}
        error={stopError}
        onConfirm={() => void confirmStop()}
      />
    </div>
  );
}

/** Hộp thoại Tạo bản mới (CH05_tao_pc): chọn Môn, Khối, Cấp độ, Năm học; có bản cũ thì sao chép toàn bộ bài từ bản chọn, chưa có thì tạo bản đầu. */
function CreateDialog({
  thisYear,
  onClose,
  onCreated,
}: {
  thisYear: number;
  onClose: () => void;
  onCreated: (code: string) => Promise<void>;
}) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const [subject, setSubject] = useState('');
  const [grade, setGrade] = useState('');
  const [level, setLevel] = useState('');
  const [year, setYear] = useState('');
  const [fromId, setFromId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const complete = subject !== '' && grade !== '' && level !== '' && year !== '';
  // Các bản đã có của đúng bộ (môn, khối, cấp độ, năm): quyết định tạo bản đầu hay bản kế.
  const existing = useFrames({ subject, grade, level, year }, 0, complete);
  const versions = (existing.data?.rows ?? []).slice().sort((a, b) => b.version - a.version);
  const source = versions.find((v) => v.id === fromId) ?? versions[0];
  const version = nextVersion(versions);
  const ready = complete && existing.data !== undefined;
  const preview = complete ? frameCodePreview(subject, grade, level, year, version) : '';
  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title="Tạo bản mới của khung chương trình"
      confirmLabel="Tạo bản mới"
      canSubmit={ready}
      busy={busy}
      error={error}
      onSubmit={() => {
        setBusy(true);
        setError(null);
        const run = source
          ? createVersion(supabase, source.id)
          : createFrame(supabase, { subject, grade, level, year });
        void run
          .then((r) => onCreated(r.code))
          .catch((e: unknown) => setError(errorOf(e).message))
          .finally(() => setBusy(false));
      }}
    >
      <div className="flex flex-col gap-3">
        <Field label="Môn" required>
          {() => (
            <OptionalSelect
              label="Môn"
              placeholder="Chọn môn"
              value={subject}
              onChange={setSubject}
              options={catalogs.options('SUBJECT')}
              requiredEmpty={subject === ''}
            />
          )}
        </Field>
        <Field label="Khối" required>
          {() => (
            <OptionalSelect
              label="Khối"
              placeholder="Chọn khối"
              value={grade}
              onChange={setGrade}
              options={catalogs.options('GRADE')}
              requiredEmpty={grade === ''}
            />
          )}
        </Field>
        <Field label="Cấp độ" required>
          {() => (
            <OptionalSelect
              label="Cấp độ"
              placeholder="Chọn cấp độ"
              value={level}
              onChange={setLevel}
              options={LEVEL_OPTIONS}
              requiredEmpty={level === ''}
            />
          )}
        </Field>
        <Field label="Năm học" required>
          {() => (
            <OptionalSelect
              label="Năm học"
              placeholder="Chọn năm học"
              value={year}
              onChange={setYear}
              options={yearOptions(thisYear)}
              requiredEmpty={year === ''}
            />
          )}
        </Field>
        <Field
          label="Mã khung"
          help="Mã sắp cấp, chỉ xem. Bản đầu không có hậu tố; bản kế thêm -v2, -v3."
        >
          {() => <p className="tabular text-body font-semibold">{preview || '—'}</p>}
        </Field>
        {ready && source && (
          <Field label="Sao chép bài từ bản">
            {(field) => (
              <Select
                id={field.id}
                label="Sao chép bài từ bản"
                value={source.id}
                onChange={setFromId}
                options={versions.map((v) => ({
                  value: v.id,
                  label: `${v.code} (${v.lesson_count} bài)`,
                }))}
              />
            )}
          </Field>
        )}
        {ready && (
          <p className="text-caption text-fg-muted">
            {source
              ? `Sao chép ${source.lesson_count} bài từ bản ${source.code}. `
              : 'Bản đầu của khung này, chưa có bài. '}
            Sau khi tạo, anh chị sửa bài ở màn danh sách bài học. Lớp cũ giữ nguyên tên khung cũ.
          </p>
        )}
      </div>
    </FormDialog>
  );
}
