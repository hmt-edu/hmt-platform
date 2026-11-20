// Hàm thuần cho khung «Không có quyền» của danh sách K03 (component ở ListForbidden.tsx).
import { HmtError } from '../lib/db';

export type ListForbiddenSpec = { subject: string; module: string };

/** Lỗi do thiếu quyền xem thì trả khung cần hiện, ngược lại undefined (danh sách giữ khung lỗi chung). */
export function listForbiddenOf(
  error: unknown,
  subject: string,
  module: string,
): ListForbiddenSpec | undefined {
  return error instanceof HmtError && error.code === 'HMT_KHONG_CO_QUYEN'
    ? { subject, module }
    : undefined;
}

/** Câu giải thích dưới tiêu đề: nêu vai trò đang đăng nhập khi biết, rồi hướng dẫn liên hệ quản trị viên. */
export function forbiddenBody(roleNames: string[], module: string): string {
  const who = roleNames.length > 0 ? `Vai trò ${roleNames.join(', ')}` : 'Tài khoản này';
  return `${who} chưa được cấp quyền xem phân hệ ${module}. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.`;
}
