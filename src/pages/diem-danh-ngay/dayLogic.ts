// BUOI-15 Điểm danh trong ngày: logic hiển thị thuần của danh sách theo dõi (R-DD-01..03; ĐỀ XUẤT docs/spec/de-xuat-luat-a.md).
export type DayState = 'CHUA_CO_DANH_SACH' | 'CHUA_GHI' | 'GHI_DO' | 'GHI_DU';

export type Counts = {
  CO_MAT: number;
  DI_MUON: number;
  VANG_CO_PHEP: number;
  VANG_KHONG_PHEP: number;
  CHUA: number;
};

export type DayRow = {
  session_id: string;
  class_id: string;
  class_code: string;
  session_no: number;
  branch_code: string;
  start_time: string;
  end_time: string;
  room_name: string | null;
  teacher_name: string | null;
  status_code: string;
  total: number;
  ops: Counts;
  teacher: Counts;
  notice: number;
  state: DayState;
};

export type DayPage = { total: number; rows: DayRow[] };

const STATE_NAMES: Record<DayState, string> = {
  CHUA_CO_DANH_SACH: 'Chưa có danh sách',
  CHUA_GHI: 'Chưa ghi',
  GHI_DO: 'Ghi dở',
  GHI_DU: 'Ghi đủ',
};

export function stateName(state: DayState): string {
  return STATE_NAMES[state];
}

/** Ghi đủ là xanh, ghi dở là cam, chưa ghi là đỏ, chưa có danh sách là trung tính. */
export function stateTone(state: DayState): 'success' | 'warning' | 'danger' | 'neutral' {
  if (state === 'GHI_DU') return 'success';
  if (state === 'GHI_DO') return 'warning';
  return state === 'CHUA_GHI' ? 'danger' : 'neutral';
}

/** "Có mặt 7 · Muộn 1 · Phép 0 · KP 0 · Chưa 2": chỉ nêu mục khác 0, rỗng thì gạch ngang. */
export function countsText(c: Counts): string {
  const parts: string[] = [];
  if (c.CO_MAT > 0) parts.push(`Có mặt ${c.CO_MAT}`);
  if (c.DI_MUON > 0) parts.push(`Muộn ${c.DI_MUON}`);
  if (c.VANG_CO_PHEP > 0) parts.push(`Phép ${c.VANG_CO_PHEP}`);
  if (c.VANG_KHONG_PHEP > 0) parts.push(`KP ${c.VANG_KHONG_PHEP}`);
  if (c.CHUA > 0) parts.push(`Chưa ${c.CHUA}`);
  return parts.length > 0 ? parts.join(' · ') : '—';
}

/** Cột Lưu ý: "PH báo nghỉ n" khi có em báo nghỉ trước (lý do liên hệ XIN_NGHI_HOC); không có thì gạch ngang. */
export function noticeText(n: number): string {
  return n > 0 ? `PH báo nghỉ ${n}` : '—';
}
