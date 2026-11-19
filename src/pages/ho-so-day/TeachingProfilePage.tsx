// QT-16 Hồ sơ giáo viên, trợ giảng (khuôn K03 danh sách + hộp thoại K08 Tạo, Sửa; không có khung canvas, theo khuôn chung). Admin tạo, sửa môn, khối, cơ sở thường dạy, ghi chú,
// Ngừng hoặc Dùng lại (không xoá). Trưởng cơ sở, CSKH chỉ xem. Hồ sơ chỉ tham khảo khi xếp lịch (R-LOP-08, R-LOP-10), không chặn chọn giáo viên khi tạo lớp.
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListConfig, ListState } from '../../list/types';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { FormDialog } from '../../ui/Dialogs';
import { Checkbox, Field, TextAreaField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { useClassCatalogs } from '../lop/useClassData';
import {
  EMPTY_TEACHING_STATE,
  KIND_LABEL,
  buildTeachingFilters,
  noteError,
  profilePayload,
  toggleCode,
  type TeachingProfile,
} from './teachingLogic';
import {
  saveTeachingProfile,
  setTeachingActive,
  useRefreshTeaching,
  useTeachingCandidates,
  useTeachingPage,
} from './useTeachingData';

type Option = { value: string; label: string };

function buildConfig(opts: {
  subjects: Option[];
  grades: Option[];
  branches: Option[];
  canEdit: boolean;
  busyId: string | null;
  onEdit: (row: TeachingProfile) => void;
  onToggle: (row: TeachingProfile) => void;
}): ListConfig<TeachingProfile> {
  return {
    screenCode: 'QT-16',
    title: 'Giáo viên, trợ giảng',
    searchPlaceholder: 'Tìm tên hoặc mã nhân sự…',
    columns: [
      {
        key: 'name',
        label: 'Họ tên',
        locked: true,
        primary: true,
        render: (r) => (
          <span className={r.is_active ? 'font-medium' : 'text-fg-label'}>{r.name}</span>
        ),
      },
      { key: 'code', label: 'Mã GV/TG', render: (r) => r.staff_code ?? '—' },
      { key: 'kind', label: 'Loại', render: (r) => KIND_LABEL[r.kind] },
      { key: 'subjects', label: 'Môn dạy', render: (r) => r.subject_names.join(', ') || '—' },
      { key: 'grades', label: 'Khối dạy', render: (r) => r.grade_names.join(', ') || '—' },
      {
        key: 'branches',
        label: 'Cơ sở thường dạy',
        render: (r) => r.branch_codes.join(', ') || '—',
      },
      { key: 'note', label: 'Ghi chú', defaultVisible: false, render: (r) => r.note ?? '' },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) =>
          r.is_active ? <Tag tone="success">Đang dạy</Tag> : <Tag tone="neutral">Ngừng</Tag>,
      },
      ...(opts.canEdit
        ? [
            {
              key: 'actions',
              label: '',
              render: (r: TeachingProfile) => (
                <span className="flex flex-nowrap justify-end gap-1.5 whitespace-nowrap">
                  <Button size="sm" onClick={() => opts.onEdit(r)}>
                    Sửa
                  </Button>
                  <Button size="sm" loading={opts.busyId === r.id} onClick={() => opts.onToggle(r)}>
                    {r.is_active ? 'Ngừng' : 'Dùng lại'}
                  </Button>
                </span>
              ),
            },
          ]
        : []),
    ],
    quickGroups: [
      {
        key: 'kind',
        label: 'Loại',
        options: [
          { value: 'GV', label: KIND_LABEL.GV },
          { value: 'TG', label: KIND_LABEL.TG },
        ],
      },
      {
        key: 'active',
        label: 'Tình trạng',
        options: [
          { value: 'DANG_DAY', label: 'Đang dạy' },
          { value: 'NGUNG', label: 'Ngừng' },
        ],
      },
    ],
    filterFields: [
      { key: 'subject', label: 'Môn dạy', type: 'select', ops: ['eq'], options: opts.subjects },
      { key: 'grade', label: 'Khối dạy', type: 'select', ops: ['eq'], options: opts.grades },
      {
        key: 'branch',
        label: 'Cơ sở thường dạy',
        type: 'select',
        ops: ['eq'],
        options: opts.branches,
      },
    ],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}

export function TeachingProfilePage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshTeaching();
  const catalogs = useClassCatalogs();
  const pageSize = useIntSetting('list_page_size_default');
  const canEdit = access.can('ADMIN', 'SUA');
  const [state, setState] = useState<ListState>(EMPTY_TEACHING_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [busyId, setBusyId] = useState<string | null>(null);
  const [editing, setEditing] = useState<TeachingProfile | 'new' | null>(null);

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildTeachingFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useTeachingPage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;

  const subjects = catalogs.options('SUBJECT');
  const grades = catalogs.options('GRADE');
  const branches = access.allBranches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` }));

  async function toggle(row: TeachingProfile) {
    setBusyId(row.id);
    try {
      await setTeachingActive(supabase, row.id, !row.is_active);
      await refresh();
      toast({
        tone: 'success',
        title: row.is_active ? 'Đã ngừng hồ sơ dạy.' : 'Đã dùng lại hồ sơ dạy.',
      });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setBusyId(null);
    }
  }

  const config = useMemo(
    () =>
      buildConfig({
        subjects,
        grades,
        branches,
        canEdit,
        busyId,
        onEdit: setEditing,
        onToggle: (r) => void toggle(r),
      }),
    // toggle, branches đổi theo dữ liệu; cấu hình dựng lại khi cần.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [catalogs.ready, access, canEdit, busyId],
  );

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view="list"
        onViewChange={() => undefined}
        rows={rows}
        rowKey={(r) => r.id}
        rowLabel={(r) => r.name}
        loading={list.isPending || list.isPlaceholderData}
        error={list.isError ? errorOf(list.error).message : null}
        onRetry={() => void list.refetch()}
        actions={
          canEdit
            ? [{ label: 'Tạo hồ sơ', icon: 'plus' as const, onClick: () => setEditing('new') }]
            : []
        }
        onRefresh={() => void refresh()}
        pager={{
          from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
          to: page * (pageSize ?? 0) + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * (pageSize ?? 0) + rows.length < total
            ? { onNext: () => setPage(page + 1) }
            : {}),
        }}
        sort={null}
        onSortChange={() => undefined}
        emptyMessage={{
          title: 'Chưa có hồ sơ dạy',
          hint: canEdit
            ? 'Bấm Tạo hồ sơ để lập hồ sơ cho giáo viên, trợ giảng (môn, khối, cơ sở thường dạy).'
            : 'Chưa có hồ sơ nào trong bộ lọc này.',
        }}
      />
      {editing !== null && (
        <ProfileDialog
          key={editing === 'new' ? 'new' : editing.id}
          profile={editing === 'new' ? null : editing}
          subjects={subjects}
          grades={grades}
          branches={branches}
          onClose={() => setEditing(null)}
          onSaved={(message) => {
            setEditing(null);
            void refresh();
            toast({ tone: 'success', title: message });
          }}
        />
      )}
    </>
  );
}

function CheckGroup({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: Option[];
  value: string[];
  onChange: (next: string[]) => void;
}) {
  return (
    <fieldset className="flex flex-col gap-1">
      <legend className="text-body font-semibold">{label}</legend>
      <div className="flex flex-wrap gap-x-4 gap-y-1">
        {options.map((o) => (
          <Checkbox
            key={o.value}
            label={o.label}
            checked={value.includes(o.value)}
            onChange={(e) => onChange(toggleCode(value, o.value, e.target.checked))}
          />
        ))}
      </div>
    </fieldset>
  );
}

function ProfileDialog({
  profile,
  subjects,
  grades,
  branches,
  onClose,
  onSaved,
}: {
  profile: TeachingProfile | null;
  subjects: Option[];
  grades: Option[];
  branches: Option[];
  onClose: () => void;
  onSaved: (message: string) => void;
}) {
  const supabase = useDb();
  const creating = profile === null;
  const candidates = useTeachingCandidates(creating);
  const [userId, setUserId] = useState('');
  const [subs, setSubs] = useState<string[]>(profile?.subject_codes ?? []);
  const [grs, setGrs] = useState<string[]>(profile?.grade_codes ?? []);
  const [brs, setBrs] = useState<string[]>(profile?.branch_ids ?? []);
  const [note, setNote] = useState(profile?.note ?? '');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const noteMsg = noteError(note);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      await saveTeachingProfile(
        supabase,
        profilePayload({
          ...(profile ? { id: profile.id } : { userId }),
          subjects: subs,
          grades: grs,
          branchIds: brs,
          note,
        }),
      );
      onSaved(creating ? 'Đã tạo hồ sơ dạy.' : 'Đã lưu hồ sơ dạy.');
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && !busy && onClose()}
      title={creating ? 'Tạo hồ sơ dạy' : `Sửa hồ sơ dạy · ${profile.name}`}
      confirmLabel={creating ? 'Tạo hồ sơ' : 'Lưu'}
      canSubmit={(!creating || userId !== '') && noteMsg === null}
      busy={busy}
      error={error}
      onSubmit={() => void submit()}
      wide
    >
      <div className="flex flex-col gap-3">
        {creating && (
          <Field label="Giáo viên, trợ giảng" required>
            {(p) => (
              <Select
                id={p.id}
                label="Giáo viên, trợ giảng"
                value={userId}
                onChange={setUserId}
                placeholder="Chọn người dùng chưa có hồ sơ"
                options={(candidates.data ?? []).map((c) => ({
                  value: c.user_id,
                  label: `${c.name}${c.staff_code ? ` · ${c.staff_code}` : ''} (${c.kind === 'GV' ? 'Giáo viên' : 'Trợ giảng'})`,
                }))}
              />
            )}
          </Field>
        )}
        <CheckGroup label="Môn dạy" options={subjects} value={subs} onChange={setSubs} />
        <CheckGroup label="Khối dạy" options={grades} value={grs} onChange={setGrs} />
        <CheckGroup label="Cơ sở thường dạy" options={branches} value={brs} onChange={setBrs} />
        <TextAreaField
          label="Ghi chú"
          value={note}
          error={noteMsg}
          onChange={(e) => setNote(e.target.value)}
          help="Ví dụ: chỉ dạy ca tối. Chỉ để tham khảo khi xếp lịch, không chặn."
        />
      </div>
    </FormDialog>
  );
}
