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
