// Biểu mẫu tạo phiếu Bảo lưu và Chuyển lớp từ chi tiết ticket (CSN-06a, CSN-06b): kiểm sớm và dựng dữ liệu gửi app.create_ticket_task. Luật chặn thật ở DB (migration 262, hàm áp dụng 234).
export type TaskOptions = {
  enrollments: {
    id: string;
    code: string;
    status_code: string;
    subject_code: string | null;
    class_id: string | null;
    class_code: string | null;
    remaining_hours: number;
  }[];
  /** Bảo lưu đang chạy của học sinh (cho Gia hạn bảo lưu, R-GD-09). */
  holds?: { id: string; enrollment_id: string; start_date: string; end_date: string }[];
  /** Buổi sắp tới của lớp học sinh đang học (phiếu Đổi lịch, migration 429). */
  sessions?: {
    id: string;
    class_code: string;
    session_no: number | null;
    date: string;
    start: string;
    end: string;
  }[];
  hold_reasons: { code: string; name: string }[];
  /** Lý do dừng học (STOP_REASON, migration 427). */
  stop_reasons?: { code: string; name: string }[];
  transfer_reasons: { code: string; name: string }[];
  classes: {
    id: string;
    code: string;
    subject_code: string;
    seats_left: number | null;
    upcoming: { date: string; session_no: number }[];
  }[];
};

/** Loại phiếu nghiệp vụ tạo bằng hộp thoại chung: Bảo lưu (kèm gia hạn, tiếp tục học), Chuyển lớp, Dừng học, Chuyển phí, Hoàn học phí. */
export type BusinessType = 'BAO_LUU' | 'CHUYEN_LOP' | 'DUNG_HOC' | 'CHUYEN_PHI' | 'HOAN_PHI';

/** Loại chuyển chọn được ở phiếu Chuyển lớp. Chuyển cơ sở (R-GD-10, R-CS-07) chỉ chọn cơ sở mới; lớp mới do quản lý cơ sở đích chọn ở cấp duyệt của họ (migration 568). */
export const TRANSFER_KINDS = [
  { value: 'DOI_GIO', label: 'Đổi giờ học' },
  { value: 'DOI_TRINH_DO', label: 'Đổi trình độ' },
  { value: 'DOI_GIAO_VIEN', label: 'Đổi giáo viên' },
  { value: 'CHUYEN_CO_SO', label: 'Chuyển cơ sở' },
] as const;

/** Kiểu chuyển phí (CSN06d): sang môn khác, gói khác hoặc anh chị em. */
export const FEE_TRANSFER_KINDS = [
  { value: 'SANG_MON', label: 'Sang môn khác' },
  { value: 'SANG_GOI', label: 'Sang gói khác' },
  { value: 'SANG_ANH_CHI_EM', label: 'Sang anh chị em' },
] as const;

/** Kết quả app.preview_fee_transfer (bảng tính tham khảo, tiền đồng, giờ). */
export type FeeTransferPreview = {
  hours_bought: number;
  hours_used: number;
  unit_price_net: number;
  paid_amount: number;
  transfer_value: number;
  hours_gift_cancelled: number;
  order_total: number | null;
  extra_to_pay: number | null;
};
/** Kết quả app.preview_stop_task_money (migration 632): tiền xem trước của phiếu Dừng học hoặc Hoàn học phí. Số có thể null khi không tính được (xem refund_error). */
export type StopMoneyPreview = {
  task_type: 'DUNG_HOC' | 'HOAN_PHI';
  money_mode?: MoneyMode;
  hours_left?: number | null;
  hours_cancelled?: number | null;
  unit_price_net: number | null;
  balance_amount?: number | null;
  paid_amount: number | null;
  fee_percent: number | null;
  fee_amount: number | null;
  refund_amount: number | null;
  refund_error: string | null;
  /** Dòng để bảng cộng khớp (migration 658): loại hoàn, tiền giờ đã học, tiền gốc các lần hoàn trước, còn lại trước phí, giờ hoàn (hoàn một phần). */
  refund_kind?: 'TOAN_BO' | 'MOT_PHAN';
  used_amount?: number | null;
  prior_refund_amount?: number | null;
  base_amount?: number | null;
  hours_refund?: number | null;
};
export type FeeTransferOrder = {
  id: string;
  code: string;
  status_code: string;
  total_amount: number;
};

export const TRANSFER_BRANCH_KIND = 'CHUYEN_CO_SO';

/** Hình thức phiếu Bảo lưu: bảo lưu mới hoặc gia hạn bản đang chạy (CSN-06b). */
export type HoldMode = 'MOI' | 'GIA_HAN' | 'TIEP_TUC';
export const HOLD_MODES: { value: HoldMode; label: string }[] = [
  { value: 'MOI', label: 'Bảo lưu mới' },
  { value: 'GIA_HAN', label: 'Gia hạn bảo lưu' },
  { value: 'TIEP_TUC', label: 'Tiếp tục học' },
];

/** Cách xử lý tiền còn lại khi Dừng học (CS-14, R-GD-16): Hoàn tiền (hoàn phí toàn bộ, R-TIEN-28) hoặc Giữ số dư (R-TIEN-33). */
export type MoneyMode = 'HOAN_TIEN' | 'GIU_SO_DU';
export const MONEY_MODES: { value: MoneyMode; label: string }[] = [
  { value: 'HOAN_TIEN', label: 'Hoàn tiền (sang phiếu Hoàn học phí)' },
  { value: 'GIU_SO_DU', label: 'Giữ số dư (không trừ phí)' },
];

/** Hình thức hoàn của phiếu Hoàn học phí (CSN06c, R-TIEN-28, R-TIEN-31): toàn bộ (giá gốc, trừ phí) hoặc một phần (số giờ × giá sau chiết khấu). */
export type RefundKind = 'TOAN_BO' | 'MOT_PHAN';
export const REFUND_KINDS: { value: RefundKind; label: string }[] = [
  { value: 'TOAN_BO', label: 'Hoàn toàn bộ' },
  { value: 'MOT_PHAN', label: 'Hoàn một phần' },
];

export type BusinessDraft = {
  /** Phiếu Hoàn học phí: hình thức hoàn và số giờ hoàn (chỉ khi hoàn một phần). */
  refundKind: RefundKind | '';
  refundHours: string;
  /** Phiếu Dừng học: ngày dừng (chỉ ghi nhận) và cách xử lý tiền còn lại. */
  stopDate: string;
  /** Chuyển phí: đơn nhận (tuỳ chọn, chỉ tham khảo). */
  orderId: string;
  moneyMode: MoneyMode | '';
  holdMode: HoldMode;
  enrollmentId: string;
  reasonCode: string;
  reason: string;
  months: string;
  toClassId: string;
  startDate: string;
  kindCode: string;
  destBranchId: string;
};
/** Cơ sở dạy học chọn làm cơ sở mới (đang hoạt động, khác cơ sở của ticket). */
export type DestBranch = { id: string; code: string; name: string };
export type BusinessErrors = Partial<Record<keyof BusinessDraft, string>>;

export const EMPTY_BUSINESS_DRAFT: BusinessDraft = {
  refundKind: '',
  refundHours: '',
  stopDate: '',
  orderId: '',
  moneyMode: '',
  holdMode: 'MOI',
  enrollmentId: '',
  reasonCode: '',
  reason: '',
  months: '',
  toClassId: '',
  startDate: '',
  kindCode: '',
  destBranchId: '',
};

export function validateBusinessDraft(
  type: BusinessType,
  draft: BusinessDraft,
  hasStudent: boolean,
): BusinessErrors {
  const e: BusinessErrors = {};
  if (!hasStudent) e.enrollmentId = 'Ticket chưa gắn học sinh nên chưa tạo phiếu này được.';
  else if (draft.enrollmentId === '') e.enrollmentId = 'Chọn ghi danh.';
  if (draft.reasonCode === '') e.reasonCode = 'Chọn lý do.';
  if (draft.reason.trim() === '') e.reason = 'Nhập lý do của phiếu.';
  if (type === 'HOAN_PHI') {
    // Hoàn học phí (CSN06c): thêm hình thức hoàn; hoàn một phần cần số giờ lớn hơn 0. Luật chặn thật ở hàm DB (R-TIEN-28, R-TIEN-31, HMT_HOAN_PHI_*).
    if (draft.refundKind === '') e.refundKind = 'Chọn hình thức hoàn.';
    else if (draft.refundKind === 'MOT_PHAN' && !(Number(draft.refundHours.replace(',', '.')) > 0))
      e.refundHours = 'Nhập số giờ hoàn lớn hơn 0.';
  } else if (type === 'DUNG_HOC') {
    // Dừng học (CSN06e): thêm Ngày dừng và Xử lý tiền còn lại; luật chặn thật ở hàm DB (R-GD-16, R-TIEN-28).
    if (draft.stopDate === '') e.stopDate = 'Chọn ngày dừng.';
    if (draft.moneyMode === '') e.moneyMode = 'Chọn cách xử lý tiền còn lại.';
  } else if (type === 'CHUYEN_PHI') {
    // Chuyển phí (CSN06d): thêm Kiểu chuyển; đơn nhận tuỳ chọn; luật chặn ở hàm DB (R-GD-10, HMT_CHUYEN_PHI_AM).
    if (draft.kindCode === '') e.kindCode = 'Chọn kiểu chuyển.';
  } else if (type === 'BAO_LUU') {
    const m = Number(draft.months);
    if (draft.holdMode !== 'TIEP_TUC' && (!Number.isInteger(m) || m < 1))
      e.months =
        draft.holdMode === 'GIA_HAN'
          ? 'Nhập số tháng gia hạn (từ 1).'
          : 'Nhập số tháng bảo lưu (từ 1).';
  } else {
    if (draft.kindCode === '') e.kindCode = 'Chọn loại chuyển.';
    if (draft.kindCode === TRANSFER_BRANCH_KIND) {
      // Chuyển cơ sở: chỉ cần cơ sở mới; lớp mới và buổi bắt đầu do quản lý cơ sở đích chọn sau (migration 568).
      if (draft.destBranchId === '') e.destBranchId = 'Chọn cơ sở mới.';
      return e;
    }
    if (draft.toClassId === '') e.toClassId = 'Chọn lớp mới.';
    if (draft.startDate === '') e.startDate = 'Chọn buổi bắt đầu ở lớp mới.';
  }
  return e;
}

/** Khoá payload đúng theo migration 262: BAO_LUU {enrollment_id, months, reason_code}; CHUYEN_LOP {enrollment_id, to_class_id, start_date, kind_code, reason_code}. */
export function buildBusinessPayload(
  type: BusinessType,
  draft: BusinessDraft,
  holdId: string | null = null,
) {
  if (type === 'HOAN_PHI')
    return {
      enrollment_id: draft.enrollmentId,
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
      kind: draft.refundKind,
      ...(draft.refundKind === 'MOT_PHAN'
        ? { hours: Number(draft.refundHours.replace(',', '.')) }
        : {}),
    };
  if (type === 'DUNG_HOC')
    return {
      enrollment_id: draft.enrollmentId,
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
      stop_date: draft.stopDate,
      money_mode: draft.moneyMode,
    };
  if (type === 'CHUYEN_PHI')
    return {
      enrollment_id: draft.enrollmentId,
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
      kind_code: draft.kindCode,
      ...(draft.orderId !== '' ? { order_id: draft.orderId } : {}),
    };
  if (type === 'BAO_LUU' && draft.holdMode === 'TIEP_TUC')
    // Tiếp tục học (quay lại sớm): kết thúc bảo lưu, về hàng chờ xếp lớp, giữ giờ (migration 424).
    return {
      enrollment_id: draft.enrollmentId,
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
      resume: true,
    };
  if (type === 'BAO_LUU')
    return {
      enrollment_id: draft.enrollmentId,
      months: Number(draft.months),
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
      // Gia hạn: nối tiếp bản đang chạy của ghi danh (hàm áp dụng kiểm lại, migration 234).
      ...(draft.holdMode === 'GIA_HAN' && holdId ? { extends_hold_id: holdId } : {}),
    };
  if (draft.kindCode === TRANSFER_BRANCH_KIND)
    return {
      enrollment_id: draft.enrollmentId,
      kind_code: draft.kindCode,
      dest_branch_id: draft.destBranchId,
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
    };
  return {
    enrollment_id: draft.enrollmentId,
    to_class_id: draft.toClassId,
    start_date: draft.startDate,
    kind_code: draft.kindCode,
    reason_code: draft.reasonCode,
    note: draft.reason.trim(),
  };
}

/** Lớp mới gợi ý: cùng môn với lớp đang học của ghi danh (R-CS-03: khác môn đi nhánh Chuyển phí), bỏ lớp hiện tại. */
export function classChoices(options: TaskOptions, enrollmentId: string) {
  const enr = options.enrollments.find((x) => x.id === enrollmentId);
  if (!enr) return [];
  // Môn của lớp đang học là chuẩn (đúng thứ máy chủ so sánh); môn lưu trên ghi danh có thể trống.
  const subject =
    options.classes.find((c) => c.id === enr.class_id)?.subject_code ?? enr.subject_code;
  return options.classes.filter(
    (c) => c.id !== enr.class_id && (subject === null || c.subject_code === subject),
  );
}

/** Ghi danh chọn được theo hình thức: Gia hạn và Tiếp tục học chỉ cho ghi danh có bảo lưu đang chạy; Bảo lưu mới chỉ cho ghi danh chưa bảo lưu. */
export function holdEnrollmentChoices(options: TaskOptions, mode: HoldMode) {
  const running = new Set((options.holds ?? []).map((h) => h.enrollment_id));
  return options.enrollments.filter((x) =>
    mode !== 'MOI'
      ? running.has(x.id)
      : x.status_code !== 'BAO_LUU' && x.status_code !== WAITING_CLASS,
  );
}

/** Ghi danh Chờ xếp lớp (chưa có lớp). */
const WAITING_CLASS = 'CHO_XEP_LOP';

/**
 * Ghi danh nào được chọn ở phiếu loại này (D-23-50, anh chốt 24/11): chỉ phiếu Hoàn học phí và Dừng học
 * nhận ghi danh Chờ xếp lớp; loại khác ẩn ngay trong hộp để không tạo, gửi duyệt rồi mới bị chặn ở bước Thực hiện.
 */
export function enrollmentSelectableFor(type: string, statusCode: string): boolean {
  return statusCode !== WAITING_CLASS || type === 'HOAN_PHI' || type === 'DUNG_HOC';
}

/** Bảo lưu đang chạy của một ghi danh (để gia hạn); không có thì null. */
export function runningHold(options: TaskOptions, enrollmentId: string) {
  return (options.holds ?? []).find((h) => h.enrollment_id === enrollmentId) ?? null;
}
