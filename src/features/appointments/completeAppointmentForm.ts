// Biểu mẫu hộp «Hoàn thành lịch hẹn» (TS-11, K08): kiểm sớm ở giao diện; luật chặn thật ở app.complete_appointment (migration 628).
export const CALL_ACTIVITY = 'GOI_DIEN';

export type CompleteDraft = {
  resultCode: string;
  nextDate: Date | null;
  nextTime: string;
  note: string;
};

export type CompleteErrors = { result?: string; next?: string };

/** Kết quả bắt buộc khi lịch là Gọi điện (anh chốt 23/11, TS-13); loại khác tuỳ chọn. */
export function resultRequired(activityCode: string): boolean {
  return activityCode === CALL_ACTIVITY;
}

/**
 * Lỗi từng ô. Hẹn lần sau tuỳ chọn: bỏ trống cả ngày và giờ là không hẹn; có ngày mà thiếu giờ (hoặc ngược lại) thì báo;
 * thời điểm phải sau hiện tại (`nextAt` đã ghép giờ Việt Nam, null khi chưa đủ ngày giờ).
 */
export function completeErrors(
  activityCode: string,
  draft: CompleteDraft,
  nextAt: Date | null,
  now: Date,
): CompleteErrors {
  const e: CompleteErrors = {};
  if (resultRequired(activityCode) && draft.resultCode === '') e.result = 'Chọn kết quả.';
  const hasAny = draft.nextDate !== null || draft.nextTime.trim() !== '';
  if (hasAny) {
    if (nextAt === null) e.next = 'Chọn đủ ngày và giờ của lần hẹn sau.';
    else if (nextAt.getTime() <= now.getTime())
      e.next = 'Hẹn lần sau không được trước thời điểm hiện tại.';
  }
  return e;
}
