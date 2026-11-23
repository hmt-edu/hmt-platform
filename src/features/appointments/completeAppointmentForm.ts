// Biểu mẫu hộp «Hoàn thành lịch hẹn» (TS-11, K08): kiểm sớm ở giao diện; luật chặn thật ở app.complete_appointment (migration 628).
export const CALL_ACTIVITY = 'GOI_DIEN';

export type CompleteDraft = {
  resultCode: string;
  nextDate: Date | null;
  nextTime: string;
  note: string;
};

export type CompleteErrors = { result?: string; next?: string };

/** Khoá tham số bật luật bắt Kết quả (QT-09); cùng khoá với app.complete_appointment. */
export const RESULT_REQUIRED_SETTING = 'appointment_call_result_required';

/**
 * Kết quả bắt buộc CHỈ khi: loại hẹn là Gọi điện, không phải lịch tự nhắc, và tham số bật (anh chốt 15:54 23/11, TS-13).
 * Khớp luật trong app.complete_appointment (migration 628); tham số chưa đọc được (null) thì không bắt, DB vẫn chặn.
 */
export function resultRequired(
  activityCode: string,
  isAutoReminder: boolean,
  settingOn: boolean | null,
): boolean {
  return activityCode === CALL_ACTIVITY && !isAutoReminder && settingOn === true;
}

/**
 * Lỗi từng ô. Hẹn lần sau tuỳ chọn: bỏ trống cả ngày và giờ là không hẹn; có ngày mà thiếu giờ (hoặc ngược lại) thì báo;
 * thời điểm phải sau hiện tại (`nextAt` đã ghép giờ Việt Nam, null khi chưa đủ ngày giờ).
 */
export function completeErrors(
  required: boolean,
  draft: CompleteDraft,
  nextAt: Date | null,
  now: Date,
): CompleteErrors {
  const e: CompleteErrors = {};
  if (required && draft.resultCode === '') e.result = 'Chọn kết quả.';
  const hasAny = draft.nextDate !== null || draft.nextTime.trim() !== '';
  if (hasAny) {
    if (nextAt === null) e.next = 'Chọn đủ ngày và giờ của lần hẹn sau.';
    else if (nextAt.getTime() <= now.getTime())
      e.next = 'Hẹn lần sau không được trước thời điểm hiện tại.';
  }
  return e;
}
