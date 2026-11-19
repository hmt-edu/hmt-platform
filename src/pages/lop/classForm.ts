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

/** Ngày đầu tiên từ ngày khai giảng trở đi rơi đúng thứ của khung (buổi đầu mặc định). */
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
    if (f.typeCode && f.typeCode !== PRIVATE_TYPE && !f.levelCode) e.levelCode = 'Chọn trình độ.';
    if (!(Number(f.totalSessions) > 0)) e.totalSessions = 'Nhập tổng số buổi lớn hơn 0.';
    if (!f.startDate) e.startDate = 'Chọn ngày khai giảng.';
    if (f.maxStudents !== '' && !(Number(f.maxStudents) >= 0))
      e.maxStudents = 'Sĩ số tối đa từ 0 trở lên (0 là không giới hạn).';
    if (f.groupMode === 'EXISTING' && !f.groupId) e.groupId = 'Chọn nhóm có sẵn.';
    if (
      (f.groupMode === 'EXISTING' || f.groupMode === 'NEW') &&
      f.subjectCode &&
      !GROUP_SUBJECTS.includes(f.subjectCode)
    ) {
      e.groupMode = 'Nhóm lớp chỉ gồm lớp Đại số và Hình học (R-LOP-14).';
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

/** Tóm tắt tự sinh từ các khung giờ đang nhập: lịch học, phòng, giáo viên và trợ giảng (chỉ đọc, canvas LOP-03). */
export function slotSummary(
  slots: SlotDraft[],
  opt:
    | {
        teachers: { id: string; name: string }[];
        assistants: { id: string; name: string }[];
        rooms: { id: string; name: string }[];
      }
    | undefined,
): { schedule: string; rooms: string; staff: string } {
  const name = (list: { id: string; name: string }[] | undefined, id: string) =>
    list?.find((x) => x.id === id)?.name ?? '';
  const uniq = (xs: string[]) => [...new Set(xs.filter((x) => x !== ''))];
  const sorted = [...slots].sort((a, b) => a.weekday - b.weekday || a.start.localeCompare(b.start));
  const schedule = sorted
    .filter((x) => x.start !== '' && x.end !== '')
    .map((x) => `${WEEKDAY_LABEL[x.weekday] ?? ''} ${x.start}–${x.end}`)
    .join('; ');
  const rooms = uniq(sorted.map((x) => name(opt?.rooms, x.roomId))).join(', ');
  const staff = uniq(
    sorted.flatMap((x) => [name(opt?.teachers, x.teacherId), name(opt?.assistants, x.assistantId)]),
  ).join(', ');
  return { schedule: schedule || 'Chưa có khung giờ', rooms: rooms || '—', staff: staff || '—' };
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
