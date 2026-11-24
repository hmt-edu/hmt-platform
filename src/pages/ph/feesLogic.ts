// PH-03 Học phí và giờ học (cổng Phụ huynh): kiểu dữ liệu của app.ph_hours_orders, app.ph_order và các hàm đổi chữ. Chỉ xem.
import { formatDate, formatMoney } from '../../lib/format';
import { hoursText, shortDate } from './homeLogic';

export type FeeOrder = {
  id: string;
  code: string;
  name: string | null;
  hours: number | null;
  status: string;
  total: number;
  paid: number;
  remaining: number;
};
export type FeeReceipt = { code: string; paid_on: string; amount: number; order_code?: string };
export type FeesData = {
  hours_left: number;
  projected_end: string | null;
  is_low: boolean;
  orders: FeeOrder[];
  receipts: FeeReceipt[];
};
export type OrderDetail = {
  code: string;
  name: string | null;
  hours: number | null;
  total: number;
  paid: number;
  remaining: number;
  status: 'DA_THU_DU' | 'CON_THIEU';
  receipts: FeeReceipt[];
};

/** «Đã thu đủ» hoặc «Còn thiếu 2.400.000 đ» cho dòng đơn. */
export function orderStatusText(order: Pick<FeeOrder, 'remaining'>): string {
  return order.remaining > 0 ? `Còn thiếu ${formatMoney(order.remaining)}` : 'Đã thu đủ';
}

/** Dòng phụ của đơn: «Đại số 9 · cơ bản A · 48 giờ» (bỏ phần thiếu). */
export function orderSubtitle(order: Pick<FeeOrder, 'name' | 'hours'>): string {
  const hours = order.hours === null ? null : `${order.hours} giờ`;
  return [order.name, hours].filter(Boolean).join(' · ');
}

/** «PT000518 · 10/11» */
export function receiptTitle(r: Pick<FeeReceipt, 'code' | 'paid_on'>): string {
  return `${r.code} · ${shortDate(r.paid_on)}`;
}

/** Ngày hết dự kiến đầy đủ (05/12/2026) hoặc «Chưa có lịch» khi chưa tính được. */
export function projectedEndText(value: string | null): string {
  return value ? formatDate(value) : 'Chưa có lịch';
}

/** Câu nhắc khi giờ còn thấp (khung PH03_gio_thap). */
export function lowHoursNotice(
  childName: string,
  data: Pick<FeesData, 'hours_left' | 'projected_end'>,
): string {
  const end = data.projected_end ? `, dự kiến hết ${shortDate(data.projected_end)}` : '';
  return `${childName} còn ${hoursText(data.hours_left)}${end}. Quý phụ huynh liên hệ cơ sở để đăng ký tiếp.`;
}
