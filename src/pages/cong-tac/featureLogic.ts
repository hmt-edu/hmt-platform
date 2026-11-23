// QT-10 Công tắc tính năng theo cơ sở: logic thuần. Không có dòng công tắc = TẮT (app.feature_enabled); Admin bật, tắt từng (phân hệ, cơ sở) qua app.set_feature.
export type FeatureModule = { code: string; name: string };
export type FeatureFlag = { module_code: string; branch_id: string; enabled: boolean };

export const isEnabled = (flags: FeatureFlag[], moduleCode: string, branchId: string): boolean =>
  flags.some((f) => f.module_code === moduleCode && f.branch_id === branchId && f.enabled);

/** Số cơ sở đang bật của một phân hệ. */
export const enabledCount = (flags: FeatureFlag[], moduleCode: string): number =>
  flags.filter((f) => f.module_code === moduleCode && f.enabled).length;

/** Tên gọn của phân hệ (bỏ phần mô tả trong ngoặc): "Bán hàng (lead, cơ hội…)" → "Bán hàng". */
export const shortName = (name: string): string => name.replace(/\s*\(.*\)\s*$/, '');

/**
 * Phân hệ KHÔNG có công tắc ở QT-10 (anh chốt 23/11/2026, RA SOAT G13): «Cổng giáo viên» không có hàm hay màn nào kiểm công tắc này
 * (cổng giáo viên chạy theo vai trò, xem bài 125 pgTAP), nên bật tắt không có tác dụng. Danh mục MODULE giữ nguyên (tham số Cài đặt còn dùng nhóm này).
 */
export const MODULES_WITHOUT_SWITCH: readonly string[] = ['CONG_GIAO_VIEN'];

export const withSwitch = <T extends { code: string }>(modules: T[]): T[] =>
  modules.filter((m) => !MODULES_WITHOUT_SWITCH.includes(m.code));
