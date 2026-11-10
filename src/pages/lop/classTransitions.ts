// Các bước chuyển tình trạng duyệt của lớp (R-LOP-01) và việc mỗi bước cần: LOP-05 (Trình, Xác nhận, Duyệt, Từ chối, Đưa về Nháp, Huỷ) và
// LOP-06 (Đóng, Huỷ: bị chặn thì máy chủ báo lý do và liệt kê tên). Hàm thuần, có kiểm thử. Quyền thật do máy chủ kiểm (app.transition_class).

export type Transition = {
  to: string;
  /** Nhãn nút / mục menu. */
  label: string;
  /** Quyền Lớp học cần có để HIỆN mục (máy chủ vẫn kiểm lại). */
  action: 'SUA' | 'DUYET' | 'HUY';
  /** 'confirm' = hộp xác nhận; 'note' = hộp ghi chú (bắt buộc khi noteRequired). */
  dialog: 'confirm' | 'note';
  noteRequired?: boolean;
  danger?: boolean;
  title: string;
  description: string;
};

const T = {
  DA_TRINH: {
    to: 'DA_TRINH',
    label: 'Trình',
    action: 'SUA',
    dialog: 'confirm',
    title: 'Trình lớp để duyệt',
    description:
      'Lớp cần có thời khoá biểu (ít nhất một khung giờ). Trình xong, người có quyền sẽ xác nhận rồi duyệt.',
  },
  DA_XAC_NHAN: {
    to: 'DA_XAC_NHAN',
    label: 'Xác nhận',
    action: 'DUYET',
    dialog: 'confirm',
    title: 'Xác nhận lớp',
    description: 'Xác nhận thời khoá biểu và thông tin lớp. Sau đó có thể Duyệt hoặc Từ chối.',
  },
  DA_DUYET: {
    to: 'DA_DUYET',
    label: 'Duyệt',
    action: 'DUYET',
    dialog: 'confirm',
    title: 'Duyệt lớp',
    description: 'Duyệt bắt buộc có thời khoá biểu. Duyệt xong hệ thống tự sinh các buổi học.',
  },
  TU_CHOI: {
    to: 'TU_CHOI',
    label: 'Từ chối',
    action: 'DUYET',
    dialog: 'note',
    noteRequired: true,
    title: 'Từ chối lớp',
    description: 'Ghi lý do để người tạo lớp sửa lại.',
  },
  NHAP: {
    to: 'NHAP',
    label: 'Đưa về Nháp',
    action: 'SUA',
    dialog: 'note',
    title: 'Đưa lớp về Nháp',
    description: 'Lớp về Nháp để sửa lại. Ghi chú không bắt buộc.',
  },
  DA_DONG: {
    to: 'DA_DONG',
    label: 'Đóng lớp',
    action: 'DUYET',
    dialog: 'confirm',
    danger: true,
    title: 'Đóng lớp',
    description:
      'Đóng lớp khi lớp kết thúc. Bị chặn nếu còn học sinh còn giờ (hệ thống liệt kê tên).',
  },
  HUY: {
    to: 'HUY',
    label: 'Huỷ lớp',
    action: 'HUY',
    dialog: 'note',
    danger: true,
    title: 'Huỷ lớp',
    description: 'Huỷ lớp không dùng nữa. Bị chặn nếu lớp đã có buổi Done.',
  },
} satisfies Record<string, Transition>;

/** Các bước đi hợp lệ từ một tình trạng (khớp app.transition_class, R-LOP-01). */
const FROM: Record<string, (keyof typeof T)[]> = {
  NHAP: ['DA_TRINH', 'HUY'],
  DA_TRINH: ['DA_XAC_NHAN', 'TU_CHOI', 'NHAP', 'HUY'],
  DA_XAC_NHAN: ['DA_DUYET', 'TU_CHOI', 'NHAP', 'HUY'],
  DA_DUYET: ['DA_DONG', 'HUY'],
  TU_CHOI: ['NHAP', 'HUY'],
};

export function transitionsFrom(status: string): Transition[] {
  return (FROM[status] ?? []).map((key) => T[key]);
}

/** Sửa thông tin / thời khoá biểu: Nháp, Từ chối sửa tất cả; Đã trình, Đã xác nhận, Đã duyệt chỉ sửa thời khoá biểu (R-LOP-02, R-LOP-10). */
export function editKind(status: string): 'FULL' | 'TIMETABLE' | null {
  if (status === 'NHAP' || status === 'TU_CHOI') return 'FULL';
  if (status === 'DA_TRINH' || status === 'DA_XAC_NHAN' || status === 'DA_DUYET')
    return 'TIMETABLE';
  return null;
}
