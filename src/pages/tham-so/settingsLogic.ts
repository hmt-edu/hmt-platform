// QT-09 Cài đặt tham số nghiệp vụ: logic thuần (nhóm, kiểm khoảng, hiển thị giá trị). Luật do hàm DB kiểm lần nữa (set_setting + trigger kiểm khoảng).
// Chỉ Admin. Tham số lấy từ bảng setting_def (khai báo + giá trị chung) và setting_branch (ghi đè theo cơ sở); khoảng, đơn vị, kiểu là dữ liệu, không viết cứng ở đây.
export type SettingDef = {
  key: string;
  name: string;
  description: string;
  value_type: 'INT' | 'NUMERIC' | 'BOOL' | 'TEXT';
  unit: string | null;
  min_value: number | null;
  max_value: number | null;
  value: string;
  allow_branch_override: boolean;
  module: string | null;
};

export type SettingOverride = {
  setting_key: string;
  branch_id: string;
  value: string;
  is_active: boolean;
};

/** Tên nhóm theo `module` của tham số; tham số không có module vào nhóm "Chung". */
export const GROUP_LABEL: Record<string, string> = {
  BAN_HANG: 'Bán hàng',
  VAN_HANH_LOP: 'Vận hành lớp',
  CONG_GIAO_VIEN: 'Cổng giáo viên',
  CSKH: 'CSKH',
  ADMIN: 'Đăng nhập, bảo mật',
  CHUNG: 'Chung',
};
const GROUP_ORDER = ['BAN_HANG', 'VAN_HANH_LOP', 'CONG_GIAO_VIEN', 'CSKH', 'ADMIN', 'CHUNG'];

export const groupOf = (def: SettingDef): string => def.module ?? 'CHUNG';

export type SettingGroup = { code: string; label: string; items: SettingDef[] };

export function buildGroups(defs: SettingDef[], search: string): SettingGroup[] {
  const key = search.trim().toLocaleLowerCase('vi');
  const hit = (d: SettingDef) =>
    key === '' ||
    d.name.toLocaleLowerCase('vi').includes(key) ||
    d.key.includes(key) ||
    d.description.toLocaleLowerCase('vi').includes(key);
  const byGroup = new Map<string, SettingDef[]>();
  for (const d of defs.filter(hit)) {
    const g = groupOf(d);
    byGroup.set(g, [...(byGroup.get(g) ?? []), d]);
  }
  return [...byGroup.keys()]
    .sort((a, b) => GROUP_ORDER.indexOf(a) - GROUP_ORDER.indexOf(b))
    .map((code) => ({
      code,
      label: GROUP_LABEL[code] ?? code,
      items: (byGroup.get(code) ?? []).sort((a, b) => a.name.localeCompare(b.name, 'vi')),
    }));
}

/** Tham số lưu bằng phút nhưng màn Cài đặt hiện và nhập theo NGÀY (canvas QT-09, spec 06: tự đăng xuất giáo viên, trợ giảng, học sinh). */
const DAY_VIEW_KEYS = new Set(['teacher_idle_logout_minutes', 'student_idle_logout_minutes']);
const MINUTES_PER_DAY = 1440; // allow-number: đổi đơn vị phút ↔ ngày để hiển thị, không phải tham số nghiệp vụ

export const isDayView = (def: SettingDef) => DAY_VIEW_KEYS.has(def.key);

const trimNumber = (n: number) => String(Math.round(n * 100) / 100); // allow-number: làm tròn hiển thị 2 chữ số

/** Giá trị đưa vào ô nhập (theo ngày với tham số hiện theo ngày). */
export function toInputText(def: SettingDef, stored: string): string {
  if (isDayView(def)) return trimNumber(Number(stored) / MINUTES_PER_DAY);
  return stored;
}

/** Từ ô nhập về giá trị lưu (phút với tham số hiện theo ngày). Trả null khi không phải số. */
export function fromInputText(def: SettingDef, text: string): string | null {
  const t = text.trim();
  if (def.value_type === 'BOOL') return t === 'true' || t === 'false' ? t : null;
  if (def.value_type === 'TEXT') return t === '' ? null : t;
  if (t === '' || !/^-?\d+([.,]\d+)?$/.test(t)) return null;
  const n = Number(t.replace(',', '.'));
  const stored = isDayView(def) ? n * MINUTES_PER_DAY : n;
  if (def.value_type === 'INT' && !Number.isInteger(stored)) return null;
  return String(stored);
}

export function unitLabel(def: SettingDef): string {
  if (isDayView(def)) return 'ngày';
  return def.unit ?? '';
}

/** Khoảng cho phép viết ra chữ kèm đơn vị ("1–90 ngày"); tham số hiện theo ngày: "5 phút–14 ngày" (spec 06). BOOL và TEXT không có khoảng. */
export function rangeLabel(def: SettingDef): string {
  if (def.value_type === 'BOOL' || def.value_type === 'TEXT') return '';
  if (def.min_value === null || def.max_value === null) return '';
  if (isDayView(def))
    return `${def.min_value} phút–${trimNumber(def.max_value / MINUTES_PER_DAY)} ngày`;
  const unit = unitLabel(def);
  return `${def.min_value}–${def.max_value}${unit ? ` ${unit}` : ''}`;
}

/** Câu hiển thị giá trị trong bảng ("14 ngày", "Bật"). */
export function formatSetting(def: SettingDef, stored: string): string {
  if (def.value_type === 'BOOL') return stored === 'true' ? 'Bật' : 'Tắt';
  if (def.value_type === 'TEXT') return stored;
  const shown = toInputText(def, stored);
  const asNumber = Number(shown);
  const text = Number.isFinite(asNumber) ? asNumber.toLocaleString('vi-VN') : shown;
  const unit = unitLabel(def);
  return unit ? `${text} ${unit}` : text;
}

/** Lỗi nhập hiện ngay dưới ô (nút Lưu khoá). Rỗng khi hợp lệ. */
export function inputError(def: SettingDef, text: string): string | null {
  if (def.value_type === 'BOOL') return null;
  const stored = fromInputText(def, text);
  if (stored === null) {
    if (def.value_type === 'TEXT') return 'Nhập giá trị.';
    return def.value_type === 'INT' ? 'Nhập một số nguyên.' : 'Nhập một số.';
  }
  if (def.value_type === 'TEXT') return null;
  const n = Number(stored);
  if (
    (def.min_value !== null && n < def.min_value) ||
    (def.max_value !== null && n > def.max_value)
  ) {
    return `Giá trị phải trong khoảng ${rangeLabel(def)}.`;
  }
  return null;
}
