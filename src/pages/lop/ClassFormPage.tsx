// LOP-03 Tạo / sửa lớp (khuôn K07, khung RecordDetail): thông tin chung, thời gian và địa điểm, giáo viên và trợ giảng, CSKH, nhóm lớp (tuỳ chọn), Time Table 7 thứ xếp dọc
// (mỗi thứ nhiều khung giờ; mỗi khung có giáo viên, trợ giảng, phòng, cách lặp, buổi đầu). Mã lớp tự cấp, không sửa các trường nằm trong mã.
// Nháp, Từ chối: sửa mọi trường được phép. Đã trình, Đã xác nhận, Đã duyệt: chỉ Time Table (Đã duyệt: áp dụng từ ngày, xem trước số buổi đổi).
// Lưu nháp xong bấm Trình ở màn lớp (R-LOP-02, R-LOP-03). Trùng phòng, trùng giáo viên chỉ cảnh báo, không chặn (R-LOP-08).
import { useCrumbTail } from '../../layout/CrumbTail';
import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router';
import { Button } from '../../ui/Button';
import { INPUT_CLASS } from '../../ui/Field';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useAuth } from '../../lib/auth/authContext';
import { errorOf, rpc, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { useToast } from '../../ui/toastContext';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { ClassChatter } from './ClassChatter';
import { classPath } from './classConfig';
import {
  EMPTY_FORM,
  GROUP_SUBJECTS,
  PRIVATE_TYPE,
  createPayload,
  errorSummary,
  firstDateOnOrAfter,
  formFromRecord,
  infoPayload,
  newSlot,
  organizationText,
  prefillFromParams,
  longSlotWarning,
  slotSummary,
  teacherOptionLabel,
  slotsPayload,
  validateForm,
  type ClassFormState,
  type SlotDraft,
} from './classForm';
import { WEEKDAY_LABEL } from './classLabels';
import { editKind } from './classTransitions';
import type { ClassRecord } from './classTypes';
import {
  useClassCatalogs,
  useClassEndPreview,
  useClassFormOptions,
  useCurriculumFrames,
  useCurriculumLessons,
  useClassRecord,
  useRefreshClasses,
} from './useClassData';

type Warnings = { message?: string }[];

export function ClassFormPage() {
  const { id } = useParams();
  const record = useClassRecord(id);
  if (id === undefined) return <FormView record={null} />;
  if (record.isPending) {
    return (
      <div className="flex min-h-40 items-center justify-center p-4">
        <Spinner />
      </div>
    );
  }
  if (record.isError) {
    return (
      <StateView
        kind="error"
        title="Không tải được lớp"
        actions={
          <Link to="/crm/lop" className="font-medium text-link hover:underline">
            Về danh sách Lớp
          </Link>
        }
      >
        {errorOf(record.error).message}
      </StateView>
    );
  }
  return <FormView key={record.data.id} record={record.data} />;
}

function FormView({ record }: { record: ClassRecord | null }) {
  const supabase = useDb();
  const access = useAccess();
  const { claims } = useAuth();
  const toast = useToast();
  const navigate = useNavigate();
  const refresh = useRefreshClasses();
  const [searchParams] = useSearchParams();
  useCrumbTail(record ? `${record.code} · Sửa` : 'Tạo lớp mới');
  const catalogs = useClassCatalogs();
  const editing = record !== null;
  const kind = record ? editKind(record.status_code) : 'FULL';
  const full = kind === 'FULL';
  const approvedEdit = record?.status_code === 'DA_DUYET';
  const infoOnlyCskh = approvedEdit; // Đã duyệt: thông tin khoá, chỉ CSKH và sĩ số tối đa (R-LOP-02)
  const initial = useMemo<ClassFormState>(() => {
    if (record) return formFromRecord(record);
    // Cơ sở mặc định: cơ sở đang chọn; chưa chọn thì cơ sở của người dùng (R-LOP-06: nhân sự chỉ mở lớp cơ sở mình).
    const own = access.allBranches.find((b) => b.code === claims?.branchCode)?.id;
    const branch =
      access.selectedBranch !== 'all'
        ? access.selectedBranch
        : (own ?? access.allBranches[0]?.id ?? '');
    // «Tạo lớp còn lại cho nhóm này»: nhóm, cơ sở, năm, khối, phân loại điền sẵn từ địa chỉ; môn, giáo viên, lịch để trống.
    return { ...EMPTY_FORM, branchId: branch, ...prefillFromParams(searchParams) };
  }, [record, access, claims?.branchCode, searchParams]);
  const [form, setForm] = useState<ClassFormState>(initial);
  const [tried, setTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<Warnings>([]);
  const [preview, setPreview] = useState<string | null>(null);
  const options = useClassFormOptions(form.branchId);
  const opt = options.data;
  const errors = validateForm(form, full, approvedEdit);
  const dirty = JSON.stringify(form) !== JSON.stringify(initial);
  const set = <K extends keyof ClassFormState>(key: K, value: ClassFormState[K]) =>
    setForm((f) => ({ ...f, [key]: value }));
  const err = (key: string) => (tried ? errors[key] : undefined);

  const years = useMemo(() => {
    const y = new Date().getFullYear();
    return [y - 1, y, y + 1].map((a) => ({
      value: `${String(a).slice(2)}${String(a + 1).slice(2)}`,
      label: `${a}-${a + 1}`,
    }));
  }, []);

  function setSlot(key: string, patch: Partial<SlotDraft>) {
    setForm((f) => ({ ...f, slots: f.slots.map((s) => (s.key === key ? { ...s, ...patch } : s)) }));
  }

  async function save() {
    setTried(true);
    if (Object.keys(errors).length > 0 || busy) return;
    setBusy(true);
    setSaveError(null);
    try {
      let classId = record?.id ?? '';
      let warn: Warnings = [];
      if (!editing) {
        let groupId: string | null = form.groupMode === 'EXISTING' ? form.groupId : null;
        if (form.groupMode === 'NEW') {
          groupId = await rpc<string>(supabase, 'create_class_group', {
            p_branch_id: form.branchId,
            p_grade_code: form.gradeCode,
            p_display_name: form.groupName.trim() || null,
          });
        }
        const created = await rpc<{ id: string; warnings?: Warnings }>(supabase, 'create_class', {
          p_data: createPayload(form, groupId),
        });
        classId = created.id;
        warn = created.warnings ?? [];
      } else {
        await rpc<null>(supabase, 'save_class_info', {
          p_id: record.id,
          p_data: infoPayload(form, record.status_code),
        });
        if (kind !== null && !infoOnlyCskh) {
          const result = await rpc<{ warnings?: Warnings }>(supabase, 'save_class_timetable', {
            p_id: record.id,
            p_slots: slotsPayload(form.slots),
            p_apply_from: null,
            p_preview: false,
          });
          warn = result.warnings ?? [];
        } else if (approvedEdit) {
          const result = await rpc<{ warnings?: Warnings }>(supabase, 'save_class_timetable', {
            p_id: record.id,
            p_slots: slotsPayload(form.slots),
            p_apply_from: form.applyFrom,
            p_preview: false,
          });
          warn = result.warnings ?? [];
        }
      }
      void refresh();
      setWarnings(warn);
      toast({ title: editing ? 'Đã lưu lớp.' : 'Đã lưu nháp. Bấm Trình ở màn lớp để gửi duyệt.' });
      if (warn.length === 0) void navigate(classPath(classId));
      else setForm(initial);
    } catch (e) {
      setSaveError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  async function previewChange() {
    if (!record || !form.applyFrom || busy) return;
    setBusy(true);
    setSaveError(null);
    try {
      const r = await rpc<{ replaced?: number; created?: number }>(
        supabase,
        'save_class_timetable',
        {
          p_id: record.id,
          p_slots: slotsPayload(form.slots),
          p_apply_from: form.applyFrom,
          p_preview: true,
        },
      );
      setPreview(
        `Đổi ${r.replaced ?? 0} buổi chưa diễn ra, sinh mới ${r.created ?? 0} buổi từ ${form.applyFrom}.`,
      );
    } catch (e) {
      setSaveError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const opts = (catalog: string) => catalogs.options(catalog);
  const groupsForGrade = (opt?.groups ?? []).filter((g) => g.grade_code === form.gradeCode);

  const summary = slotSummary(form.slots, opt);
  // Xem trước ngày kết thúc dự kiến từ khung giờ đang nhập (chưa lưu): hàm đọc ở máy chủ, gọi sau khi ngừng gõ. Lớp đã có buổi thì hiện ngày đã lưu.
  const slotsReady =
    form.slots.length > 0 && form.slots.every((x) => x.start && x.end && x.firstDate);
  const previewKey = useDebounced(
    JSON.stringify({
      branchId: form.branchId,
      startDate: form.startDate,
      totalSessions: Number(form.totalSessions),
      slots: slotsPayload(form.slots),
    }),
  );
  const previewArgs = useMemo(
    () =>
      JSON.parse(previewKey) as {
        branchId: string;
        startDate: string;
        totalSessions: number;
        slots: unknown[];
      },
    [previewKey],
  );
  const endPreview = useClassEndPreview({ ...previewArgs, enabled: full && slotsReady });
  const endText = !full
    ? record?.expected_end_date
      ? formatDate(record.expected_end_date)
      : ''
    : endPreview.isError
      ? errorOf(endPreview.error).message
      : endPreview.data
        ? formatDate(endPreview.data)
        : endPreview.isFetching
          ? 'Đang tính…'
          : 'Nhập ngày bắt đầu, số buổi và khung giờ để xem trước';
  // Khung chương trình khớp môn, khối, phân loại, năm học; giá trị cũ ngoài danh sách vẫn hiện để không mất dữ liệu.
  const frames = useCurriculumFrames(
    form.subjectCode,
    form.gradeCode,
    form.typeCode,
    form.yearCode,
  );
  const frameList = frames.data ?? [];
  const frameId = frameList.find((f) => f.code === form.curriculumRef)?.id ?? '';
  const lessons = useCurriculumLessons(frameId);
  const keepOld = (value: string, list: { value: string; label: string }[]) =>
    value !== '' && !list.some((o) => o.value === value)
      ? [...list, { value, label: `${value} (giá trị cũ)` }]
      : list;
  const frameOptions = keepOld(
    form.curriculumRef,
    frameList.map((f) => ({ value: f.code, label: `${f.code} · bản ${f.version}` })),
  );
  const lessonOptions = keepOld(
    form.startLesson,
    (lessons.data ?? []).map((l) => ({ value: l.code, label: `${l.code} · ${l.title}` })),
  );
  const mode: DetailMode = editing ? 'edit' : 'create';
  const saveLabel = editing ? 'Lưu thay đổi' : 'Lưu nháp';
  const summaryText = tried ? errorSummary(errors, form.slots, saveLabel) : null;
  // Lớp bị từ chối: lý do lấy từ sự kiện từ chối mới nhất (khung LOP03_sua).
  const rejected =
    record?.status_code === 'TU_CHOI'
      ? record.events
          .filter((e) => e.event_code === 'TU_CHOI')
          .sort((a, b) => b.created_at.localeCompare(a.created_at))[0]
      : undefined;
  const nameOf = (list: { value: string; label: string }[], value: string) =>
    list.find((o) => o.value === value)?.label ?? value;
  const branchOptions = access.allBranches.map((b) => ({
    value: b.id,
    label: `${b.code} ${b.name}`,
  }));
  const select = (p: {
    label: string;
    value: string;
    options: { value: string; label: string }[];
    onChange: (v: string) => void;
    required?: boolean;
    errorKey?: string;
    locked?: boolean;
    disabled?: boolean;
    placeholder?: string;
    hint?: string;
  }) => (
    <DetailField
      mode={p.locked ? 'view' : mode}
      label={p.label}
      hint={p.hint}
      required={p.required}
      value={p.value === '' ? '' : nameOf(p.options, p.value)}
      error={p.errorKey ? (err(p.errorKey) ?? null) : null}
      editor={
        <select
          aria-label={p.label}
          aria-invalid={p.errorKey && err(p.errorKey) ? true : undefined}
          className={INPUT_CLASS}
          value={p.value}
          disabled={p.disabled}
          onChange={(e) => p.onChange(e.target.value)}
        >
          <option value="">{p.placeholder ?? '— Chọn —'}</option>
          {p.options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      }
    />
  );
  // Lớp chung mà môn, khối, phân loại, năm học đã chọn chưa có khung nào: nói rõ và chỉ nơi tạo, không để biểu mẫu kẹt im lặng.
  const missingFrame =
    full &&
    form.typeCode !== PRIVATE_TYPE &&
    frames.data !== undefined &&
    frameList.length === 0 &&
    form.curriculumRef === '';
  const input = (p: {
    label: string;
    value: string;
    onChange: (v: string) => void;
    type?: 'text' | 'number' | 'date';
    min?: number;
    required?: boolean;
    errorKey?: string;
    locked?: boolean;
    hint?: string;
  }) => (
    <DetailField
      mode={p.locked ? 'view' : mode}
      label={p.label}
      hint={p.hint}
      required={p.required}
      value={p.type === 'date' && p.value ? formatDate(p.value) : p.value}
      error={p.errorKey ? (err(p.errorKey) ?? null) : null}
      editor={
        <input
          aria-label={p.label}
          aria-invalid={p.errorKey && err(p.errorKey) ? true : undefined}
          type={p.type ?? 'text'}
          min={p.min}
          className={INPUT_CLASS}
          value={p.value}
          onChange={(e) => p.onChange(e.target.value)}
        />
      }
    />
  );
  const readOnly = (label: string, value: string) => (
    <DetailField mode="view" label={label} value={value} />
  );

  return (
    <RecordDetail
      kind="Lớp"
      title={editing ? record.code : 'Tạo lớp mới'}
      mode={mode}
      dirty={dirty && !busy}
      saving={busy}
      saveLabel={saveLabel}
      stickyHeader
      onEdit={() => undefined}
      onSave={() => void save()}
      onCancel={() => void navigate(editing ? classPath(record.id) : '/crm/lop')}
      aside={editing ? <ClassChatter record={record} /> : null}
      asideLabel="Ghi chú và hoạt động"
    >
      <div className="flex flex-col gap-5">
        <p className="text-caption text-fg-muted">
          {editing ? record.status_name : 'Nháp'}. Mã lớp tự cấp khi lưu.
        </p>
        {rejected && (
          <Alert
            tone="warning"
            title={`Lớp bị từ chối${rejected.actor_name ? ` bởi ${rejected.actor_name}` : ''}`}
          >
            {rejected.note ? `Lý do: ${rejected.note}. ` : ''}Sửa rồi bấm {saveLabel}; ở màn lớp bấm
            «Đưa về Nháp» rồi trình lại.
          </Alert>
        )}
        {summaryText && <Alert tone="danger">{summaryText}</Alert>}
        {saveError && <Alert tone="danger">{saveError}</Alert>}
        {warnings.length > 0 && (
          <Alert tone="warning" title="Đã lưu, có cảnh báo (không chặn)">
            <ul className="list-disc pl-5">
              {warnings.map((w, i) => (
                <li key={i}>{w.message}</li>
              ))}
            </ul>
            <Button
              size="sm"
              className="mt-2"
              onClick={() => void navigate(classPath(record?.id ?? ''))}
              disabled={!record}
            >
              Về hồ sơ lớp
            </Button>
          </Alert>
        )}
        {!full && kind !== null && (
          <Alert tone="info">
            {approvedEdit
              ? 'Lớp đã duyệt: sửa được Time Table (chọn ngày áp dụng), CSKH phụ trách và sĩ số tối đa. Buổi đã diễn ra và buổi chỉnh lẻ tay giữ nguyên.'
              : 'Lớp đang chờ duyệt: chỉ sửa được Time Table.'}
          </Alert>
        )}

        {missingFrame && (
          <Alert tone="warning">
            Môn/khối này chưa có khung chương trình, tạo ở{' '}
            <Link
              to="/crm/cau-hinh/khung-chuong-trinh"
              className="font-medium text-link hover:underline"
            >
              Cấu hình › Khung chương trình
            </Link>
            .
          </Alert>
        )}

        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin chung">
            {readOnly('Mã lớp', record?.code ?? 'Tự cấp khi lưu')}
            {input({
              label: 'Mã lớp cũ (Sheet)',
              value: form.legacyRef,
              locked: !full,
              onChange: (v) => set('legacyRef', v),
            })}
            {select({
              label: 'Cơ sở',
              required: true,
              errorKey: 'branchId',
              locked: editing,
              value: form.branchId,
              options: branchOptions,
              onChange: (v) =>
                setForm({
                  ...form,
                  branchId: v,
                  cskhId: '',
                  groupId: '',
                  slots: form.slots.map((s) => ({
                    ...s,
                    teacherId: '',
                    assistantId: '',
                    roomId: '',
                  })),
                }),
            })}
            {select({
              label: 'Năm học',
              required: true,
              errorKey: 'yearCode',
              locked: editing,
              value: form.yearCode,
              options: years,
              onChange: (v) => set('yearCode', v),
            })}
            {select({
              label: 'Môn học',
              required: true,
              errorKey: 'subjectCode',
              locked: editing,
              value: form.subjectCode,
              options: opts('SUBJECT'),
              onChange: (v) => set('subjectCode', v),
            })}
            {select({
              label: 'Khối',
              required: true,
              errorKey: 'gradeCode',
              locked: editing,
              value: form.gradeCode,
              options: opts('GRADE'),
              onChange: (v) => setForm({ ...form, gradeCode: v, groupId: '' }),
            })}
            {select({
              label: 'Phân loại',
              required: true,
              errorKey: 'typeCode',
              locked: editing,
              value: form.typeCode,
              options: opts('CLASS_TYPE'),
              onChange: (v) =>
                setForm({
                  ...form,
                  typeCode: v,
                  levelCode: v === PRIVATE_TYPE ? '' : form.levelCode,
                }),
            })}
            {form.typeCode !== PRIVATE_TYPE &&
              select({
                label: 'Trình độ',
                required: true,
                errorKey: 'levelCode',
                locked: editing,
                value: form.levelCode,
                options: opts('LEVEL'),
                onChange: (v) => set('levelCode', v),
              })}
            {select({
              label: 'Hình thức học',
              required: true,
              errorKey: 'deliveryModeCode',
              locked: !full,
              value: form.deliveryModeCode,
              options: opts('CLASS_DELIVERY'),
              onChange: (v) => set('deliveryModeCode', v),
            })}
            {/* Tổ chức lớp tự suy từ Phân loại, không phải ô nhập (anh Trường chốt 20/11). */}
            {readOnly('Tổ chức lớp', organizationText(form.typeCode))}
          </DetailSection>

          <div className="flex min-w-0 flex-col gap-6">
            <DetailSection title="Thời gian và địa điểm">
              {select({
                label: 'Khung chương trình',
                required: form.typeCode !== '' && form.typeCode !== PRIVATE_TYPE,
                errorKey: 'curriculumRef',
                locked: !full,
                value: form.curriculumRef,
                options: frameOptions,
                hint: 'Chọn môn, khối, phân loại, năm học trước; khung lấy ở Cấu hình, Khung chương trình.',
                onChange: (v) => setForm({ ...form, curriculumRef: v, startLesson: '' }),
              })}
              {select({
                label: 'Bài bắt đầu',
                locked: !full,
                disabled: frameId === '',
                value: form.startLesson,
                options: lessonOptions,
                onChange: (v) => set('startLesson', v),
              })}
              {input({
                label: 'Tổng số buổi',
                required: true,
                errorKey: 'totalSessions',
                type: 'number',
                min: 1,
                locked: !full,
                value: form.totalSessions,
                onChange: (v) => set('totalSessions', v),
              })}
              {input({
                label: 'Ngày bắt đầu',
                required: true,
                errorKey: 'startDate',
                type: 'date',
                locked: !full,
                value: form.startDate,
                onChange: (v) =>
                  setForm({
                    ...form,
                    startDate: v,
                    slots: form.slots.map((s) => ({
                      ...s,
                      firstDate: firstDateOnOrAfter(v, s.weekday) || s.firstDate,
                    })),
                  }),
              })}
              {readOnly('Kết thúc dự kiến', endText)}
              {readOnly('Lịch học', summary.schedule)}
              {readOnly('Phòng học', summary.rooms)}
            </DetailSection>
            <DetailSection title="Giáo viên và trợ giảng">
              {readOnly('Giáo viên', summary.teachers)}
              {readOnly('Trợ giảng', summary.assistants)}
            </DetailSection>
            <DetailSection title="Vận hành và chăm sóc khách hàng">
              {select({
                label: 'CSKH phụ trách',
                value: form.cskhId,
                options: (opt?.cskh ?? []).map((u) => ({ value: u.id, label: u.name })),
                placeholder: '— Chọn CSKH —',
                onChange: (v) => set('cskhId', v),
              })}
              {input({
                label: 'Sĩ số tối đa',
                type: 'number',
                min: 0,
                errorKey: 'maxStudents',
                hint: '0 hoặc để trống là không giới hạn',
                value: form.maxStudents,
                onChange: (v) => set('maxStudents', v),
              })}
              {readOnly('Sĩ số hiện tại', String(record?.students.length ?? 0))}
            </DetailSection>
          </div>
        </div>

        {!editing && (
          <section aria-labelledby="lop3-group" className="flex flex-col gap-2">
            <h3
              id="lop3-group"
              className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
            >
              Nhóm lớp (tuỳ chọn)
            </h3>
            <div role="radiogroup" aria-label="Nhóm lớp" className="flex flex-wrap gap-3">
              {(
                [
                  ['NONE', 'Không thuộc nhóm'],
                  ['EXISTING', 'Gắn vào nhóm có sẵn'],
                  ['NEW', 'Tạo nhóm mới'],
                ] as const
              ).map(([value, label]) => (
                <label key={value} className="flex items-center gap-1.5">
                  <input
                    type="radio"
                    name="group-mode"
                    checked={form.groupMode === value}
                    onChange={() => set('groupMode', value)}
                  />
                  {label}
                </label>
              ))}
            </div>
            {err('groupMode') && (
              <p role="alert" className="text-caption text-on-danger-subtle">
                {err('groupMode')}
              </p>
            )}
            <dl className="max-w-2xl">
              {form.groupMode === 'EXISTING' &&
                select({
                  label: 'Nhóm có sẵn (cùng cơ sở, cùng khối)',
                  errorKey: 'groupId',
                  value: form.groupId,
                  options: groupsForGrade.map((g) => ({
                    value: g.id,
                    label: g.name ?? 'Nhóm chưa đặt tên chung',
                  })),
                  placeholder: '— Chọn nhóm —',
                  onChange: (v) => set('groupId', v),
                })}
              {form.groupMode === 'NEW' &&
                input({
                  label: 'Tên chung của nhóm',
                  hint: 'Không bắt buộc. Chỉ là tham chiếu (ví dụ tên cũ 9M1), hiện nhỏ dưới mã lớp.',
                  value: form.groupName,
                  onChange: (v) => set('groupName', v),
                })}
            </dl>
            <p className="text-caption text-fg-muted">
              Nhóm không có mã riêng; chỉ môn {GROUP_SUBJECTS.join(', ')} (Đại, Hình). Mỗi lớp trong
              nhóm vẫn độc lập.
            </p>
          </section>
        )}

        <section aria-labelledby="lop3-tt" className="flex flex-col gap-3">
          <h3
            id="lop3-tt"
            className="text-caption font-semibold tracking-wide text-fg-muted uppercase"
          >
            Time Table
          </h3>
          {approvedEdit && (
            <div className="flex flex-wrap items-end gap-3">
              <dl className="w-full max-w-2xl">
                {input({
                  label: 'Áp dụng thay đổi Time Table từ ngày',
                  required: true,
                  errorKey: 'applyFrom',
                  type: 'date',
                  value: form.applyFrom,
                  onChange: (v) => {
                    set('applyFrom', v);
                    setPreview(null);
                  },
                })}
              </dl>
              <p className="w-full text-caption text-fg-muted">
                Buổi trước ngày này và buổi đã diễn ra giữ nguyên. Buổi đã chỉnh lẻ tay cũng giữ.
              </p>
              <Button onClick={() => void previewChange()} disabled={!form.applyFrom || busy}>
                Xem trước số buổi đổi
              </Button>
              {preview && (
                <p role="status" className="text-body">
                  {preview}
                </p>
              )}
            </div>
          )}
          {[1, 2, 3, 4, 5, 6, 7].map((day) => {
            const slots = form.slots.filter((s) => s.weekday === day);
            const bad = slots.filter((s) => err(`slot-${s.key}`) !== undefined).length;
            return (
              <section
                key={day}
                aria-label={`Time Table ${WEEKDAY_LABEL[day] ?? ''}`}
                className="flex flex-col gap-2 border-t border-border pt-2"
              >
                <h4 className="font-semibold">
                  {WEEKDAY_LABEL[day]}
                  {slots.length > 0 && <span className="text-fg-muted"> ({slots.length})</span>}
                  {bad > 0 && <span className="text-on-danger-subtle"> · {bad} lỗi</span>}
                </h4>
                {slots.length === 0 ? (
                  <p className="text-caption text-fg-muted">
                    Chưa có khung giờ nào cho {WEEKDAY_LABEL[day]}. Bấm Thêm khung giờ ở dưới.
                  </p>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[56rem] border-collapse text-left text-body">
                      <caption className="sr-only">Khung giờ của {WEEKDAY_LABEL[day]}</caption>
                      <thead className="text-caption text-fg-muted">
                        <tr>
                          {[
                            'Giờ bắt đầu',
                            'Giờ kết thúc',
                            'Giáo viên',
                            'Trợ giảng',
                            'Phòng',
                            'Cách lặp (tuần)',
                            'Buổi đầu',
                          ].map((h) => (
                            <th key={h} scope="col" className="px-1 pb-1 font-medium">
                              {h}
                            </th>
                          ))}
                          <th scope="col" className="px-1 pb-1">
                            <span className="sr-only">Xoá</span>
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {slots.map((s) => (
                          <SlotRow
                            key={s.key}
                            s={s}
                            dayLabel={WEEKDAY_LABEL[day] ?? ''}
                            opt={opt}
                            error={err(`slot-${s.key}`)}
                            onChange={(patch) => setSlot(s.key, patch)}
                            onRemove={() =>
                              setForm((f) => ({
                                ...f,
                                slots: f.slots.filter((x) => x.key !== s.key),
                              }))
                            }
                          />
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
                <div>
                  <Button
                    size="sm"
                    icon="plus"
                    aria-label={`Thêm khung giờ ${WEEKDAY_LABEL[day] ?? ''}`}
                    onClick={() =>
                      setForm((f) => ({ ...f, slots: [...f.slots, newSlot(day, f.startDate)] }))
                    }
                  >
                    Thêm khung giờ
                  </Button>
                </div>
              </section>
            );
          })}
          <p className="text-caption text-fg-muted">
            Lưu nháp xong, bấm Trình ở màn lớp. Trình lớp bắt buộc có Time Table. Khung lặp mỗi 2
            tuần thì «Buổi đầu» quyết định tuần nào có buổi.
          </p>
        </section>
      </div>
    </RecordDetail>
  );
}

function SlotRow({
  s,
  dayLabel,
  opt,
  error,
  onChange,
  onRemove,
}: {
  s: SlotDraft;
  dayLabel: string;
  opt:
    | {
        teachers: { id: string; name: string }[];
        assistants: { id: string; name: string }[];
        rooms: { id: string; name: string }[];
      }
    | undefined;
  error: string | undefined;
  onChange: (patch: Partial<SlotDraft>) => void;
  onRemove: () => void;
}) {
  return (
    <>
      <tr className="align-top">
        <td className="p-1">
          <input
            type="time"
            className={INPUT_CLASS}
            value={s.start}
            onChange={(e) => onChange({ start: e.target.value })}
            aria-label={`${dayLabel} giờ bắt đầu`}
          />
        </td>
        <td className="p-1">
          <input
            type="time"
            className={INPUT_CLASS}
            value={s.end}
            onChange={(e) => onChange({ end: e.target.value })}
            aria-label={`${dayLabel} giờ kết thúc`}
          />
        </td>
        <td className="p-1">
          <PersonCell
            label={`${dayLabel} giáo viên`}
            value={s.teacherId}
            people={opt?.teachers ?? []}
            onChange={(v) => onChange({ teacherId: v })}
          />
        </td>
        <td className="p-1">
          <PersonCell
            label={`${dayLabel} trợ giảng`}
            value={s.assistantId}
            people={opt?.assistants ?? []}
            onChange={(v) => onChange({ assistantId: v })}
          />
        </td>
        <td className="p-1">
          <PersonCell
            label={`${dayLabel} phòng`}
            value={s.roomId}
            people={opt?.rooms ?? []}
            onChange={(v) => onChange({ roomId: v })}
          />
        </td>
        <td className="p-1">
          <input
            type="number"
            min={1}
            className={INPUT_CLASS}
            value={s.repeatWeeks}
            onChange={(e) => onChange({ repeatWeeks: e.target.value })}
            aria-label={`${dayLabel} cách lặp (tuần)`}
          />
        </td>
        <td className="p-1">
          <input
            type="date"
            className={INPUT_CLASS}
            value={s.firstDate}
            onChange={(e) => onChange({ firstDate: e.target.value })}
            aria-label={`${dayLabel} buổi đầu`}
          />
        </td>
        <td className="p-1">
          <Button size="sm" onClick={onRemove}>
            Xoá
          </Button>
        </td>
      </tr>
      {!error && longSlotWarning(s.start, s.end) && (
        <tr>
          <td colSpan={8} role="status" className="px-1 pb-2 text-caption text-on-warning-subtle">
            {longSlotWarning(s.start, s.end)}
          </td>
        </tr>
      )}
      {error && (
        <tr>
          <td colSpan={8} role="alert" className="px-1 pb-2 text-caption text-on-danger-subtle">
            {error}
          </td>
        </tr>
      )}
    </>
  );
}

function PersonCell({
  label,
  value,
  people,
  onChange,
}: {
  label: string;
  value: string;
  people: {
    id: string;
    name: string;
    has_profile?: boolean | undefined;
    subject_names?: string[] | undefined;
    grade_names?: string[] | undefined;
  }[];
  onChange: (v: string) => void;
}) {
  return (
    <select
      className={INPUT_CLASS}
      aria-label={label}
      value={value}
      onChange={(e) => onChange(e.target.value)}
    >
      <option value="">— Chọn —</option>
      {people.map((p) => (
        <option key={p.id} value={p.id}>
          {teacherOptionLabel(p)}
        </option>
      ))}
    </select>
  );
}
