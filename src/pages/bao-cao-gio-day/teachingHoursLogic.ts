// Hàm thuần của BC-09 Giờ dạy giáo viên: kiểu dữ liệu, danh sách tháng, gộp một dòng mỗi người khi xem «Tất cả cơ sở». Có kiểm thử.
import { vnDayBounds } from '../../lib/vnDay';

export type HoursByType = { CHINH: number; CUNG_CO: number; HOC_BU: number; BO_TRO: number };
export type HoursRow = {
  user_id: string;
  code: string | null;
  name: string;
  role: 'GIAO_VIEN' | 'TRO_GIANG';
  branch_code: string;
  hours: number;
  by_type: HoursByType;
};
export type HoursReport = {
  month: string;
  total: number;
  totals: { hours: number; teachers: number; assistants: number; by_type: HoursByType };
  rows: HoursRow[];
  /** null: chưa chốt; có giá trị: tháng đã chốt (cả hệ thống). */
  closed: { closed_at: string; closed_by_name: string } | null;
};

export const TYPE_COLUMNS: { key: keyof HoursByType; label: string }[] = [
  { key: 'CHINH', label: 'Học chính' },
  { key: 'CUNG_CO', label: 'Củng cố' },
  { key: 'HOC_BU', label: 'Học bù' },
  { key: 'BO_TRO', label: 'Học bổ trợ' },
];

const MONTHS_BACK = 12; // allow-number: số tháng gần nhất cho chọn tháng (hiển thị, không phải luật)

/** Danh sách tháng gần nhất (mới trước) theo giờ Việt Nam: giá trị `YYYY-MM-01`, nhãn `Tháng MM/YYYY`. */
export function monthOptions(now: Date = new Date()): { value: string; label: string }[] {
  const [y, m] = vnDayBounds(now).dateKey.split('-').map(Number) as [number, number];
  const out: { value: string; label: string }[] = [];
  for (let i = 0; i < MONTHS_BACK; i++) {
    const d = new Date(Date.UTC(y, m - 1 - i, 1));
    const yy = d.getUTCFullYear();
    const mm = String(d.getUTCMonth() + 1).padStart(2, '0');
    out.push({ value: `${yy}-${mm}-01`, label: `Tháng ${mm}/${yy}` });
  }
  return out;
}

/** Một người dạy nhiều cơ sở có nhiều dòng (theo từng cơ sở): gộp thành MỘT dòng, cộng giờ từng loại. Giữ thứ tự xuất hiện đầu tiên. */
export function mergePerPerson(rows: HoursRow[]): HoursRow[] {
  const map = new Map<string, HoursRow>();
  for (const r of rows) {
    const cur = map.get(r.user_id);
    if (!cur) {
      map.set(r.user_id, { ...r, by_type: { ...r.by_type } });
      continue;
    }
    cur.hours += r.hours;
    for (const t of TYPE_COLUMNS) cur.by_type[t.key] += r.by_type[t.key];
    if (!cur.branch_code.split(', ').includes(r.branch_code))
      cur.branch_code += `, ${r.branch_code}`;
  }
  return [...map.values()];
}

/** Giờ hiển thị một chữ số thập phân, dấu phẩy: 13,5. */
export const formatHours = (h: number): string => h.toFixed(1).replace('.', ',');

/** Tháng `YYYY-MM-01` đã kết thúc (hôm nay, giờ Việt Nam, đã sang tháng sau)? Chỉ để ẩn nút Chốt; DB kiểm lại. */
export function monthEnded(monthStart: string, now: Date = new Date()): boolean {
  const [y, m] = monthStart.split('-').map(Number) as [number, number];
  const [ty, tm] = vnDayBounds(now).dateKey.split('-').map(Number) as [number, number];
  return ty * 12 + tm > y * 12 + m;
}
