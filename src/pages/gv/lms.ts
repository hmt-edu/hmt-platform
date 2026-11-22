// GV-17 Giao bài trên LMS: kiểu dữ liệu hàm app.lms_list_assignments và logic thuần (trạng thái bài, kiểm form, hạn nộp theo giờ Việt Nam).
// Luật: R-LMS-01 (hạn mặc định là giờ vào buổi sau; hai công tắc), Q2 (sửa, gỡ), Q4 (mặc định Cho nộp lại bật, Nhận bài muộn tắt),
// Q10 (không có buổi sau: bắt buộc hạn tay), Q11 (tối thiểu 1 em). Máy chủ kiểm lại mọi luật; trang chỉ báo sớm.
import type { TagTone } from '../../ui/Data';

export type LmsAssignmentRow = {
  id: string;
  title: string;
  description: string;
  due_at: string;
  status: 'DANG_GIAO' | 'DA_GO';
  version: number;
  audience: 'CA_LOP' | 'CHON_EM';
  allow_resubmit: boolean;
  allow_late: boolean;
  session_id: string;
  session_no: number | null;
  created_at: string;
  targets: number;
  submitted: number;
  graded: number;
};

export type LmsList = { total: number; rows: LmsAssignmentRow[] };

export type LmsState = 'DANG_MO' | 'QUA_HAN' | 'CHAM_HET' | 'DA_GO';

export const LMS_STATE_TEXT: Record<LmsState, { label: string; tone: TagTone }> = {
  DANG_MO: { label: 'Đang mở', tone: 'info' },
  QUA_HAN: { label: 'Quá hạn', tone: 'warning' },
  CHAM_HET: { label: 'Đã chấm hết', tone: 'success' },
  DA_GO: { label: 'Đã gỡ', tone: 'neutral' },
};

/** Trạng thái hiển thị của bài: Đã gỡ, Đã chấm hết (mọi em nhận bài đều đã chấm), Quá hạn, Đang mở. */
export function lmsState(
  a: Pick<LmsAssignmentRow, 'status' | 'due_at' | 'targets' | 'graded'>,
  now: Date,
): LmsState {
  if (a.status === 'DA_GO') return 'DA_GO';
  if (a.targets > 0 && a.graded >= a.targets) return 'CHAM_HET';
  return new Date(a.due_at).getTime() <= now.getTime() ? 'QUA_HAN' : 'DANG_MO';
}

const VN_ZONE = 'Asia/Ho_Chi_Minh';
const VN_OFFSET = '+07:00'; // Việt Nam không đổi giờ theo mùa

/** Tách một thời điểm thành ngày «2026-11-20» và giờ «18:00» theo giờ Việt Nam (cho ô ngày, ô giờ). */
export function vnParts(iso: string): { date: string; time: string } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: VN_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date(iso));
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? '';
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    time: `${get('hour')}:${get('minute')}`,
  };
}

/** Ghép ngày «2026-11-20» và giờ «18:00» (giờ Việt Nam) thành thời điểm gửi máy chủ; thiếu một trong hai thì null. */
export function dueIso(date: string, time: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(time)) return null;
  return `${date}T${time}:00${VN_OFFSET}`;
}

export type LmsSessionLite = {
  id: string;
  session_no: number | null;
  session_date: string;
  start_time: string;
  status_code: string;
};

/** Buổi dùng làm buổi giao: buổi thật của lớp (không huỷ, không bị thay). */
export function giveableSessions<T extends LmsSessionLite>(sessions: T[]): T[] {
  return sessions.filter((s) => ['NHAP', 'DA_CHOT', 'DONE'].includes(s.status_code));
}

/** Buổi sau buổi đã chọn (giờ vào buổi sau là hạn mặc định, R-LMS-01); null khi lớp chưa có buổi sau (Q10). */
export function nextSessionOf<T extends LmsSessionLite>(
  sessions: T[],
  sessionId: string,
): T | null {
  const list = giveableSessions(sessions);
  const current = list.find((s) => s.id === sessionId);
  if (!current) return null;
  const key = (s: LmsSessionLite) => `${s.session_date}T${s.start_time}`;
  const later = list
    .filter((s) => key(s) > key(current))
    .sort((a, b) => key(a).localeCompare(key(b)));
  return later[0] ?? null;
}

export type LmsFormValues = {
  title: string;
  description: string;
  date: string;
  time: string;
  audience: 'CA_LOP' | 'CHON_EM';
  studentIds: string[];
  /** true khi lớp có buổi sau: ô hạn có thể để trống (máy chủ lấy giờ vào buổi sau). */
  hasDefaultDue: boolean;
};

export type LmsFormErrors = Partial<Record<'title' | 'description' | 'due' | 'students', string>>;

/** Báo sớm các lỗi nhập liệu (máy chủ vẫn kiểm lại). Hạn bỏ trống chỉ được khi lớp có buổi sau (Q10). */
export function validateLmsForm(v: LmsFormValues, now: Date): LmsFormErrors {
  const errors: LmsFormErrors = {};
  if (v.title.trim() === '') errors.title = 'Cần nhập tiêu đề bài.';
  if (v.description.trim() === '') errors.description = 'Cần nhập mô tả, đề bài.';
  const blank = v.date === '' && v.time === '';
  if (blank) {
    if (!v.hasDefaultDue) errors.due = 'Lớp chưa có buổi sau: hãy chọn hạn nộp.';
  } else {
    const iso = dueIso(v.date, v.time);
    if (iso === null) errors.due = 'Chọn đủ ngày và giờ của hạn nộp.';
    else if (new Date(iso).getTime() <= now.getTime())
      errors.due = 'Hạn nộp không được trước thời điểm giao.';
  }
  if (v.audience === 'CHON_EM' && v.studentIds.length === 0)
    errors.students = 'Chọn ít nhất một em đang học để giao bài.';
  return errors;
}

/** Dữ liệu gửi app.lms_create_assignment. Hạn bỏ trống thì không gửi (máy chủ lấy giờ vào buổi sau). */
export function createPayload(
  sessionId: string,
  v: LmsFormValues,
  allowResubmit: boolean,
  allowLate: boolean,
) {
  const due = dueIso(v.date, v.time);
  return {
    session_id: sessionId,
    title: v.title.trim(),
    description: v.description.trim(),
    audience: v.audience,
    allow_resubmit: allowResubmit,
    allow_late: allowLate,
    ...(due ? { due_at: due } : {}),
    ...(v.audience === 'CHON_EM' ? { student_ids: v.studentIds } : {}),
  };
}
