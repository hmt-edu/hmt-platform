// Kiểu dữ liệu QT-12: khớp app.list_login_events, app.list_export_log (migration 551).
export type LoginRow = {
  id: number;
  at: string;
  login_name: string;
  user_id: string | null;
  branch_code: string | null;
  result: string;
  ip: string | null;
  user_agent: string | null;
  temp_locked: boolean;
};
export type ExportRow = {
  id: number;
  at: string;
  user_id: string;
  user_name: string | null;
  branch_code: string | null;
  module_code: string;
  filters: Record<string, unknown>;
  row_count: number;
};
export type Paged<T> = { total: number; rows: T[] };
