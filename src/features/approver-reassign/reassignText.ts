// Chữ hiển thị của «Chuyển người duyệt» (R-V2-44). Thuần chữ, có kiểm thử.
import type { ReassignState } from './useReassign';

/** Vì sao người đã chốt không duyệt được (từ get_reassign_state.reason). */
export function reassignReasonText(reason: ReassignState['reason']): string {
  switch (reason) {
    case 'BI_KHOA':
      return 'Tài khoản người duyệt đang bị khoá.';
    case 'MAT_QUYEN':
      return 'Người duyệt không còn quyền Duyệt ở cơ sở này.';
    case 'QUA_HAN':
      return 'Người duyệt để chứng từ chờ quá hạn xử lý.';
    default:
      return '';
  }
}

/** Mã lý do gợi ý sẵn theo tình trạng người duyệt (người dùng vẫn đổi được). */
export function suggestedReasonCode(reason: ReassignState['reason']): string {
  switch (reason) {
    case 'BI_KHOA':
      return 'BI_KHOA';
    case 'QUA_HAN':
      return 'QUA_HAN_XU_LY';
    default:
      return '';
  }
}

/** Câu ghi chú gửi cho máy chủ: «Khác» cần ghi chú, các lý do còn lại ghi chú tuỳ chọn. */
export function noteForReassign(note: string): string | null {
  const text = note.trim();
  return text === '' ? null : text;
}
