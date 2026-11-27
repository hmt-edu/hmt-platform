// Kiểu dữ liệu trả về của app.list_my_work (docs/nghiep-vu/viec-cua-toi.md).
export type Urgency = 'NOW' | 'TODAY' | 'SOON';

export type WorkSignal =
  | 'APPOINTMENT'
  | 'TEST'
  | 'APPROVAL'
  | 'SESSION_PENDING'
  | 'SESSION_NO_ATTENDANCE'
  | 'ABSENT_TODAY'
  | 'RENEWAL'
  | 'TICKET_OVERDUE'
  | 'DEBT_OVERDUE';

export type WorkItem = {
  signal: WorkSignal;
  entity_type: string;
  entity_id: string;
  urgency: Urgency;
  title: string;
  why: string;
  due_at: string | null;
  owner_name: string | null;
  branch_code: string | null;
};

export type WorkCard = {
  group_key: string;
  parent_id: string | null;
  parent_name: string | null;
  phone: string | null;
  urgency: Urgency;
  items: WorkItem[];
};

export type WorkPage = {
  counts: { now: number; today: number; soon: number };
  total_cards: number;
  cards: WorkCard[];
};
