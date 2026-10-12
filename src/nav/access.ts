// Tính quyền hiển thị từ dữ liệu khung (hàm thuần, có kiểm thử).
import type { AccessData, BranchRow } from './accessData';
import { SCOPE_ALL } from './accessData';
import type { MenuAccess } from './crmMenu';

/** Giá trị "Tất cả cơ sở" của ô chọn cơ sở. */
export const ALL_BRANCHES = 'all';

export type AccessView = MenuAccess & {
  /** Người thấy mọi cơ sở (có vai trò phạm vi Toàn hệ thống): có ô chọn cơ sở. */
  seesAllBranches: boolean;
  /** Cơ sở dạy học cho ô chọn cơ sở của dữ liệu nghiệp vụ: không có Hội sở CS3 (R-HT-02). */
  teachingBranches: BranchRow[];
  /** Tên các vai trò của người dùng, để hiện ở góc tài khoản. */
  roleNames: string[];
};

export function buildAccess(
  data: AccessData,
  user: { roles: string[]; branchCode: string | null },
  selectedBranch: string,
): AccessView {
  const granted = new Set(data.permissions.map((p) => `${p.module_code}|${p.action_code}`));
  const actions = new Set(data.permissions.map((p) => p.action_code));
  const myRoles = data.roles.filter((r) => user.roles.includes(r.code));
  const seesAllBranches = myRoles.some((r) => r.default_scope === SCOPE_ALL);
  const teachingBranches = data.branches.filter((b) => !b.is_office);

  // Công tắc tính năng xét theo cơ sở đang xem: người một cơ sở thì cơ sở của mình;
  // người thấy mọi cơ sở thì cơ sở đang chọn, "Tất cả cơ sở" = bật ở ít nhất một cơ sở.
  const scopeBranchIds = seesAllBranches
    ? teachingBranches
        .filter((b) => selectedBranch === ALL_BRANCHES || b.id === selectedBranch)
        .map((b) => b.id)
    : data.branches.filter((b) => b.code === user.branchCode).map((b) => b.id);

  return {
    can: (module, action) => granted.has(`${module}|${action}`),
    canAnyModule: (action) => actions.has(action),
    featureOn: (feature) =>
      data.features.some(
        (f) => f.enabled && f.module_code === feature && scopeBranchIds.includes(f.branch_id),
      ),
    seesAllBranches,
    teachingBranches,
    roleNames: myRoles.map((r) => r.name),
  };
}
