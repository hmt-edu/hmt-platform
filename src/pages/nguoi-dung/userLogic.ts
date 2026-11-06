// Phần thuần của màn Người dùng: lý do khoá gửi đi, kiểm vai trò chọn, tóm tắt vai trò, tên loại mã NV/GV/TG.
import type { UserRoleRef } from './userTypes';

/** Lý do khoá gửi cho hàm khoá: tên mục danh mục, kèm ghi chú nếu có ("Khác: ghi chú"). */
export function lockReasonText(reasonName: string, note: string): string {
  const extra = note.trim();
  return extra === '' ? reasonName : `${reasonName}: ${extra}`;
}

/** Lỗi nhập hộp chọn vai trò (null là hợp lệ): tài khoản phải có ít nhất một vai trò (R-HT-03). */
export function rolesError(selected: string[]): string | null {
  return selected.length === 0 ? 'Chọn ít nhất một vai trò.' : null;
}

/** Hai tập vai trò giống nhau (không phân biệt thứ tự): hộp Sửa vai trò không cho lưu khi chưa đổi gì. */
export function sameRoles(a: string[], b: string[]): boolean {
  return a.length === b.length && [...a].sort().join('|') === [...b].sort().join('|');
}

export function roleNames(roles: UserRoleRef[]): string {
  return roles.map((r) => r.name).join(', ');
}

/** Loại tài khoản từ mã: NV (nhân viên), GV (giáo viên), TG (trợ giảng). Chưa có mã thì để trống. */
export function staffKind(code: string | null): string {
  if (!code) return '';
  if (code.startsWith('GV')) return 'Giáo viên';
  if (code.startsWith('TG')) return 'Trợ giảng';
  return 'Nhân viên';
}

/** Dạng tên đăng nhập hợp lệ (khớp ràng buộc DB): chữ thường không dấu, số, dấu chấm, gạch; bắt đầu bằng chữ; 2 đến 40 ký tự. */
export const USERNAME_PATTERN = /^[a-z][a-z0-9._-]{1,39}$/;

/** Gợi ý tên đăng nhập từ tên hiển thị, cùng cách với hàm DB app.suggest_username: tên (từ cuối) + chữ cái đầu họ và tên đệm, không dấu ("Nguyễn Văn An" thành "annv"). */
export function suggestUsername(displayName: string): string {
  const words = displayName
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w !== '');
  if (words.length === 0) return '';
  const given = words[words.length - 1] ?? '';
  const initials = words
    .slice(0, -1)
    .map((w) => w.charAt(0))
    .join('');
  return `${given}${initials}`.slice(0, 40);
}

/** Email quy ước từ tên đăng nhập và tên miền trong Cài đặt: `<tên đăng nhập>@<tên miền>`. */
export function conventionalEmail(username: string, domain: string): string {
  return username === '' || domain === '' ? '' : `${username}@${domain}`;
}

/** Lỗi dạng của tên đăng nhập (null là hợp lệ); trùng thì hỏi DB. */
export function usernameFormatError(username: string): string | null {
  return USERNAME_PATTERN.test(username)
    ? null
    : 'Chữ thường không dấu, số, dấu chấm hoặc gạch; bắt đầu bằng chữ; từ 2 đến 40 ký tự.';
}

/** Email đúng dạng đơn giản (kiểm đầy đủ ở máy chủ). */
export function emailFormatError(email: string): string | null {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? null : 'Email không đúng dạng.';
}

/** Loại nhân sự gửi cho hàm cấp mã: NV, GV, TG. */
export const STAFF_KINDS = [
  { value: 'NV', label: 'Nhân viên' },
  { value: 'GV', label: 'Giáo viên' },
  { value: 'TG', label: 'Trợ giảng' },
];
