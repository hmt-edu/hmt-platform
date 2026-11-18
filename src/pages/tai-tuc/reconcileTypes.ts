// Kiểu dữ liệu màn TT-04 Đối chiếu tái tục theo tháng: khớp app.list_upsale_reconcile, app.upsale_reconcile_summary (migration 553).
export type ReconcileRow = {
  student_id: string;
  student_code: string;
  student_name: string;
  class_id: string;
  class_code: string;
  enrollment_codes: string | null;
  branch_code: string;
  hours_left: number | null;
  expected_end_date: string | null;
  campaign_label: string;
  ticket_id: string | null;
  ticket_code: string | null;
  ticket_origin: 'HE_THONG' | 'TAY' | null;
  missing_reason: 'CO_PHIEU_L5' | 'LOP_CHUA_CO_LICH' | 'CHO_QUET_DEM' | null;
};

export type ReconcilePage = { total: number; rows: ReconcileRow[] };

export type ReconcileSummary = {
  total: number;
  with_ticket: number;
  missing: number;
  manual: number;
  branches: { branch_code: string; total: number; with_ticket: number; missing: number }[];
};

export type ReconcileQuery = {
  /** Tháng YYYY-MM. */
  month: string;
  filters: Record<string, unknown>;
};
