// Biểu mẫu phiếu Đổi lịch học từ ticket (CS-11, CSN-06e): kiểm sớm và dựng dữ liệu cho app.create_ticket_task. Luật chặn thật ở DB (migration 429, R-CS-03, R-LOP-10).
// Hành động: dời MỘT buổi; đổi ca cố định (làm ở Sửa lớp, phiếu chỉ ghi nhận); xin học bù (R-BUOI-03: quản lý duyệt sinh buổi mới, không chọn buổi có sẵn).
export type ScheduleAction = 'DOI_BUOI' | 'DOI_CA' | 'HOC_BU';
export const SCHEDULE_ACTIONS: { value: ScheduleAction; label: string }[] = [
  { value: 'DOI_BUOI', label: 'Dời một buổi' },
  { value: 'DOI_CA', label: 'Đổi ca cố định' },
  { value: 'HOC_BU', label: 'Xin học bù' },
];

export type ScheduleSession = {
  id: string;
  class_code: string;
  session_no: number | null;
  date: string;
  start: string;
  end: string;
};

export type ScheduleDraft = {
  action: ScheduleAction;
  sessionId: string;
  classId: string;
  date: string;
  start: string;
  end: string;
  reason: string;
};
export type ScheduleErrors = Partial<Record<keyof ScheduleDraft, string>>;

export const EMPTY_SCHEDULE_DRAFT: ScheduleDraft = {
  action: 'DOI_BUOI',
  sessionId: '',
  classId: '',
  date: '',
  start: '',
  end: '',
  reason: '',
};

const hhmm = (t: string) => t.slice(0, 5);

export function validateScheduleDraft(draft: ScheduleDraft, hasStudent: boolean): ScheduleErrors {
  const e: ScheduleErrors = {};
  if (!hasStudent) e.sessionId = 'Ticket chưa gắn học sinh nên chưa tạo phiếu này được.';
  if (draft.reason.trim() === '') e.reason = 'Nhập lý do của phiếu.';
  if (draft.action === 'HOC_BU' && hasStudent && draft.classId === '')
    e.classId = 'Chọn lớp học bù.';
  if (draft.action === 'DOI_BUOI' || draft.action === 'HOC_BU') {
    if (draft.action === 'DOI_BUOI' && hasStudent && draft.sessionId === '')
      e.sessionId = 'Chọn buổi cần dời.';
    if (draft.date === '') e.date = 'Chọn ngày mới.';
    if (draft.start === '') e.start = 'Nhập giờ bắt đầu mới.';
    if (draft.end === '') e.end = 'Nhập giờ kết thúc mới.';
    else if (draft.start !== '' && draft.end <= draft.start)
      e.end = 'Giờ kết thúc phải sau giờ bắt đầu.';
  }
  return e;
}

/** Khoá payload đúng theo migration 429: DOI_BUOI {action, session_id, date, start, end, note}; DOI_CA {action, note}. */
export function buildSchedulePayload(draft: ScheduleDraft) {
  if (draft.action === 'DOI_CA') return { action: 'DOI_CA', note: draft.reason.trim() };
  // Học bù (R-BUOI-03): quản lý duyệt thì sinh buổi Học bù mới cho em của ticket, không chọn buổi có sẵn; không trừ giờ.
  if (draft.action === 'HOC_BU')
    return {
      action: 'HOC_BU',
      class_id: draft.classId,
      date: draft.date,
      start: draft.start,
      end: draft.end,
      note: draft.reason.trim(),
    };
  return {
    action: 'DOI_BUOI',
    session_id: draft.sessionId,
    date: draft.date,
    start: draft.start,
    end: draft.end,
    note: draft.reason.trim(),
  };
}

/** Nhãn buổi trong ô chọn: «Lớp · Buổi n · ngày giờ». */
export function sessionLabel(s: ScheduleSession, format: (iso: string) => string): string {
  return `${s.class_code}${s.session_no ? ` · Buổi ${s.session_no}` : ''} · ${format(s.date)} ${hhmm(s.start)}–${hhmm(s.end)}`;
}
