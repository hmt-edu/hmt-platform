// Kiểu dữ liệu màn Đơn hàng (BH-06): một dòng danh sách do hàm list_orders trả; chỉ các cột màn hiện.
export type OrderRow = {
  id: string;
  code: string;
  status_code: 'NHAP' | 'DA_TRINH' | 'DA_DUYET' | 'HUY';
  status: string | null;
  parent_id: string;
  parent_code: string;
  parent_name: string;
  parent_phone: string;
  opportunity_id: string | null;
  opportunity_code: string | null;
  quotation_id: string | null;
  quotation_code: string | null;
  /** Em của dòng đầu tiên. */
  student_name: string | null;
  /** Tên các em theo thứ tự dòng, không trùng (list_orders từ migration 060). */
  student_names: string[];
  line_count: number;
  total_amount: number;
  needs_acknowledgement: boolean;
  submitted_at: string | null;
  approved_at: string | null;
  created_at: string;
  branch_code: string;
  created_by_name: string | null;
  approver_name: string | null;
};

export type OrderPage = { total: number; rows: OrderRow[] };

export type OrderExportRow = {
  code: string;
  status: string;
  parent_name: string;
  parent_phone: string;
  opportunity: string | null;
  quotation: string | null;
  students: string | null;
  total_amount: number;
  submitted_at: string | null;
  approved_at: string | null;
  branch: string;
  created_by: string | null;
  created_at: string;
};

export type OrderExportResult = {
  total: number;
  exported: number;
  truncated: boolean;
  rows: OrderExportRow[];
};

export type OrderLineDiscount = {
  id: string;
  policy_id: string;
  policy_code: string;
  policy_name: string;
  kind: 'PERCENT' | 'GIFT_HOURS';
  applied_value: number;
  requires_approval: boolean;
};

export type OrderLine = {
  id: string;
  line_no: number;
  line_kind: 'ENROL' | 'GIFT';
  quotation_line_id: string | null;
  package_id: string;
  package_code: string;
  package_name: string;
  package_type_code: string;
  delivery_mode_code: string;
  unit_code: 'GIO' | 'THANG' | 'BO';
  quantity: number;
  gifted_quantity: number;
  unit_price: number;
  gross_amount: number;
  discount_percent: number;
  gift_percent: number;
  discount_amount: number;
  line_total: number;
  over_cap: boolean;
  needs_acknowledgement: boolean;
  student_name: string | null;
  student_birth_year: number | null;
  student_code: string | null;
  student_complete: boolean;
  gift_policy_name: string | null;
  discounts: OrderLineDiscount[];
};

export type OrderInstallment = {
  seq: number;
  due_days: number;
  amount: number;
  due_date: string | null;
};

export type OrderEvent = {
  seq: number;
  event_code:
    'TAO' | 'TRINH' | 'DUYET' | 'TU_CHOI' | 'HUY' | 'SUA' | 'CANH_BAO_XEP_LOP' | 'CHO_HOC_TRUOC';
  from_status: string | null;
  to_status: string | null;
  reason_code: string | null;
  note: string | null;
  on_behalf: boolean;
  created_at: string;
  actor_name: string | null;
  /** Ảnh chụp tổng tiền của đơn lúc ghi sự kiện (migration 080); sự kiện cũ thì null. */
  total_amount?: number | null | undefined;
};

/** Đường duyệt dự kiến của đơn Nháp (get_order): TRUONG_CS = chưa có quản lý trực tiếp, Trưởng cơ sở duyệt (R-V2-12, migration 083); THIEU = chưa có quản lý và cơ sở cũng chưa có Trưởng cơ sở. */
export type ExpectedBlock = 'KHONG_CO_QUAN_LY' | 'NGUOI_DUYET_BI_KHOA' | 'NGUOI_DUYET_THIEU_QUYEN';
export type ExpectedRoute = 'QUAN_LY' | 'TU_DUYET' | 'TRUONG_CS' | 'THIEU';

/** Bản ghi đơn do get_order trả (BH-05). Mọi con số do máy chủ tính; giao diện không cộng, không trừ. */
export type OrderRecord = {
  id: string;
  code: string;
  legacy_ref: string | null;
  branch_id: string;
  branch_code: string;
  opportunity_id: string | null;
  opportunity_code: string | null;
  quotation_id: string | null;
  quotation_code: string | null;
  parent_id: string;
  parent_code: string;
  parent_name: string;
  parent_phone: string;
  status_code: 'NHAP' | 'DA_TRINH' | 'DA_DUYET' | 'HUY';
  status: string | null;
  payment_term_name: string | null;
  priced_on: string;
  total_amount: number;
  gross_total: number;
  discount_total: number;
  approval_route: 'QUAN_LY' | 'TU_DUYET' | 'TRUONG_CS' | null;
  /** Người lập và người duyệt đã chốt lúc trình (id), để hiện đúng nút Huỷ theo R-TIEN-38. */
  created_by: string | null;
  assigned_approver_id: string | null;
  needs_acknowledgement: boolean;
  submitted_at: string | null;
  submitted_by_name: string | null;
  approver_name: string | null;
  approved_at: string | null;
  approved_by_name: string | null;
  approved_on_behalf: boolean;
  cancel_reason_code: string | null;
  cancel_reason: string | null;
  cancel_note: string | null;
  cancelled_at: string | null;
  created_at: string;
  created_by_name: string | null;
  has_incomplete_students: boolean;
  expected_route: ExpectedRoute | null;
  expected_approver_id: string | null;
  expected_approver_name: string | null;
  expected_approver_can_approve: boolean | null;
  /** Một lý do chặn phía người duyệt của đơn Nháp (migration 082, Q-63, Q-62): dải thông báo cạnh nút trình dùng lại. null: không chặn. */
  expected_block?: ExpectedBlock | null | undefined;
  /** Việc người gọi làm được ở tình trạng hiện tại (get_order từ migration 063): giao diện chỉ hiện nút đúng, máy chủ kiểm lại. */
  can_submit: boolean;
  can_cancel: boolean;
  can_approve: boolean;
  can_reject: boolean;
  lines: OrderLine[];
  installments: OrderInstallment[];
  events: OrderEvent[];
};
