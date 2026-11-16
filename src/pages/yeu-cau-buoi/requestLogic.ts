// Yêu cầu buổi (BUOI-08 tạo, BUOI-10 danh sách và duyệt): kiểu dữ liệu và hàm thuần. Máy chủ quyết quyền, trạng thái, tính mọi con số (app.list_session_requests,
// app.save_session_request...); trang chỉ đặt chữ và kiểm lỗi nhập cơ bản. Lát đầu: chỉ loại Củng cố (R-BUOI-04).
export type RequestStatus = 'NHAP' | 'CHO_DUYET' | 'DA_DUYET' | 'TU_CHOI' | 'HUY';

export type RequestRow = {
  id: string;
  code: string;
  kind: 'CUNG_CO';
  status_code: RequestStatus;
  class_id: string;
  class_code: string;
  subject_name: string | null;
  student_count: number;
  session_date: string;
  start_time: string;
  end_time: string;
  room_name: string | null;
  note: string | null;
  created_at: string;
  created_by_name: string | null;
  reject_reason_code: string | null;
  reject_note: string | null;
  created_session_id: string | null;
  can_approve: boolean;
};
export type RequestPage = { total: number; rows: RequestRow[] };

const STATUS_NAMES: Record<RequestStatus, string> = {
  NHAP: 'Nháp',
  CHO_DUYET: 'Chờ duyệt',
  DA_DUYET: 'Đã duyệt',
  TU_CHOI: 'Từ chối',
  HUY: 'Huỷ',
};

/** Tên tình trạng cho người đọc (tên tạm trong code vì luật lõi R-BUOI-04: các bước cố định). */
export function statusName(code: RequestStatus): string {
  return STATUS_NAMES[code];
}

export type TagTone = 'neutral' | 'info' | 'warning' | 'success' | 'danger';
/** Màu theo tình trạng; luôn kèm chữ, không chỉ dùng màu. */
export function statusTone(code: RequestStatus): TagTone {
  switch (code) {
    case 'CHO_DUYET':
      return 'warning';
    case 'DA_DUYET':
      return 'success';
    case 'TU_CHOI':
      return 'danger';
    default:
      return 'neutral';
  }
}

/** "Cả lớp Đại số 9 · cơ bản A (4 em)" cho cột Học sinh của buổi củng cố (cả lớp, R-BUOI-04). */
export function targetText(
  r: Pick<RequestRow, 'subject_name' | 'class_code' | 'student_count'>,
): string {
  return `Cả lớp ${r.subject_name ?? r.class_code} (${r.student_count} em)`;
}

/** "dd/mm/yyyy · 18:00–19:30" */
export function whenText(r: Pick<RequestRow, 'session_date' | 'start_time' | 'end_time'>): string {
  const d = `${r.session_date.slice(8, 10)}/${r.session_date.slice(5, 7)}/${r.session_date.slice(0, 4)}`; // allow-number: cắt chuỗi yyyy-mm-dd
  return `${d} · ${r.start_time.slice(0, 5)}–${r.end_time.slice(0, 5)}`; // allow-number: cắt hh:mm:ss
}

export type DraftError = Partial<Record<'class' | 'date' | 'start' | 'end', string>>;

/** Kiểm nhập cơ bản ở form (máy chủ kiểm lại): lớp, ngày, giờ, giờ kết thúc sau giờ bắt đầu. Rỗng nghĩa là hợp lệ. */
export function validateDraft(d: {
  classId: string;
  date: string;
  start: string;
  end: string;
}): DraftError {
  const e: DraftError = {};
  if (d.classId === '') e.class = 'Chọn lớp.';
  if (d.date === '') e.date = 'Chọn ngày buổi củng cố.';
  if (d.start === '') e.start = 'Nhập giờ bắt đầu.';
  if (d.end === '') e.end = 'Nhập giờ kết thúc.';
  else if (d.start !== '' && d.end <= d.start) e.end = 'Giờ kết thúc phải sau giờ bắt đầu.';
  return e;
}
