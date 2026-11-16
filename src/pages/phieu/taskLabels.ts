// Nhãn loại phiếu và trạng thái phiếu nghiệp vụ (AS-10), dùng ở chi tiết ticket. Màn Phiếu nghiệp vụ (CS-05, CS-06) có bản riêng ở phieuTypes.ts; hai bản phải khớp.
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
