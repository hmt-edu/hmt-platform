// Đọc thông tin người dùng từ token (do hook custom_access_token_hook đưa vào).
// Chỉ dùng để giao diện ẩn/hiện cho gọn; quyền thật do RLS trong cơ sở dữ liệu quyết định.

export type Portal = 'crm' | 'gv' | 'hoc';
export const PORTALS: readonly Portal[] = ['crm', 'gv', 'hoc'];

export type HmtClaims = {
  userId: string;
  name: string;
  roles: string[];
  branchCode: string | null;
  portals: Portal[];
  viewOnlyPortals: Portal[];
  requireMfa: boolean;
  /** Vai trò có cờ hai bước nhưng tham số bắt buộc đang tắt (D41): vẫn cho cài thiết bị hai bước tự nguyện ở Hồ sơ. */
  mfaOptional: boolean;
  mustChangePassword: boolean;
  aal: string;
};

function decodePayload(token: string): Record<string, unknown> | null {
  const part = token.split('.')[1];
  if (!part) return null;
  try {
    const base64 = part.replace(/-/g, '+').replace(/_/g, '/');
    const binary = atob(base64);
    const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
    const parsed: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

function stringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v): v is string => typeof v === 'string') : [];
}

function portalArray(value: unknown): Portal[] {
  return stringArray(value).filter((p): p is Portal => (PORTALS as readonly string[]).includes(p));
}

export function readClaims(accessToken: string): HmtClaims | null {
  const payload = decodePayload(accessToken);
  if (!payload || typeof payload.sub !== 'string') return null;
  return {
    userId: payload.sub,
    name: typeof payload.hmt_name === 'string' ? payload.hmt_name : '',
    roles: stringArray(payload.hmt_roles),
    branchCode: typeof payload.hmt_branch_code === 'string' ? payload.hmt_branch_code : null,
    portals: portalArray(payload.hmt_portals),
    viewOnlyPortals: portalArray(payload.hmt_view_only_portals),
    requireMfa: payload.hmt_require_mfa === true,
    mfaOptional: payload.hmt_mfa_optional === true,
    mustChangePassword: payload.hmt_must_change_password === true,
    aal: typeof payload.aal === 'string' ? payload.aal : 'aal1',
  };
}

export type PortalAccess = 'full' | 'view' | 'none';

export function portalAccess(claims: HmtClaims, portal: Portal): PortalAccess {
  if (claims.portals.includes(portal)) return 'full';
  if (claims.viewOnlyPortals.includes(portal)) return 'view';
  return 'none';
}

/** Bước còn phải làm trước khi vào cổng: đổi mật khẩu lần đầu, rồi xác thực hai bước. */
export function pendingStep(claims: HmtClaims): 'change-password' | 'mfa' | null {
  if (claims.mustChangePassword) return 'change-password';
  if (claims.requireMfa && claims.aal !== 'aal2') return 'mfa';
  return null;
}

/** Cổng đầu tiên được vào (đầy đủ trước, chỉ xem sau). */
export function homePortal(claims: HmtClaims): Portal | null {
  return claims.portals[0] ?? claims.viewOnlyPortals[0] ?? null;
}

export type IdleGroup = 'staff' | 'teacher' | 'student';
/** Nhóm của từng vai trò, đọc từ cột idle_group của bảng vai trò (không viết cứng danh sách vai trò). */
export type RoleGroups = Record<string, IdleGroup | undefined>;

/**
 * Nhóm tự đăng xuất; người nhiều vai trò lấy nhóm chặt nhất (nhân viên > giáo viên > học sinh).
 * Vai trò không có trong bảng tính như học sinh (mặc định của cột).
 */
export function idleGroup(roles: string[], groups: RoleGroups): IdleGroup {
  const of = (r: string) => groups[r] ?? 'student';
  if (roles.some((r) => of(r) === 'staff')) return 'staff';
  if (roles.some((r) => of(r) === 'teacher')) return 'teacher';
  return 'student';
}

export const IDLE_SETTING_KEY: Record<IdleGroup, string> = {
  staff: 'staff_idle_logout_minutes',
  teacher: 'teacher_idle_logout_minutes',
  student: 'student_idle_logout_minutes',
};
