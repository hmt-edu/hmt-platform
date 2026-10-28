// Hàm thuần của bản in báo giá (BH-03, khuôn K13): nhãn trạng thái, chữ quá hạn, che số điện thoại. Có kiểm thử. Không tính tiền (R-TIEN-13).
import type { QuotationRecord } from './quoteTypes';

/** Nhãn đóng khung theo tình trạng (Đ273): Nháp, Từ chối, Huỷ có nhãn; Đã gửi không có. */
export function printStamp(status: QuotationRecord['status_code']): string | null {
  if (status === 'NHAP') return 'BẢN NHÁP';
  if (status === 'TU_CHOI') return 'ĐÃ TỪ CHỐI';
  if (status === 'HUY') return 'ĐÃ HUỶ';
  return null;
}

/** "Đã quá hạn N ngày" chỉ khi quá hạn (Đ273); trong hạn hoặc chưa có hạn thì rỗng. */
export function overdueText(days: number | null): string | null {
  return days !== null && days > 0 ? `Đã quá hạn ${days} ngày` : null;
}

/** "0912000345" → "0912 *** 345" như canvas BH03_in; số khác dạng giữ nguyên. */
export function maskPhone(phone: string): string {
  const match = /^(\d{4})\d{3}(\d{3})$/.exec(phone);
  return match ? `${match[1]} *** ${match[2]}` : phone;
}

/** Số giờ mua/tặng viết gọn: bỏ .00, dấu phẩy thập phân. */
export function hoursText(value: number): string {
  return String(value).replace(/\.0+$/, '').replace('.', ',');
}
