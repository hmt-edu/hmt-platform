// Kiểu dữ liệu màn Lịch hẹn: khớp kết quả hàm list_appointments (docs/spec/04 R-CRM-04).
export type AppointmentStatus = 'CHUA_LAM' | 'HOAN_THANH' | 'HUY';

export type AppointmentRow = {
  id: string;
  activity_code: string;
  scheduled_at: string;
  title: string;
  status: AppointmentStatus;
  owner_id: string;
  owner_name: string | null;
  lead_id: string | null;
  lead_code: string | null;
  opportunity_id: string | null;
  opportunity_code: string | null;
  student_test_id: string | null;
  student_test_code: string | null;
  is_auto_reminder: boolean;
  /** Mã và nhãn của hồ sơ gắn (lead, cơ hội hoặc phiếu kiểm tra). */
  record_code: string | null;
  record_label: string | null;
  cancel_reason_code: string | null;
  branch_code: string;
};

export type AppointmentPage = { total: number; rows: AppointmentRow[] };

export const STATUS_LABEL: Record<AppointmentStatus, string> = {
  CHUA_LAM: 'Chưa làm',
  HOAN_THANH: 'Hoàn thành',
  HUY: 'Huỷ',
};

/** Hồ sơ gắn thuộc loại nào, để dựng đường dẫn và nhãn "Lead", "Cơ hội", "Phiếu". */
export function recordKind(row: AppointmentRow): 'LEAD' | 'OPPORTUNITY' | 'TEST' {
  if (row.lead_id) return 'LEAD';
  if (row.opportunity_id) return 'OPPORTUNITY';
  return 'TEST';
}

export const RECORD_KIND_LABEL = { LEAD: 'Lead', OPPORTUNITY: 'Cơ hội', TEST: 'Phiếu' } as const;

/** Một dòng xuất file (khớp export_appointments; tên danh mục, không phải mã). */
export type AppointmentExportRow = {
  kind: string;
  record_code: string | null;
  record_label: string | null;
  activity: string | null;
  title: string;
  scheduled_at: string;
  status: string;
  owner: string | null;
  branch: string;
  auto_reminder: boolean;
  cancel_reason: string | null;
  cancel_note: string | null;
  created_at: string;
};
export type AppointmentExport = {
  total: number;
  exported: number;
  truncated: boolean;
  rows: AppointmentExportRow[];
};

/** Kết quả giao hàng loạt (khớp assign_appointments): giao phần hợp lệ, nêu lý do từng nhóm bị bỏ. */
export type AssignSkipReason = { code: string; message: string; count: number; ids: string[] };
export type AssignAppointmentsResult = {
  requested: number;
  assigned: number;
  skipped: number;
  reasons: AssignSkipReason[];
};
