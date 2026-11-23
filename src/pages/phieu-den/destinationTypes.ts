// CS-07 màn cơ sở ĐÍCH (R-GD-10, R-CS-07; migration 568): kiểu dữ liệu khớp app.list_tasks_for_destination và app.get_task_for_destination, cùng kiểm sớm khi chọn lớp mới.
export type DestinationRow = {
  id: string;
  code: string;
  ticket_code: string;
  student_name: string | null;
  from_branch_code: string;
  dest_branch_code: string;
  created_at: string;
};
export type DestinationClass = {
  id: string;
  code: string;
  subject_code: string;
  seats_left: number | null;
  upcoming: { date: string; session_no: number }[];
};
export type DestinationRecord = {
  task: {
    id: string;
    code: string;
    reason: string;
    level: number;
    level_total: number;
    from_branch_code: string;
    dest_branch_code: string;
    to_class_id: string | null;
    start_date: string | null;
    student_name: string | null;
    hours_left: number;
    subject_code: string | null;
    approved_by_source: string | null;
  };
  classes: DestinationClass[];
};

/** Kiểm sớm trước khi lưu lớp: phải chọn lớp và buổi bắt đầu (luật chặn thật ở app.set_task_destination_class). */
export function validateDestinationChoice(classId: string, startDate: string) {
  const e: { classId?: string; startDate?: string } = {};
  if (classId === '') e.classId = 'Chọn lớp mới.';
  if (startDate === '') e.startDate = 'Chọn buổi bắt đầu ở lớp mới.';
  return e;
}

/** Đã chọn lớp ở bước này chưa: nút Duyệt chỉ bật sau khi lớp được lưu (hàm duyệt kiểm lại, HMT_PHIEU_CHUA_CHON_LOP). */
export const hasSavedDestinationClass = (t: DestinationRecord['task']) =>
  t.to_class_id !== null && t.start_date !== null;
