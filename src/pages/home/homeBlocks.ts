// Các khối của Trang chủ CRM (CHUNG-14). Khối nào hiện với ai do ma trận quyền và công tắc tính năng quyết định
// (không ghi theo tên vai trò). Phân hệ nào có dữ liệu thì thêm một dòng ở đây; khối chưa có dữ liệu thì chưa khai báo
// (bị ẩn), không hiện thẻ trống hay số giả.

export type HomeBlockId =
  | 'appointments'
  | 'approvals'
  | 'sessions'
  | 'debt'
  | 'classesPending'
  | 'tickets'
  | 'sessionsToday';

export type HomeBlock = {
  id: HomeBlockId;
  /** Phân hệ và hành động cần có trong ma trận quyền; `module: '*'` = có hành động đó ở một phân hệ bất kỳ (như mục «Việc chờ tôi duyệt»). */
  module: string;
  action: string;
  /** Công tắc tính năng (danh mục MODULE) của khối; tắt ở cơ sở thì ẩn. */
  feature?: string | undefined;
};

export const HOME_BLOCKS: HomeBlock[] = [
  { id: 'appointments', module: 'APPOINTMENT', action: 'XEM', feature: 'BAN_HANG' },
  // Khối việc theo vai trò (D-23-15, giai đoạn 1): dùng hàm đọc có sẵn của màn nguồn; mỗi khối hiện theo quyền của chính màn nguồn.
  { id: 'approvals', module: '*', action: 'DUYET' },
  { id: 'sessions', module: 'SESSION', action: 'XEM', feature: 'VAN_HANH_LOP' },
  { id: 'classesPending', module: 'CLASS', action: 'DUYET', feature: 'VAN_HANH_LOP' },
  { id: 'tickets', module: 'TICKET', action: 'XEM' },
  { id: 'sessionsToday', module: 'SESSION', action: 'XEM', feature: 'DIEM_DANH_TRONG_NGAY' },
  { id: 'debt', module: 'SALES_ORDER', action: 'XEM', feature: 'BAN_HANG' },
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
