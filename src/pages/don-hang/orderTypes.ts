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
