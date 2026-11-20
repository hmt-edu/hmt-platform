// Nhãn tiếng Việt dùng chung cho màn Lớp.
export const WEEKDAY_LABEL: Record<number, string> = {
  1: 'Thứ 2',
  2: 'Thứ 3',
  3: 'Thứ 4',
  4: 'Thứ 5',
  5: 'Thứ 6',
  6: 'Thứ 7',
  7: 'Chủ nhật',
};

export const SESSION_STATUS_LABEL: Record<string, string> = {
  NHAP: 'Nháp',
  DA_CHOT: 'Đã chốt',
  DONE: 'Done',
  HUY_CO_PHI: 'Huỷ có tính phí',
  HUY_KHONG_PHI: 'Huỷ không tính phí',
};

export const timeText = (value: string) => value.slice(0, 5);

export type ClassNotes = {
  /** Dòng trên đầu bản ghi (canvas LOP05_*, LOP06_*). */
  top?: { tone: 'info' | 'warning'; text: string };
  /** Dòng dưới mục Time Table. */
  bottom?: string;
};

/**
 * Câu giải thích theo tình trạng duyệt của lớp (canvas 9933: LOP05_thieu_tkb, LOP05_xacnhan, LOP05_venhap, LOP06_dong_chan).
 * Chỉ chọn câu theo tình trạng và việc đã có khung giờ hay chưa; luật thật do máy chủ kiểm (R-LOP-02, R-LOP-03, R-LOP-11).
 */
export function classNotes(status: string, slotCount: number): ClassNotes {
  if (status === 'NHAP' || status === 'TU_CHOI') {
    return slotCount === 0
      ? {
          top: {
            tone: 'warning',
            text: 'Chưa có thời khoá biểu, nên chưa trình được. Thêm khung giờ ở mục Time Table bên dưới rồi bấm Trình.',
          },
          bottom:
            'Thêm, sửa khung giờ ở màn Sửa lớp (LOP-03), mục Time Table. Trình lớp bắt buộc có Time Table (R-LOP-03).',
        }
      : status === 'NHAP'
        ? { top: { tone: 'info', text: 'Lớp ở Nháp: sửa được thông tin.' } }
        : {};
  }
  if (status === 'DA_TRINH') {
    return {
      top: {
        tone: 'info',
        text: 'Lớp đã trình, đang chờ quản lý cơ sở xác nhận. Chỉ sửa được Time Table; thông tin khác bị khoá (R-LOP-02).',
      },
      bottom:
        'Lớp đã trình: chỉ sửa được Time Table (giáo viên, lịch học tự cập nhật theo); thông tin khác của lớp vẫn khoá. Sửa xong quản lý cơ sở thấy bản mới khi xác nhận, duyệt.',
    };
  }
  if (status === 'DA_XAC_NHAN') {
    return {
      bottom:
        'Lớp đã xác nhận: chỉ sửa được Time Table (giáo viên, lịch học tự cập nhật theo); thông tin khác của lớp vẫn khoá. Sửa Time Table thì lớp quay về Đã trình để quản lý cơ sở duyệt đúng bản cuối.',
    };
  }
  if (status === 'DA_DUYET') {
    return {
      bottom:
        'Lớp đã duyệt: bấm Sửa để đổi Time Table (giáo viên, lịch học), CSKH phụ trách, Sĩ số tối đa; các thông tin khác bị khoá. Thay đổi Time Table áp dụng từ ngày chọn, buổi đã diễn ra giữ nguyên (R-LOP-11).',
    };
  }
  return {};
}

/** Chữ ở ô Nhóm lớp khi lớp không thuộc nhóm nào (canvas LOP05_thieu_tkb). */
export const NO_GROUP_TEXT =
  'Lớp không thuộc nhóm nào. Lớp Đại số, Hình học cùng khối, cùng cơ sở có thể gắn vào một nhóm khi tạo hoặc sửa lớp (LOP-03).';
