// Kiểu dữ liệu màn Ticket (CS-01 Danh sách, CSN-01): khớp kết quả app.list_tickets (migration 157).
export type TicketRow = {
  id: string;
  code: string;
  title: string;
  ticket_type: 'DN' | 'KN' | 'GV';
  branch_code: string;
  category_name: string | null;
  priority_code: 'KHAN' | 'CAO' | 'THUONG' | 'THAP';
  status_code: string;
  assignee_name: string | null;
  sender_name: string | null;
  resolve_due_at: string;
  created_at: string;
  /** QUA_HAN, SAP_QUA_HAN, CHO_DONG hoặc KHONG (hàm DB tính, giao diện không tính hạn). */
  sla_state: 'QUA_HAN' | 'SAP_QUA_HAN' | 'CHO_DONG' | 'KHONG';
};

export type TicketPage = { total: number; rows: TicketRow[] };

export type TicketFilters = Record<string, unknown>;

/** Một cột Kanban từ app.ticket_board (một lần gọi cho cả bảy cột). */
export type TicketBoardColumn = {
  status_code: string;
  name: string;
  total: number;
  rows: TicketRow[];
};

/** Chi tiết ticket từ app.get_ticket (migration 158): ticket_row cộng các trường chi tiết. */
export type TicketDetail = TicketRow & {
  branch_id: string;
  description: string;
  channel_code: string;
  category_code: string;
  team_code: string | null;
  student_name: string | null;
  resolution: string | null;
  cancel_reason: string | null;
  satisfaction: number | null;
  response_due_at: string;
  first_response_at: string | null;
  resolved_at: string | null;
  closed_at: string | null;
};

export type TicketEvent = {
  id: string;
  event_type: 'TAO' | 'GIAO' | 'DOI_TRANG_THAI' | 'DOI_NHOM_CON' | 'DOI_MUC_DO' | 'GHI_CHU';
  from_status: string | null;
  to_status: string | null;
  note: string | null;
  created_at: string;
  created_by_name: string | null;
};

export type TicketRecord = { ticket: TicketDetail; events: TicketEvent[] };
