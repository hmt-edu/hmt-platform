// Hộp thoại đổi trạng thái ticket theo canvas CSN-04: Huỷ (lý do bắt buộc), Đóng làm tay (ghi chú bắt buộc khi nhóm con có nghiệp vụ), Mở lại (lý do bắt buộc), Đóng khiếu nại (mức hài lòng).
// Kiểm sớm cho giao diện; luật chặn thật ở app.change_ticket_status (AS-02, AS-03, AS-04).
export type StatusDialogInput = {
  from: string;
  to: string;
  ticketType: 'DN' | 'KN' | 'GV';
  businessType: string | null;
};
export type StatusDialogSpec = {
  title: string | null; // null: dùng tiêu đề chung «Chuyển sang …»
  confirmLabel: string;
  noteLabel: string;
  noteRequired: boolean;
  hint: string | null;
};

export function statusDialogSpec(i: StatusDialogInput): StatusDialogSpec {
  if (i.to === 'DA_HUY')
    return {
      title: null,
      confirmLabel: 'Huỷ ticket',
      noteLabel: 'Lý do huỷ',
      noteRequired: true,
      hint: 'Ticket không xoá được, chỉ chuyển sang Huỷ.',
    };
  if (i.from === 'DA_DONG' && i.to === 'DANG_XU_LY')
    return {
      title: 'Mở lại ticket',
      confirmLabel: 'Mở lại',
      noteLabel: 'Lý do mở lại',
      noteRequired: true,
      hint: 'Ticket quay về Đang xử lý. Chỉ mở lại được trong số ngày cho phép sau khi đóng.',
    };
  if (i.to === 'DA_DONG' && i.businessType !== null)
    return {
      title: 'Đóng ticket làm tay',
      confirmLabel: 'Đóng ticket',
      noteLabel: 'Ghi chú làm tay',
      noteRequired: true,
      hint: 'Phiếu nghiệp vụ chưa làm trong hệ thống. Ticket đóng với ghi chú làm tay, không sinh dòng tiền hay giờ.',
    };
  if (i.to === 'DA_DONG' && i.ticketType === 'KN')
    return {
      title: 'Đóng khiếu nại',
      confirmLabel: 'Đóng khiếu nại',
      noteLabel: 'Ghi chú đóng',
      noteRequired: false,
      hint: null,
    };
  return {
    title: null,
    confirmLabel: 'Chuyển',
    noteLabel: 'Ghi chú',
    noteRequired: false,
    hint: null,
  };
}
