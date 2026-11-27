// Kiểu dữ liệu màn «Điểm danh»: khớp app.attendance_board, app.attendance_call_list (migration 701).
export type BoardRow = {
  session_id: string;
  student_id: string;
  student_name: string;
  session_date: string;
  start_time: string;
  end_time: string;
  class_code: string;
  subject_name: string;
  room_name: string | null;
  teacher_name: string | null;
  /** Buổi đã Done: khoá hai cột. */
  locked: boolean;
  session_total: number;
  session_marked: number;
  ops_status_code: string | null;
  teacher_status_code: string | null;
  contact_reason_code: string | null;
  contact_reason_name: string | null;
  ops_note: string | null;
};
export type Board = {
  from: string;
  to: string;
  total: number;
  rows: BoardRow[];
  summary: {
    present: number;
    late: number;
    absent: number;
    unmarked: number;
    to_call: number;
    sessions: number;
    incomplete_sessions: number;
  };
  classes: { id: string; code: string }[];
};
export type CallRow = {
  session_id: string;
  student_id: string;
  student_name: string;
  session_date: string;
  start_time: string;
  class_code: string;
  locked: boolean;
  status_code: string | null;
  contact_reason_code: string | null;
  contact_reason_name: string | null;
  ops_note: string | null;
  parent_phone: string | null;
};
export type CallList = { total: number; rows: CallRow[]; times: string[] };
export type Quick = '' | 'CHUA' | 'LECH';
export type RangeFilters = { from: string; to: string; branch_id?: string };
