// QT-14 Ngày nghỉ lễ: logic thuần (đổi ngày ↔ chuỗi yyyy-mm-dd theo giờ địa phương, nhãn phạm vi). Luật R-LOP-12, R-LOP-09; quyền do hàm DB kiểm.
export type Holiday = {
  id: string;
  holiday_date: string;
  name: string;
  branch_id: string | null;
  is_active: boolean;
};

export type HolidaySession = {
  id: string;
  session_date: string;
  start_time: string;
  end_time: string;
  status_code: string;
  class_id: string;
  class_code: string;
  branch_code: string;
};
export type HolidaySessions = { total: number; rows: HolidaySession[] };

export const toIso = (d: Date): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: định dạng yyyy-mm-dd

export function fromIso(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y ?? 0, (m ?? 1) - 1, d ?? 1);
}

/** Nhãn phạm vi: "Mọi cơ sở" khi branch_id rỗng, không thì mã cơ sở. */
export const scopeLabel = (h: Holiday, branchCode: (id: string) => string): string =>
  h.branch_id ? branchCode(h.branch_id) : 'Mọi cơ sở';

/** Khoảng ngày của một năm dương lịch để lọc ở máy chủ. */
export const yearRange = (year: number): { from: string; to: string } => ({
  from: `${year}-01-01`,
  to: `${year}-12-31`,
});

export const SESSION_STATUS_LABEL: Record<string, string> = {
  NHAP: 'Nháp',
  DA_CHOT: 'Đã chốt',
};
