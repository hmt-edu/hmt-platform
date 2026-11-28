// Màn «Điểm danh» (BUOI-11, R-DD-07, anh Trường 28/11): MỘT bảng khuôn K03, mỗi dòng một học sinh trong một buổi. Xem cần Buổi học · Xem,
// ghi cần Điểm danh · Sửa. Không theo công tắc DIEM_DANH_TRONG_NGAY. Lọc, nhóm, phân trang ở máy chủ.
import { useMemo, useState } from 'react';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { vnDayBounds } from '../../lib/vnDay';
import { listForbiddenOf } from '../../list/forbiddenSpec';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { BulkActionBar } from '../../ui/Data';
import { TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { buildAttendanceConfig, COLUMN_KEYS } from './attendanceConfig';
import { boardGroups, PRESETS, presetRange, rowKey } from './attendanceLogic';
import { useBoard, useBulkOps } from './useAttendanceData';

const INITIAL: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: ['date', 'class'],
  columns: COLUMN_KEYS,
  dateField: '',
  datePreset: '',
};

export function AttendancePage() {
  const access = useAccess();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const pageSize = useIntSetting('list_page_size_default');
  const canEdit = access.can('ATTENDANCE', 'SUA');
  const today = vnDayBounds().dateKey;
  const [range, setRange] = useState(() => presetRange('today', today));
  const [branch, setBranch] = useState(
    access.selectedBranch !== 'all' ? access.selectedBranch : '',
  );
  const [classId, setClassId] = useState('');
  const [teacher, setTeacher] = useState('');
  const [owner, setOwner] = useState('');
  const [state, setState] = useState<ListState>(INITIAL);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const bulk = useBulkOps();

  const filters = {
    ...range,
    ...(branch ? { branch_id: branch } : {}),
    ...(classId ? { class_id: classId } : {}),
    ...(teacher ? { teacher_id: teacher } : {}),
    ...(owner ? { cskh_id: owner } : {}),
    quick: state.quick.quick ?? [],
    group: state.group,
  };
  // Đổi bộ lọc thì về trang đầu.
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const offset = page * (pageSize ?? 0);
  const board = useBoard(filters, offset, pageSize);
  const statuses = catalogs.options('ATTENDANCE_STATUS');
  const reasons = catalogs.options('ATTENDANCE_CONTACT_REASON');
  const config = useMemo(
    () => buildAttendanceConfig({ statuses, reasons, canEdit }),
    [statuses, reasons, canEdit],
  );
  const data = board.data;
  const rows = data?.rows ?? [];
  const total = data?.total ?? 0;
  // Chỉ gán cho dòng còn trên trang và buổi chưa khoá.
  const chosen = rows.filter((r) => !r.locked && selected.has(rowKey(r)));
  const groupLabel = (field: string, key: string) => {
    if (field === 'date') return formatDate(key);
    return key === '' ? 'Chưa có' : key;
  };
  const branches = access.viewableBranches;
  const preset = PRESETS.find((p) => {
    const r = presetRange(p.key, today);
    return r.from === range.from && r.to === range.to;
  })?.key;

  async function assign(status: string) {
    try {
      await bulk.mutateAsync(
        chosen.map((r) => ({
          session_id: r.session_id,
          student_id: r.student_id,
          status_code: status,
        })),
      );
      setSelected(new Set());
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    }
  }

  const toolbar = (
    <div className="flex flex-col gap-2">
      <div className="flex flex-wrap items-end gap-2">
        <div role="group" aria-label="Chọn nhanh ngày" className="flex flex-wrap gap-1">
          {PRESETS.map((p) => (
            <Button
              key={p.key}
              variant={preset === p.key ? 'primary' : 'secondary'}
              aria-pressed={preset === p.key}
              onClick={() => setRange(presetRange(p.key, today))}
            >
              {p.label}
            </Button>
          ))}
        </div>
        <TextField
          label="Từ ngày"
          type="date"
          value={range.from}
          onChange={(e) => {
            const from = e.target.value;
            if (from) setRange({ from, to: from > range.to ? from : range.to });
          }}
        />
        <TextField
          label="Đến ngày"
          type="date"
          value={range.to}
          onChange={(e) => {
            const to = e.target.value;
            if (to) setRange({ from: to < range.from ? to : range.from, to });
          }}
        />
        {branches.length > 1 && (
          <div className="w-full sm:w-52">
            <OptionalSelect
              label="Cơ sở"
              value={branch}
              onChange={(v) => {
                setBranch(v);
                setClassId('');
                setTeacher('');
                setOwner('');
              }}
              options={branches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` }))}
              placeholder="Mọi cơ sở"
            />
          </div>
        )}
        <div className="w-full sm:w-44">
          <OptionalSelect
            label="Lớp"
            value={classId}
            onChange={setClassId}
            options={(data?.classes ?? []).map((c) => ({ value: c.id, label: c.code }))}
            placeholder="Tất cả lớp"
          />
        </div>
        <div className="w-full sm:w-44">
          <OptionalSelect
            label="Giáo viên"
            value={teacher}
            onChange={setTeacher}
            options={(data?.teachers ?? []).map((t) => ({ value: t.id, label: t.name }))}
            placeholder="Tất cả giáo viên"
          />
        </div>
        <div className="w-full sm:w-44">
          <OptionalSelect
            label="Phụ trách"
            value={owner}
            onChange={setOwner}
            options={(data?.owners ?? []).map((o) => ({ value: o.id, label: o.name }))}
            placeholder="Tất cả phụ trách"
          />
        </div>
      </div>
      {data && (
        <dl aria-label="Số đếm" className="flex flex-wrap gap-x-6 gap-y-1 text-body">
          {(
            [
              ['Có mặt', data.summary.present],
              ['Đi muộn', data.summary.late],
              ['Vắng', data.summary.absent],
              ['Chưa điểm danh', data.summary.unmarked],
              ['Lệch', data.summary.mismatch],
              ['Chưa vào lớp', data.summary.not_in_class],
            ] as const
          ).map(([label, value]) => (
            <div key={label} className="flex items-baseline gap-1">
              <dt className="text-caption text-fg-muted">{label}</dt>
              <dd className="tabular font-semibold">{value}</dd>
            </div>
          ))}
        </dl>
      )}
    </div>
  );

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={rowKey}
      rowLabel={(r) => `${r.student_name} ${r.class_code}`}
      loading={board.isPending}
      error={board.isError ? errorOf(board.error).message : null}
      forbidden={listForbiddenOf(board.error, 'điểm danh', 'Đào tạo')}
      onRetry={() => void board.refetch()}
      onRefresh={() => board.refetch()}
      belowToolbar={toolbar}
      groupTree={
        state.group.length > 0
          ? boardGroups(rows, data?.groups ?? [], state.group, groupLabel)
          : undefined
      }
      groupsOpenByDefault
      selected={canEdit ? selected : undefined}
      onSelectedChange={canEdit ? setSelected : undefined}
      bulk={
        canEdit ? (
          <BulkActionBar count={chosen.length} onClear={() => setSelected(new Set())}>
            <span className="text-caption">Gán cùng lúc:</span>
            {statuses.map((s) => (
              <Button
                key={s.value}
                loading={bulk.isPending && bulk.variables?.[0]?.status_code === s.value}
                disabled={bulk.isPending}
                onClick={() => void assign(s.value)}
              >
                {s.label}
              </Button>
            ))}
          </BulkActionBar>
        ) : undefined
      }
      emptyMessage={{
        title: 'Không có dòng nào khớp',
        hint: 'Đổi khoảng ngày hoặc bỏ bớt bộ lọc.',
      }}
      pager={
        total > 0
          ? {
              from: offset + 1,
              to: offset + rows.length,
              total,
              ...(page > 0 ? { onPrev: () => setPaging({ key: pagingKey, page: page - 1 }) } : {}),
              ...(offset + rows.length < total
                ? { onNext: () => setPaging({ key: pagingKey, page: page + 1 }) }
                : {}),
            }
          : undefined
      }
    />
  );
}
