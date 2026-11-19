// LOP-03 Tạo / sửa lớp (khuôn K07): thông tin chung, thời gian và địa điểm, giáo viên và trợ giảng, CSKH, nhóm lớp (tuỳ chọn), Time Table theo thứ
// (mỗi thứ nhiều khung giờ; mỗi khung có giáo viên, trợ giảng, phòng, cách lặp, buổi đầu). Mã lớp tự cấp, không sửa các trường nằm trong mã.
// Nháp, Từ chối: sửa mọi trường được phép. Đã trình, Đã xác nhận, Đã duyệt: chỉ Time Table (Đã duyệt: áp dụng từ ngày, xem trước số buổi đổi).
// Lưu nháp xong bấm Trình ở màn lớp (R-LOP-02, R-LOP-03). Trùng phòng, trùng giáo viên chỉ cảnh báo, không chặn (R-LOP-08).
import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { Button } from '../../ui/Button';
import { UnsavedGuard } from '../../ui/Dialogs';
import { Field, INPUT_CLASS, TextField } from '../../ui/Field';
import { Tabs } from '../../ui/Overlays';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { useAuth } from '../../lib/auth/authContext';
import { errorOf, rpc, useDb } from '../../lib/db';
import { useAccess } from '../../nav/AccessContext';
import { useToast } from '../../ui/toastContext';
import { classPath } from './classConfig';
import {
  EMPTY_FORM,
  GROUP_SUBJECTS,
  PRIVATE_TYPE,
  createPayload,
  firstDateOnOrAfter,
  formFromRecord,
  infoPayload,
  newSlot,
  longSlotWarning,
  slotSummary,
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
    return { ...EMPTY_FORM, branchId: branch };
  }, [record, access, claims?.branchCode]);
  const [form, setForm] = useState<ClassFormState>(initial);
  const [tried, setTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<Warnings>([]);
  const [preview, setPreview] = useState<string | null>(null);
  const options = useClassFormOptions(form.branchId);
  const opt = options.data;
  // Tab thứ đang mở của Time Table: mặc định thứ đầu tiên đã có khung giờ, không có thì Thứ 2.
  const [dayTab, setDayTab] = useState(() => String(form.slots[0]?.weekday ?? 1));
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
    // Lỗi ở khung giờ của thứ khác tab đang mở: chuyển sang tab có lỗi đầu tiên để người dùng thấy.
    const badSlot = form.slots.find((x) => errors[`slot-${x.key}`] !== undefined);
    if (badSlot && String(badSlot.weekday) !== dayTab) setDayTab(String(badSlot.weekday));
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
  return (
    <div className="mx-auto flex w-full max-w-5xl flex-col gap-4 p-4">
      <UnsavedGuard when={dirty && !busy} />
      {/* Thanh tiêu đề và nút Lưu/Huỷ ghim đầu khung cuộn: cuộn xuống cuối Time Table vẫn thấy nút (báo cáo T2, mục 3). */}
      <header className="sticky top-topbar z-[9] flex flex-wrap items-center justify-between gap-3 border-b border-border bg-canvas py-2">
        <div>
          <h1 className="text-h3">{editing ? `Sửa lớp ${record.code}` : 'Tạo lớp mới'}</h1>
          <p className="text-caption text-fg-muted">
            {editing ? record.status_name : 'Nháp'}. Mã lớp tự cấp khi lưu.
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            onClick={() => void navigate(editing ? classPath(record.id) : '/crm/lop')}
            disabled={busy}
          >
            Huỷ
          </Button>
          <Button variant="primary" loading={busy} onClick={() => void save()}>
            {editing ? 'Lưu thay đổi' : 'Lưu nháp'}
          </Button>
        </div>
      </header>

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

      <section aria-labelledby="lop3-general" className="grid gap-3 md:grid-cols-3">
        <h2 id="lop3-general" className="text-h4 md:col-span-3">
          Thông tin chung
        </h2>
        <ReadOnlyField label="Mã lớp" value={record?.code ?? 'Tự cấp khi lưu'} />
        <Field label="Cơ sở" required error={err('branchId')}>
          {(p) => (
            <select
              {...p}
              className={INPUT_CLASS}
              value={form.branchId}
              disabled={editing}
              onChange={(e) =>
                setForm({
                  ...form,
                  branchId: e.target.value,
                  cskhId: '',
                  groupId: '',
                  slots: form.slots.map((s) => ({
                    ...s,
                    teacherId: '',
                    assistantId: '',
                    roomId: '',
                  })),
                })
              }
            >
              {access.allBranches.map((b) => (
                <option key={b.id} value={b.id}>
                  {b.code} {b.name}
                </option>
              ))}
            </select>
          )}
        </Field>
        <Field label="Năm học" required error={err('yearCode')}>
          {(p) => (
            <select
              {...p}
              className={INPUT_CLASS}
              value={form.yearCode}
              disabled={editing}
              onChange={(e) => set('yearCode', e.target.value)}
            >
              <option value="">— Chọn —</option>
              {years.map((y) => (
                <option key={y.value} value={y.value}>
                  {y.label}
                </option>
              ))}
            </select>
          )}
        </Field>
        <TextField
          label="Mã lớp cũ (Sheet)"
          value={form.legacyRef}
          disabled={!full}
          onChange={(e) => set('legacyRef', e.target.value)}
        />
        <Select
          label="Môn học"
          required
          error={err('subjectCode')}
          value={form.subjectCode}
          disabled={editing}
          options={opts('SUBJECT')}
          onChange={(v) => set('subjectCode', v)}
        />
        <Select
          label="Khối"
          required
          error={err('gradeCode')}
          value={form.gradeCode}
          disabled={editing}
          options={opts('GRADE')}
          onChange={(v) => setForm({ ...form, gradeCode: v, groupId: '' })}
        />
        <Select
          label="Phân loại"
          required
          error={err('typeCode')}
          value={form.typeCode}
          disabled={editing}
          options={opts('CLASS_TYPE')}
          onChange={(v) =>
            setForm({ ...form, typeCode: v, levelCode: v === PRIVATE_TYPE ? '' : form.levelCode })
          }
        />
        {form.typeCode !== PRIVATE_TYPE && (
          <Select
            label="Trình độ"
            required
            error={err('levelCode')}
            value={form.levelCode}
            disabled={editing}
            options={opts('LEVEL')}
            onChange={(v) => set('levelCode', v)}
          />
        )}
      </section>

      <section aria-labelledby="lop3-time" className="grid gap-3 md:grid-cols-3">
        <h2 id="lop3-time" className="text-h4 md:col-span-3">
          Thời gian và địa điểm
        </h2>
        <Select
          label="Khung chương trình"
          error={undefined}
          value={form.curriculumRef}
          disabled={!full}
          options={frameOptions}
          onChange={(v) => setForm({ ...form, curriculumRef: v, startLesson: '' })}
        />
        <Select
          label="Bài bắt đầu"
          error={undefined}
          value={form.startLesson}
          disabled={!full || frameId === ''}
          options={lessonOptions}
          onChange={(v) => set('startLesson', v)}
        />
        <TextField
          label="Tổng số buổi"
          required
          type="number"
          min={1}
          value={form.totalSessions}
          error={err('totalSessions')}
          disabled={!full}
          onChange={(e) => set('totalSessions', e.target.value)}
        />
        <TextField
          label="Ngày khai giảng"
          required
          type="date"
          value={form.startDate}
          error={err('startDate')}
          disabled={!full}
          onChange={(e) =>
            setForm({
              ...form,
              startDate: e.target.value,
              slots: form.slots.map((s) => ({
                ...s,
                firstDate: firstDateOnOrAfter(e.target.value, s.weekday) || s.firstDate,
              })),
            })
          }
        />
      </section>

      <section aria-labelledby="lop3-summary" className="grid gap-3 md:grid-cols-2">
        <h2 id="lop3-summary" className="text-h4 md:col-span-2">
          Lịch học, phòng và giáo viên (tự sinh từ Time Table)
        </h2>
        <ReadOnlyField
          label="Kết thúc dự kiến"
          value={record?.expected_end_date ?? 'Tính sau khi lưu'}
        />
        <ReadOnlyField label="Lịch học" value={summary.schedule} />
        <ReadOnlyField label="Phòng học" value={summary.rooms} />
        <ReadOnlyField label="Giáo viên và trợ giảng" value={summary.staff} />
      </section>

      <section aria-labelledby="lop3-ops" className="grid gap-3 md:grid-cols-3">
        <h2 id="lop3-ops" className="text-h4 md:col-span-3">
          Vận hành và chăm sóc khách hàng
        </h2>
        <TextField
          label="Sĩ số tối đa"
          type="number"
          min={0}
          help="0 hoặc để trống là không giới hạn"
          value={form.maxStudents}
          error={err('maxStudents')}
          disabled={!editing && false}
          onChange={(e) => set('maxStudents', e.target.value)}
        />
        <Field label="CSKH phụ trách">
          {(p) => (
            <select
              {...p}
              className={INPUT_CLASS}
              value={form.cskhId}
              onChange={(e) => set('cskhId', e.target.value)}
            >
              <option value="">— Chọn CSKH —</option>
              {(opt?.cskh ?? []).map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name}
                </option>
              ))}
            </select>
          )}
        </Field>
        <ReadOnlyField label="Sĩ số hiện tại" value={String(record?.students.length ?? 0)} />
      </section>

      {!editing && (
        <section aria-labelledby="lop3-group" className="flex flex-col gap-2">
          <h2 id="lop3-group" className="text-h4">
            Nhóm lớp (tuỳ chọn)
          </h2>
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
          {form.groupMode === 'EXISTING' && (
            <Field label="Nhóm có sẵn (cùng cơ sở, cùng khối)" error={err('groupId')}>
              {(p) => (
                <select
                  {...p}
                  className={INPUT_CLASS}
                  value={form.groupId}
                  onChange={(e) => set('groupId', e.target.value)}
                >
                  <option value="">— Chọn nhóm —</option>
                  {groupsForGrade.map((g) => (
                    <option key={g.id} value={g.id}>
                      {g.name ?? 'Nhóm chưa đặt tên chung'}
                    </option>
                  ))}
                </select>
              )}
            </Field>
          )}
          {form.groupMode === 'NEW' && (
            <TextField
              label="Tên chung của nhóm"
              help="Không bắt buộc. Chỉ là tham chiếu (ví dụ tên cũ 9M1), hiện nhỏ dưới mã lớp."
              value={form.groupName}
              onChange={(e) => set('groupName', e.target.value)}
            />
          )}
          <p className="text-caption text-fg-muted">
            Nhóm không có mã riêng; chỉ môn {GROUP_SUBJECTS.join(', ')} (Đại, Hình). Mỗi lớp trong
            nhóm vẫn độc lập (R-LOP-14).
          </p>
        </section>
      )}

      <section aria-labelledby="lop3-tt" className="flex flex-col gap-3">
        <h2 id="lop3-tt" className="text-h4">
          Time Table
        </h2>
        {approvedEdit && (
          <div className="flex flex-wrap items-end gap-3">
            <TextField
              label="Áp dụng thay đổi Time Table từ ngày"
              required
              type="date"
              value={form.applyFrom}
              error={err('applyFrom')}
              onChange={(e) => {
                set('applyFrom', e.target.value);
                setPreview(null);
              }}
            />
            <p className="w-full text-caption text-fg-muted">
              Buổi trước ngày này và buổi đã diễn ra giữ nguyên. Buổi đã chỉnh lẻ tay cũng giữ
              (R-LOP-11).
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
        <Tabs
          label="Time Table theo thứ"
          value={dayTab}
          onChange={setDayTab}
          items={[1, 2, 3, 4, 5, 6, 7].map((day) => {
            const slots = form.slots.filter((s) => s.weekday === day);
            return {
              value: String(day),
              label: WEEKDAY_LABEL[day] ?? '',
              count: slots.length > 0 ? slots.length : undefined,
              content: (
                <div className="flex flex-col gap-2">
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
                      onClick={() =>
                        setForm((f) => ({ ...f, slots: [...f.slots, newSlot(day, f.startDate)] }))
                      }
                    >
                      Thêm khung giờ
                    </Button>
                  </div>
                </div>
              ),
            };
          })}
        />
        <p className="text-caption text-fg-muted">
          Lưu nháp xong, bấm Trình ở màn lớp. Trình lớp bắt buộc có Time Table (R-LOP-02, R-LOP-03).
          Khung lặp mỗi 2 tuần thì «Buổi đầu» quyết định tuần nào có buổi (R-LOP-13).
        </p>
      </section>
    </div>
  );
}

function Select({
  label,
  required,
  error,
  value,
  disabled,
  options,
  onChange,
}: {
  label: string;
  required?: boolean;
  error?: string | undefined;
  value: string;
  disabled?: boolean;
  options: { value: string; label: string }[];
  onChange: (v: string) => void;
}) {
  return (
    <Field label={label} required={required} error={error}>
      {(p) => (
        <select
          {...p}
          className={INPUT_CLASS}
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
        >
          <option value="">— Chọn —</option>
          {options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      )}
    </Field>
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
  people: { id: string; name: string }[];
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
          {p.name}
        </option>
      ))}
    </select>
  );
}

function ReadOnlyField({ label, value }: { label: string; value: string }) {
  return (
    <Field label={label}>
      {(p) => (
        <input
          id={p.id}
          aria-describedby={p['aria-describedby']}
          readOnly
          value={value}
          className={`${INPUT_CLASS} bg-surface-subtle text-fg-label`}
        />
      )}
    </Field>
  );
}
