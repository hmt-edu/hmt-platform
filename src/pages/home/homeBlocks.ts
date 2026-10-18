// Các khối của Trang chủ CRM (CHUNG-14). Khối nào hiện với ai do ma trận quyền và công tắc tính năng quyết định
// (không ghi theo tên vai trò). Phân hệ nào có dữ liệu thì thêm một dòng ở đây; khối chưa có dữ liệu thì chưa khai báo
// (bị ẩn), không hiện thẻ trống hay số giả.

export type HomeBlockId = 'appointments';

export type HomeBlock = {
  id: HomeBlockId;
  /** Phân hệ và hành động cần có trong ma trận quyền. */
  module: string;
  action: string;
  /** Công tắc tính năng (danh mục MODULE) của khối; tắt ở cơ sở thì ẩn. */
  feature?: string | undefined;
};

export const HOME_BLOCKS: HomeBlock[] = [
  { id: 'appointments', module: 'APPOINTMENT', action: 'XEM', feature: 'BAN_HANG' },
];

/** Khối nhìn thấy được với bộ quyền `can` và công tắc `featureOn`. Hàm thuần, có kiểm thử. */
export function visibleHomeBlocks(
  blocks: HomeBlock[],
  can: (module: string, action: string) => boolean,
  featureOn: (feature: string) => boolean,
): HomeBlock[] {
  return blocks.filter(
    (b) => can(b.module, b.action) && (b.feature === undefined || featureOn(b.feature)),
  );
}
