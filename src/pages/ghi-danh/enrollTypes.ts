// Kiểu dữ liệu các hàm đọc ghi danh (migration 113, 114). Giao diện không tính giờ, tiền: chỉ hiện số do hàm cơ sở dữ liệu trả.

export type EnrollmentRow = {
  id: string;
  code: string;
  student_id: string;
  student_name: string;
  student_code: string;
  package_code: string | null;
  package_name: string | null;
  delivery_mode_code: string | null;
  delivery_mode_name: string | null;
  class_id: string | null;
  class_code: string | null;
  granted_hours: number;
  used_hours: number;
  remaining_hours: number;
  status_code: string;
  status_name: string;
};
export type EnrollmentPage = { total: number; rows: EnrollmentRow[] };

export type QueueRow = {
  id: string;
  code: string;
  student_id: string;
  student_name: string;
  package_code: string | null;
  package_name: string | null;
  delivery_mode_code: string | null;
  delivery_mode_name: string | null;
  waiting_since: string;
};
export type QueuePage = { total: number; rows: QueueRow[] };

export type EnrollmentRecord = {
  enrollment: {
    id: string;
    code: string;
    legacy_ref: string | null;
    status_code: string;
    status_name: string;
    student_id: string;
    student_code: string;
    student_name: string;
    parent_id: string;
    parent_code: string;
    parent_name: string;
    package_code: string | null;
    package_name: string | null;
    delivery_mode_code: string | null;
    delivery_mode_name: string | null;
    order_id: string | null;
    order_code: string | null;
    branch_code: string;
    branch_name: string;
    enrolled_on: string;
    start_date: string | null;
    expected_end_date: string | null;
    package_deadline: string | null;
  };
  hours: { granted: number; gifted: number; used: number; remaining: number };
  classes: {
    class_id: string;
    class_code: string;
    start_date: string;
    end_date: string | null;
    end_reason: string | null;
    studied_hours: number;
  }[];
  tickets: number;
};

export type LedgerRow = {
  id: string;
  on_date: string;
  entry_type: string;
  entry_name: string;
  class_code: string | null;
  session_no: number | null;
  session_date: string | null;
  receipt_code: string | null;
  adjusted_by: string | null;
  reason_name: string | null;
  note: string | null;
  ticket_code: string | null;
  hours: number;
  balance: number;
};
export type LedgerPage = { total: number; rows: LedgerRow[] };

/** Lớp phù hợp (app.enrollment_matching_classes). */
export type MatchingClass = {
  id: string;
  code: string;
  subject_name: string;
  class_type_name: string;
  level_name: string | null;
  grade_code: string;
  group_id: string | null;
  group_name: string | null;
  /** Hình thức học của lớp (OFF, ONL, OMO); thiếu ở máy chủ cũ. */
  delivery_mode_code?: string;
  schedule_text: string | null;
  teacher_name: string | null;
  seats_left: number | null;
  has_sessions: boolean;
  class_start_date: string;
  weekdays: number[];
  upcoming: { date: string; session_no: number | null }[];
  clash_sessions: number;
};

export type AssignOptions = {
  enrollment: {
    id: string;
    code: string;
    status_code: string;
    student_id: string;
    student_name: string;
    package_id: string | null;
    delivery_mode_code: string | null;
  };
  siblings: {
    id: string;
    code: string;
    package_id: string | null;
    package_code: string | null;
    package_name: string | null;
  }[];
  classes: MatchingClass[];
  groups: {
    group_id: string;
    group_name: string | null;
    pairs: { enrollment_id: string; enrollment_code: string; class: MatchingClass }[];
  }[];
};

export type OrderLineClass = {
  line_no: number;
  class_id: string;
  class_code: string;
  enrol_start_date: string;
};
