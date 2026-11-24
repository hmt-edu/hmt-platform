// Kiểu dữ liệu màn Phiếu chi (TC-10, TC-11): dòng danh sách do list_payment_vouchers trả, bản ghi do get_payment_voucher trả. Giao diện KHÔNG tính tiền.
export type VoucherStatus = 'CHO_CHI' | 'DA_CHI';

export type VoucherRow = {
  id: string;
  code: string;
  status_code: VoucherStatus;
  amount: number;
  ticket_ref: string | null;
  refund_request_id: string;
  kind_code: 'TOAN_BO' | 'MOT_PHAN';
  parent_id: string;
  parent_code: string;
  parent_name: string;
  branch_code: string;
  created_at: string;
  paid_at: string | null;
  /** Hình thức chi (danh mục PAYMENT_METHOD chung với Phiếu thu); trống tới khi ghi nhận đã chi. */
  payment_method?: string | null;
  payment_method_code?: string | null;
  /** Tài khoản nhận của người nhận hoàn tiền, chữ tự do (TC-10, TC-11; migration 581). */
  payout_account_note?: string | null;
  /** Ngày chi dự kiến (YYYY-MM-DD); chỉ cảnh báo, không chặn chi. */
  planned_on?: string | null;
};

export type VoucherPage = { total: number; rows: VoucherRow[] };

/** Số liệu bảng tính hoàn: CHỤP lúc tạo yêu cầu hoàn phí (R-TIEN-28), giao diện chỉ hiện. */
export type VoucherRecord = {
  voucher: {
    id: string;
    code: string;
    status_code: VoucherStatus;
    amount: number;
    pay_note: string | null;
    payment_method?: string | null;
    payment_method_code?: string | null;
    payout_account_note?: string | null;
    planned_on?: string | null;
    created_at: string;
    paid_at: string | null;
    created_by_name: string | null;
    paid_by_name: string | null;
    branch_code: string;
    parent_id: string;
    parent_code: string;
    parent_name: string;
    can_pay: boolean;
  };
  refund: {
    id: string;
    kind_code: 'TOAN_BO' | 'MOT_PHAN';
    reason_code: string;
    note: string | null;
    ticket_ref: string | null;
    hours_refund: number;
    paid_amount: number;
    hours_used: number;
    /** Tiền giờ đã học (giờ × giá gốc), máy chủ tính. */
    used_amount: number;
    /** Tiền gốc các lần hoàn trước (chỉ khi hoàn toàn bộ), máy chủ tính. */
    prior_refund_amount: number;
    unit_price_base: number;
    unit_price_net: number;
    base_amount: number;
    fee_percent: number;
    fee_amount: number;
    refund_amount: number;
  };
  enrollment: { id: string; code: string; status_code: string; student_name: string | null };
};
