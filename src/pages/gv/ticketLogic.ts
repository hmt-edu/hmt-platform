// GV-14 Ticket từ cổng giáo viên: logic thuần của form và danh sách (R-CS-10: giáo viên chỉ tạo và theo dõi; AS-05: ticket giáo viên).
export type TicketCategory = {
  code: string;
  name: string;
  group_code: string;
  group_name: string;
  nature_code: 'HO_TRO' | 'PHAN_ANH' | null;
  requires_student: boolean;
  requires_class: boolean;
};

export type TicketClass = {
  id: string;
  code: string;
  subject_name: string | null;
  students: { id: string; name: string }[];
};

export type TicketOptions = { categories: TicketCategory[]; classes: TicketClass[] };

export type TicketRow = {
  id: string;
  code: string;
  title: string;
  ticket_type: 'DN' | 'KN' | 'GV';
  category_name: string | null;
  status_code: string;
  class_code: string | null;
  student_name: string | null;
  created_at: string;
};

export type TicketPage = { total: number; rows: TicketRow[] };

const TYPE_NAMES = { DN: 'Đề nghị', KN: 'Khiếu nại', GV: 'Ticket giáo viên' } as const;
const STATUS_NAMES: Record<string, string> = {
  MOI: 'Mới',
  DA_GIAO: 'Đã giao',
  DANG_XU_LY: 'Đang xử lý',
  CHO_THONG_TIN: 'Chờ thông tin',
  DA_XU_LY: 'Đã xử lý',
  DA_DONG: 'Đã đóng',
  DA_HUY: 'Đã huỷ',
};

export function typeName(t: TicketRow['ticket_type']): string {
  return TYPE_NAMES[t];
}

export function statusName(code: string): string {
  return STATUS_NAMES[code] ?? code;
}

/** Tính chất tự gắn theo nhóm con, chỉ đọc (canvas GV14): Cần hỗ trợ, Phản ánh; nhóm Khác chưa xếp thì "Chưa xếp". */
export function natureText(code: TicketCategory['nature_code'] | undefined): string {
  if (code === 'HO_TRO') return 'Cần hỗ trợ';
  if (code === 'PHAN_ANH') return 'Phản ánh';
  return 'Chưa xếp';
}

export type FormError = Partial<
  Record<'group' | 'category' | 'class' | 'student' | 'description' | 'title', string>
>;

/** Kiểm nhập cơ bản (máy chủ kiểm lại): nhóm, nhóm con, tiêu đề, mô tả; lớp và học sinh theo nhóm con. */
export function validateTicket(d: {
  groupCode: string;
  category: TicketCategory | undefined;
  classId: string;
  studentId: string;
  title: string;
  description: string;
}): FormError {
  const e: FormError = {};
  if (d.groupCode === '') e.group = 'Chọn nhóm.';
  if (d.category === undefined) e.category = 'Chọn nhóm con.';
  if (d.title.trim() === '') e.title = 'Nhập tiêu đề.';
  if (d.description.trim() === '') e.description = 'Mô tả là bắt buộc.';
  if (d.category?.requires_class === true && d.classId === '')
    e.class = 'Nhóm con này bắt buộc chọn lớp.';
  if (d.category?.requires_student === true && d.studentId === '')
    e.student = 'Nhóm con này bắt buộc chọn học sinh.';
  return e;
}

/** Danh sách nhóm (không trùng) theo thứ tự xuất hiện của nhóm con. */
export function groupsOf(categories: TicketCategory[]): { code: string; name: string }[] {
  const seen = new Map<string, string>();
  for (const c of categories) if (!seen.has(c.group_code)) seen.set(c.group_code, c.group_name);
  return [...seen].map(([code, name]) => ({ code, name }));
}
