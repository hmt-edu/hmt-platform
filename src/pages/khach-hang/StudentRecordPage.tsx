// KH-05 Học sinh (hồ sơ 360°, khuôn K06): thông tin, ghi danh và lớp, điểm danh, điểm kiểm tra, phiếu kiểm tra đầu vào; nút liên kết có số đếm;
// ghi chú và hoạt động (Chatter). Mọi tab bấm được và luôn hiện đủ cột (khung KH05_*). Không có Tạo tay (R-CRM-27). Sửa (KH-06) gọi update_student; cơ sở tiếp nhận chỉ xem (R-CRM-28). Tạo ticket chưa làm: hiện mờ kèm chú thích. Tài khoản app học sinh: xem StudentAccount.
// Giáo viên được phân công xem hồ sơ trong lớp mình nhưng không thấy SĐT phụ huynh (R-GV-13): máy chủ trả null.
import { useState } from 'react';
import { MergeDialog } from '../../features/merge/MergeDialog';
import { formatPhone } from '../lead/leadFormat';
import { Link, useNavigate, useParams } from 'react-router';
import { useCrumbTail } from '../../layout/CrumbTail';
import { Button } from '../../ui/Button';
import { HmtError, errorOf, rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { dateToIso, isoToDate } from '../lead/leadRecord';
import { formatDate, formatDateTime } from '../../lib/format';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { RecordSummary } from '../../features/record360/RecordSummary';
import type { ChatterFocus } from '../../ui/Chatter';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { CustTabs } from './CustTabs';
import { CustTickets } from './CustTickets';
import { AppointmentTab, UpsaleTab } from './FollowUpTabs';
import { useOpportunityAppointments } from '../../features/appointments/useRecordAppointments';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { STUDENT_STATUS_LABEL, type StudentRecord } from './custTypes';
import {
  StudentAttendanceTab,
  StudentCareTab,
  StudentExamTab,
  StudentStudyTab,
} from './StudentTabs';
import { useComplaintCount, useOpenTicketCount } from './useCustTickets';
import { parentPath, studentPath } from './custConfig';
import { newTicketForParentPath } from './custFilters';
import { useStudentAccount } from './StudentAccount';
import { useRefreshCustomers, useStudentRecord } from './useCustData';

const FORMAT = {
  labels: {
    full_name: 'Họ tên',
    birth_date: 'Ngày sinh',
    birth_year: 'Năm sinh',
    school: 'Trường học',
    goal: 'Mục tiêu',
    grade: 'Khối',
  },
};

type StudentDraft = {
  full_name: string;
  birth_date: string;
  birth_year: string;
  grade: string;
  school: string;
  goal: string;
};

function toStudentDraft(r: StudentRecord): StudentDraft {
  return {
    full_name: r.full_name,
    birth_date: r.birth_date ?? '',
    birth_year: r.birth_year === null ? '' : String(r.birth_year),
    grade: r.grade === null ? '' : String(r.grade),
    school: r.school ?? '',
    goal: r.goal ?? '',
  };
}

// Khối 1 đến 12 theo ràng buộc của cột student.grade (R-V2-31), không phải danh sách nghiệp vụ.
const GRADE_OPTIONS = Array.from({ length: 12 }, (_, i) => ({
  // allow-number: ràng buộc cột khối 1..12
  value: String(i + 1),
  label: `Lớp ${i + 1}`,
}));

export function StudentRecordPage() {
  const { id } = useParams();
  const query = useStudentRecord(id);
  if (query.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (query.isError) {
    const code = query.error instanceof HmtError ? query.error.code : '';
    return (
      <StateView
        kind={
          code === 'HMT_KHONG_CO_QUYEN'
            ? 'forbidden'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'not-found'
              : 'error'
        }
        title={
          code === 'HMT_KHONG_CO_QUYEN'
            ? 'Bạn không có quyền xem học sinh này'
            : code === 'HMT_KHONG_TIM_THAY'
              ? 'Không tìm thấy học sinh'
              : 'Không tải được học sinh'
        }
        actions={
          <>
            <Link to="/crm/hoc-sinh" className="font-medium text-link hover:underline">
              Về danh sách Học sinh
            </Link>
            {code === '' && <Button onClick={() => void query.refetch()}>Thử lại</Button>}
          </>
        }
      >
        {errorOf(query.error).message}
      </StateView>
    );
  }
  return <StudentView key={query.data.id} record={query.data} />;
}

function StudentView({ record }: { record: StudentRecord }) {
  const refresh = useRefreshCustomers();
  const navigate = useNavigate();
  const [tab, setTab] = useState('overview');
  const [focus, setFocus] = useState<ChatterFocus | undefined>();
  useCrumbTail(`${record.full_name} · ${record.code}`);
  const merged = record.record_status === 'DA_GOP';
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const canEdit = access.can('STUDENT', 'SUA') && !merged;
  const canTickets = access.can('TICKET', 'XEM');
  const openTickets = useOpenTicketCount({ key: 'student_id', id: record.id }, canTickets);
  const complaints = useComplaintCount(record.id, canTickets);
  const [ticketType, setTicketType] = useState<string | undefined>();
  const account = useStudentAccount(record);
  const catalogs = useLeadCatalogs();
  const appointments = useOpportunityAppointments({
    opportunityId: '',
    branchId: '',
    label: `${record.code} · ${record.full_name}`,
    catalogs,
    canEdit: access.can('APPOINTMENT', 'SUA') && !merged,
    canCancel: access.can('APPOINTMENT', 'HUY') && !merged,
    refresh: async () => {
      await refresh();
    },
    upcomingOfCustomer: { key: 'student_id', id: record.id },
  });
  // Gộp trùng dùng quyền Duyệt (R-CRM-25); bản đã gộp chỉ đọc.
  const canMerge = access.can('STUDENT', 'DUYET') && !merged;
  const [mergeOpen, setMergeOpen] = useState(false);
  const [mode, setMode] = useState<DetailMode>('view');
  const [draft, setDraft] = useState<StudentDraft>(() => toStudentDraft(record));
  const [errors, setErrors] = useState<Partial<Record<keyof StudentDraft, string>>>({});
  const [saving, setSaving] = useState(false);
  const editing = mode !== 'view';
  const dirty = editing && JSON.stringify(draft) !== JSON.stringify(toStudentDraft(record));

  function startEdit() {
    setDraft(toStudentDraft(record));
    setErrors({});
    setMode('edit');
  }
  function set<K extends keyof StudentDraft>(key: K, value: StudentDraft[K]) {
    setDraft((d) => ({ ...d, [key]: value }));
  }
  async function save() {
    // Luật R-CRM-03, Đ165: họ tên và năm sinh bắt buộc; ngày sinh không bắt buộc.
    const found: Partial<Record<keyof StudentDraft, string>> = {};
    if (draft.full_name.trim() === '') found.full_name = 'Bắt buộc nhập họ tên';
    if (draft.birth_year.trim() === '' && draft.birth_date === '')
      found.birth_year = 'Bắt buộc nhập năm sinh';
    setErrors(found);
    if (Object.keys(found).length > 0) return;
    setSaving(true);
    try {
      await rpc<null>(supabase, 'update_student', {
        p_id: record.id,
        p_data: {
          full_name: draft.full_name,
          birth_date: draft.birth_date === '' ? null : draft.birth_date,
          birth_year: draft.birth_year.trim() === '' ? null : Number(draft.birth_year),
          grade: draft.grade === '' ? null : Number(draft.grade),
          school: draft.school,
          goal: draft.goal,
        },
      });
      await refresh();
      setMode('view');
      toast({ title: 'Đã lưu.' });
    } catch (e) {
      const error = errorOf(e);
      if (error.code === 'HMT_HOC_SINH_TRUNG' || error.code === 'HMT_THIEU_HOC_SINH')
        setErrors((x) => ({ ...x, full_name: error.message }));
      else if (error.code === 'HMT_NAM_SINH_SAI')
        setErrors((x) => ({ ...x, birth_year: error.message }));
      else toast({ tone: 'danger', title: error.message });
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <RecordDetail
        kind="Học sinh"
        title={`${record.full_name} · ${record.code}`}
        mode={mode}
        dirty={dirty}
        saving={saving}
        readOnly={!canEdit}
        onEdit={startEdit}
        onSave={() => void save()}
        onCancel={() => {
          setErrors({});
          setMode('view');
        }}
        onRefresh={() => void refresh()}
        menu={{
          label: 'Hành động',
          items: [
            {
              kind: 'action',
              label: 'Sửa',
              onSelect: startEdit,
              ...(canEdit
                ? {}
                : {
                    unavailable: merged
                      ? 'Hồ sơ đã gộp chỉ xem được'
                      : 'Bạn không có quyền sửa học sinh',
                  }),
            },
            {
              kind: 'action',
              label: 'Gộp',
              onSelect: () => setMergeOpen(true),
              ...(canMerge
                ? {}
                : {
                    unavailable: merged
                      ? 'Hồ sơ đã gộp chỉ xem được'
                      : 'Bạn không có quyền gộp (cần quyền Duyệt)',
                  }),
            },
            {
              kind: 'action',
              label: 'Tạo ticket',
              onSelect: () => undefined,
              unavailable: 'Ticket chăm sóc làm sau',
            },
            ...account.menuItems,
          ],
        }}
        summary={
          <RecordSummary
            entityType="STUDENT"
            entityId={record.id}
            label={`${record.code} · ${record.full_name}`}
            readOnly={merged}
            ticketPath={
              record.parent ? newTicketForParentPath(record.parent.id, record.parent.code) : null
            }
            onFlag={(t) => {
              setTicketType(undefined);
              setTab(t === 'tickets' || t === 'upsale' ? t : 'attendance');
            }}
            onChatter={(target) => setFocus((f) => ({ target, seq: (f?.seq ?? 0) + 1 }))}
          />
        }
        smart={[
          {
            key: 'ghi-danh',
            label: 'Ghi danh',
            icon: 'training',
            count: record.counts.enrollments,
            hidden: !access.can('ENROLLMENT', 'XEM'),
            onOpen: () => setTab('study'),
          },
          {
            key: 'lop',
            label: 'Lớp',
            icon: 'training',
            count: record.counts.classes,
            hidden: !access.can('CLASS', 'XEM'),
            onOpen: () => setTab('study'),
          },
          {
            key: 'phieu-test',
            label: 'Phiếu test',
            icon: 'results',
            count: record.counts.tests,
            hidden: !access.can('STUDENT_TEST', 'XEM'),
            onOpen: () => setTab('exam'),
          },
          {
            key: 'ticket-mo',
            label: 'Ticket mở',
            icon: 'results',
            count: openTickets ?? 0,
            hidden: openTickets === undefined,
            onOpen: () => {
              setTicketType(undefined);
              setTab('tickets');
            },
          },
          {
            key: 'khieu-nai',
            label: 'Khiếu nại',
            icon: 'results',
            count: complaints ?? 0,
            hidden: complaints === undefined,
            onOpen: () => {
              setTicketType('KN');
              setTab('tickets');
            },
          },
          {
            key: 'phu-huynh',
            label: 'Phụ huynh',
            icon: 'training',
            count: record.parent ? 1 : 0,
            hidden: !record.parent || !access.can('PARENT', 'XEM'),
            onOpen: () => {
              if (record.parent) void navigate(parentPath(record.parent.id));
            },
          },
        ]}
        aside={
          <RecordChatter
            entityType="STUDENT"
            entityId={record.id}
            format={FORMAT}
            createdText="Tạo học sinh."
            canWrite={!merged}
            focus={focus}
            upcoming={access.can('APPOINTMENT', 'XEM') ? appointments.upcoming : undefined}
          />
        }
        asideLabel="Ghi chú và hoạt động"
      >
        {merged && (
          <p role="status" className="rounded-control bg-canvas p-3">
            Hồ sơ này đã gộp vào hồ sơ khác.{' '}
            {record.merged_into_id && (
              <Link
                className="font-medium text-link hover:underline"
                to={`/crm/hoc-sinh/${record.merged_into_id}`}
              >
                Mở hồ sơ đích
              </Link>
            )}
          </p>
        )}
        <div className="flex flex-wrap items-center gap-2">
          <Tag tone={record.status === 'DANG_HOC' ? 'success' : 'neutral'}>
            {STUDENT_STATUS_LABEL[record.status]}
          </Tag>
        </div>
        <CustTabs
          active={tab}
          onChange={setTab}
          tabs={[
            { key: 'overview', label: 'Tổng quan' },
            { key: 'study', label: 'Học tập' },
            { key: 'attendance', label: 'Điểm danh' },
            { key: 'exam', label: 'Điểm kiểm tra' },
            { key: 'care', label: 'Chăm sóc' },
            { key: 'tickets', label: 'Đề nghị & khiếu nại' },
            { key: 'upsale', label: 'Tái tục' },
            { key: 'appointments', label: 'Lịch hẹn' },
          ]}
        />
        {tab === 'overview' && (
          <DetailSection title="Thông tin học sinh">
            <DetailField
              mode="view"
              label="Mã cũ (Sheet)"
              hint="chỉ xem, Admin sửa được"
              value={record.legacy_ref ?? ''}
            />
            <DetailField
              mode={mode}
              label="Họ tên"
              required
              value={record.full_name}
              error={errors.full_name ?? null}
              editor={
                <input
                  aria-label="Họ tên"
                  value={draft.full_name}
                  onChange={(e) => set('full_name', e.target.value)}
                  aria-invalid={errors.full_name ? true : undefined}
                  className={INPUT_CLASS}
                />
              }
            />
            <DetailField
              mode={mode}
              label="Ngày sinh"
              value={record.birth_date ? formatDate(record.birth_date) : ''}
              editor={
                <DateInput
                  label="Ngày sinh"
                  value={isoToDate(draft.birth_date)}
                  onChange={(d) =>
                    setDraft((x) => ({
                      ...x,
                      birth_date: dateToIso(d),
                      birth_year: d ? String(d.getFullYear()) : x.birth_year,
                    }))
                  }
                />
              }
            />
            <DetailField
              mode={mode}
              label="Năm sinh"
              required
              value={record.birth_year ?? ''}
              error={errors.birth_year ?? null}
              editor={
                <input
                  aria-label="Năm sinh"
                  inputMode="numeric"
                  value={draft.birth_year}
                  onChange={(e) => set('birth_year', e.target.value.replace(/\D/g, ''))}
                  aria-invalid={errors.birth_year ? true : undefined}
                  className={INPUT_CLASS}
                />
              }
            />
            <DetailField
              mode={mode}
              label="Khối"
              value={record.grade ? `Lớp ${record.grade}` : ''}
              editor={
                <OptionalSelect
                  label="Khối"
                  value={draft.grade}
                  onChange={(v) => set('grade', v)}
                  options={GRADE_OPTIONS}
                  placeholder="Chọn khối"
                />
              }
            />
            <DetailField
              mode={mode}
              label="Trường học"
              value={record.school ?? ''}
              editor={
                <input
                  aria-label="Trường học"
                  value={draft.school}
                  onChange={(e) => set('school', e.target.value)}
                  className={INPUT_CLASS}
                />
              }
            />
            <DetailField
              mode={mode}
              label="Mục tiêu"
              value={record.goal ?? ''}
              editor={
                <TextAreaField
                  label="Mục tiêu"
                  value={draft.goal}
                  onChange={(e) => set('goal', e.target.value)}
                />
              }
            />
            <DetailField
              mode="view"
              label="Phụ huynh"
              value={
                record.parent ? (
                  <Link
                    className="font-medium text-link hover:underline"
                    to={`/crm/phu-huynh/${record.parent.id}`}
                  >
                    {record.parent.full_name}
                  </Link>
                ) : (
                  ''
                )
              }
            />
            <DetailField mode="view" label="SĐT phụ huynh" value={record.parent?.phone ?? ''} />
            <DetailField
              mode="view"
              label="Tình trạng"
              hint="hệ thống tự đổi theo ghi danh"
              value={STUDENT_STATUS_LABEL[record.status]}
            />
            <DetailField
              mode="view"
              label="Cơ sở tiếp nhận"
              hint="chỉ Admin sửa"
              value={record.branch_code}
            />
            <DetailField
              mode="view"
              label="Đang học tại"
              hint="tự tính từ các lớp"
              value={record.studying_at.join(', ')}
            />
            <DetailField
              mode="view"
              label="Cập nhật lần cuối"
              value={formatDateTime(record.updated_at)}
            />
          </DetailSection>
        )}
        {tab === 'overview' && account.section}
        {tab === 'study' && <StudentStudyTab record={record} />}
        {tab === 'attendance' && <StudentAttendanceTab record={record} />}
        {tab === 'exam' && <StudentExamTab record={record} />}
        {tab === 'care' && <StudentCareTab />}
        {tab === 'upsale' && <UpsaleTab owner={{ key: 'student_id', id: record.id }} />}
        {tab === 'appointments' && <AppointmentTab owner={{ key: 'student_id', id: record.id }} />}
        {tab === 'tickets' && (
          <CustTickets
            owner={{ key: 'student_id', id: record.id }}
            ticketType={ticketType}
            onTypeChange={setTicketType}
          />
        )}
      </RecordDetail>
      {account.dialogs}
      {appointments.dialogs}
      {canMerge && (
        <MergeDialog
          open={mergeOpen}
          onOpenChange={setMergeOpen}
          entity="STUDENT"
          current={{
            id: record.id,
            code: record.code,
            label: record.full_name,
            phone: formatPhone(record.parent?.phone ?? ''),
          }}
          onMerged={(keepId, keepCode) => {
            toast({ title: `Đã gộp vào ${keepCode}.` });
            if (keepId === record.id) void refresh();
            else void navigate(studentPath(keepId), { replace: true });
          }}
        />
      )}
    </>
  );
}
