// Tab «Theo buổi» (canvas «Đào tạo — menu và điểm danh», khung Main): số đếm, lọc nhanh, nhóm theo ngày rồi theo lớp, bấm trạng thái là tự lưu,
// chọn nhiều để gán cùng lúc. Cột Giáo viên chỉ xem; buổi Done khoá. Quyền, khoá và tự Done do máy chủ quyết.
import { useMemo, useState } from 'react';
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { Button } from '../../ui/Button';
import { BulkActionBar, Tag } from '../../ui/Data';
import { Alert } from '../../ui/Feedback';
import { Checkbox } from '../../ui/Field';
import { groupRows, isMismatch, rowKey } from './attendanceLogic';
import type { Board, BoardRow, Quick } from './attendanceTypes';
import { useBulkOps, useSaveOpsEntry } from './useAttendanceData';

type Status = { value: string; label: string };

export function BoardTab({
  board,
  statuses,
  quick,
  onQuick,
  canEdit,
}: {
  board: Board;
  statuses: Status[];
  quick: Quick;
  onQuick: (quick: Quick) => void;
  canEdit: boolean;
}) {
  const save = useSaveOpsEntry();
  const bulk = useBulkOps();
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [error, setError] = useState<string | null>(null);
  const days = useMemo(() => groupRows(board.rows), [board.rows]);
  // Chỉ giữ lựa chọn còn trên trang và còn sửa được.
  const chosen = board.rows.filter((r) => !r.locked && selected.has(rowKey(r)));
  const { summary } = board;
  const statusName = (code: string) => statuses.find((s) => s.value === code)?.label ?? code;

  async function run(action: () => Promise<unknown>) {
    setError(null);
    try {
      await action();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  const toggle = (keys: string[], on: boolean) =>
    setSelected((prev) => {
      const next = new Set(prev);
      for (const key of keys) {
        if (on) next.add(key);
        else next.delete(key);
      }
      return next;
    });

  const statusButtons = (r: BoardRow) => (
    <div role="group" aria-label={`Điểm danh ${r.student_name}`} className="flex flex-wrap gap-1">
      {statuses.map((s) => (
        <Button
          key={s.value}
          variant={r.ops_status_code === s.value ? 'primary' : 'secondary'}
          aria-pressed={r.ops_status_code === s.value}
          disabled={!canEdit || r.locked || save.isPending}
          onClick={() => {
            if (r.ops_status_code === s.value) return;
            void run(() =>
              save.mutateAsync({
                sessionId: r.session_id,
                entry: { student_id: r.student_id, status_code: s.value },
              }),
            );
          }}
        >
          {s.label}
        </Button>
      ))}
    </div>
  );

  return (
    <div className="flex flex-col gap-3">
      <dl aria-label="Số đếm" className="flex flex-wrap gap-x-6 gap-y-1 text-body">
        {(
          [
            ['Có mặt', summary.present],
            ['Đi muộn', summary.late],
            ['Vắng', summary.absent],
            ['Chưa điểm danh', summary.unmarked],
            ['Buổi chưa đủ', `${summary.incomplete_sessions}/${summary.sessions}`],
          ] as const
        ).map(([label, value]) => (
          <div key={label} className="flex items-baseline gap-1">
            <dt className="text-caption text-fg-muted">{label}</dt>
            <dd className="tabular font-semibold">{value}</dd>
          </div>
        ))}
      </dl>
      <div role="group" aria-label="Lọc nhanh" className="flex flex-wrap gap-1">
        {(
          [
            ['CHUA', 'Chưa điểm danh'],
            ['LECH', 'Lệch'],
          ] as const
        ).map(([code, label]) => (
          <Button
            key={code}
            variant={quick === code ? 'primary' : 'secondary'}
            aria-pressed={quick === code}
            onClick={() => onQuick(quick === code ? '' : code)}
          >
            {label}
          </Button>
        ))}
      </div>
      {error && <Alert tone="danger">{error}</Alert>}
      {canEdit && (
        <BulkActionBar count={chosen.length} onClear={() => setSelected(new Set())}>
          <span className="text-caption">Gán cùng lúc:</span>
          {statuses.map((s) => (
            <Button
              key={s.value}
              loading={bulk.isPending && bulk.variables?.[0]?.status_code === s.value}
              disabled={bulk.isPending}
              onClick={() =>
                void run(async () => {
                  await bulk.mutateAsync(
                    chosen.map((r) => ({
                      session_id: r.session_id,
                      student_id: r.student_id,
                      status_code: s.value,
                    })),
                  );
                  setSelected(new Set());
                })
              }
            >
              {s.label}
            </Button>
          ))}
        </BulkActionBar>
      )}
      {days.length === 0 && (
        <p className="text-body text-fg-muted">
          Không có buổi nào khớp. Đổi khoảng ngày hoặc bỏ bớt bộ lọc nhanh.
        </p>
      )}
      {days.map((day) => (
        <section
          key={day.date}
          aria-label={`Ngày ${formatDate(day.date)}`}
          className="flex flex-col gap-3"
        >
          <h2 className="text-h3">{formatDate(day.date)}</h2>
          {day.sessions.map(({ sessionId, head, rows }) => {
            const keys = rows.filter((r) => !r.locked).map(rowKey);
            const title = `${head.subject_name} ${head.class_code}`;
            return (
              <div key={sessionId} className="rounded-control border border-border bg-surface">
                <div className="flex flex-wrap items-center gap-2 border-b border-border bg-surface-subtle px-3 py-2">
                  {canEdit && keys.length > 0 && (
                    <Checkbox
                      label={<span className="sr-only">Chọn cả lớp {head.class_code}</span>}
                      checked={keys.every((k) => selected.has(k))}
                      onChange={(e) => toggle(keys, e.target.checked)}
                    />
                  )}
                  <Link to={`/crm/buoi-hoc/${sessionId}`} className="focus-ring text-link">
                    <b>{title}</b>
                  </Link>
                  <span className="text-caption text-fg-muted">
                    {[`${head.start_time}–${head.end_time}`, head.room_name, head.teacher_name]
                      .filter(Boolean)
                      .join(' · ')}
                  </span>
                  <span className="ml-auto">
                    {head.locked ? (
                      <Tag tone="info">Đã Done · khoá</Tag>
                    ) : (
                      <Tag
                        tone={head.session_marked === head.session_total ? 'success' : 'warning'}
                      >
                        {head.session_marked}/{head.session_total} đã điểm danh
                      </Tag>
                    )}
                  </span>
                </div>
                <ul aria-label={`Học sinh ${title}`}>
                  {rows.map((r) => (
                    <li
                      key={r.student_id}
                      className="flex flex-col gap-2 border-t border-border px-3 py-2 first:border-t-0 lg:flex-row lg:items-center"
                    >
                      <span className="flex items-center gap-2 lg:w-56">
                        {canEdit && !r.locked && (
                          <Checkbox
                            label={<span className="sr-only">Chọn {r.student_name}</span>}
                            checked={selected.has(rowKey(r))}
                            onChange={(e) => toggle([rowKey(r)], e.target.checked)}
                          />
                        )}
                        {r.student_name}
                      </span>
                      {statusButtons(r)}
                      <span className="flex items-center gap-1 text-caption">
                        <span className="text-fg-muted">Giáo viên:</span>
                        {r.teacher_status_code ? statusName(r.teacher_status_code) : 'Chưa tích'}
                        {isMismatch(r) && <Tag tone="warning">Lệch</Tag>}
                      </span>
                      <span className="text-caption text-fg-muted lg:ml-auto">
                        {[r.contact_reason_name, r.ops_note].filter(Boolean).join(' · ')}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            );
          })}
        </section>
      ))}
    </div>
  );
}
