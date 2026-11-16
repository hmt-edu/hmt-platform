// QT-04 Vai trò (danh sách + mô tả): logic thuần (nhãn cổng, hai bước, nhóm tự đăng xuất). Luật S03-06. Chỉ đọc; quyền chi tiết sửa ở QT-05 Ma trận quyền.
export type RoleSummary = {
  code: string;
  name: string;
  default_scope: string;
  portals: string[];
  view_only_portals: string[];
  require_mfa: boolean;
  idle_group: string;
  sort_order: number;
  users: number;
  cells: number;
};

export const PORTAL_LABEL: Record<string, string> = {
  crm: 'CRM',
  gv: 'Giáo viên',
  hoc: 'Học tập',
};

export const IDLE_GROUP_LABEL: Record<string, string> = {
  staff: 'Nhân viên',
  teacher: 'Giáo viên, trợ giảng',
  student: 'Học sinh, phụ huynh',
};

/** Cổng vào của vai trò: «CRM, Giáo viên (chỉ xem)». Không cổng nào thì «Chưa có cổng». */
export function portalsLabel(role: Pick<RoleSummary, 'portals' | 'view_only_portals'>): string {
  if (role.portals.length === 0) return 'Chưa có cổng';
  return role.portals
    .map((p) => {
      const name = PORTAL_LABEL[p] ?? p;
      return role.view_only_portals.includes(p) ? `${name} (chỉ xem)` : name;
    })
    .join(', ');
}

/** Tìm vai trò theo tên hoặc mã, không phân biệt hoa thường. */
export function filterRoles(roles: RoleSummary[], search: string): RoleSummary[] {
  const key = search.trim().toLocaleLowerCase('vi');
  if (key === '') return roles;
  return roles.filter(
    (r) =>
      r.name.toLocaleLowerCase('vi').includes(key) || r.code.toLocaleLowerCase('vi').includes(key),
  );
}
