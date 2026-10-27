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
