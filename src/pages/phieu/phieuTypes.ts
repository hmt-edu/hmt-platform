// Kiểu dữ liệu màn Phiếu nghiệp vụ (CSN-05, CSN-06): khớp app.list_ticket_tasks và app.get_ticket_task (migration 260).
export type TaskRow = {
  id: string;
  code: string;
  task_type: string;
  status_code: string;
  level: number;
  level_total: number;
  next_role: string | null;
  ticket_id: string;
  ticket_code: string;
  student_name: string | null;
  branch_code: string;
  created_at: string;
};
export type TaskPage = { total: number; rows: TaskRow[] };
export type TaskFilters = Record<string, unknown>;

export type TaskEvent = {
  id: string;
  event_type: 'TAO' | 'TRINH' | 'DUYET' | 'TU_CHOI' | 'THUC_HIEN' | 'HUY';
  from_status: string | null;
  to_status: string | null;
  note: string | null;
  created_at: string;
  created_by_name: string | null;
};

export type TaskDetail = {
  id: string;
  code: string;
  task_type: string;
  status_code: string;
  reason: string;
  payload: {
    entity?: string;
    changes?: Record<string, string>;
    months?: number;
    start_date?: string;
    kind_code?: string;
    note?: string;
  };
  result: {
    entity?: string;
    before?: Record<string, unknown> | null;
    changes?: Record<string, string>;
  } | null;
  level: number;
  level_total: number;
  levels: string[];
  reject_reason: string | null;
  cancel_reason: string | null;
  branch_id: string;
  branch_code: string;
  created_at: string;
  submitted_at: string | null;
  approved_at: string | null;
  executed_at: string | null;
  created_by_name: string | null;
  can_approve: boolean;
  is_creator: boolean;
};
export type TaskRecord = {
  task: TaskDetail;
  ticket: {
    id: string;
    code: string;
    title: string;
    status_code: string;
    student_name: string | null;
  };
  events: TaskEvent[];
};

export const TASK_TYPE_LABEL: Record<string, string> = {
  CAP_NHAT_HO_SO: 'Cập nhật hồ sơ',
  DOI_LICH: 'Đổi lịch, học bù',
  CHUYEN_LOP: 'Chuyển lớp',
  BAO_LUU: 'Bảo lưu, tiếp tục học',
  DUNG_HOC: 'Dừng học',
  HOAN_PHI: 'Hoàn học phí',
  CHUYEN_PHI: 'Chuyển phí',
};
export const TASK_STATUS_LABEL: Record<string, string> = {
  NHAP: 'Nháp',
  CHO_DUYET: 'Chờ duyệt',
  DA_DUYET: 'Đã duyệt',
  DA_THUC_HIEN: 'Đã thực hiện',
  TU_CHOI: 'Từ chối',
  DA_HUY: 'Đã huỷ',
};
export const LEVEL_ROLE_LABEL: Record<string, string> = {
  QUAN_LY_CO_SO: 'Quản lý cơ sở',
  KE_TOAN: 'Kế toán',
};
export const TASK_FIELD_LABEL: Record<string, string> = {
  full_name: 'Họ tên phụ huynh',
  address: 'Địa chỉ',
  relative_name: 'Người thân',
  school: 'Trường',
  school_type: 'Loại trường',
  grade: 'Khối',
  goal: 'Mục tiêu',
  gender: 'Giới tính',
};
