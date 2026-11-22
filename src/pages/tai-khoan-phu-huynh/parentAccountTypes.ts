// Kiểu dữ liệu màn Tài khoản phụ huynh (QT-17): khớp kết quả app.list_parent_accounts (migration 616).
export type ParentAccountState = 'CHUA_CAP' | 'HOAT_DONG' | 'BI_KHOA';

export type ParentAccountRow = {
  parent_id: string;
  parent_code: string;
  full_name: string;
  branch_code: string;
  children_count: number;
  /** Tài khoản đăng nhập; null khi chưa cấp. */
  user_id: string | null;
  state: ParentAccountState;
  must_change_password: boolean;
  last_login_at: string | null;
};

export type ParentAccountPage = { total: number; rows: ParentAccountRow[] };
