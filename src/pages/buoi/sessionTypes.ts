// Kiểu dữ liệu các hàm đọc cụm Buổi A (migration 120): app.session_list, app.session_record, app.session_ops_sheet, app.absent_today_list.

export type SessionRow = {
  id: string;
  session_date: string;
  start_time: string;
  end_time: string;
  class_id: string;
  class_code: string;
  subject_name: string;
  branch_code: string;
  session_no: number | null;
  type_code: string;
  type_name: string;
  teacher_name: string | null;
  room_name: string | null;
  status_code: string;
  status_name: string;
  note: string | null;
};
export type SessionPage = { total: number; rows: SessionRow[] };

export type RecordStudent = {
  student_id: string;
  student_code: string;
  full_name: string;
  is_trial: boolean;
  enrollment_code: string | null;
  ops_status_code: string | null;
  ops_status_name: string | null;
  teacher_status_code: string | null;
  teacher_status_name: string | null;
  mismatch: boolean;
};
export type SessionRecord = {
  session: {
    id: string;
    status_code: string;
    status_name: string;
    type_code: string;
    type_name: string;
    session_no: number | null;
    session_date: string;
    start_time: string;
    end_time: string;
    class_id: string;
    class_code: string;
    class_type_code: string;
    subject_name: string;
    branch_code: string;
    branch_name: string;
    teacher_name: string | null;
    assistant_name: string | null;
    room_name: string | null;
    start_lesson: string | null;
    cancel_reason_code: string | null;
    cancel_reason_name: string | null;
    cancel_note: string | null;
    branch_id: string;
    teacher_id: string | null;
    assistant_id: string | null;
  };
  pending_reason: string | null;
  complete_deadline: string | null;
  listed: boolean;
  students: RecordStudent[];
  excluded: { student_id: string; student_code: string; full_name: string; reason_code: string }[];
  reviews: {
    student_id: string;
    full_name: string;
    comment: string | null;
    teacher_status_code: string | null;
  }[];
};

export type OpsStudent = {
  student_id: string;
  student_code: string;
  full_name: string;
  ops_status_code: string | null;
  contact_reason_code: string | null;
  ops_note: string | null;
  teacher_status_code: string | null;
};
export type OpsSheet = {
  session: {
    id: string;
    status_code: string;
    session_no: number | null;
    session_date: string;
    start_time: string;
    end_time: string;
    class_id: string;
    class_code: string;
    subject_name: string;
  };
  statuses: { code: string; name: string }[];
  reasons: { code: string; name: string; requires_note: boolean }[];
  listed: boolean;
  students: OpsStudent[];
};

export type AbsentRow = {
  session_id: string;
  student_id: string;
  student_name: string;
  class_code: string;
  subject_name: string;
  session_date: string;
  start_time: string;
  kind: 'VANG' | 'CHUA_DEN';
  ops_status_code: string | null;
  effective_status_code: string | null;
  contact_reason_code: string | null;
  contact_reason_name: string | null;
  ops_note: string | null;
};
export type AbsentPage = { total: number; rows: AbsentRow[] };

export type CancelPreview = { added_session_no: number | null; added_date: string | null };
export type MoveOptions = {
  current_room_id: string | null;
  rooms: { id: string; code: string; name: string }[];
};
export type MoveCheck = { room_clash: string[]; teacher_clash: string[] };
export type PendingRow = {
  id: string;
  class_code: string;
  subject_name: string;
  session_no: number | null;
  session_date: string;
  start_time: string;
  teacher_name: string | null;
  deadline: string;
  /** Âm = đã quá hạn. */
  minutes_left: number;
  reason: string | null;
};
export type PendingPage = { total: number; rows: PendingRow[] };
