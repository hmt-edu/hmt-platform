// Hàm thuần của CH-08 Chiến dịch marketing: kiểu dữ liệu, nhãn, bộ lọc, chuyển ngày. Có kiểm thử.
export type CampaignRow = {
  id: string;
  name: string;
  starts_on: string | null;
  ends_on: string | null;
  is_active: boolean;
  lead_count: number;
  created_by_name: string | null;
  can_toggle: boolean;
};
export type CampaignPage = { total: number; rows: CampaignRow[] };
export type CampaignFilters = { q?: string; status?: 'DANG_DUNG' | 'NGUNG' };

export const STATUS_OPTIONS = [
  { value: '', label: 'Tất cả' },
  { value: 'DANG_DUNG', label: 'Đang dùng' },
  { value: 'NGUNG', label: 'Ngừng' },
];

/** Bộ lọc gửi máy chủ: bỏ ô trống. */
export function campaignFilters(q: string, status: string): CampaignFilters {
  const filters: CampaignFilters = {};
  const text = q.trim();
  if (text !== '') filters.q = text;
  if (status === 'DANG_DUNG' || status === 'NGUNG') filters.status = status;
  return filters;
}

/** «01/12/2026 – 31/12/2026», «Từ 01/12/2026», «Đến 31/12/2026» hoặc «Chưa đặt thời gian». */
export function periodText(
  from: string | null,
  to: string | null,
  format: (iso: string) => string,
): string {
  if (from && to) return `${format(from)} – ${format(to)}`;
  if (from) return `Từ ${format(from)}`;
  if (to) return `Đến ${format(to)}`;
  return 'Chưa đặt thời gian';
}

export const toIsoDate = (d: Date): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
