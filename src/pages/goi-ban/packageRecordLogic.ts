// Phần thuần của CH-02 Gói bán (bản ghi): chọn giá đang hiệu lực theo hình thức và dựng nhãn. Luật chính thức do DB kiểm (package_price_at, add_package_price).
export type PriceRow = {
  id: string;
  delivery_mode_code: string;
  unit_price: number | null;
  effective_from: string;
};

export const MODE_LABEL: Record<string, string> = { OFF: 'Offline', ONL: 'Online' };
export const MODE_CODES = ['OFF', 'ONL'];

/** Giá đang hiệu lực của từng hình thức tại ngày `today` (YYYY-MM-DD): dòng có ngày hiệu lực lớn nhất không sau `today`. Giá null = ngừng bán hình thức đó. */
export function currentPrices(rows: PriceRow[], today: string): Record<string, PriceRow | null> {
  const out: Record<string, PriceRow | null> = {};
  for (const mode of MODE_CODES) {
    const cands = rows
      .filter((r) => r.delivery_mode_code === mode && r.effective_from <= today)
      .sort((a, b) => (a.effective_from < b.effective_from ? 1 : -1));
    out[mode] = cands[0] ?? null;
  }
  return out;
}

/** Nhãn dòng lịch sử: «Từ 01/12/2026», thêm «chưa tới» khi ngày hiệu lực còn ở tương lai. */
export function priceStateLabel(r: PriceRow, today: string): string {
  if (r.effective_from > today) return 'Chưa tới ngày hiệu lực';
  return 'Đã hiệu lực';
}

/** Giá hiển thị: «1.200.000 đ» hoặc «Ngừng bán» (giá trống). */
export function priceText(price: number | null, money: (n: number) => string): string {
  return price === null ? 'Ngừng bán' : money(price);
}

/** Ô nhập giá (chữ số, chấm hoặc dấu phẩy ngăn nghìn) thành số nguyên dương; trống = null (ngừng bán); sai = undefined. */
export function parsePriceInput(text: string): number | null | undefined {
  const t = text.trim();
  if (t === '') return null;
  const digits = t.replace(/[.,\s]/g, '');
  if (!/^\d+$/.test(digits)) return undefined;
  const n = Number(digits);
  return n > 0 ? n : undefined;
}
