// PH-04 Đề nghị và khiếu nại (cổng Phụ huynh): kiểu dữ liệu và chữ hiển thị. Dữ liệu từ app.ph_list_tickets, ph_get_ticket, ph_request_categories.
export type RequestStatus = 'DANG_XU_LY' | 'CHO_XAC_NHAN' | 'DA_XONG' | 'DA_HUY';

export type RequestRow = {
  id: string;
  code: string;
  title: string;
  ticket_type: 'DN' | 'KN';
  student_name: string | null;
  created_at: string;
  status: RequestStatus;
};

export type RequestDetail = RequestRow & {
  step: number;
  proposal: string | null;
  satisfaction: number | null;
  steps_at: {
    received: string | null;
    processing: string | null;
    proposal: string | null;
    done: string | null;
  };
};

export type RequestCategory = { code: string; name: string; group_name: string };

export function typeText(type: 'DN' | 'KN'): string {
  return type === 'KN' ? 'Khiếu nại' : 'Đề nghị';
}

export function statusText(status: RequestStatus): string {
  switch (status) {
    case 'CHO_XAC_NHAN':
      return 'Chờ xác nhận';
    case 'DA_XONG':
      return 'Đã xong';
    case 'DA_HUY':
      return 'Đã huỷ';
    default:
      return 'Đang xử lý';
  }
}

export function statusTone(status: RequestStatus): 'warning' | 'info' | 'success' | 'neutral' {
  if (status === 'CHO_XAC_NHAN') return 'info';
  if (status === 'DA_XONG') return 'success';
  if (status === 'DA_HUY') return 'neutral';
  return 'warning';
}

/** «19/11» từ thời điểm ISO, theo giờ Việt Nam. */
export function sentDate(iso: string): string {
  const d = new Date(iso);
  return new Intl.DateTimeFormat('en-GB', {
    day: '2-digit',
    month: '2-digit',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(d);
}

export function sentSubtitle(r: Pick<RequestRow, 'created_at' | 'ticket_type'>): string {
  return `Gửi ${sentDate(r.created_at)} · ${typeText(r.ticket_type)}`;
}

export type StepView = { no: number; label: string; state: 'done' | 'current' | 'todo' };

/** Bốn bước theo dõi (khung PH04_chi_tiet): bước nhỏ hơn bước hiện tại là xong; bước hiện tại đang làm; bước cuối đạt thì xong. */
export function buildSteps(step: number): StepView[] {
  const labels = ['Đã nhận', 'Đang xử lý', 'Phương án', 'Hoàn tất'];
  return labels.map((label, i) => {
    const no = i + 1;
    const last = no === labels.length;
    const state = no < step || (last && step >= no) ? 'done' : no === step ? 'current' : 'todo';
    return { no, label, state };
  });
}
