// Phần thuần của hộp Duyệt đơn (BH-07): dòng vượt trần, chữ trần chiết khấu. Giao diện không tính trần: cờ over_cap và các % do máy chủ trả.
import type { OrderLine } from './orderTypes';

export type OverCapLine = {
  line_no: number;
  student_name: string | null;
  total_percent_text: string;
};

/** Tổng % hiển thị: bỏ số 0 thừa sau dấu phẩy, dùng dấu phẩy thập phân (8,3). */
export function percentText(value: number): string {
  return String(Math.round(value * 10) / 10).replace('.', ','); // allow-number: làm tròn một chữ số thập phân để hiển thị
}

/** Các dòng máy chủ đánh dấu vượt trần, kèm tổng % cộng dồn (chiết khấu + giờ tặng quy ra %). */
export function overCapLines(lines: OrderLine[]): OverCapLine[] {
  return lines
    .filter((l) => l.over_cap)
    .map((l) => ({
      line_no: l.line_no,
      student_name: l.student_name,
      total_percent_text: percentText(l.discount_percent + l.gift_percent),
    }));
}

/** "20%" từ tham số discount_total_cap_percent; chưa tải xong thì chữ chung để không viết cứng số. */
export function capPercentText(cap: number | null): string {
  return cap === null ? 'đã cấu hình' : `${cap}%`;
}

/** Câu dưới bảng Đơn đang sửa (khung BH05_chip_*, R-V2-11): giờ tặng quy ra % tính vào trần; N đọc từ tham số. */
export function orderCapText(cap: number | null): string {
  return `Ưu đãi cộng dồn; giờ tặng quy ra % tính vào trần ${capPercentText(cap)}. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được.`;
}

/** Làm tròn một chữ số thập phân để hiện (8,33 thành 8,3 như khung BH05_nhap_xem); không dùng để tính tiền. */
export function roundOne(value: number): number {
  return Math.round(value * 10) / 10; // allow-number: làm tròn hiện một chữ số thập phân
}

/**
 * Cột "Tổng %" của Đơn Xem (khung BH05_nhap_xem): chiết khấu % cộng giờ tặng quy ra %, đúng số cộng dồn tính vào trần (R-V2-11).
 * Hai số do máy chủ trả (discount_percent, gift_percent); rỗng khi không có chiết khấu hay là dòng quà tặng.
 */
export function totalPercentText(
  line: Pick<OrderLine, 'line_kind' | 'discount_percent' | 'gift_percent'>,
): string {
  if (line.line_kind === 'GIFT') return '';
  const total = line.discount_percent + line.gift_percent;
  return total > 0 ? `${percentText(roundOne(total))}%` : '';
}
