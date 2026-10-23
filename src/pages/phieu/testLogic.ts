// Luật hiển thị của màn Phiếu kiểm tra: nút nào hiện ở trạng thái nào, giờ nhắc mặc định, kiểm điểm. Hàm thuần, có kiểm thử.
// Luật thật ở hàm cơ sở dữ liệu (R-CRM-05, 06, 10, 11, 15, 21); đây chỉ để hiện đúng nút và chặn sớm ô sai dạng.
import type { TestStatus } from './testTypes';

export type TestAction =
  | 'start' // Bắt đầu test: Nháp → Đang test
  | 'submit' // Nộp bài: Đang test → Chờ giáo viên chấm
  | 'enter-result' // Nhập kết quả (cả sửa kết quả sau khi Hoàn thành)
  | 'complete' // Hoàn thành: Chờ giáo viên chấm → Hoàn thành
  | 'reschedule' // Đổi lịch (chỉ Nháp)
  | 'step-back' // Lùi một bước (R-CRM-21)
  | 'cancel' // Huỷ (R-CRM-06)
  | 'reopen' // Mở lại phiếu huỷ về Nháp
  | 'edit'; // Sửa người phụ trách, cơ sở test, phòng, giáo viên chấm, tên đề

/** Các việc làm được với một phiếu ở từng trạng thái (quyền kiểm riêng theo Sửa, Huỷ). */
export const ACTIONS_BY_STATUS: Record<TestStatus, TestAction[]> = {
  DRAFT: ['start', 'reschedule', 'cancel', 'edit'],
  TESTING: ['submit', 'step-back', 'cancel', 'edit'],
  TEACHER_REVIEW: ['enter-result', 'complete', 'step-back', 'cancel', 'edit'],
  COMPLETED: ['enter-result', 'step-back', 'edit'],
  CANCELLED: ['reopen'],
};

/** Trạng thái đích khi lùi một bước (R-CRM-21); Hoàn thành về Nháp (bắt lý do), Đang test về Nháp, Chờ chấm về Đang test. */
export const STEP_BACK_TARGET: Partial<Record<TestStatus, TestStatus>> = {
  TESTING: 'DRAFT',
  TEACHER_REVIEW: 'TESTING',
  COMPLETED: 'DRAFT',
};

/** Lùi từ Hoàn thành về Nháp bắt buộc nhập lý do; các bước lùi khác chỉ ghi lịch sử (R-CRM-21). */
export function stepBackNeedsReason(status: TestStatus): boolean {
  return status === 'COMPLETED';
}

export type ReminderSettings = {
  /** test_reminder_time_minutes: phút kể từ 0 giờ ngày hôm trước (1020 = 17:00). */
  timeMinutes: number;
  /** test_reminder_short_window_hours: test bắt đầu trong khoảng này kể từ lúc tạo thì nhắc gần giờ test. */
  shortWindowHours: number;
  /** test_reminder_short_lead_hours: nhắc trước giờ test bấy nhiêu giờ. */
  shortLeadHours: number;
};

const HOUR_MS = 3_600_000; // allow-number: số mili giây trong một giờ
const MINUTE_MS = 60_000; // allow-number: số mili giây trong một phút
const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày
/** Giờ nhắc kém giờ test ít nhất một phút (cùng luật hàm test_reminder_time). */
const MIN_LEAD_MS = MINUTE_MS;

/**
 * Giờ nhắc mặc định của lịch hẹn nhắc phiếu (TS-15), cùng công thức hàm DB `app.test_reminder_time` (ba tham số Cài đặt):
 * test bắt đầu trong `shortWindowHours` giờ tới thì nhắc trước `shortLeadHours` giờ; không thì nhắc lúc `timeMinutes` phút kể từ
 * 0 giờ ngày hôm trước ngày test (giờ Việt Nam). Giờ nhắc không sớm hơn lúc tạo, không muộn hơn một phút trước giờ test.
 * `dayStartVn` là 0 giờ (giờ Việt Nam) của NGÀY TEST, tính ở nơi gọi (cần múi giờ).
 */
export function defaultReminder(
  testAt: Date,
  now: Date,
  dayStartVnOfTest: Date,
  settings: ReminderSettings,
): Date {
  const short = testAt.getTime() - now.getTime() <= settings.shortWindowHours * HOUR_MS;
  const at = short
    ? testAt.getTime() - settings.shortLeadHours * HOUR_MS
    : dayStartVnOfTest.getTime() - DAY_MS + settings.timeMinutes * MINUTE_MS;
  return new Date(Math.min(Math.max(at, now.getTime()), testAt.getTime() - MIN_LEAD_MS));
}

const SCORE = /^\d{1,2}([.,]\d)?$/; // allow-number: điểm có tối đa một chữ số thập phân (R-CRM-10)
const MAX_SCORE = 10; // allow-number: thang điểm 0–10 của R-CRM-10

/** Điểm nhập tay ("7,5" hoặc "7.5") → số; sai dạng hoặc ngoài 0–10 thì null. */
export function parseScore(text: string): number | null {
  const trimmed = text.trim();
  if (!SCORE.test(trimmed)) return null;
  const value = Number(trimmed.replace(',', '.'));
  return value >= 0 && value <= MAX_SCORE ? value : null;
}

/** Điểm hiện cho người dùng: "7,5/10". */
export function formatScore(score: number | null): string {
  return score === null ? '' : `${String(score).replace('.', ',')}/${MAX_SCORE}`;
}
