// TS-17 Trang Phiếu kiểm tra (xem, Sửa): khuôn K3 nối cơ sở dữ liệu. Đọc bằng get_student_test (một lần gọi); thanh trạng thái chỉ đọc,
// đổi trạng thái bằng các nút (Bắt đầu test, Nộp bài, Nhập kết quả, Hoàn thành, Đổi lịch, Lùi bước, Huỷ, Mở lại), mỗi nút một hàm DB
// (R-CRM-05, 06, 10, 11, 15, 21). Kết quả nhập thay giáo viên thì lịch sử ghi "nhập thay" (R-CRM-11). "Gợi ý lớp" chờ màn Lớp học.
import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { useFromState, useNavigateFrom } from '../../layout/crumbTrail';
import { useOpportunityAppointments } from '../../features/appointments/useRecordAppointments';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { useCrumbTail } from '../../layout/CrumbTail';
import { HmtError, errorOf, useDb } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { ReasonDialog } from '../../ui/Dialogs';
import { Spinner, StateView } from '../../ui/Feedback';
import { INPUT_CLASS } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { TEST_FIELD_LABELS, testHistoryValue } from './testHistory';
import { ACTIONS_BY_STATUS, STEP_BACK_TARGET, stepBackNeedsReason } from './testLogic';
import { RescheduleTestDialog, ResultDialog, TextReasonDialog } from './TestDialogs';
import { STATUS_FLOW, STATUS_LABEL, type TestRecord } from './testTypes';
import {
  cancelTest,
  completeTest,
  enterTestResult,
  reopenTest,
  rescheduleTest,
  startTest,
  stepBackTest,
  submitTest,
  updateTest,
  useRefreshTestRecord,
  useTestGraders,
  useTestRecord,
  useTestRooms,
} from './useTestData';

const STAGE_NOTE = 'Stage chỉ đọc, đổi bằng nút bên dưới. Huỷ phiếu nằm trong menu Hành động.';

type Draft = {
  owner_id: string;
  test_branch_id: string;
  room_id: string;
  grader_id: string;
  exam_name: string;
};

function toDraft(r: TestRecord): Draft {
  return {
    owner_id: r.owner_id,
    test_branch_id: r.test_branch_id,
    room_id: r.room_id ?? '',
    grader_id: r.grader_id ?? '',
    exam_name: r.exam_name ?? '',
  };
}

export function TestRecordPage() {
  const { id } = useParams<{ id: string }>();
  const query = useTestRecord(id);
  if (query.isPending) return <Spinner label="Đang tải phiếu…" />;
  if (query.isError) {
    const error = query.error;
    const forbidden = error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN';
    const missing = error instanceof HmtError && error.code === 'HMT_KHONG_TIM_THAY';
    return (
      <StateView
        kind={forbidden ? 'forbidden' : missing ? 'not-found' : 'error'}
        title={
          forbidden
            ? 'Bạn không có quyền xem phiếu này'
            : missing
              ? 'Không tìm thấy phiếu'
              : 'Không tải được phiếu'
        }
        actions={
          <>
            <Link to="/crm/phieu-kiem-tra" className="font-medium text-link hover:underline">
              Về danh sách Kiểm tra đầu vào
            </Link>
            {!forbidden && !missing && (
              <Button onClick={() => void query.refetch()}>Thử lại</Button>
            )}
          </>
        }
      >
        {errorOf(error).message}
      </StateView>
    );
  }
  return <TestView key={query.data.id} record={query.data} />;
}

function TestView({ record }: { record: TestRecord }) {
  const supabase = useDb();
  const openFrom = useNavigateFrom();
  const fromState = useFromState();
  const toast = useToast();
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const refreshRecord = useRefreshTestRecord(record.id);

  const status = record.status_code;
  const cancelled = status === 'CANCELLED';
  const actions = ACTIONS_BY_STATUS[status];
  const canEdit = access.can('STUDENT_TEST', 'SUA');
  const canCancel = access.can('STUDENT_TEST', 'HUY');
  const canAssign = access.can('STUDENT_TEST', 'GIAO_VIEC');
  const canAppt = access.can('APPOINTMENT', 'TAO') && !cancelled;
  const can = (a: (typeof actions)[number]) => actions.includes(a);

  const initial = useMemo<Draft>(() => toDraft(record), [record]);
  const [mode, setMode] = useState<DetailMode>('view');
  const [draft, setDraft] = useState<Draft>(initial);
  const [saving, setSaving] = useState(false);
  const [busy, setBusy] = useState(false);
  const [resultOpen, setResultOpen] = useState(false);
  const [rescheduleOpen, setRescheduleOpen] = useState(false);
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);
  const [backOpen, setBackOpen] = useState(false);
  const [reopenOpen, setReopenOpen] = useState(false);

  const editing = mode !== 'view';
  const dirty = editing && JSON.stringify(draft) !== JSON.stringify(initial);
  const set = <K extends keyof Draft>(key: K, value: Draft[K]) =>
    setDraft((d) => ({ ...d, [key]: value }));

  const branchForLists = editing ? draft.test_branch_id : record.test_branch_id;
  const rooms = useTestRooms(branchForLists, editing);
  const graders = useTestGraders(branchForLists, editing || resultOpen);
  const staff = useAssignableStaff('STUDENT_TEST', record.branch_id, editing && canAssign);
  const staffOptions = (staff.data ?? []).map((s) => ({ value: s.id, label: s.display_name }));

  const title = [record.student_name, record.subject, record.mode, record.level]
    .filter(Boolean)
    .join(' · ');
  useCrumbTail(`${record.code} · ${record.student_name}`);

  const appointments = useOpportunityAppointments({
    opportunityId: record.opportunity_id,
    branchId: record.branch_id,
    label: [record.opportunity_code, record.parent_name, record.student_name]
      .filter(Boolean)
      .join(' · '),
    catalogs,
    canEdit: access.can('APPOINTMENT', 'SUA') && !cancelled,
    canCancel: access.can('APPOINTMENT', 'HUY') && !cancelled,
    refresh: refreshRecord,
    upcomingOfTest: record.id,
  });

  /** Một thao tác: gọi hàm DB, tải lại, báo kết quả; lỗi nghiệp vụ hiện nguyên câu của hàm. */
  async function run(action: () => Promise<unknown>, success: string) {
    if (busy) return;
    setBusy(true);
    try {
      await action();
      await refreshRecord();
      toast({ title: success });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setBusy(false);
    }
  }

  async function save() {
    setSaving(true);
    try {
      await updateTest(supabase, record.id, {
        owner_id: draft.owner_id,
        test_branch_id: draft.test_branch_id,
        room_id: draft.room_id === '' ? null : draft.room_id,
        grader_id: draft.grader_id === '' ? null : draft.grader_id,
        exam_name: draft.exam_name.trim() === '' ? null : draft.exam_name.trim(),
      });
      await refreshRecord();
      setMode('view');
      toast({ title: 'Đã lưu.' });
    } catch (e) {
      toast({ tone: 'danger', title: errorOf(e).message });
    } finally {
      setSaving(false);
    }
  }

  const stepLock = 'Đổi trạng thái bằng nút bên dưới. Huỷ phiếu nằm trong menu Hành động.';
  const steps: StageStep[] = STATUS_FLOW.map((s) => ({
    code: s,
    label: STATUS_LABEL[s],
    ...(s === status ? {} : { lockedReason: stepLock }),
  }));
  const backTarget = STEP_BACK_TARGET[status];
  const readyToComplete =
    record.grader_id !== null && record.score !== null && !!record.result_note;

  const menuItems = [
    ...(backTarget && can('step-back') && canEdit
      ? [
          {
            kind: 'action' as const,
            label: `Lùi về ${STATUS_LABEL[backTarget]}`,
            onSelect: () =>
              stepBackNeedsReason(status)
                ? setBackOpen(true)
                : void run(
                    () => stepBackTest(supabase, record.id, null),
                    `Đã lùi về ${STATUS_LABEL[backTarget]}.`,
                  ),
          },
        ]
      : []),
    ...(can('cancel') && canCancel
      ? [
          {
            kind: 'action' as const,
            label: 'Huỷ phiếu',
            tone: 'danger' as const,
            onSelect: () => {
              setCancelError(null);
              setCancelOpen(true);
            },
          },
        ]
      : []),
  ];

  const roomText = record.room_name
    ? [
        record.room_name,
        record.room_capacity ? `${record.room_capacity} chỗ` : null,
        record.test_branch_code,
      ]
        .filter(Boolean)
        .join(' · ')
    : '';

  return (
    <>
      <RecordDetail
        kind="Phiếu kiểm tra"
        title={title}
        mode={mode}
        dirty={dirty}
        saving={saving}
        readOnly={!canEdit || !can('edit')}
        onEdit={() => {
          setDraft(initial);
          setMode('edit');
        }}
        onSave={() => void save()}
        onCancel={() => {
          setDraft(initial);
          setMode('view');
        }}
        menu={menuItems.length > 0 ? { label: 'Hành động', items: menuItems } : undefined}
        onRefresh={() => void refreshRecord()}
        stage={{
          steps,
          current: cancelled ? '' : status,
          forwardOnly: false,
          onSelect: () => undefined,
          onLockedClick: (_step, reason) => toast({ tone: 'warning', title: reason }),
        }}
        stageShowCode={false}
        stageNote={cancelled ? 'Phiếu đã huỷ. Mở lại để đưa về Nháp.' : STAGE_NOTE}
        businessActions={
          <>
            {canEdit && can('start') && (
              <Button
                variant="primary"
                loading={busy}
                onClick={() => void run(() => startTest(supabase, record.id), 'Đã bắt đầu test.')}
              >
                Bắt đầu test
              </Button>
            )}
            {canEdit && can('reschedule') && (
              <Button onClick={() => setRescheduleOpen(true)}>Đổi lịch</Button>
            )}
            {canEdit && can('submit') && (
              <Button
                variant="primary"
                loading={busy}
                onClick={() =>
                  void run(() => submitTest(supabase, record.id), 'Đã nộp bài, chờ giáo viên chấm.')
                }
              >
                Nộp bài
              </Button>
            )}
            {canEdit && can('enter-result') && (
              <Button onClick={() => setResultOpen(true)}>
                {record.score === null ? 'Nhập kết quả' : 'Sửa kết quả'}
              </Button>
            )}
            {canEdit && status === 'TEACHER_REVIEW' && (
              <Button
                variant="primary"
                loading={busy}
                disabled={!readyToComplete}
                title={
                  readyToComplete
                    ? undefined
                    : 'Cần giáo viên chấm, điểm và nhận xét trước khi Hoàn thành'
                }
                onClick={() =>
                  void run(() => completeTest(supabase, record.id), 'Đã hoàn thành phiếu.')
                }
              >
                Hoàn thành
              </Button>
            )}
            {status === 'COMPLETED' && (
              <Button disabled title="Có khi làm màn Lớp học">
                Gợi ý lớp
              </Button>
            )}
            {canEdit && can('reopen') && (
              <Button variant="primary" onClick={() => setReopenOpen(true)}>
                Mở lại
              </Button>
            )}
          </>
        }
        smart={[
          {
            key: 'lich-hen',
            label: 'Lịch hẹn',
            icon: 'calendar',
            count: record.appointments_total,
            onOpen: () =>
              openFrom(`/crm/lich-hen?phieu=${record.id}&ma=${encodeURIComponent(record.code)}`),
          },
          {
            key: 'bao-gia',
            label: 'Báo giá',
            icon: 'payment',
            count: 0,
            unavailable: 'Có ở phần Bán hàng (giai đoạn sau)',
            onOpen: () => undefined,
          },
          {
            key: 'don-hang',
            label: 'Đơn hàng',
            icon: 'file',
            count: 0,
            unavailable: 'Có ở phần Bán hàng (giai đoạn sau)',
            onOpen: () => undefined,
          },
          {
            key: 'hoc-sinh',
            label: 'Học sinh',
            icon: 'training',
            count: 1,
            unavailable: 'Có khi làm màn Khách hàng',
            onOpen: () => undefined,
          },
          {
            key: 'co-hoi-goc',
            label: 'Cơ hội gốc',
            icon: 'sales',
            count: 1,
            onOpen: () => openFrom(`/crm/co-hoi/${record.opportunity_id}`),
          },
          {
            key: 'lead-goc',
            label: 'Lead gốc',
            icon: 'recruit',
            count: 1,
            onOpen: () => openFrom(`/crm/lead/${record.lead_id}`),
          },
        ]}
        aside={
          <RecordChatter
            entityType="STUDENT_TEST"
            entityId={record.id}
            createdText={`Tạo phiếu từ cơ hội ${record.opportunity_code}.`}
            format={{ labels: TEST_FIELD_LABELS, value: testHistoryValue(catalogs, record) }}
            canWrite={!cancelled}
            actions={
              canAppt ? (
                <Button icon="calendar" onClick={appointments.openCreate}>
                  Lên lịch hẹn
                </Button>
              ) : undefined
            }
            upcoming={appointments.upcoming}
          />
        }
      >
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <div className="flex flex-col gap-6">
            <DetailSection title="Bài test">
              <DetailField
                label="Môn"
                mode="view"
                value={[record.subject_code, record.subject].filter(Boolean).join(' · ')}
              />
              <DetailField label="Khối" mode="view" value={record.grade ?? ''} />
              <DetailField label="Hình thức test" mode="view" value={record.mode ?? ''} />
              <DetailField label="Cấp độ đề" mode="view" value={record.level ?? ''} />
              <DetailField
                label="Đề test"
                mode={mode}
                value={editing ? draft.exam_name : (record.exam_name ?? '')}
                editor={
                  <input
                    aria-label="Đề test"
                    value={draft.exam_name}
                    onChange={(e) => set('exam_name', e.target.value)}
                    className={INPUT_CLASS}
                  />
                }
              />
            </DetailSection>
            <DetailSection title="Lịch và phụ trách">
              <DetailField
                label="Ngày giờ test"
                mode="view"
                value={formatDateTime(record.scheduled_at)}
              />
              <DetailField
                label="Cơ sở test"
                mode={mode}
                value={`${record.test_branch_code} ${record.test_branch_name}`}
                editor={
                  <OptionalSelect
                    label="Cơ sở test"
                    value={draft.test_branch_id}
                    onChange={(v) =>
                      setDraft((d) => ({ ...d, test_branch_id: v, room_id: '', grader_id: '' }))
                    }
                    options={access.teachingBranches.map((b) => ({
                      value: b.id,
                      label: `${b.code} ${b.name}`,
                    }))}
                    placeholder="Chọn cơ sở"
                  />
                }
              />
              <DetailField
                label="Phòng"
                mode={mode}
                value={roomText}
                editor={
                  <OptionalSelect
                    label="Phòng"
                    value={draft.room_id}
                    onChange={(v) => set('room_id', v)}
                    options={(rooms.data ?? []).map((r) => ({
                      value: r.id,
                      label: `${r.name}${r.capacity ? ` · ${r.capacity} chỗ` : ''}`,
                    }))}
                    placeholder="Chọn phòng"
                  />
                }
              />
              <DetailField
                label="GV chấm"
                mode={mode}
                value={record.grader_name ?? ''}
                editor={
                  <OptionalSelect
                    label="GV chấm"
                    value={draft.grader_id}
                    onChange={(v) => set('grader_id', v)}
                    options={[
                      ...(record.grader_id &&
                      !(graders.data ?? []).some((g) => g.id === record.grader_id)
                        ? [
                            {
                              value: record.grader_id,
                              label: record.grader_name ?? 'Giáo viên hiện tại',
                            },
                          ]
                        : []),
                      ...(graders.data ?? []).map((g) => ({ value: g.id, label: g.name })),
                    ]}
                    placeholder="Chọn giáo viên"
                  />
                }
              />
              <DetailField
                label="Người phụ trách"
                mode={mode}
                value={record.owner_name ?? ''}
                editor={
                  canAssign ? (
                    <OptionalSelect
                      label="Người phụ trách"
                      value={draft.owner_id}
                      onChange={(v) => set('owner_id', v)}
                      options={[
                        ...(staffOptions.some((o) => o.value === record.owner_id)
                          ? []
                          : [
                              {
                                value: record.owner_id,
                                label: record.owner_name ?? 'Người hiện tại',
                              },
                            ]),
                        ...staffOptions,
                      ]}
                      placeholder="Chọn nhân sự"
                    />
                  ) : (
                    <input
                      readOnly
                      aria-label="Người phụ trách"
                      title="Đổi người phụ trách cần quyền Giao việc"
                      value={record.owner_name ?? ''}
                      className={INPUT_CLASS}
                    />
                  )
                }
              />
            </DetailSection>
          </div>
          <div className="flex flex-col gap-6">
            <DetailSection title="Kết quả">
              <DetailField
                label="Điểm"
                mode="view"
                value={
                  record.score === null ? (
                    ''
                  ) : (
                    <span>
                      <b className="font-display text-h2 tabular">
                        {String(record.score).replace('.', ',')}
                      </b>
                      <span className="text-fg-muted"> / 10</span>
                    </span>
                  )
                }
              />
              <DetailField
                label="Trình độ đề xuất"
                mode="view"
                value={
                  record.suggested_level ? <Tag tone="success">{record.suggested_level}</Tag> : ''
                }
              />
              <DetailField
                label="Phân loại đề xuất"
                mode="view"
                value={record.suggested_framework ?? ''}
              />
              <DetailField label="Lớp đề xuất" mode="view" value="" />
              <DetailField
                label="Nhận xét"
                mode="view"
                value={
                  record.result_note ? (
                    <span className="whitespace-pre-line">{record.result_note}</span>
                  ) : (
                    ''
                  )
                }
              />
              {record.result_entered_by_name && (
                <DetailField
                  label="Nhập bởi"
                  mode="view"
                  value={
                    <>
                      {record.result_entered_by_name}
                      {record.result_on_behalf && (
                        <Tag tone="warning">
                          <span className="ml-0">nhập thay</span>
                        </Tag>
                      )}
                    </>
                  }
                />
              )}
            </DetailSection>
            {cancelled && (
              <DetailSection title="Huỷ phiếu">
                <DetailField label="Lý do huỷ" mode="view" value={record.cancel_reason ?? ''} />
                <DetailField label="Ghi chú" mode="view" value={record.cancel_note ?? ''} />
              </DetailSection>
            )}
          </div>
        </div>
        <p className="mt-6 flex flex-wrap gap-x-8 gap-y-1 border-t border-border pt-3 text-caption text-fg-muted">
          <span>
            Người tạo phiếu <b className="text-fg">{record.created_by_name ?? ''}</b>
          </span>
          <span>
            Cơ sở tạo phiếu{' '}
            <b className="text-fg">
              {record.created_branch_code} {record.created_branch_name}
            </b>
          </span>
          <span>
            Tạo lúc <b className="text-fg">{formatDateTime(record.created_at)}</b>
          </span>
          <span>
            Cơ hội{' '}
            <Link
              to={`/crm/co-hoi/${record.opportunity_id}`}
              state={fromState}
              className="font-medium text-link hover:underline"
            >
              {record.opportunity_code}
            </Link>
          </span>
        </p>
      </RecordDetail>

      {appointments.dialogs}
      <ResultDialog
        open={resultOpen}
        onOpenChange={setResultOpen}
        record={record}
        catalogs={catalogs}
        graders={graders.data ?? []}
        onSubmit={async (data) => {
          await enterTestResult(supabase, { id: record.id, ...data });
          await refreshRecord();
          toast({ title: 'Đã lưu kết quả.' });
        }}
      />
      <RescheduleTestDialog
        open={rescheduleOpen}
        onOpenChange={setRescheduleOpen}
        record={record}
        onSubmit={async (at) => {
          await rescheduleTest(supabase, record.id, at, null);
          await refreshRecord();
          toast({ title: 'Đã đổi lịch test.' });
        }}
      />
      <TextReasonDialog
        open={backOpen}
        onOpenChange={setBackOpen}
        title="Đưa về Nháp"
        subtitle={`${record.code} · ${record.student_name}`}
        hint="Đưa phiếu đã Hoàn thành về Nháp bắt buộc có lý do (R-CRM-21). Cơ hội không lùi giai đoạn."
        confirmLabel="Đưa về Nháp"
        onSubmit={async (reason) => {
          await stepBackTest(supabase, record.id, reason);
          await refreshRecord();
          toast({ title: 'Đã đưa phiếu về Nháp.' });
        }}
      />
      <TextReasonDialog
        open={reopenOpen}
        onOpenChange={setReopenOpen}
        title="Mở lại phiếu"
        subtitle={`${record.code} · ${record.student_name}`}
        hint="Mở lại phiếu đã huỷ về Nháp bắt buộc có lý do (R-CRM-10)."
        confirmLabel="Mở lại"
        onSubmit={async (reason) => {
          await reopenTest(supabase, record.id, reason);
          await refreshRecord();
          toast({ title: 'Đã mở lại phiếu về Nháp.' });
        }}
      />
      <ReasonDialog
        open={cancelOpen}
        onOpenChange={setCancelOpen}
        title="Huỷ phiếu kiểm tra"
        description={`${record.code} · ${record.student_name}`}
        options={catalogs.options('TEST_CANCEL_REASON').map((o) => ({
          ...o,
          needsNote: catalogs.requiresNote('TEST_CANCEL_REASON', o.value),
        }))}
        confirmLabel="Huỷ phiếu"
        busy={cancelBusy}
        error={cancelError}
        onConfirm={(result) => {
          setCancelBusy(true);
          setCancelError(null);
          void cancelTest(
            supabase,
            record.id,
            result.option,
            result.note.trim() === '' ? null : result.note.trim(),
          )
            .then(refreshRecord)
            .then(() => {
              setCancelOpen(false);
              toast({ title: 'Đã huỷ phiếu.' });
            })
            .catch((e: unknown) => setCancelError(errorOf(e).message))
            .finally(() => setCancelBusy(false));
        }}
      />
    </>
  );
}
