// Hàm thuần của bản ghi Báo giá (BH-02): các bước hiện trên thanh tình trạng, nhãn đơn vị, chữ chiết khấu. Có kiểm thử.
import type { QuotationLine, QuotationRecord } from './quoteTypes';

/** Các bước hiện trên thanh tình trạng: luồng thường Nháp, Đã gửi, Đã chuyển đơn; Từ chối và Huỷ thay bước cuối. */
export function statusSteps(record: Pick<QuotationRecord, 'status_code'>): string[] {
  if (record.status_code === 'TU_CHOI') return ['NHAP', 'DA_GUI', 'TU_CHOI'];
  if (record.status_code === 'HUY') return ['NHAP', 'HUY'];
  return ['NHAP', 'DA_GUI', 'DA_CHUYEN_DON'];
}

/** Đơn vị của số lượng theo loại gói (Đ101): giờ, tháng, bộ. */
export const UNIT_LABEL: Record<QuotationLine['unit_code'], string> = {
  GIO: 'giờ',
  THANG: 'tháng',
  BO: 'bộ',
};

/** Chữ chiết khấu của một dòng: "10%" kèm tên chính sách; giờ tặng ghi riêng; không có chiết khấu thì rỗng. */
export function discountText(line: QuotationLine): string {
  if (line.line_kind === 'GIFT') return line.gift_policy_name ?? 'Quà tặng';
  const parts: string[] = [];
  if (line.discount_percent > 0) parts.push(`${String(line.discount_percent).replace('.', ',')}%`);
  if (line.gifted_quantity > 0)
    parts.push(`tặng ${String(line.gifted_quantity).replace('.', ',')} giờ`);
  return parts.join(' + ');
}

/** Số lượng viết gọn: bỏ phần thập phân .00. */
export function quantityText(line: Pick<QuotationLine, 'quantity' | 'unit_code'>): string {
  return `${String(line.quantity).replace(/\.0+$/, '').replace('.', ',')} ${UNIT_LABEL[line.unit_code]}`;
}
