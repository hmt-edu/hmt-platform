// Kiểm sớm biểu mẫu «Ghi nhận liên hệ»; luật chặn thật ở app.log_contact (R-CRM-43). Hàm thuần.
export type ContactDraft = {
  channel: string;
  result: string;
  body: string;
  nextDate: Date | null;
  nextTime: string;
};

export type ContactErrors = { channel?: string; result?: string; body?: string; next?: string };

export function contactErrors(draft: ContactDraft, nextAt: Date | null, now: Date): ContactErrors {
  const errors: ContactErrors = {};
  if (draft.channel === '') errors.channel = 'Chọn kênh liên hệ.';
  if (draft.result === '') errors.result = 'Chọn kết quả liên hệ.';
  if (draft.body.trim() === '') errors.body = 'Nhập nội dung trao đổi.';
  const wantsNext = draft.nextDate !== null || draft.nextTime !== '';
  if (wantsNext && nextAt === null) errors.next = 'Hẹn lần sau cần cả ngày và giờ.';
  else if (nextAt !== null && nextAt.getTime() <= now.getTime())
    errors.next = 'Hẹn lần sau phải sau thời điểm hiện tại.';
  return errors;
}
