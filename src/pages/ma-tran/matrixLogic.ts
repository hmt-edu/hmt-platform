// QT-05 Ma trận quyền: logic thuần (khoá ô, so sánh bản nháp với bản hiện hành, danh sách thay đổi gửi hàm lưu). Luật: S03-07, S03-10; hàm DB save_permission_matrix kiểm lại
// (phiên bản hiện hành, ô hợp lệ, có ô đổi thật, phân hệ Quản trị chỉ ADMIN). Mỗi lần lưu tạo phiên bản mới, có hiệu lực ngay, có nhật ký.
export type Role = { code: string; name: string };
export type NamedCode = { code: string; name: string };
export type PermissionRow = {
  role_code: string;
  module_code: string;
  action_code: string;
  scope_code: string;
  is_active: boolean;
};
export type VersionRow = {
  version_no: number;
  saved_at: string;
  changed_count: number;
  note: string | null;
};
export type ChangeRow = {
  version_no: number;
  role_code: string;
  module_code: string;
  action_code: string;
  from_scope: string | null;
  to_scope: string | null;
};

/** Không có quyền: giá trị rỗng của ô chọn. */
export const NO_SCOPE = '';

export const cellKey = (role: string, module: string, action: string): string =>
  `${role}|${module}|${action}`;

/** Phạm vi đang có của từng ô (dòng không hoạt động coi như không có). */
export function baseMap(rows: PermissionRow[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const r of rows) {
    if (r.is_active) map.set(cellKey(r.role_code, r.module_code, r.action_code), r.scope_code);
  }
  return map;
}

/** Ô chỉ ADMIN được có quyền (phân hệ Quản trị): các vai trò khác không sửa được. */
export const isLockedCell = (role: string, module: string): boolean =>
  module === 'ADMIN' && role !== 'ADMIN';

export type Draft = Map<string, string>;

/** Phạm vi hiện ra ở ô: bản nháp nếu đã sửa, không thì bản hiện hành. */
export function scopeAt(base: Map<string, string>, draft: Draft, key: string): string {
  return draft.has(key) ? (draft.get(key) ?? NO_SCOPE) : (base.get(key) ?? NO_SCOPE);
}

/** Đặt một ô; đặt lại đúng giá trị hiện hành thì bỏ khỏi bản nháp (ô không còn «đã sửa»). */
export function setCell(
  base: Map<string, string>,
  draft: Draft,
  key: string,
  scope: string,
): Draft {
  const next = new Map(draft);
  if ((base.get(key) ?? NO_SCOPE) === scope) next.delete(key);
  else next.set(key, scope);
  return next;
}

export type Change = { role: string; module: string; action: string; scope: string };

/** Danh sách ô đã đổi để gửi save_permission_matrix (scope rỗng = tắt quyền). */
export function changesOf(draft: Draft): Change[] {
  return [...draft.entries()].map(([key, scope]) => {
    const [role = '', module = '', action = ''] = key.split('|');
    return { role, module, action, scope };
  });
}

export const countForRole = (draft: Draft, role: string): number =>
  [...draft.keys()].filter((k) => k.startsWith(`${role}|`)).length;

/** Câu mô tả một thay đổi trong lịch sử: "CSKH: Ticket · Giao việc, từ Không có sang Cơ sở mình". */
export function describeChange(
  c: ChangeRow,
  names: {
    role: (code: string) => string;
    module: (code: string) => string;
    action: (code: string) => string;
    scope: (code: string | null) => string;
  },
): string {
  return `${names.role(c.role_code)}: ${names.module(c.module_code)} · ${names.action(c.action_code)}, ${names.scope(c.from_scope)} → ${names.scope(c.to_scope)}`;
}
