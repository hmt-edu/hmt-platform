// Kiểu dữ liệu màn Số dư khách hàng (TC-14): dòng danh sách do list_customer_balances trả, lịch sử do get_customer_balance_history trả. Giao diện KHÔNG tính tiền.
export type BalanceRow = {
  parent_id: string;
  parent_code: string;
  parent_name: string;
  branch_code: string;
  balance: number;
  last_date: string | null;
  entries: number;
};

export type BalancePage = { total: number; rows: BalanceRow[] };

export type BalanceEntryType =
  'DAU_KY_THU_THUA' | 'DAU_KY_CONG_NO' | 'TU_DUNG_HOC' | 'DUNG_CHO_DON' | 'DIEU_CHINH';

export type BalanceEntry = {
  id: string;
  entry_type: BalanceEntryType;
  amount: number;
  entry_date: string;
  source_ref: string | null;
  note: string | null;
  enrollment_code: string | null;
  student_name: string | null;
};

export type BalanceHistory = {
  parent: { id: string; code: string; name: string; branch_code: string };
  balance: number;
  entries: BalanceEntry[];
};

export const BALANCE_ENTRY_NAME: Record<BalanceEntryType, string> = {
  DAU_KY_THU_THUA: 'Thu thừa đầu kỳ',
  DAU_KY_CONG_NO: 'Công nợ đầu kỳ',
  TU_DUNG_HOC: 'Từ dừng học',
  DUNG_CHO_DON: 'Dùng cho đơn',
  DIEU_CHINH: 'Điều chỉnh',
};
