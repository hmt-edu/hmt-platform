// Phần thuần của màn Bảng giá (CH-03, theo gói): ngày, đơn vị giá, ghép dòng giá gửi hàm DB. Luật chính thức do DB kiểm (R-TIEN-10, 14, 15).

export type PriceState = 'CO_GIA' | 'CHUA_CO_GIA' | 'KHONG_BAN';
export type PriceCell = { state: PriceState; price: number | null; effective_from: string | null };

/** Ngày dạng yyyy-mm-dd theo giờ địa phương (giờ máy người dùng ở Việt Nam). */
export function toDateKey(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0'); // allow-number: hai chữ số
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** Đơn vị của giá: dịch vụ theo tháng, tài liệu theo bộ, còn lại theo giờ (Đ101; hàm DB app.package_unit là gốc, đây chỉ là chữ hiển thị). */
export function priceUnit(packageType: string): string {
  if (packageType === 'DV') return 'tháng';
  if (packageType === 'TL') return 'bộ';
  return 'giờ';
}

/** Gói không có giá online (R-TIEN-15). */
export const hasNoOnline = (packageType: string) => packageType === 'DV' || packageType === 'TL';

/** Giá nhập ở một ô: số đồng, 'none' = không bán hình thức đó (dòng giá để trống), null = không thêm dòng. */
export type PriceInput = number | 'none' | null;

export type PriceItem = { package_id: string; mode: 'OFF' | 'ONL'; unit_price: number | null };

/**
 * Ghép các dòng giá gửi hàm add_package_prices: mỗi gói đã chọn lấy giá riêng của gói nếu có, không thì giá chung; ô null thì bỏ qua.
 * Gói dịch vụ, tài liệu không có online nên bỏ ô online.
 */
export function buildPriceItems(
  selected: { id: string; type: string }[],
  common: { off: PriceInput; onl: PriceInput },
  overrides: Record<string, { off?: PriceInput; onl?: PriceInput }>,
): PriceItem[] {
  const items: PriceItem[] = [];
  const push = (id: string, mode: 'OFF' | 'ONL', v: PriceInput) => {
    if (v === null) return;
    items.push({ package_id: id, mode, unit_price: v === 'none' ? null : v });
  };
  for (const s of selected) {
    const o = overrides[s.id];
    push(s.id, 'OFF', o && o.off !== undefined ? o.off : common.off);
    if (!hasNoOnline(s.type)) push(s.id, 'ONL', o && o.onl !== undefined ? o.onl : common.onl);
  }
  return items;
}
