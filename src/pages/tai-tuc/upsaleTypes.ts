// Kiểu dữ liệu màn Phiếu tái tục (TT-01): khớp kết quả app.list_upsale_tickets, app.upsale_board (migration 414).
export type UpsaleRow = {
  id: string;
  code: string;
  branch_code: string;
  student_id: string;
  student_name: string;
  class_id: string;
  class_code: string;
  enrollment_count: number;
  hours_left: number | null;
  expected_end_date: string | null;
  /** «Tái tục MM/YYYY»: nhãn tháng tính từ ngày hết giờ dự kiến, không phải bản ghi chiến dịch. */
  campaign_label: string | null;
  stage_code: string;
  substage_code: string | null;
  owner_id: string | null;
  owner_name: string | null;
  risk_flag: boolean;
  origin_code: 'HE_THONG' | 'TAY';
  created_at: string;
};

export type UpsalePage = { total: number; rows: UpsaleRow[] };
export type UpsaleFilters = Record<string, unknown>;
export type UpsaleBoardColumn = {
  stage_code: string;
  name: string;
  total: number;
  rows: UpsaleRow[];
};

export type UpsalePreview = {
  found: boolean;
  student_name?: string;
  class_code?: string;
  enrollment_count?: number;
  open_ticket_code?: string | null;
};

export type UpsaleAssignee = { id: string; name: string };
