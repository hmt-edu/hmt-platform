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
