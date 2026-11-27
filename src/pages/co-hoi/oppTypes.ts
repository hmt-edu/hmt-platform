// Kiểu dữ liệu màn Cơ hội: khớp kết quả các hàm list_opportunities, opportunity_board, get_opportunity (docs/spec/04 R-CRM-02, 03, 12 đến 17).

import type { ProspectStudent } from '../../features/prospect/prospectLogic';

export type OppStatus = 'DANG_DUNG' | 'DA_GOP';

export type OpportunityRow = {
  id: string;
  code: string;
  /** Trống = cơ hội tạo trực tiếp, không qua lead. */
  lead_id: string | null;
  lead_code: string | null;
  parent_id: string;
  parent_code: string;
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
  record_status: OppStatus;
  merged_into_code: string | null;
};

export type OpportunityPage = { total: number; rows: OpportunityRow[] };

/** Thẻ Kanban: các cột màn hiện. */
export type OppBoardCard = Pick<
  OpportunityRow,
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

export type OppBoardColumn = {
  stage_code: string;
  name: string;
  total: number;
  bar: { ok: number; today: number; overdue: number; none: number };
  rows: OppBoardCard[];
};

/** Một phiếu kiểm tra của cơ hội (tên danh mục do máy chủ trả). */
export type OppTest = {
  id: string;
  code: string;
  status_code: string;
  status: string | null;
  scheduled_at: string;
  subject: string | null;
  mode: string | null;
  level: string | null;
  test_branch_code: string;
  score: number | null;
  cancel_reason: string | null;
};

/** Số phiếu theo trạng thái (R-CRM-12, 14), để giao diện chọn đúng hộp chuyển giai đoạn. */
export type OppTestState = {
  in_progress: number;
  completed: number;
  cancelled: number;
  in_progress_codes: string[] | null;
};

/** Kết quả get_opportunity: các cột của cơ hội kèm tên, mã, số đếm cho trang bản ghi. */
export type OppRecord = {
  id: string;
  code: string;
  /** Danh sách em (app.prospect_students_json). */
  students: ProspectStudent[];
  /** Trống = cơ hội tạo trực tiếp, không qua lead. */
  lead_id: string | null;
  lead_code: string | null;
  parent_id: string;
  parent_code: string;
  parent_name: string;
  parent_phone: string;
  parent_province_code: string | null;
  parent_ward_code: string | null;
  parent_address: string | null;
  student_id: string | null;
  branch_id: string;
  branch_code: string;
  branch_name: string;
  owner_id: string;
  owner_name: string | null;
  supporter_id: string | null;
  supporter_name: string | null;
  need: string | null;
  student_name: string | null;
  student_birth_date: string | null;
  student_birth_year: number | null;
  school: string | null;
  self_rating: string | null;
  goal: string | null;
  source_type_code: string;
  source_code: string;
  channel_code: string | null;
  campaign_id: string | null;
  campaign_name: string | null;
  stage_code: string;
  substage_code: string | null;
  skip_reason_code: string | null;
  record_status: OppStatus;
  merged_into_code: string | null;
  assigned_at: string;
  next_appointment_at: string | null;
  legacy_ref: string | null;
  created_at: string;
  created_by_name: string | null;
  updated_at: string;
  updated_by_name: string | null;
  appointments_total: number;
  appointments_open: number;
  tests_total: number;
  sales_documents: string[] | null;
  test_state: OppTestState | null;
  tests: OppTest[];
};
