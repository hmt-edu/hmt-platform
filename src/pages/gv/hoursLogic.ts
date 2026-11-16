// GV-16 Giờ dạy của tôi (căn cứ lương): kiểu dữ liệu và hàm thuần cho màn. Máy chủ (app.teacher_my_hours) tính giờ, đếm buổi trễ hạn, quyết buổi nào tính
// (R-GV-14); trang chỉ đổi tháng và đặt chữ. Giờ hiện một chữ số thập phân khi có lẻ, dấu phẩy.
export type HoursRow = {
  session_id: string;
  class_code: string;
  subject_name: string | null;
  session_no: number | null;
  session_date: string;
  start_time: string;
  end_time: string;
  type_code: string;
  type_name: string | null;
  my_role: 'GIAO_VIEN' | 'TRO_GIANG';
  hours: number;
  late: boolean | null;
  late_hours: number | null;
};
export type HoursByType = {
  type_code: string;
  type_name: string | null;
  sessions: number;
  hours: number;
};
export type MyHours = {
  month: string;
  summary: { sessions: number; hours: number; late_sessions: number; late_hours: number };
  by_type: HoursByType[];
  rows: HoursRow[];
};

const MONTHS_IN_YEAR = 12; // allow-number: một năm có mười hai tháng (đổi tháng ở lịch, không phải số nghiệp vụ)

/** Mùng 1 của tháng cách tháng đã cho n tháng (n âm là lùi); đầu vào dạng yyyy-mm-dd. */
export function shiftMonth(monthKey: string, n: number): string {
  const total =
    Number(monthKey.slice(0, 4)) * MONTHS_IN_YEAR + (Number(monthKey.slice(5, 7)) - 1) + n; // allow-number: cắt chuỗi yyyy-mm-dd
  const y = Math.floor(total / MONTHS_IN_YEAR);
  const m = (total % MONTHS_IN_YEAR) + 1;
  return `${String(y).padStart(4, '0')}-${String(m).padStart(2, '0')}-01`; // allow-number: định dạng yyyy-mm-dd
}

/** "Tháng 11/2026" */
export function monthTitle(monthKey: string): string {
  return `Tháng ${monthKey.slice(5, 7)}/${monthKey.slice(0, 4)}`; // allow-number: cắt chuỗi yyyy-mm-dd
}

/** "12" hoặc "1,5" (không thừa số 0, dấu phẩy). */
export function hoursText(h: number): string {
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(h); // allow-number: tối đa hai chữ số lẻ khi hiện giờ
}

/** Cột Thời hạn: "Đúng hạn", "Trễ hạn 2 giờ"; buổi Done trước khi có dấu thì "Chưa ghi nhận". */
export function lateText(r: Pick<HoursRow, 'late' | 'late_hours'>): string {
  if (r.late === null) return 'Chưa ghi nhận';
  return r.late ? `Trễ hạn ${hoursText(r.late_hours ?? 0)} giờ` : 'Đúng hạn';
}

/** "Giáo viên" hoặc "Trợ giảng". */
export function roleText(role: HoursRow['my_role']): string {
  return role === 'TRO_GIANG' ? 'Trợ giảng' : 'Giáo viên';
}

/** "24/10 · Buổi 5" */
export function rowDay(r: Pick<HoursRow, 'session_date' | 'session_no'>): string {
  const d = `${r.session_date.slice(8, 10)}/${r.session_date.slice(5, 7)}`; // allow-number: cắt chuỗi yyyy-mm-dd
  return r.session_no === null ? d : `${d} · Buổi ${r.session_no}`;
}
