// GD-07 Sắp hết giờ: logic hiển thị thuần của danh sách dự báo (R-GD-07: hạn gói chỉ để dự báo, không chặn; ĐỀ XUẤT docs/spec/de-xuat-luat-a.md).
export type ExpiringStatus = 'HET_GIO' | 'SAP_HET_GIO' | 'SAP_HET_HAN_GOI' | 'QUA_HAN_CON_GIO';

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
  /** Phiếu tái tục đang mở của (học sinh, lớp), nếu có (canvas GD07, thẻ F51). */
  upsale_id: string | null;
  upsale_code: string | null;
};

export type ExpiringPage = { total: number; rows: ExpiringRow[] };

const NAMES: Record<ExpiringStatus, string> = {
  HET_GIO: 'Hết giờ',
  SAP_HET_GIO: 'Sắp hết giờ',
  SAP_HET_HAN_GOI: 'Sắp hết hạn gói',
  QUA_HAN_CON_GIO: 'Quá hạn gói, còn giờ',
};

export function statusName(code: ExpiringStatus): string {
  return NAMES[code];
}

/** Hết giờ là đỏ, sắp hết giờ là cam, quá hạn gói mà còn giờ là trung tính (vẫn học bình thường, R-GD-07). */
export function statusTone(code: ExpiringStatus): 'danger' | 'warning' | 'neutral' {
  if (code === 'HET_GIO') return 'danger';
  return code === 'SAP_HET_GIO' || code === 'SAP_HET_HAN_GOI' ? 'warning' : 'neutral';
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

/** Ô «Phiếu tái tục» khi chưa có phiếu: Hết giờ thì nói rõ phiếu sẽ do đợt quét đêm sinh (canvas GD07), còn lại gạch ngang. */
export function noUpsaleText(status: ExpiringStatus): string {
  return status === 'HET_GIO' ? 'Chưa có phiếu · chờ đợt quét đêm' : '—';
}

/**
 * Câu giải thích đầu danh sách (canvas GD07). Ngưỡng giờ, ngày lấy từ tham số upsale_hours_left_threshold,
 * upsale_days_left_threshold (không viết cứng); chưa đọc được tham số thì bỏ phần ngưỡng.
 */
export function expiringIntro(
  hoursThreshold: number | null,
  daysThreshold: number | null,
  todayText: string,
): string {
  const base = 'Mỗi dòng là một học sinh trong một lớp; giờ còn là tổng các ghi danh còn hiệu lực.';
  if (hoursThreshold === null || daysThreshold === null) return base;
  return `${base} Gắn «Sắp hết giờ» khi giờ còn ≤ ${hoursThreshold} giờ hoặc ngày hết giờ dự kiến ≤ ${daysThreshold} ngày tính từ hôm nay (${todayText}).`;
}

/** Trường nhóm giao diện GD-07 (canvas GD07: Tình trạng) → tên trường của app.expiring_group_counts. */
export const EXPIRING_GROUP_FIELD_OF: Record<string, string> = { status: 'status' };

/** Bộ lọc của MỘT nhóm (để mở nhóm tải dòng bằng list_expiring_enrollments). */
export function expiringGroupFilter(field: string, key: string): Record<string, unknown> {
  if (field === 'status' && key !== '') return { status: [key] };
  return {};
}
