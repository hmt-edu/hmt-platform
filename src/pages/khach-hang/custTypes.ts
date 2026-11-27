// Kiểu dữ liệu cụm Khách hàng (KH-01 phụ huynh, KH-02 bản ghi phụ huynh, KH-04 học sinh, KH-05 hồ sơ 360°): khớp app.list_parents, get_parent_record, list_students, get_student_record.
export type StudentStatus = 'DANG_HOC' | 'BAO_LUU' | 'DUNG' | 'TIEM_NANG';

export const STUDENT_STATUS_LABEL: Record<StudentStatus, string> = {
  DANG_HOC: 'Đang học',
  BAO_LUU: 'Bảo lưu',
  DUNG: 'Dừng học',
  TIEM_NANG: 'Tiềm năng',
};

export type ParentRow = {
  id: string;
  code: string;
  full_name: string;
  phone: string;
  branch_code: string;
  is_studying: boolean;
  children_count: number;
  studying_at: string[];
};
export type ParentPage = { total: number; rows: ParentRow[] };

export type StudentRow = {
  id: string;
  code: string;
  legacy_ref: string | null;
  full_name: string;
  grade: number | null;
  status: StudentStatus;
  branch_code: string;
  parent_id: string;
  parent_name: string;
  parent_phone: string | null;
  studying_at: string[];
  classes: string[];
};
export type StudentPage = { total: number; rows: StudentRow[] };

export type ParentRecord = {
  id: string;
  code: string;
  full_name: string;
  phone: string;
  phone_2: string | null;
  /** Từ migration 709. */
  email: string | null;
  relative_name: string | null;
  address: string | null;
  ward_name: string | null;
  province_name: string | null;
  branch_code: string;
  record_status: string;
  merged_into_id: string | null;
  created_at: string;
  is_studying: boolean;
  studying_at: string[];
  children: {
    id: string;
    code: string;
    full_name: string;
    grade: number | null;
    status: StudentStatus;
  }[];
  orders: {
    id: string;
    code: string;
    status_code: string;
    total_amount: number;
    created_at: string;
  }[];
  receipts: {
    id: string;
    code: string;
    status_code: string;
    amount: number;
    paid_on: string | null;
  }[];
  counts: {
    children: number;
    opportunities: number;
    tests: number;
    enrollments: number;
    orders: number;
    receipts: number;
  };
};

export type StudentRecord = {
  id: string;
  code: string;
  legacy_ref: string | null;
  full_name: string;
  birth_date: string | null;
  birth_year: number | null;
  grade: number | null;
  school: string | null;
  goal: string | null;
  gender: string | null;
  branch_code: string;
  status: StudentStatus;
  record_status: string;
  merged_into_id: string | null;
  created_at: string;
  updated_at: string;
  parent: { id: string; code: string; full_name: string; phone: string | null } | null;
  studying_at: string[];
  enrollments: {
    id: string;
    code: string;
    subject_code: string;
    subject_name: string | null;
    status_code: string;
    status_name: string | null;
    class_id: string | null;
    class_code: string | null;
    hours_left: number;
  }[];
  attendance_summary: Record<string, number>;
  attendance: {
    session_date: string;
    start_time: string;
    class_code: string;
    session_status: string;
    status: string | null;
  }[];
  exam_scores: {
    session_date: string;
    class_code: string;
    total_score: number | null;
    max_score: number | null;
  }[];
  tests: {
    id: string;
    code: string;
    status_code: string;
    scheduled_at: string | null;
    score: number | null;
  }[];
  counts: { enrollments: number; classes: number; tests: number };
};

export const ATTENDANCE_LABEL: Record<string, string> = {
  CO_MAT: 'Có mặt',
  DI_MUON: 'Đi muộn',
  VANG_CO_PHEP: 'Vắng có phép',
  VANG_KHONG_PHEP: 'Vắng không phép',
  CHUA: 'Chưa điểm danh',
};
