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

/** Bản ghi phiếu từ app.get_upsale_ticket (migration 416). */
export type UpsaleTicketDetail = UpsaleRow & {
  lost_reason_code: string | null;
  lost_note: string | null;
  next_goal: string | null;
  next_roadmap: string | null;
  closed_at: string | null;
  created_by_name: string | null;
};

export type UpsaleEvent = {
  id: string;
  event_type: 'TAO' | 'GIAO' | 'DOI_GIAI_DOAN' | 'SUA_GHI_CHU';
  from_stage: string | null;
  to_stage: string | null;
  note: string | null;
  created_at: string;
  created_by_name: string | null;
};

export type UpsaleAction = 'giao' | 'doi_giai_doan' | 'sua_ghi_chu';

export type UpsaleRecord = {
  ticket: UpsaleTicketDetail;
  parent: {
    id: string;
    code: string;
    name: string;
    phone: string;
    email: string | null;
    zalo: boolean | null;
  } | null;
  student: { id: string; code: string; name: string } | null;
  class: { id: string; code: string; teacher_name: string | null };
  enrollments: { id: string; code: string; status_code: string; hours_left: number }[];
  hours: {
    bought: number;
    used: number;
    absences_window: number;
    window_days: number;
    /** Lần cấp giờ mua mới nhất (migration 623); null khi chưa có. */
    last_purchase: { hours: number; at: string } | null;
  };
  events: UpsaleEvent[];
  actions: UpsaleAction[];
};

/** app.list_upsale_order_options (migration 418): tuỳ chọn cho hộp Tạo đơn. */
export type UpsaleOrderOptions = {
  delivery_mode_code: string | null;
  packages: { id: string; code: string; name: string; prices: Record<string, number> }[];
  terms: { id: string; name: string }[];
  sessions: string[];
};

export type UpsaleOrderRow = {
  id: string;
  code: string;
  status_code: string;
  total_amount: number;
  created_at: string;
};
