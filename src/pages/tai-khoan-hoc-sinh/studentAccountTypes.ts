// Kiểu dữ liệu màn Tài khoản học sinh (QT-13): khớp kết quả app.list_student_accounts (migration 565).
export type StudentAccountState = 'CHUA_CAP' | 'HOAT_DONG' | 'BI_KHOA';

export type StudentAccountRow = {
  student_id: string;
  student_code: string;
  full_name: string;
  branch_code: string;
  parent_name: string;
  /** Tài khoản đăng nhập; null khi chưa cấp. */
  user_id: string | null;
  state: StudentAccountState;
  must_change_password: boolean;
  last_login_at: string | null;
};

export type StudentAccountPage = { total: number; rows: StudentAccountRow[] };

/** Một dòng kết quả cấp hàng loạt: mật khẩu tạm chỉ nằm trong bộ nhớ và trong file tải về một lần. */
export type IssueResult = {
  student_code: string;
  full_name: string;
  password: string | null;
  error: string | null;
};
