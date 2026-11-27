// Hàm thuần của bản in đơn hàng (BH-12, khuôn K13). Nhãn đóng khung theo đúng bốn tình trạng thật của đơn. Có kiểm thử.
import type { OrderRecord } from './orderTypes';

const STAMP: Record<OrderRecord['status_code'], string> = {
  NHAP: 'BẢN NHÁP',
  DA_TRINH: 'ĐÃ TRÌNH',
  DA_DUYET: 'ĐÃ DUYỆT',
  HUY: 'ĐÃ HUỶ',
};

export function orderStamp(status: OrderRecord['status_code']): string {
  return STAMP[status];
}
