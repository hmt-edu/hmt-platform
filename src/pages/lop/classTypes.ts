// Kiểu dữ liệu màn Lớp (LOP-01 danh sách, LOP-02 hồ sơ, LOP-08 lịch tuần): khớp kết quả app.list_classes, app.get_class_record, app.week_sessions.
export type ClassRow = {
  id: string;
  code: string;
  legacy_ref: string | null;
  branch_id: string;
  branch_code: string;
  subject_code: string;
  subject_name: string | null;
  grade_code: string;
  class_type_code: string;
  class_type_name: string | null;
  level_code: string | null;
  level_name: string | null;
  status_code: string;
  status_name: string | null;
  operating_status: 'CHUA_KHAI_GIANG' | 'DANG_HOC' | 'DA_KET_THUC' | null;
  max_students: number;
  enrolled: number;
  seats_left: number | null;
  start_date: string;
  expected_end_date: string | null;
  total_sessions: number;
  group_name: string | null;
  schedule: {
    weekday: number;
    start_time: string;
    end_time: string;
    teacher_name?: string | null;
    room_name?: string | null;
  }[];
  teacher_names: string | null;
};

export type ClassPage = { total: number; rows: ClassRow[] };

export type ClassSlot = {
  id: string;
  weekday: number;
  start_time: string;
  end_time: string;
  repeat_weeks: number;
  first_date: string;
  teacher_id: string | null;
  assistant_id: string | null;
  room_id: string | null;
  teacher_name: string | null;
  assistant_name: string | null;
  room_name: string | null;
};

export type ClassStudent = {
  enrollment_id: string;
  enrollment_code: string;
  student_id: string;
  student_code: string;
  full_name: string;
  start_date: string;
  enrollment_status: string;
  hours_left: number;
};

export type ClassSessionRow = {
  id: string;
  session_no: number | null;
  session_date: string;
  start_time: string;
  end_time: string;
  status_code: string;
  type_code: string;
  teacher_name: string | null;
};

export type ClassRecord = Omit<ClassRow, 'enrolled' | 'branch_code' | 'subject_name'> & {
  branch_code: string;
  subject_name: string | null;
  year_code: string;
  /** Hình thức học của lớp: OFF, ONL, OMO (danh mục CLASS_DELIVERY). */
  delivery_mode_code?: string;
  delivery_mode_name?: string | null;
  curriculum_ref: string | null;
  start_lesson: string | null;
  cskh_id: string | null;
  group_id: string | null;
  slots: ClassSlot[];
  students: ClassStudent[];
  session_counts: Record<string, number>;
  sessions: ClassSessionRow[];
  /** Các lớp KHÁC cùng nhóm lớp (R-LOP-14), mỗi lớp độc lập. */
  group_classes?: {
    id: string;
    code: string;
    subject_name: string | null;
    status_code: string;
    status_name: string | null;
    teacher_names: string | null;
  }[];
  clash_warnings: { kind?: string; message?: string }[] | unknown[];
  events: { event_code: string; created_at: string; note: string | null }[];
};

export type WeekSession = {
  session_id: string;
  class_id: string;
  class_code: string;
  group_id: string | null;
  session_date: string;
  start_time: string;
  end_time: string;
  status_code: string;
  type_code: string;
  teacher_name: string | null;
  assistant_name: string | null;
  room_id: string | null;
  room_name: string | null;
  room_clash: boolean;
  teacher_clash: boolean;
};

export const OPERATING_LABEL: Record<string, string> = {
  CHUA_KHAI_GIANG: 'Chưa khai giảng',
  DANG_HOC: 'Đang học',
  DA_KET_THUC: 'Đã kết thúc',
};
