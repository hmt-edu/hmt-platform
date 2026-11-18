// Kiểu dữ liệu QT-11 Nhật ký thao tác: khớp kết quả app.list_audit_log (migration 550).
export type AuditRow = {
  id: number;
  at: string;
  table_name: string;
  record_id: string;
  action: 'I' | 'U' | 'D';
  /** Sửa: {"cột": [cũ, mới]}; xoá: cả dòng cũ; tạo: rỗng. */
  changes: Record<string, unknown> | null;
  actor_id: string | null;
  actor_name: string | null;
};
export type AuditPage = { total: number; rows: AuditRow[] };
