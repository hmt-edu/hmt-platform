// HT-02 Bài tập của học sinh: ba nhóm Cần làm, Đã nộp, Đã chấm (khung HT02_can_lam, _da_nop, _da_cham, _tai, _trong, _loi).
// Bài quá hạn nằm ở «Cần làm» với nhãn «Quá hạn» (anh chốt). Chỉ đọc; quyền do máy chủ quyết (app.portal_assignments).
import { useState } from 'react';
import { Link } from 'react-router';
import { errorOf } from '../../lib/db';
import { formatDateTime } from '../../lib/datetime';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { Tabs } from '../../ui/Overlays';
import {
  dueNote,
  useChildren,
  usePortalAssignments,
  type AssignmentGroup,
  type PortalAssignmentRow,
} from './portalData';

const GROUPS: { value: AssignmentGroup; label: string; empty: string }[] = [
  { value: 'CAN_LAM', label: 'Cần làm', empty: 'Em không có bài nào cần làm.' },
  { value: 'DA_NOP', label: 'Đã nộp', empty: 'Chưa có bài nào đã nộp và chờ chấm.' },
  { value: 'DA_CHAM', label: 'Đã chấm', empty: 'Chưa có bài nào được chấm.' },
];

export function StudentAssignmentsPage() {
  const [group, setGroup] = useState<AssignmentGroup>('CAN_LAM');
  const [offset, setOffset] = useState(0);
  const children = useChildren();
  const student = children.data?.[0];
  const query = usePortalAssignments(student?.id, group, offset);
  const pageSize = query.data?.rows.length ?? 0;

  let body;
  if (children.isPending || (student !== undefined && query.isPending)) {
    body = <Spinner label="Đang tải bài tập…" />;
  } else if (children.isError || query.isError) {
    body = (
      <div className="flex flex-col gap-3">
        <Alert tone="danger">{errorOf(children.error ?? query.error).message}</Alert>
        <div>
          <Button
            onClick={() => {
              void children.refetch();
              void query.refetch();
            }}
          >
            Thử lại
          </Button>
        </div>
      </div>
    );
  } else if (student === undefined) {
    body = (
      <StateView kind="empty" title="Chưa có bài tập" headingLevel={2}>
        Tài khoản chưa gắn với học sinh hoặc cơ sở chưa bật Học tập. Liên hệ trung tâm để được hỗ
        trợ.
      </StateView>
    );
  } else if (pageSize === 0) {
    body = (
      <StateView
        kind="empty"
        title={GROUPS.find((g) => g.value === group)?.empty ?? ''}
        headingLevel={2}
      />
    );
  } else {
    const total = query.data?.total ?? 0;
    body = (
      <div className="flex flex-col gap-3">
        <ul className="flex flex-col gap-2">
          {query.data?.rows.map((r) => (
            <AssignmentCard key={r.assignment_id} row={r} group={group} />
          ))}
        </ul>
        {total > offset + pageSize && (
          <div>
            <Button onClick={() => setOffset(offset + pageSize)}>Xem thêm</Button>
          </div>
        )}
      </div>
    );
  }

  const counts = query.data?.counts;
  return (
    <div className="flex flex-col gap-3">
      <h1 className="text-h2">Bài tập</h1>
      <Tabs
        label="Nhóm bài tập"
        value={group}
        onChange={(v) => {
          setGroup(v as AssignmentGroup);
          setOffset(0);
        }}
        items={GROUPS.map((g) => ({
          value: g.value,
          label: g.label,
          ...(counts ? { count: counts[g.value] } : {}),
          content: g.value === group ? body : null,
        }))}
      />
    </div>
  );
}

function AssignmentCard({ row: r, group }: { row: PortalAssignmentRow; group: AssignmentGroup }) {
  return (
    <li>
      <Link
        to={`/hoc/bai-tap/${r.assignment_id}`}
        className="focus-ring flex flex-col gap-1 rounded-lg border border-border bg-surface p-3 hover:bg-surface-subtle"
      >
        <div className="flex flex-wrap items-center gap-2">
          <p className="font-semibold">{r.title}</p>
          {group === 'CAN_LAM' && r.is_overdue && <Tag tone="danger">Quá hạn</Tag>}
          {r.is_late && <Tag tone="warning">Nộp muộn</Tag>}
          {group === 'DA_CHAM' && r.score !== null && <Tag tone="success">{r.score}/5</Tag>}
          {group === 'DA_CHAM' && r.score === null && r.grade_status_name && (
            <Tag>{r.grade_status_name}</Tag>
          )}
        </div>
        <p className="text-caption text-fg-muted">
          {[r.subject_name, r.class_code].filter(Boolean).join(' · ')}
        </p>
        {group === 'CAN_LAM' && (
          <p className="text-caption text-fg-muted">
            {dueNote(r)}: {formatDateTime(r.due_at)}
          </p>
        )}
        {group !== 'CAN_LAM' && r.submitted_at && (
          <p className="text-caption text-fg-muted">Đã nộp: {formatDateTime(r.submitted_at)}</p>
        )}
      </Link>
    </li>
  );
}
