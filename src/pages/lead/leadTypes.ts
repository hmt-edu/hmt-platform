// Kiểu dữ liệu màn Lead: khớp kết quả các hàm list_leads, lead_board, lead_group_counts, list_assignable_staff, export_leads.

export type LeadStatus = 'DANG_DUNG' | 'DA_GOP' | 'DA_HUY';

export type LeadRow = {
  id: string;
  code: string;
  parent_name: string;
  parent_phone: string;
  student_name: string | null;
  student_birth_year: number | null;
  stage_code: string;
  substage_code: string | null;
  source_type_code: string;
  source_code: string;
  channel_code: string | null;
  campaign_id: string | null;
  campaign_name: string | null;
  owner_id: string;
  owner_name: string | null;
  supporter_id: string | null;
  supporter_name: string | null;
  branch_code: string;
  assigned_at: string;
  next_appointment_at: string | null;
  created_at: string;
  record_status: LeadStatus;
  merged_into_code: string | null;
};

export type LeadPage = { total: number; rows: LeadRow[] };

/** Thẻ Kanban: các cột màn hiện (không có chiến dịch, người hỗ trợ…). */
export type BoardCard = Pick<
  LeadRow,
  | 'id'
  | 'code'
  | 'parent_name'
  | 'parent_phone'
  | 'student_name'
  | 'source_type_code'
  | 'source_code'
  | 'channel_code'
  | 'substage_code'
  | 'owner_id'
  | 'owner_name'
  | 'branch_code'
  | 'next_appointment_at'
  | 'created_at'
>;

export type BoardBar = { ok: number; today: number; overdue: number; none: number };

export type BoardColumn = {
  stage_code: string;
  name: string;
  total: number;
  bar: BoardBar;
  rows: BoardCard[];
};

export type GroupCount = {
  k1: string;
  l1: string;
  k2: string | null;
  l2: string | null;
  count: number;
};
export type GroupCounts = { total: number; groups: GroupCount[] };

export type ExportRow = Record<string, string | number | null>;
export type ExportResult = {
  total: number;
  exported: number;
  truncated: boolean;
  rows: ExportRow[];
};
