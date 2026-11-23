// Công tắc tính năng của phiếu nghiệp vụ (CLAUDE.md: kiểm cả ở giao diện lẫn hàm DB). Hàm DB (app.require_feature) kiểm theo CƠ SỞ CỦA PHIẾU/TICKET:
// AFTERSALE cho mọi thao tác phiếu; thêm phân hệ riêng khi thực hiện Bảo lưu, Chuyển lớp, Dừng học, Hoàn phí. Giao diện khoá nút sớm kèm câu rõ ràng,
// không để người dùng đi tới bước cuối mới gặp lỗi.
import { TASK_TYPE_LABEL } from './phieuTypes';

/** Phân hệ riêng của từng loại phiếu (ngoài AFTERSALE). Loại không có ở đây chỉ cần AFTERSALE. */
export const TASK_TYPE_FEATURE: Record<string, string> = {
  BAO_LUU: 'BAO_LUU',
  CHUYEN_LOP: 'CHUYEN_LOP',
  DUNG_HOC: 'DUNG_HOC',
  HOAN_PHI: 'HOAN_PHI',
};

/** Câu hiện khi tính năng tắt; null khi cả hai công tắc đều bật ở cơ sở của phiếu. */
export function taskFeatureOffMessage(
  taskType: string,
  featureOnAt: (feature: string, branchCode: string | null) => boolean,
  branchCode: string | null,
): string | null {
  if (!featureOnAt('AFTERSALE', branchCode))
    return 'Tính năng Chăm sóc khách hàng chưa bật ở cơ sở này.';
  const own = TASK_TYPE_FEATURE[taskType];
  if (own !== undefined && !featureOnAt(own, branchCode))
    return `Tính năng ${TASK_TYPE_LABEL[taskType] ?? taskType} chưa bật ở cơ sở này.`;
  return null;
}
