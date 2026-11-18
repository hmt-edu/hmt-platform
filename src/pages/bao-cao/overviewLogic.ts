// Hàm thuần của BC-01 Tổng quan Ban giám đốc: kiểu kết quả app.report_overview và đổi khoảng ngày thành tham số gửi máy chủ.
import { vnDayBounds } from '../../lib/vnDay';

export type Overview = {
  as_of: string;
  from: string;
  to: string;
  branch_id: string | null;
  students_active: number;
  students_on_hold: number;
  revenue_recognized: number;
  revenue_hours: number;
  hours_without_price: number;
  cash_received: number;
  hours_fund_value: number;
  hours_fund_hours: number;
};

/** Ngày Việt Nam dạng yyyy-mm-dd của một mốc thời gian (không theo múi giờ trình duyệt). */
export function dayKey(date: Date): string {
  return vnDayBounds(date).dateKey;
}

/** Khoảng ngày hợp lệ để gọi máy chủ (đến không trước từ). */
export function rangeParams(
  range: { from: Date; to: Date } | null,
): { p_from: string; p_to: string } | null {
  if (!range) return null;
  const p_from = dayKey(range.from);
  const p_to = dayKey(range.to);
  return p_to < p_from ? null : { p_from, p_to };
}
