// Kiểu dữ liệu màn Phiếu kiểm tra: khớp kết quả các hàm list_student_tests, student_test_board, get_student_test
// (docs/spec/04 R-CRM-05, 06, 10, 11, 21).

export type TestStatus = 'DRAFT' | 'TESTING' | 'TEACHER_REVIEW' | 'COMPLETED' | 'CANCELLED';

export type TestRow = {
  id: string;
  code: string;
  opportunity_id: string;
  opportunity_code: string;
  student_id: string;
  student_code: string;
  student_name: string;
  student_birth_year: number | null;
  parent_name: string;
  subject_code: string;
  grade_code: string;
  mode_code: string;
  level_code: string;
  exam_name: string | null;
  scheduled_at: string;
  status_code: TestStatus;
  branch_code: string;
  test_branch_code: string;
  room_id: string | null;
  room_name: string | null;
  grader_id: string | null;
  grader_name: string | null;
  owner_id: string;
  owner_name: string | null;
  created_by_name: string | null;
  score: number | null;
  cancel_reason_code: string | null;
  created_at: string;
};

export type TestPage = { total: number; rows: TestRow[] };

/** Thẻ Kanban: các cột màn hiện. */
export type TestBoardCard = Pick<
  TestRow,
  | 'id'
  | 'code'
  | 'student_name'
  | 'parent_name'
  | 'subject_code'
  | 'grade_code'
  | 'mode_code'
  | 'level_code'
  | 'scheduled_at'
  | 'test_branch_code'
  | 'room_name'
  | 'grader_id'
  | 'grader_name'
  | 'owner_id'
  | 'owner_name'
  | 'created_by_name'
  | 'score'
  | 'status_code'
> & { created_by: string | null };

export type TestBoardColumn = {
  status_code: TestStatus;
  name: string;
  total: number;
  bar: { upcoming: number; today: number; overdue: number };
  rows: TestBoardCard[];
};

/** Kết quả get_student_test: các cột của phiếu kèm tên, mã, số đếm cho trang bản ghi. */
export type TestRecord = {
  id: string;
  code: string;
  opportunity_id: string;
  opportunity_code: string;
  opportunity_stage_code: string;
  /** Trống = cơ hội tạo trực tiếp, không qua lead. */
  lead_id: string | null;
  lead_code: string | null;
  student_id: string;
  student_code: string;
  student_name: string;
  student_birth_year: number | null;
  parent_code: string;
  parent_name: string;
  status_code: TestStatus;
  status: string | null;
  subject_code: string;
  subject: string | null;
  grade_code: string;
  grade: string | null;
  mode_code: string;
  mode: string | null;
  level_code: string;
  level: string | null;
  exam_name: string | null;
  scheduled_at: string;
  branch_id: string;
  branch_code: string;
  branch_name: string;
  test_branch_id: string;
  test_branch_code: string;
  test_branch_name: string;
  created_branch_code: string;
  created_branch_name: string;
  room_id: string | null;
  room_name: string | null;
  room_capacity: number | null;
  grader_id: string | null;
  grader_name: string | null;
  owner_id: string;
  owner_name: string | null;
  created_by_name: string | null;
  created_at: string;
  updated_by_name: string | null;
  updated_at: string;
  status_reason: string | null;
  cancel_reason_code: string | null;
  cancel_reason: string | null;
  cancel_note: string | null;
  score: number | null;
  result_note: string | null;
  suggested_level_code: string | null;
  suggested_level: string | null;
  suggested_framework_code: string | null;
  suggested_framework: string | null;
  result_entered_by_name: string | null;
  result_on_behalf: boolean | null;
  appointments_total: number;
  appointments_open: number;
};

export const STATUS_LABEL: Record<TestStatus, string> = {
  DRAFT: 'Nháp',
  TESTING: 'Đang test',
  TEACHER_REVIEW: 'Chờ giáo viên chấm',
  COMPLETED: 'Hoàn thành',
  CANCELLED: 'Huỷ',
};

/** Bốn trạng thái của thanh trạng thái trên trang phiếu (Huỷ nằm ngoài thanh, ở menu Hành động). */
export const STATUS_FLOW: TestStatus[] = ['DRAFT', 'TESTING', 'TEACHER_REVIEW', 'COMPLETED'];
