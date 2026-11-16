// Kiểu dữ liệu cụm Thu tiền: TC-08 Khoản tiền vào (list_money_in) và TC-13 Công nợ (list_receivables). Chỉ đọc.
export type MoneyInRow = {
  id: string;
  code: string;
  receipt_id: string | null;
  receipt_code: string | null;
  order_id: string;
  order_code: string;
  parent_id: string;
  parent_name: string;
  amount: number;
  created_at: string;
  branch_code: string;
  /** Khoản đảo (TC-09): mã khoản gốc. Khoản thu thường: null. */
  reversal_of_code: string | null;
  /** Khoản gốc đã bị hoàn tác (không hoàn tác lần hai). */
  is_reversed: boolean;
  reason_code: string | null;
};
export type MoneyInPage = { total: number; sum: number; rows: MoneyInRow[] };

export type DebtStatus = 'QUA_HAN' | 'SAP_DEN_HAN' | 'CHUA_DEN_HAN';
export type ReceivableRow = {
  order_id: string;
  order_code: string;
  parent_id: string;
  parent_name: string;
  branch_code: string;
  sale_name: string | null;
  seq: number;
  seq_count: number;
  due_date: string;
  due_amount: number;
  paid_amount: number;
  owed: number;
  status: DebtStatus;
  overdue_days: number | null;
};
export type ReceivablePage = { total: number; owed_sum: number; rows: ReceivableRow[] };

export const DEBT_STATUS_LABEL: Record<DebtStatus, string> = {
  QUA_HAN: 'Quá hạn',
  SAP_DEN_HAN: 'Sắp đến hạn',
  CHUA_DEN_HAN: 'Chưa đến hạn',
};
