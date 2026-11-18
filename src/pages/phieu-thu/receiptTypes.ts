// Kiểu dữ liệu màn Phiếu thu (TC-01, TC-02, TC-04): một dòng danh sách do hàm list_receipts trả, bản ghi do get_receipt trả. Giao diện KHÔNG tính tiền.
export type ReceiptStatus = 'NHAP' | 'DA_GUI' | 'CHO_KE_TOAN' | 'DA_DUYET' | 'HUY';

export type ReceiptRow = {
  id: string;
  code: string;
  status_code: ReceiptStatus;
  status: string | null;
  order_id: string;
  order_code: string;
  parent_id: string;
  parent_code: string;
  parent_name: string;
  amount: number;
  payment_method_code: string;
  payment_method: string | null;
  paid_on: string;
  branch_code: string;
  collect_branch_code: string;
  created_at: string;
  created_by_name: string | null;
  approver_name: string | null;
  submitted_at: string | null;
};

export type ReceiptPage = { total: number; rows: ReceiptRow[] };

/** Việc người gọi làm được ở trạng thái hiện tại (get_receipt.actions): giao diện chỉ hiện nút đúng, không lặp luật quyền. */
export type ReceiptAction = 'sua' | 'gui' | 'duyet_quan_ly' | 'duyet_ke_toan' | 'tu_choi' | 'huy';

export type ReceiptEvent = {
  event_code:
    | 'TAO'
    | 'SUA'
    | 'GUI'
    | 'DUYET_QL'
    | 'TU_DUYET_QL'
    | 'DUYET_KT'
    | 'TU_CHOI'
    | 'HUY'
    | 'CHUYEN_NGUOI_DUYET';
  from_status: string | null;
  to_status: string;
  note: string | null;
  at: string;
  by_name: string | null;
};

export type OrderPayment = {
  order_id: string;
  total: number;
  paid: number;
  remaining: number;
  receivable: number;
  deposit_reached: boolean;
  fully_paid: boolean;
};

export type ReceiptRecord = {
  id: string;
  code: string;
  status_code: ReceiptStatus;
  status: string | null;
  order: { id: string; code: string; total_amount: number; status_code: string };
  parent: { id: string; code: string; name: string; phone: string } | null;
  amount: number;
  payment_method_code: string;
  payment_method: string | null;
  txn_ref: string | null;
  paid_on: string;
  note: string | null;
  target_line_id: string | null;
  branch_code: string;
  collect_branch_id: string;
  collect_branch_code: string;
  receiver_id: string | null;
  receiver_name: string | null;
  created_at: string;
  created_by: string | null;
  created_by_name: string | null;
  approver_name: string | null;
  approval_route: 'QUAN_LY' | 'TU_DUYET' | 'TRUONG_CS' | null;
  submitted_at: string | null;
  manager_approved_at: string | null;
  accountant_approved_at: string | null;
  cancel_reason: string | null;
  cancel_note: string | null;
  cancelled_at: string | null;
  payment: OrderPayment;
  actions: ReceiptAction[];
  events: ReceiptEvent[];
  money_in: {
    code: string;
    amount: number;
    allocations: { line_no: number; package_name: string; amount: number }[];
  } | null;
};

/** Dữ liệu nhập của phiếu thu (create_receipt, save_receipt); số tiền là số nguyên đồng. */
export type ReceiptInput = {
  amount: number;
  payment_method_code: string;
  txn_ref?: string | null;
  paid_on?: string | null;
  collect_branch_id?: string | null;
  receiver_id?: string | null;
  target_line_id?: string | null;
  note?: string | null;
};
