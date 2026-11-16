// GD-07 Sắp hết giờ: logic hiển thị thuần của danh sách dự báo (R-GD-07: hạn gói chỉ để dự báo, không chặn; ĐỀ XUẤT docs/spec/de-xuat-luat-a.md).
export type ExpiringStatus = 'HET_GIO' | 'SAP_HET_GIO' | 'QUA_HAN_CON_GIO';

export type ExpiringRow = {
  student_id: string;
  student_name: string;
  class_id: string;
  class_code: string;
  enrollment_codes: string[];
  hours_left: number;
  projected_end: string | null;
  validity_date: string | null;
  status_code: ExpiringStatus;
};

export type ExpiringPage = { total: number; rows: ExpiringRow[] };

const NAMES: Record<ExpiringStatus, string> = {
  HET_GIO: 'Hết giờ',
  SAP_HET_GIO: 'Sắp hết giờ',
  QUA_HAN_CON_GIO: 'Quá hạn gói, còn giờ',
};

export function statusName(code: ExpiringStatus): string {
  return NAMES[code];
}

/** Hết giờ là đỏ, sắp hết giờ là cam, quá hạn gói mà còn giờ là trung tính (vẫn học bình thường, R-GD-07). */
export function statusTone(code: ExpiringStatus): 'danger' | 'warning' | 'neutral' {
  if (code === 'HET_GIO') return 'danger';
  return code === 'SAP_HET_GIO' ? 'warning' : 'neutral';
}

/** "2026-11-30" thành "30/11/2026"; rỗng thì gạch ngang. */
export function dateText(iso: string | null): string {
  if (iso === null) return '—';
  const [y, m, d] = iso.split('-');
  return `${d ?? ''}/${m ?? ''}/${y ?? ''}`;
}

/** Giờ còn một chữ số thập phân kiểu Việt ("2,5"); số nguyên không có phần lẻ. */
export function hoursText(hours: number): string {
  return Number.isInteger(hours) ? String(hours) : hours.toFixed(1).replace('.', ',');
}
