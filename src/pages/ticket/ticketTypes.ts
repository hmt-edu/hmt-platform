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
