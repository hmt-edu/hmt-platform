// Màn «Điểm danh» (DD1, thay BUOI-11 và BUOI-15): mọi buổi trong khoảng ngày (mặc định hôm nay), tab «Theo buổi» (Buổi học · Xem) và «Cần gọi»
// (Điểm danh · Sửa). Không theo công tắc DIEM_DANH_TRONG_NGAY (anh chốt 27/11). Lọc và phân trang ở máy chủ.
import { useState } from 'react';
import { useSearchParams } from 'react-router';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { vnDayBounds } from '../../lib/vnDay';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Spinner, StateView } from '../../ui/Feedback';
import { Checkbox, TextField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { CustTabs } from '../khach-hang/CustTabs';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { BoardTab } from './BoardTab';
import { CallTab } from './CallTab';
import { PRESETS, presetRange, type RangePreset } from './attendanceLogic';
import type { Quick } from './attendanceTypes';
import { useBoard, useCallList } from './useAttendanceData';

export function AttendancePage() {
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const pageSize = useIntSetting('list_page_size_default');
  const [params, setParams] = useSearchParams();
  const canEdit = access.can('ATTENDANCE', 'SUA');
  const tab = canEdit && params.get('tab') === 'can-goi' ? 'call' : 'board';
  const today = vnDayBounds().dateKey;
  const [range, setRange] = useState(() => presetRange('today', today));
  const [branch, setBranch] = useState(
    access.selectedBranch !== 'all' ? access.selectedBranch : '',
  );
  const [classId, setClassId] = useState('');
  const [quick, setQuick] = useState<Quick>('');
  const [time, setTime] = useState('');
  const [noReason, setNoReason] = useState(false);
  const [page, setPage] = useState(0);
  // Đổi bộ lọc thì về trang đầu.
  const change =
    <T,>(set: (v: T) => void) =>
    (value: T) => {
      set(value);
      setPage(0);
    };

  const base = { ...range, ...(branch ? { branch_id: branch } : {}) };
  const offset = page * (pageSize ?? 0);
  const board = useBoard(
    { ...base, ...(classId ? { class_id: classId } : {}), ...(quick ? { quick } : {}) },
    tab === 'board' ? offset : 0,
    pageSize,
    true,
  );
  const calls = useCallList(
    { ...base, ...(time ? { start_time: time } : {}), ...(noReason ? { no_reason: true } : {}) },
    tab === 'call' ? offset : 0,
    pageSize,
    canEdit && tab === 'call',
  );
  const active = tab === 'board' ? board : calls;
  const total = active.data?.total ?? 0;
  const shown = active.data?.rows.length ?? 0;
  const branches = access.viewableBranches;
  const preset = PRESETS.find((p) => {
    const r = presetRange(p.key, today);
    return r.from === range.from && r.to === range.to;
  })?.key;
  const pickPreset = (key: RangePreset) => change(setRange)(presetRange(key, today));

  return (
    <div className="flex flex-col gap-3">
      <header className="flex flex-col gap-1">
        <h1 className="text-h2">Điểm danh</h1>
        <p className="text-caption text-fg-muted">
          {range.from === range.to
            ? formatDate(range.from)
            : `${formatDate(range.from)} – ${formatDate(range.to)}`}
          . Bấm một nút là tự lưu, buổi đã Done thì khoá.
        </p>
      </header>
      <div className="flex flex-wrap items-end gap-2">
        <div role="group" aria-label="Chọn nhanh ngày" className="flex flex-wrap gap-1">
          {PRESETS.map((p) => (
            <Button
              key={p.key}
              variant={preset === p.key ? 'primary' : 'secondary'}
              aria-pressed={preset === p.key}
              onClick={() => pickPreset(p.key)}
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
            if (from) change(setRange)({ from, to: from > range.to ? from : range.to });
          }}
        />
        <TextField
          label="Đến ngày"
          type="date"
          value={range.to}
          onChange={(e) => {
            const to = e.target.value;
            if (to) change(setRange)({ from: to < range.from ? to : range.from, to });
          }}
        />
        {branches.length > 1 && (
          <div className="w-52">
            <OptionalSelect
              label="Cơ sở"
              value={branch}
              onChange={(v) => {
                change(setBranch)(v);
                setClassId('');
              }}
              options={branches.map((b) => ({ value: b.id, label: `${b.code} ${b.name}` }))}
              placeholder="Mọi cơ sở"
            />
          </div>
        )}
        {tab === 'board' ? (
          <div className="w-44">
            <OptionalSelect
              label="Lớp"
              value={classId}
              onChange={change(setClassId)}
              options={(board.data?.classes ?? []).map((c) => ({ value: c.id, label: c.code }))}
              placeholder="Tất cả lớp"
            />
          </div>
        ) : (
          <>
            <div className="w-36">
              <OptionalSelect
                label="Giờ"
                value={time}
                onChange={change(setTime)}
                options={(calls.data?.times ?? []).map((t) => ({ value: t, label: t }))}
                placeholder="Tất cả giờ"
              />
            </div>
            <Checkbox
              label="Chỉ chưa ghi lý do"
              checked={noReason}
              onChange={(e) => change(setNoReason)(e.target.checked)}
            />
          </>
        )}
      </div>
      {canEdit && (
        <CustTabs
          active={tab}
          onChange={(key) => {
            setPage(0);
            setParams(key === 'call' ? { tab: 'can-goi' } : {}, { replace: true });
          }}
          tabs={[
            { key: 'board', label: 'Theo buổi' },
            {
              key: 'call',
              label: board.data ? `Cần gọi (${board.data.summary.to_call})` : 'Cần gọi',
            },
          ]}
        />
      )}
      {active.isError ? (
        <StateView
          kind="error"
          title="Không tải được điểm danh"
          actions={<Button onClick={() => void active.refetch()}>Thử lại</Button>}
        >
          {errorOf(active.error).message}
        </StateView>
      ) : !active.data ? (
        <div className="flex min-h-40 items-center justify-center">
          <Spinner />
        </div>
      ) : tab === 'board' && board.data ? (
        <BoardTab
          board={board.data}
          statuses={catalogs.options('ATTENDANCE_STATUS')}
          quick={quick}
          onQuick={change(setQuick)}
          canEdit={canEdit}
        />
      ) : (
        <CallTab
          rows={calls.data?.rows ?? []}
          statuses={catalogs.options('ATTENDANCE_STATUS')}
          reasons={catalogs.options('ATTENDANCE_CONTACT_REASON')}
        />
      )}
      {total > shown && (
        <div className="flex items-center justify-end gap-2 text-caption">
          <span>
            {offset + 1}–{offset + shown} / {total}
          </span>
          <Button disabled={page === 0} onClick={() => setPage(page - 1)}>
            Trang trước
          </Button>
          <Button disabled={offset + shown >= total} onClick={() => setPage(page + 1)}>
            Trang sau
          </Button>
        </div>
      )}
    </div>
  );
}
