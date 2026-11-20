// Kiểu dữ liệu màn Phiếu thu (TC-01, TC-02, TC-04): một dòng danh sách do hàm list_receipts trả, bản ghi do get_receipt trả. Giao diện KHÔNG tính tiền.
export type ReceiptStatus = 'NHAP' | 'DA_GUI' | 'CHO_KE_TOAN' | 'DA_DUYET' | 'HUY';

export type ReceiptRow = {
  id: string;
  code: string;
  status_code: ReceiptStatus;
  status: string | null;
  /** Null với phiếu Thu nợ đầu kỳ (không có đơn, R-V2-15). */
  order_id: string | null;
  order_code: string | null;
  is_opening_debt?: boolean;
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
  /** Người nhận tiền (canvas TC01); migration 563. */
  receiver_name?: string | null;
  /** Mã giao dịch (TC-04, migration 431). */
  txn_ref?: string | null;
  /** Đã khớp sao kê (TC-15, migration 576); cột «Sao kê» của TC-04. */
  bank_matched?: boolean;
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

/** Bản chia tiền vào dòng đơn của một phiếu (TC-17, migration 578): xem trước từ bước Đã trình, tiền thật khi Đã duyệt. */
export type ReceiptAllocLine = {
  line_id: string;
  line_no: number;
  student_name: string | null;
  package_name: string;
  line_total: number;
  amount: number;
  /** Giờ cấp của dòng cho phiếu này (R-TIEN-21). */
  hours: number;
  hours_total: number;
  /** Dòng được cấn trước («Dồn trước», R-TIEN-23). */
  first: boolean;
};
export type ReceiptAllocPreview = {
  actual: boolean;
  note: string | null;
  lines: ReceiptAllocLine[];
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
  /** Null với phiếu Thu nợ đầu kỳ (không có đơn, R-V2-15). */
  order: { id: string; code: string; total_amount: number; status_code: string } | null;
  is_opening_debt?: boolean;
  /** Em tham chiếu của phiếu nợ đầu kỳ (nợ tính theo từng em). */
  opening_student?: { id: string; code: string; name: string } | null;
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
  /** Phiếu có đơn: tiền của đơn; phiếu nợ đầu kỳ: nợ đầu kỳ còn lại của phụ huynh (hàm DB tính). */
  payment: OrderPayment | { opening_debt_remaining: number };
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
