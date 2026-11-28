// Logic thuần của LOP-03 Tạo / sửa lớp: trạng thái biểu mẫu, kiểm hợp lệ, dựng dữ liệu gửi app.create_class, app.save_class_info,
// app.save_class_timetable. Luật R-LOP-02 (sửa theo tình trạng), R-LOP-06 (cơ sở mình), R-LOP-10, 13 (khung giờ, lặp mỗi N tuần), R-LOP-14 (nhóm lớp).
import { WEEKDAY_LABEL } from './classLabels';
import type { ClassRecord } from './classTypes';

export type SlotDraft = {
  key: string;
  /** 1 = Thứ 2 … 7 = Chủ nhật (khớp class_slot.weekday). */
  weekday: number;
  start: string;
  end: string;
  teacherId: string;
  assistantId: string;
  roomId: string;
  repeatWeeks: string;
  firstDate: string;
};

export type GroupMode = 'NONE' | 'EXISTING' | 'NEW';

export type ClassFormState = {
  branchId: string;
  yearCode: string;
  subjectCode: string;
  gradeCode: string;
  typeCode: string;
  levelCode: string;
  /** Hình thức học của lớp: OFF, ONL, OMO. */
  deliveryModeCode: string;
  legacyRef: string;
  curriculumRef: string;
  startLesson: string;
  totalSessions: string;
  startDate: string;
  maxStudents: string;
  cskhId: string;
  groupMode: GroupMode;
  groupId: string;
  groupName: string;
  slots: SlotDraft[];
  /** Chỉ dùng khi sửa lớp Đã duyệt: Time Table áp dụng từ ngày này (R-LOP-10). */
  applyFrom: string;
};

export const EMPTY_FORM: ClassFormState = {
  branchId: '',
  yearCode: '',
  subjectCode: '',
  gradeCode: '',
  typeCode: '',
  levelCode: '',
  deliveryModeCode: 'OFF',
  legacyRef: '',
  curriculumRef: '',
  startLesson: '',
  totalSessions: '',
  startDate: '',
  maxStudents: '',
  cskhId: '',
  groupMode: 'NONE',
  groupId: '',
  groupName: '',
  slots: [],
  applyFrom: '',
};

/** Mã lớp riêng: không có trình độ (check class_type_code = 'LR' khớp level_code trống). */
export const PRIVATE_TYPE = 'LR';
/** Chỉ môn Đại và Hình vào nhóm lớp luân phiên (R-LOP-14). */
export const GROUP_SUBJECTS = ['DAI', 'HINH'];

const DAY_MS = 86_400_000; // allow-number: số mili giây một ngày

/** Thứ trong tuần theo kiểu ISO (1 = Thứ 2 … 7 = Chủ nhật) của ngày yyyy-mm-dd. */
export function isoWeekday(day: string): number {
  const d = new Date(`${day}T00:00:00Z`).getUTCDay();
  return d === 0 ? 7 : d; // allow-number: Chủ nhật = 7 theo ISO
}

/** Ngày đầu tiên từ ngày bắt đầu trở đi rơi đúng thứ của khung (buổi đầu mặc định). */
export function firstDateOnOrAfter(startDate: string, weekday: number): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate)) return '';
  const diff = (weekday - isoWeekday(startDate) + 7) % 7; // allow-number: bảy ngày một tuần
  return new Date(new Date(`${startDate}T00:00:00Z`).getTime() + diff * DAY_MS)
    .toISOString()
    .slice(0, 10); // allow-number: cắt yyyy-mm-dd
}

export function newSlot(weekday: number, startDate: string): SlotDraft {
  return {
    key: `${weekday}-${Math.random().toString(36).slice(2, 8)}`, // allow-number: mã ngắn làm khoá dòng
    weekday,
    start: '18:00',
    end: '19:30',
    teacherId: '',
    assistantId: '',
    roomId: '',
    repeatWeeks: '1',
    firstDate: firstDateOnOrAfter(startDate, weekday),
  };
}

/** Tab Time Table mở sẵn: thứ đầu tuần có khung giờ, chưa có khung nào thì Thứ 2. */
export function defaultDayTab(slots: { weekday: number }[]): string {
  return String(slots.length > 0 ? Math.min(...slots.map((s) => s.weekday)) : 1);
}

export type FormErrors = Partial<Record<string, string>>;

/** Kiểm hợp lệ phía giao diện (máy chủ kiểm lại). `full` = Nháp, Từ chối hoặc Tạo; `false` = chỉ Time Table (Đã trình, Đã xác nhận, Đã duyệt). */
export function validateForm(f: ClassFormState, full: boolean, approvedEdit: boolean): FormErrors {
  const e: FormErrors = {};
  if (full) {
    if (!f.branchId) e.branchId = 'Chọn cơ sở.';
    if (!f.yearCode) e.yearCode = 'Chọn năm học.';
    if (!f.subjectCode) e.subjectCode = 'Chọn môn học.';
    if (!f.gradeCode) e.gradeCode = 'Chọn khối.';
    if (!f.typeCode) e.typeCode = 'Chọn phân loại.';
    if (!f.deliveryModeCode) e.deliveryModeCode = 'Chọn hình thức học.';
    if (f.typeCode && f.typeCode !== PRIVATE_TYPE && !f.levelCode) e.levelCode = 'Chọn trình độ.';
    // R-LOP-07: khung chương trình bắt buộc với lớp chung, tuỳ chọn với lớp riêng.
    if (f.typeCode && f.typeCode !== PRIVATE_TYPE && !f.curriculumRef.trim())
      e.curriculumRef = 'Lớp chung bắt buộc có khung chương trình.';
    if (!(Number(f.totalSessions) > 0)) e.totalSessions = 'Nhập tổng số buổi lớn hơn 0.';
    if (!f.startDate) e.startDate = 'Chọn ngày bắt đầu.';
    if (f.maxStudents !== '' && !(Number(f.maxStudents) >= 0))
      e.maxStudents = 'Sĩ số tối đa từ 0 trở lên (0 là không giới hạn).';
    if (f.groupMode === 'EXISTING' && !f.groupId) e.groupId = 'Chọn nhóm có sẵn.';
    if (
      (f.groupMode === 'EXISTING' || f.groupMode === 'NEW') &&
      f.subjectCode &&
      !GROUP_SUBJECTS.includes(f.subjectCode)
    ) {
      e.groupMode = 'Nhóm lớp chỉ gồm lớp Đại số và Hình học.';
    }
  }
  f.slots.forEach((s) => {
    if (!s.start || !s.end || s.end <= s.start)
      e[`slot-${s.key}`] = 'Giờ kết thúc phải sau giờ bắt đầu.';
    else if (!s.firstDate) e[`slot-${s.key}`] = 'Chọn buổi đầu tiên.';
    else if (isoWeekday(s.firstDate) !== s.weekday)
      e[`slot-${s.key}`] = 'Buổi đầu tiên phải đúng thứ của khung giờ.';
    else if (!(Number(s.repeatWeeks) >= 1)) e[`slot-${s.key}`] = 'Cách lặp từ mỗi 1 tuần trở lên.';
  });
  if (approvedEdit && !f.applyFrom) e.applyFrom = 'Chọn ngày áp dụng Time Table.';
  return e;
}

export function slotsPayload(slots: SlotDraft[]) {
  return slots.map((s) => ({
    weekday: s.weekday,
    start_time: s.start,
    end_time: s.end,
    teacher_id: s.teacherId || null,
    assistant_id: s.assistantId || null,
    room_id: s.roomId || null,
    repeat_weeks: Number(s.repeatWeeks),
    first_date: s.firstDate,
  }));
}

/** Dữ liệu cho app.create_class (group_id điền sau khi tạo nhóm mới). */
export function createPayload(f: ClassFormState, groupId: string | null) {
  return {
    branch_id: f.branchId,
    year_code: f.yearCode,
    subject_code: f.subjectCode,
    grade_code: f.gradeCode,
    class_type_code: f.typeCode,
    level_code: f.typeCode === PRIVATE_TYPE ? null : f.levelCode,
    delivery_mode_code: f.deliveryModeCode,
    max_students: f.maxStudents === '' ? 0 : Number(f.maxStudents),
    start_date: f.startDate,
    total_sessions: Number(f.totalSessions),
    curriculum_ref: f.curriculumRef.trim() || null,
    start_lesson: f.startLesson.trim() || null,
    cskh_id: f.cskhId || null,
    group_id: groupId,
    legacy_ref: f.legacyRef.trim() || null,
    slots: slotsPayload(f.slots),
  };
}

/** Dữ liệu cho app.save_class_info theo tình trạng: Nháp, Từ chối sửa mọi trường được phép; Đã duyệt chỉ CSKH và sĩ số tối đa (R-LOP-02). */
export function infoPayload(f: ClassFormState, status: string) {
  const common = {
    max_students: f.maxStudents === '' ? 0 : Number(f.maxStudents),
    cskh_id: f.cskhId || null,
  };
  if (status === 'DA_DUYET') return common;
  return {
    ...common,
    start_date: f.startDate,
    total_sessions: Number(f.totalSessions),
    curriculum_ref: f.curriculumRef.trim() || null,
    start_lesson: f.startLesson.trim() || null,
    legacy_ref: f.legacyRef.trim() || null,
    delivery_mode_code: f.deliveryModeCode,
  };
}

/** Trạng thái biểu mẫu từ hồ sơ lớp (màn Sửa). */
export function formFromRecord(r: ClassRecord): ClassFormState {
  return {
    branchId: r.branch_id,
    yearCode: r.year_code,
    subjectCode: r.subject_code,
    gradeCode: r.grade_code,
    typeCode: r.class_type_code,
    levelCode: r.level_code ?? '',
    deliveryModeCode: r.delivery_mode_code ?? 'OFF',
    legacyRef: r.legacy_ref ?? '',
    curriculumRef: r.curriculum_ref ?? '',
    startLesson: r.start_lesson ?? '',
    totalSessions: String(r.total_sessions),
    startDate: r.start_date,
    maxStudents: String(r.max_students),
    cskhId: r.cskh_id ?? '',
    groupMode: r.group_id ? 'EXISTING' : 'NONE',
    groupId: r.group_id ?? '',
    groupName: '',
    applyFrom: '',
    slots: r.slots.map((s) => ({
      key: s.id,
      weekday: s.weekday,
      start: s.start_time.slice(0, 5),
      end: s.end_time.slice(0, 5),
      teacherId: s.teacher_id ?? '',
      assistantId: s.assistant_id ?? '',
      roomId: s.room_id ?? '',
      repeatWeeks: String(s.repeat_weeks),
      firstDate: s.first_date,
    })),
  };
}

/** Tóm tắt tự sinh từ các khung giờ đang nhập: lịch học, phòng, giáo viên, trợ giảng (chỉ đọc, canvas LOP-03). */
export function slotSummary(
  slots: SlotDraft[],
  opt:
    | {
        teachers: { id: string; name: string }[];
        assistants: { id: string; name: string }[];
        rooms: { id: string; name: string }[];
      }
    | undefined,
): { schedule: string; rooms: string; teachers: string; assistants: string } {
  const name = (list: { id: string; name: string }[] | undefined, id: string) =>
    list?.find((x) => x.id === id)?.name ?? '';
  const uniq = (xs: string[]) => [...new Set(xs.filter((x) => x !== ''))];
  const sorted = [...slots].sort((a, b) => a.weekday - b.weekday || a.start.localeCompare(b.start));
  const schedule = sorted
    .filter((x) => x.start !== '' && x.end !== '')
    .map((x) => `${WEEKDAY_LABEL[x.weekday] ?? ''} ${x.start}–${x.end}`)
    .join('; ');
  const rooms = uniq(sorted.map((x) => name(opt?.rooms, x.roomId))).join(', ');
  const teachers = uniq(sorted.map((x) => name(opt?.teachers, x.teacherId))).join(', ');
  const assistants = uniq(sorted.map((x) => name(opt?.assistants, x.assistantId))).join(', ');
  return {
    schedule: schedule || 'Chưa có khung giờ',
    rooms: rooms || '—',
    teachers: teachers || '—',
    assistants: assistants || '—',
  };
}

/** Câu tóm tắt lỗi đầu biểu mẫu (khung LOP03_loi): số ô chưa hợp lệ ở thông tin lớp và ở thời khoá biểu theo thứ; không lỗi thì null. */
export function errorSummary(
  errors: FormErrors,
  slots: Pick<SlotDraft, 'key' | 'weekday'>[],
  saveLabel: string,
): string | null {
  const keys = Object.keys(errors).filter((k) => errors[k] !== undefined);
  if (keys.length === 0) return null;
  const bad = slots.filter((s) => keys.includes(`slot-${s.key}`));
  const timetable = bad.length + (keys.includes('applyFrom') ? 1 : 0);
  const info = keys.length - timetable;
  const days = [...new Set(bad.map((s) => s.weekday))]
    .sort((a, b) => a - b)
    .map((d) => WEEKDAY_LABEL[d] ?? '')
    .join(', ');
  const parts = [
    info > 0 ? `${info} ở thông tin lớp` : '',
    timetable > 0 ? `${timetable} ở thời khoá biểu${days ? `: ${days}` : ''}` : '',
  ].filter(Boolean);
  return `Còn ${keys.length} chỗ chưa hợp lệ (${parts.join(', ')}). Sửa các ô đỏ rồi bấm ${saveLabel} lại.`;
}

/** Ngưỡng giờ một khung giờ bị coi là dài bất thường (chỉ nhắc ở giao diện, không chặn; báo cáo T2: 12:30–23:30 lưu được không cảnh báo). */
const LONG_SLOT_HOURS = 4; // allow-number: ngưỡng nhắc ở giao diện, không phải luật nghiệp vụ
const MINUTES_PER_HOUR = 60; // allow-number: số phút trong một giờ

/** Khung giờ dài hơn ngưỡng thì trả câu nhắc (không chặn lưu); giờ trống hoặc không hợp lệ thì null (đã có lỗi riêng). */
export function longSlotWarning(start: string, end: string): string | null {
  const toMin = (t: string) => {
    const [h, m] = t.split(':').map(Number);
    return Number.isFinite(h) && Number.isFinite(m)
      ? (h as number) * MINUTES_PER_HOUR + (m as number)
      : null;
  };
  const a = toMin(start);
  const b = toMin(end);
  if (a === null || b === null || b <= a) return null;
  const hours = (b - a) / MINUTES_PER_HOUR;
  return hours > LONG_SLOT_HOURS
    ? `Khung giờ dài ${Number.isInteger(hours) ? hours : hours.toFixed(1)} giờ, kiểm tra lại giờ bắt đầu và kết thúc.`
    : null;
}

/** Nhãn ô chọn giáo viên, trợ giảng: tên kèm môn, khối từ hồ sơ dạy (QT-16, R-LOP-10); chưa có hồ sơ thì ghi rõ, vẫn chọn được (hồ sơ chỉ gợi ý, không chặn). */
export function teacherOptionLabel(p: {
  name: string;
  has_profile?: boolean | undefined;
  subject_names?: string[] | undefined;
  grade_names?: string[] | undefined;
}): string {
  if (p.has_profile === undefined) return p.name;
  if (!p.has_profile) return `${p.name} (chưa có hồ sơ dạy)`;
  const hint = [(p.subject_names ?? []).join(', '), (p.grade_names ?? []).join(', ')]
    .filter((x) => x !== '')
    .join(' · ');
  return hint === '' ? p.name : `${p.name} · ${hint}`;
}

/** «Tổ chức lớp» tự suy từ Phân loại, không phải ô nhập (anh Trường chốt 20/11): Lớp riêng là Học riêng, còn lại là Học chung. Chưa chọn phân loại thì trống. */
export function organizationText(typeCode: string): string {
  if (typeCode === '') return '';
  return typeCode === PRIVATE_TYPE ? 'Học riêng' : 'Học chung';
}

export type ClassPrefill = Partial<
  Pick<ClassFormState, 'branchId' | 'yearCode' | 'gradeCode' | 'typeCode' | 'groupMode' | 'groupId'>
>;

/**
 * «Tạo lớp còn lại cho nhóm này» (anh Trường chốt 20/11): chỉ điền sẵn nhóm, cơ sở, năm, khối, phân loại từ địa chỉ; để TRỐNG môn, giáo viên, lịch.
 * Tham số: nhom, co_so, nam, khoi, phan_loai. Giá trị trống bị bỏ qua.
 */
export function prefillFromParams(params: URLSearchParams): ClassPrefill {
  const out: ClassPrefill = {};
  const pick = (key: string) => (params.get(key) ?? '').trim();
  if (pick('co_so')) out.branchId = pick('co_so');
  if (pick('nam')) out.yearCode = pick('nam');
  if (pick('khoi')) out.gradeCode = pick('khoi');
  if (pick('phan_loai')) out.typeCode = pick('phan_loai');
  if (pick('nhom')) {
    out.groupMode = 'EXISTING';
    out.groupId = pick('nhom');
  }
  return out;
}

/** Địa chỉ mở màn Tạo lớp với phần điền sẵn của «Tạo lớp còn lại cho nhóm này». */
export function remainingClassPath(c: {
  group_id: string | null;
  branch_id: string;
  year_code: string;
  grade_code: string;
  class_type_code: string;
}): string {
  const q = new URLSearchParams({
    nhom: c.group_id ?? '',
    co_so: c.branch_id,
    nam: c.year_code,
    khoi: c.grade_code,
    phan_loai: c.class_type_code,
  });
  return `/crm/lop/tao?${q.toString()}`;
}
