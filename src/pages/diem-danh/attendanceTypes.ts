// Kiểu dữ liệu màn «Điểm danh»: khớp app.attendance_board (migration 714).
export type BoardRow = {
  session_id: string;
  student_id: string;
  student_code: string;
  student_name: string;
  session_date: string;
  start_time: string;
  end_time: string;
  class_id: string;
  class_code: string;
  subject_name: string;
  grade_code: string | null;
  parent_name: string;
  /** Chỉ có khi người xem có Phụ huynh · Xem. */
  parent_phone: string | null;
  teacher_name: string | null;
  /** Người phụ trách chăm sóc của lớp. */
  cskh_name: string | null;
  /** Buổi đã Done: khoá cột Vận hành và Liên hệ phụ huynh. */
  locked: boolean;
  ops_status_code: string | null;
  teacher_status_code: string | null;
  teacher_marked_at: string | null;
  contact_reason_code: string | null;
  contact_reason_name: string | null;
  ops_note: string | null;
  /** Khoá nhóm cấp một, cấp hai theo trường đang nhóm (null khi không nhóm cấp đó). */
  k1: string | null;
  k2: string | null;
};
export type GroupCount = { k1: string | null; k2: string | null; count: number };
export type Board = {
  from: string;
  to: string;
  total: number;
  rows: BoardRow[];
  groups: GroupCount[];
  summary: {
    present: number;
    late: number;
    absent: number;
    unmarked: number;
    mismatch: number;
    not_in_class: number;
  };
  classes: { id: string; code: string }[];
  teachers: { id: string; name: string }[];
  owners: { id: string; name: string }[];
};
export type BoardFilters = {
  from: string;
  to: string;
  branch_id?: string;
  class_id?: string;
  teacher_id?: string;
  cskh_id?: string;
  quick: string[];
  group: string[];
};
