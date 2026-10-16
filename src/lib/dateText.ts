// Ngày nhập tay dạng dd/mm/yyyy, không phụ thuộc ngôn ngữ của trình duyệt (khác ô <input type="date">).
// Ngày không có múi giờ: dùng Date ở giờ địa phương lúc 00:00 và chuỗi ISO "yyyy-mm-dd" khi lưu.
const pad = (n: number) => String(n).padStart(2, '0');

/** 05/10/2026 */
export function formatDmy(date: Date | null | undefined): string {
  return date ? `${pad(date.getDate())}/${pad(date.getMonth() + 1)}/${date.getFullYear()}` : '';
}

/** Tự chèn dấu "/" khi gõ số: "05102026" thành "05/10/2026"; bỏ ký tự lạ; tối đa 8 chữ số. */
export function maskDmy(raw: string): string {
  const MAX_DIGITS = 8; // allow-number: ddmmyyyy
  const digits = raw.replace(/\D/g, '').slice(0, MAX_DIGITS);
  const day = digits.slice(0, 2);
  const month = digits.slice(2, 4);
  const year = digits.slice(4);
  return [day, month, year].filter((part, i) => part !== '' || i === 0).join('/');
}

/** Đọc "dd/mm/yyyy" chặt chẽ: sai định dạng hoặc ngày không có thật (31/02) thì trả null. */
export function parseDmy(text: string): Date | null {
  const match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(text.trim());
  if (!match) return null;
  const [day, month, year] = [Number(match[1]), Number(match[2]), Number(match[3])];
  const date = new Date(year, month - 1, day);
  const real =
    date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day;
  return real ? date : null;
}

/** "2026-10-05" (ngày lưu trong cơ sở dữ liệu) thành Date địa phương. */
export function fromIsoDate(iso: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!match) return null;
  return parseDmy(`${match[3]}/${match[2]}/${match[1]}`);
}

/** Date thành "2026-10-05" (không đổi múi giờ). */
export function toIsoDate(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}
