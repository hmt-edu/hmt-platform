// BUOI-02 Buổi học (bản ghi, khuôn K06, chỉ đọc): thanh Nháp → Đã chốt → Hoàn thành, thông tin buổi, danh sách và điểm danh hai cột (trung tâm, giáo viên chính thức),
// em không vào danh sách kèm lý do, nhận xét của giáo viên, lý do chưa Done. Tình trạng đổi bằng nút nghiệp vụ, không bấm trên Stage.
// Nút: Chốt danh sách (buổi Nháp), Điểm danh vận hành (buổi Đã chốt, sang BUOI-03), Dời (BUOI-05), Huỷ (BUOI-04). Sửa điểm danh sau Done (BUOI-14, Điểm danh · Duyệt). Đổi giáo viên (BUOI-13, dạy thay). Đổi giáo viên, Thêm học thử: BUOI-13, BUOI-06 (cụm sau).
// Chưa làm (làm sau 17/11): ghi chú và dòng thời gian, "Báo nghỉ trước", "Đưa về Nháp", "Xác nhận hoàn thành" (Done do hệ thống, mark_session_done là hàm nội bộ).
// Lệch khung có chủ đích: nhãn lớp "môn + mã lớp" (như cụm Lớp), không có "Nhãn bài" riêng ngoài bài bắt đầu của lớp.
import { useState } from 'react';
import { Link, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { useNavigateFrom } from '../../layout/crumbTrail';
import { errorOf } from '../../lib/db';
import { formatDate, formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ConfirmDialog } from '../../ui/Dialogs';
import { CancelSessionDialog } from './CancelSessionDialog';
import { AddTrialDialog } from './AddTrialDialog';
import { ChangeStaffDialog } from './ChangeStaffDialog';
import { CorrectAttendanceDialog } from './CorrectAttendanceDialog';
import { MoveSessionDialog } from './MoveSessionDialog';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { CustTabs } from '../khach-hang/CustTabs';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { sessionTone } from './sessionConfig';
import { EXCLUDED_LABEL, classLabel, sessionNoLabel } from './sessionLogic';
import { useCloseSession, useSessionRecord } from './useSessionData';

const STEPS: StageStep[] = [
  { code: 'NHAP', label: 'Nháp' },
  { code: 'DA_CHOT', label: 'Đã chốt' },
  { code: 'DONE', label: 'Hoàn thành' },
];

const MUTED = <span className="text-fg-muted">—</span>;

const CHATTER_FORMAT = {
  labels: {
    status_code: 'Tình trạng',
    session_date: 'Ngày học',
    start_time: 'Giờ bắt đầu',
    end_time: 'Giờ kết thúc',
    teacher_id: 'Giáo viên',
    room_id: 'Phòng',
  },
  value: (column: string, value: unknown): string | null =>
    column === 'status_code' ? (STEPS.find((x) => x.code === value)?.label ?? null) : null,
};

export function SessionRecordPage() {
  const { id } = useParams();
  const query = useSessionRecord(id);
  const access = useAccess();
  const openFrom = useNavigateFrom();
  const toast = useToast();
  const close = useCloseSession();
  const [confirming, setConfirming] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [moving, setMoving] = useState(false);
  const [changingStaff, setChangingStaff] = useState(false);
  const [addingTrial, setAddingTrial] = useState(false);
  const [correcting, setCorrecting] = useState(false);
  const [tab, setTab] = useState('list');
  const [actionError, setActionError] = useState<string | null>(null);
  useCrumbTail(
    query.data
      ? `${classLabel(query.data.session.subject_name, query.data.session.class_code)} · ${sessionNoLabel(query.data.session.session_no)}`
      : null,
  );

  if (query.isPending) return <Spinner />;
  if (query.isError) {
    const err = errorOf(query.error);
    const forbidden = err.code === 'HMT_KHONG_CO_QUYEN';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : 'not-found'}
        title={forbidden ? 'Bạn không có quyền xem buổi học này' : 'Không tìm thấy buổi học'}
      >
        {err.message}
      </StateView>
    );
  }
  const {
    session: s,
    students,
    excluded,
    reviews,
    listed,
    pending_reason,
    complete_deadline,
  } = query.data;
  const view = 'view' as const;
  const inStages = STEPS.some((st) => st.code === s.status_code);
  const canClose = s.status_code === 'NHAP' && access.can('SESSION', 'SUA');
  const canOps = s.status_code === 'DA_CHOT' && access.can('ATTENDANCE', 'SUA');
  // Dời, huỷ được tới khi buổi Done (R-BUOI-09); giáo viên không có quyền Sửa buổi nên không thấy.
  const canEditSession =
    ['NHAP', 'DA_CHOT'].includes(s.status_code) && access.can('SESSION', 'SUA');
  // Thêm học thử (BUOI-06): buổi Đã chốt, quyền Sửa buổi, cờ HOC_THU bật (tắt mặc định).
  const canTrial =
    s.status_code === 'DA_CHOT' && access.can('SESSION', 'SUA') && access.featureOn('HOC_THU');
  // Sửa điểm danh sau Done: chỉ Điểm danh · Duyệt (Trưởng cơ sở, Admin), bắt buộc lý do (BUOI-14, R-GIO-07).
  const canCorrect =
    s.status_code === 'DONE' && access.can('ATTENDANCE', 'DUYET') && students.length > 0;
  const cancelled = s.status_code === 'HUY_CO_PHI' || s.status_code === 'HUY_KHONG_PHI';
  const title = `${classLabel(s.subject_name, s.class_code)} · ${sessionNoLabel(s.session_no)} · ${formatDate(s.session_date)}`;

  async function doClose() {
    setActionError(null);
    try {
      await close.mutateAsync(s.id);
      toast({ tone: 'success', title: 'Đã chốt danh sách' });
      setConfirming(false);
    } catch (e) {
      setConfirming(false);
      setActionError(errorOf(e).message);
    }
  }

  return (
    <>
      <RecordDetail
        kind="Buổi học"
        title={title}
        mode={view}
        readOnly
        showEdit={false}
        onEdit={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
        stageShowCode={false}
        stage={{
          steps: STEPS,
          current: inStages ? s.status_code : '',
          forwardOnly: true,
          onSelect: () => undefined,
        }}
        stageNote="Tình trạng chỉ đọc, đổi bằng nút bên dưới."
        aside={
          <RecordChatter
            entityType="CLASS_SESSION"
            entityId={s.id}
            format={CHATTER_FORMAT}
            createdText="Tạo buổi học."
            canWrite
          />
        }
        businessActions={
          <span className="flex flex-wrap items-center gap-2">
            {canClose && (
              <Button variant="primary" onClick={() => setConfirming(true)}>
                Chốt danh sách
              </Button>
            )}
            {canOps && (
              <Button variant="primary" onClick={() => openFrom(`/crm/diem-danh/buoi/${s.id}`)}>
                Điểm danh vận hành
              </Button>
            )}
            {canTrial && <Button onClick={() => setAddingTrial(true)}>Thêm học thử</Button>}
            {canEditSession && <Button onClick={() => setMoving(true)}>Dời</Button>}
            {canEditSession && (
              <Button onClick={() => setChangingStaff(true)}>Đổi giáo viên</Button>
            )}
            {canEditSession && <Button onClick={() => setCancelling(true)}>Huỷ</Button>}
            {canCorrect && <Button onClick={() => setCorrecting(true)}>Sửa điểm danh</Button>}
            {!inStages && <Tag tone={sessionTone(s.status_code)}>{s.status_name}</Tag>}
          </span>
        }
        smart={[
          {
            key: 'lop',
            label: 'Lớp',
            icon: 'file',
            count: 1,
            onOpen: () => openFrom(`/crm/lop/${s.class_id}`),
          },
          {
            key: 'hoc-sinh',
            label: 'Học sinh',
            icon: 'user',
            count: students.length,
            unavailable: 'Danh sách học sinh xem ngay bên dưới',
            onOpen: () => undefined,
          },
        ]}
      >
        {actionError && <Alert tone="danger">{actionError}</Alert>}
        <div className="grid gap-6 md:grid-cols-2">
          <DetailSection title="Thông tin buổi">
            <DetailField
              label="Buổi"
              mode={view}
              value={`${sessionNoLabel(s.session_no)} · ${s.status_name}`}
            />
            <DetailField
              label="Lớp"
              mode={view}
              value={
                <Link to={`/crm/lop/${s.class_id}`} className="text-link hover:underline">
                  {classLabel(s.subject_name, s.class_code)}
                </Link>
              }
            />
            <DetailField
              label="Ngày giờ"
              mode={view}
              value={`${formatDate(s.session_date)} · ${s.start_time}–${s.end_time}`}
            />
            <DetailField label="Cơ sở" mode={view} value={`${s.branch_code} ${s.branch_name}`} />
            <DetailField label="Phòng" mode={view} value={s.room_name ?? ''} />
            <DetailField label="Giáo viên" mode={view} value={s.teacher_name ?? ''} />
            <DetailField label="Trợ giảng" mode={view} value={s.assistant_name ?? 'không có'} />
            <DetailField label="Loại buổi" mode={view} value={s.type_name} />
            <DetailField label="Bài bắt đầu của lớp" mode={view} value={s.start_lesson ?? ''} />
          </DetailSection>
        </div>

        {cancelled && (
          <div className="mt-6">
            <Alert tone="info">
              <b>{s.status_name}.</b> Lý do: {s.cancel_reason_name ?? 'không ghi'}
              {s.cancel_note ? ` · ${s.cancel_note}` : ''}. Các dòng điểm danh đã bị vô hiệu
              (R-BUOI-09).
            </Alert>
          </div>
        )}
        {pending_reason && (
          <div className="mt-6">
            <Alert tone="warning">
              <b>Chưa hoàn thành.</b> {pending_reason}
              {complete_deadline && (
                <> Hạn giáo viên hoàn tất: {formatDateTime(complete_deadline)}.</>
              )}
            </Alert>
          </div>
        )}
        {s.status_code === 'NHAP' && (
          <div className="mt-6">
            <Alert tone="info">
              Buổi ở Nháp: danh sách chưa chốt. Hệ thống tự chốt trước giờ bắt đầu, hoặc bấm Chốt
              danh sách để chốt ngay. Em ghi danh sau ngày buổi không lọt vào danh sách.
            </Alert>
          </div>
        )}

        <div className="mt-6">
          <CustTabs
            active={tab}
            onChange={setTab}
            tabs={[
              { key: 'list', label: 'Danh sách và điểm danh' },
              { key: 'review', label: 'Nhận xét' },
            ]}
          />
        </div>
        {tab === 'list' && (
          <>
            <section className="mt-6 flex flex-col gap-2" aria-labelledby="buoi02-list">
              <h3
                id="buoi02-list"
                className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
              >
                Danh sách và điểm danh
              </h3>
              {!listed ? (
                <p className="text-body text-fg-muted">
                  Chưa có danh sách. Danh sách chốt khi buổi chuyển sang Đã chốt.
                </p>
              ) : students.length === 0 ? (
                <p className="text-body text-fg-muted">Buổi không có em nào trong danh sách.</p>
              ) : (
                <div className="overflow-x-auto rounded-control border border-border">
                  <table aria-label="Danh sách và điểm danh" className="w-full text-body">
                    <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
                      <tr>
                        <th className="px-3 py-2">Học sinh</th>
                        <th className="px-3 py-2">Ghi danh</th>
                        <th className="px-3 py-2">Trung tâm điểm danh</th>
                        <th className="px-3 py-2">Điểm danh giáo viên (chính thức)</th>
                      </tr>
                    </thead>
                    <tbody>
                      {students.map((st) => (
                        <tr key={st.student_id} className="border-t border-border">
                          <td className="px-3 py-2">
                            {st.full_name} {st.is_trial && <Tag tone="info">Học thử</Tag>}
                          </td>
                          <td className="px-3 py-2">{st.enrollment_code ?? MUTED}</td>
                          <td className="px-3 py-2">{st.ops_status_name ?? MUTED}</td>
                          <td className="px-3 py-2">
                            {st.teacher_status_name ?? MUTED}{' '}
                            {st.mismatch && <Tag tone="warning">Lệch</Tag>}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              <p className="text-caption text-fg-muted">
                Một em một dòng. Ô của giáo viên quyết định trạng thái chính thức (R-DD-02). Thẻ
                Lệch: điểm danh của trung tâm khác của giáo viên, chỉ để đối chiếu.
              </p>
            </section>

            {excluded.length > 0 && (
              <section className="mt-6 flex flex-col gap-2" aria-labelledby="buoi02-excluded">
                <h3
                  id="buoi02-excluded"
                  className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
                >
                  Em không vào danh sách
                </h3>
                <ul className="flex flex-col gap-1 text-body">
                  {excluded.map((e) => (
                    <li key={e.student_id}>
                      {e.full_name}: {EXCLUDED_LABEL[e.reason_code] ?? e.reason_code}
                    </li>
                  ))}
                </ul>
              </section>
            )}
          </>
        )}
        {tab === 'review' && (
          <section className="mt-6 flex flex-col gap-2" aria-labelledby="buoi02-review">
            <h3
              id="buoi02-review"
              className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
            >
              Nhận xét của giáo viên
            </h3>
            {!listed || s.status_code === 'HUY_CO_PHI' || s.status_code === 'HUY_KHONG_PHI' ? (
              <p className="text-body text-fg-muted">
                Chưa có nhận xét: giáo viên nhập sau buổi học.
              </p>
            ) : (
              <ul className="flex flex-col gap-1 text-body">
                {reviews.map((r) => (
                  <li key={r.student_id}>
                    <b>{r.full_name}</b>:{' '}
                    {r.comment ?? <span className="text-fg-muted">chưa có</span>}
                  </li>
                ))}
              </ul>
            )}
          </section>
        )}
      </RecordDetail>
      <CancelSessionDialog
        sessionId={s.id}
        isPrivateClass={s.class_type_code === 'LR'}
        open={cancelling}
        onClose={() => setCancelling(false)}
      />
      <MoveSessionDialog session={s} open={moving} onClose={() => setMoving(false)} />
      <AddTrialDialog sessionId={s.id} open={addingTrial} onClose={() => setAddingTrial(false)} />
      <ChangeStaffDialog
        sessionId={s.id}
        branchId={s.branch_id}
        teacherId={s.teacher_id}
        assistantId={s.assistant_id}
        open={changingStaff}
        onClose={() => setChangingStaff(false)}
      />
      <CorrectAttendanceDialog
        sessionId={s.id}
        students={students}
        open={correcting}
        onClose={() => setCorrecting(false)}
      />
      <ConfirmDialog
        open={confirming}
        onOpenChange={setConfirming}
        title="Chốt danh sách buổi này?"
        description="Danh sách em chốt ngay theo ghi danh hiện tại. Ghi danh sinh sau không lọt vào danh sách (R-GIO-02)."
        confirmLabel="Chốt danh sách"
        cancelLabel="Để sau"
        busy={close.isPending}
        onConfirm={() => void doClose()}
      />
    </>
  );
}
