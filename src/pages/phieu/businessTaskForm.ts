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

/** Loại phiếu nghiệp vụ tạo bằng hộp thoại chung: Bảo lưu (kèm gia hạn, tiếp tục học), Chuyển lớp, Dừng học, Chuyển phí. */
export type BusinessType = 'BAO_LUU' | 'CHUYEN_LOP' | 'DUNG_HOC' | 'CHUYEN_PHI';

/** Loại chuyển chọn được ở phiếu Chuyển lớp. Chuyển cơ sở (R-GD-10, R-CS-07) chỉ chọn cơ sở mới; lớp mới do quản lý cơ sở đích chọn ở cấp duyệt của họ (migration 568). */
export const TRANSFER_KINDS = [
  { value: 'DOI_GIO', label: 'Đổi giờ học' },
  { value: 'DOI_TRINH_DO', label: 'Đổi trình độ' },
  { value: 'DOI_GIAO_VIEN', label: 'Đổi giáo viên' },
  { value: 'CHUYEN_CO_SO', label: 'Chuyển cơ sở' },
] as const;

export const TRANSFER_BRANCH_KIND = 'CHUYEN_CO_SO';

/** Hình thức phiếu Bảo lưu: bảo lưu mới hoặc gia hạn bản đang chạy (CSN-06b). */
export type HoldMode = 'MOI' | 'GIA_HAN' | 'TIEP_TUC';
export const HOLD_MODES: { value: HoldMode; label: string }[] = [
  { value: 'MOI', label: 'Bảo lưu mới' },
  { value: 'GIA_HAN', label: 'Gia hạn bảo lưu' },
  { value: 'TIEP_TUC', label: 'Tiếp tục học' },
];

export type BusinessDraft = {
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
  if (type === 'DUNG_HOC' || type === 'CHUYEN_PHI') {
    // Dừng học, Chuyển phí: chỉ cần ghi danh, lý do (danh mục) và ghi chú; luật chặn ở hàm áp dụng (R-GD-16, R-GD-10).
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
  if (type === 'DUNG_HOC' || type === 'CHUYEN_PHI')
    return {
      enrollment_id: draft.enrollmentId,
      reason_code: draft.reasonCode,
      note: draft.reason.trim(),
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

/** Lớp mới gợi ý: cùng môn với ghi danh, bỏ lớp hiện tại. */
export function classChoices(options: TaskOptions, enrollmentId: string) {
  const enr = options.enrollments.find((x) => x.id === enrollmentId);
  if (!enr) return [];
  return options.classes.filter(
    (c) =>
      c.id !== enr.class_id && (enr.subject_code === null || c.subject_code === enr.subject_code),
  );
}

/** Ghi danh chọn được theo hình thức: Gia hạn và Tiếp tục học chỉ cho ghi danh có bảo lưu đang chạy; Bảo lưu mới chỉ cho ghi danh chưa bảo lưu. */
export function holdEnrollmentChoices(options: TaskOptions, mode: HoldMode) {
  const running = new Set((options.holds ?? []).map((h) => h.enrollment_id));
  return options.enrollments.filter((x) =>
    mode !== 'MOI' ? running.has(x.id) : x.status_code !== 'BAO_LUU',
  );
}

/** Bảo lưu đang chạy của một ghi danh (để gia hạn); không có thì null. */
export function runningHold(options: TaskOptions, enrollmentId: string) {
  return (options.holds ?? []).find((h) => h.enrollment_id === enrollmentId) ?? null;
}
