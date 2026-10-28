// Kiểu dữ liệu màn Báo giá (BH-01): một dòng danh sách do hàm list_quotations trả; chỉ các cột màn hiện.
export type QuotationRow = {
  id: string;
  code: string;
  status_code: string;
  display_status_code: string;
  parent_id: string;
  parent_code: string;
  parent_name: string;
  parent_phone: string;
  opportunity_id: string;
  opportunity_code: string;
  student_name: string | null;
  /** Tên các em theo thứ tự dòng, không trùng (list_quotations từ migration 053). */
  student_names: string[];
  student_count: number;
  total_amount: number;
  valid_until: string | null;
  overdue_days: number | null;
  sent_at: string | null;
  created_at: string;
  branch_code: string;
  created_by_name: string | null;
};

export type QuotationPage = { total: number; rows: QuotationRow[] };

export type QuotationExportRow = {
  code: string;
  status: string;
  parent_name: string;
  parent_phone: string;
  opportunity: string;
  students: string | null;
  total_amount: number;
  valid_until: string | null;
  sent_at: string | null;
  branch: string;
  created_by: string | null;
  created_at: string;
};

export type QuotationExportResult = {
  total: number;
  exported: number;
  truncated: boolean;
  rows: QuotationExportRow[];
};

export type QuotationLineDiscount = {
  id: string;
  policy_id: string;
  policy_code: string;
  policy_name: string;
  kind: 'PERCENT' | 'GIFT_HOURS';
  applied_value: number;
  requires_approval: boolean;
};

export type QuotationLine = {
  id: string;
  line_no: number;
  line_kind: 'ENROL' | 'GIFT';
  prospect_student_id: string | null;
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
  gift_policy_id: string | null;
  gift_policy_name: string | null;
  /** Đơn đang sống sinh từ dòng này (Đ106: tối đa một); chưa lên đơn hoặc đơn đã huỷ thì rỗng. */
  order_id: string | null;
  order_code: string | null;
  order_status_code: string | null;
  discounts: QuotationLineDiscount[];
};

/** Bản ghi báo giá do get_quotation trả (BH-02). */
export type QuotationRecord = {
  id: string;
  code: string;
  legacy_ref: string | null;
  branch_id: string;
  branch_code: string;
  opportunity_id: string;
  opportunity_code: string;
  parent_id: string;
  parent_code: string;
  parent_name: string;
  parent_phone: string;
  status_code: 'NHAP' | 'DA_GUI' | 'TU_CHOI' | 'HUY';
  display_status_code: string;
  display_status: string | null;
  priced_on: string;
  valid_until: string | null;
  overdue_days: number | null;
  sent_at: string | null;
  sent_by_name: string | null;
  reject_reason: string | null;
  reject_note: string | null;
  rejected_at: string | null;
  cancel_note: string | null;
  cancelled_at: string | null;
  total_amount: number;
  /** Tổng niêm yết và tổng chiết khấu do máy chủ cộng từ các dòng đã đóng băng (migration 062); quà tặng không tính. */
  gross_total: number;
  discount_total: number;
  created_at: string;
  created_by_name: string | null;
  has_incomplete_students: boolean;
  /** Số đơn đang sống sinh từ báo giá này (migration 056). */
  live_order_count: number;
  lines: QuotationLine[];
};
