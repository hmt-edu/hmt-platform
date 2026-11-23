// KH-05 Học sinh (hồ sơ 360°, khuôn K06): thông tin, ghi danh và lớp, điểm danh, điểm kiểm tra, phiếu kiểm tra đầu vào; nút liên kết có số đếm;
// ghi chú và hoạt động (Chatter). Không có Tạo tay (R-CRM-27). Sửa (KH-06) gọi update_student; cơ sở tiếp nhận chỉ xem (R-CRM-28). Gộp, Tạo ticket, tài khoản học tập: chưa làm, hiện mờ kèm chú thích.
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
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { Tag } from '../../ui/Data';
import { Spinner, StateView } from '../../ui/Feedback';
import { CustTabs } from './CustTabs';
import { CustTickets } from './CustTickets';
import { ATTENDANCE_LABEL, STUDENT_STATUS_LABEL, type StudentRecord } from './custTypes';
import { studentPath } from './custConfig';
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
  useCrumbTail(`${record.full_name} · ${record.code}`);
  const merged = record.record_status === 'DA_GOP';
  const summary = Object.entries(record.attendance_summary);
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const canEdit = access.can('STUDENT', 'SUA') && !merged;
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
              unavailable: 'Ticket chăm sóc (CS-04) làm sau',
            },
            {
              kind: 'action',
              label: 'Cấp tài khoản',
              onSelect: () => undefined,
              unavailable: 'Tài khoản học tập chưa bật',
            },
          ],
        }}
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
        ]}
        aside={
          <RecordChatter
            entityType="STUDENT"
            entityId={record.id}
            format={FORMAT}
            createdText="Tạo học sinh."
            canWrite={!merged}
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
            { key: 'care', label: 'Chăm sóc', note: 'Chưa có dữ liệu (chăm sóc làm sau)' },
            access.can('TICKET', 'XEM')
              ? { key: 'tickets', label: 'Đề nghị & khiếu nại' }
              : {
                  key: 'tickets',
                  label: 'Đề nghị & khiếu nại',
                  note: 'Bạn không có quyền xem ticket',
                },
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
        {tab === 'study' &&
          (record.enrollments.length === 0 ? (
            <p className="py-2 text-fg-muted">Chưa có ghi danh.</p>
          ) : (
            <ul className="flex flex-col divide-y divide-border">
              {record.enrollments.map((e) => (
                <li key={e.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
                  <span>
                    <span className="font-medium">{e.code}</span>{' '}
                    <span className="text-fg-muted">{e.subject_name ?? e.subject_code}</span>
                  </span>
                  <span className="text-caption text-fg-muted">
                    {e.status_name ?? e.status_code}
                    {e.class_id && e.class_code ? (
                      <>
                        {' · '}
                        <Link className="text-link hover:underline" to={`/crm/lop/${e.class_id}`}>
                          {e.class_code}
                        </Link>
                      </>
                    ) : (
                      ' · chưa xếp lớp'
                    )}
                    {` · còn ${e.hours_left} giờ`}
                  </span>
                </li>
              ))}
            </ul>
          ))}
        {tab === 'attendance' && (
          <div className="flex flex-col gap-2">
            <p className="text-fg-muted">
              {summary.length === 0
                ? 'Chưa có điểm danh.'
                : summary.map(([k, n]) => `${ATTENDANCE_LABEL[k] ?? k}: ${n}`).join(' · ')}
            </p>
            <ul className="flex flex-col divide-y divide-border">
              {record.attendance.map((a, i) => (
                <li key={i} className="flex flex-wrap justify-between gap-2 py-1.5">
                  <span>
                    {formatDate(a.session_date)} {a.start_time.slice(0, 5)} · {a.class_code}
                  </span>
                  <span className="text-caption text-fg-muted">
                    {ATTENDANCE_LABEL[a.status ?? 'CHUA'] ?? a.status}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
        {tab === 'tickets' && <CustTickets owner={{ key: 'student_id', id: record.id }} />}
        {tab === 'exam' && (
          <div className="flex flex-col gap-3">
            <DetailSection title="Điểm kiểm tra trong lớp">
              {record.exam_scores.length === 0 ? (
                <p className="py-2 text-fg-muted">Chưa có điểm kiểm tra.</p>
              ) : (
                <ul className="flex flex-col divide-y divide-border">
                  {record.exam_scores.map((x, i) => (
                    <li key={i} className="flex flex-wrap justify-between gap-2 py-1.5">
                      <span>
                        {formatDate(x.session_date)} · {x.class_code}
                      </span>
                      <span className="tabular font-medium">
                        {x.total_score ?? '—'}
                        {x.max_score ? ` / ${x.max_score}` : ''}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </DetailSection>
            <DetailSection title="Phiếu kiểm tra đầu vào">
              {record.tests.length === 0 ? (
                <p className="py-2 text-fg-muted">Chưa có phiếu kiểm tra.</p>
              ) : (
                <ul className="flex flex-col divide-y divide-border">
                  {record.tests.map((t) => (
                    <li key={t.id} className="flex flex-wrap justify-between gap-2 py-1.5">
                      <Link
                        to={`/crm/phieu-kiem-tra/${t.id}`}
                        className="font-medium text-link hover:underline"
                      >
                        {t.code}
                      </Link>
                      <span className="text-caption text-fg-muted">
                        {t.scheduled_at ? formatDate(t.scheduled_at) : '—'}
                        {t.score !== null ? ` · điểm ${t.score}` : ''}
                      </span>
                    </li>
                  ))}
                </ul>
              )}
            </DetailSection>
          </div>
        )}
      </RecordDetail>
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
