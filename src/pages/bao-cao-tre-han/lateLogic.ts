// Hàm thuần của BC-08 Giáo viên trễ hạn hằng tháng: kiểu dữ liệu, danh sách tháng, gộp một dòng mỗi người. Có kiểm thử.
import { vnDayBounds } from '../../lib/vnDay';

export type LateRow = {
  user_id: string;
  code: string | null;
  name: string;
  role: 'GIAO_VIEN' | 'TRO_GIANG';
  branch_code: string;
  late_sessions: number;
  late_hours: number;
  done_sessions: number;
};
export type LateReport = {
  month: string;
  total: number;
  totals: { people: number; late_sessions: number; late_hours: number };
  rows: LateRow[];
};

export type LateExport = {
  month: string;
  total: number;
  exported: number;
  truncated: boolean;
  rows: LateRow[];
};

const MONTHS_BACK = 12; // allow-number: số tháng gần nhất cho chọn tháng (hiển thị, không phải luật)

/** Danh sách tháng gần nhất (mới trước) theo giờ Việt Nam: giá trị `YYYY-MM-01`, nhãn `Tháng MM/YYYY`. */
export function monthOptions(now: Date = new Date()): { value: string; label: string }[] {
  const [y, m] = vnDayBounds(now).dateKey.split('-').map(Number) as [number, number];
  const out: { value: string; label: string }[] = [];
  for (let i = 0; i < MONTHS_BACK; i++) {
    const d = new Date(Date.UTC(y, m - 1 - i, 1));
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    out.push({
      value: `${d.getUTCFullYear()}-${mm}-01`,
      label: `Tháng ${mm}/${d.getUTCFullYear()}`,
    });
  }
  return out;
}

/** Người dạy nhiều cơ sở có nhiều dòng: gộp thành MỘT dòng, cộng buổi trễ và giờ trễ. */
export function mergePerPerson(rows: LateRow[]): LateRow[] {
  const map = new Map<string, LateRow>();
  for (const r of rows) {
    const cur = map.get(r.user_id);
    if (!cur) {
      map.set(r.user_id, { ...r });
      continue;
    }
    cur.late_sessions += r.late_sessions;
    cur.late_hours += r.late_hours;
    cur.done_sessions += r.done_sessions;
    if (!cur.branch_code.split(', ').includes(r.branch_code))
      cur.branch_code += `, ${r.branch_code}`;
  }
  return [...map.values()];
}

/** Giờ một chữ số thập phân, dấu phẩy: 3,0. */
export const formatHours = (h: number): string => h.toFixed(1).replace('.', ',');
