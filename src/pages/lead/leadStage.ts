// Nhóm con chọn tay khi lead đổi giai đoạn (R-CRM-41). Danh sách lấy từ danh mục LEAD_SUBSTAGE, không viết cứng.
// C4D do hệ thống gắn khi tạo cơ hội nên không bao giờ nằm trong lựa chọn của người dùng (R-CRM-09).
import type { LeadCatalogs } from './useCatalogs';

export const SYSTEM_SUBSTAGE = 'C4D';

type Children = Pick<LeadCatalogs, 'childrenOf'>;

/** Nhóm con người dùng chọn được của một giai đoạn (rỗng = giai đoạn không có nhóm con, như C1). */
export function selectableSubstages(
  catalogs: Children,
  stage: string,
): { value: string; label: string }[] {
  return catalogs
    .childrenOf('LEAD_SUBSTAGE', 'LEAD_STAGE', stage)
    .filter((o) => o.value !== SYSTEM_SUBSTAGE);
}

/**
 * Hoàn tác về (giai đoạn, nhóm con) cũ có làm được không: C4D hệ thống gắn thì không; giai đoạn có nhóm con mà bản ghi cũ
 * chưa có nhóm con (dữ liệu trước luật R-CRM-41) thì hàm DB sẽ chặn nên không mời Hoàn tác.
 */
export function canRestore(catalogs: Children, stage: string, substage: string | null): boolean {
  if (substage === SYSTEM_SUBSTAGE) return false;
  return substage !== null || selectableSubstages(catalogs, stage).length === 0;
}
