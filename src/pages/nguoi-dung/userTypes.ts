// Kiểu dữ liệu màn Người dùng (QT-01, QT-02): khớp kết quả app.list_users, app.get_user, app.export_users (migration 042).
export type UserRoleRef = { code: string; name: string };

export type UserRow = {
  id: string;
  display_name: string;
  login_name: string;
  staff_code: string | null;
  branch_code: string;
  roles: UserRoleRef[];
  is_locked: boolean;
  last_login_at: string | null;
  must_change_password: boolean;
  manager_name: string | null;
};
export type UserPage = { total: number; rows: UserRow[] };

export type LoginEvent = {
  at: string;
  result: string;
  ip: string | null;
  user_agent: string | null;
};

export type UserRecord = {
  id: string;
  display_name: string;
  login_name: string;
  staff_code: string | null;
  branch: { id: string; code: string; name: string };
  roles: (UserRoleRef & { require_mfa: boolean })[];
  manager: { id: string; name: string | null } | null;
  is_locked: boolean;
  locked_at: string | null;
  lock_reason: string | null;
  must_change_password: boolean;
  failed_login_count: number;
  temp_locked_until: string | null;
  last_login_at: string | null;
  created_at: string;
  mfa_devices: number;
  mfa_required: boolean;
  mfa_reset_at: string | null;
  mfa_reset_by: string | null;
  recent_logins: LoginEvent[];
};

export type UserExportRow = {
  staff_code: string | null;
  display_name: string;
  login_name: string;
  roles: string;
  branch: string;
  status: string;
};
export type UserExport = {
  total: number;
  exported: number;
  truncated: boolean;
  rows: UserExportRow[];
};

/** Kết quả đăng nhập (login_event.result) → chữ tiếng Việt cho lịch sử đăng nhập. */
export const LOGIN_RESULT_LABEL: Record<string, string> = {
  THANH_CONG: 'Thành công',
  SAI_MAT_KHAU: 'Sai mật khẩu',
  TAI_KHOAN_KHOA: 'Tài khoản bị khoá',
  KHOA_TAM: 'Khoá tạm',
  KHONG_CO_TAI_KHOAN: 'Không có tài khoản',
  LOI: 'Lỗi',
};
