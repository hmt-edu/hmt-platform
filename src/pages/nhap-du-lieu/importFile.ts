// Đọc file CSV của màn Nhập thành các hàng gửi máy chủ, và dựng file "dòng lỗi" để Admin sửa rồi nạp lại.
// Không chạy công thức, không gửi file đi đâu ngoài các hàng đã chọn cột.
import { toCsv } from '../lead/csv';
import type { CsvTable } from '../lead/importCsv';
import type { ImportKindConfig } from './importKinds';

export type ImportRowStatus = 'HOP_LE' | 'TRUNG' | 'LOI';

export type ImportLine = {
  row: number;
  label: string;
  initial: string | null;
  status: ImportRowStatus;
  code: string | null;
  message: string | null;
  warnings?: string[];
};

export type ImportResult = {
  mode: 'XEM_TRUOC' | 'NHAP';
  kind: string;
  total: number;
  imported: number;
  duplicates: number;
  errors: number;
  rows: ImportLine[];
  /** Chỉ Người dùng, chỉ lần nạp thật: mật khẩu tạm trả MỘT lần. */
  passwords?: { username: string; password: string }[];
};

export type BuiltRows = {
  rows: Record<string, string | number>[];
  /** Cột bắt buộc không có trong file. */
  missing: string[];
  /** Cột trong file không thuộc loại này (bị bỏ qua). */
  ignored: string[];
};

/** Tên cột chuẩn hoá: bỏ khoảng trắng hai đầu, chữ thường. */
export function normalizeHeader(name: string): string {
  return name.trim().toLowerCase();
}

/** File dòng lỗi do màn này xuất thêm dấu nháy trước ô bắt đầu bằng = + - @ (chống công thức Excel); đọc lại thì bỏ dấu nháy đó (ví dụ SĐT +84…). */
function unquoteFormula(value: string): string {
  return /^'[=+\-@]/.test(value) ? value.slice(1) : value;
}

/** Ghép dòng dữ liệu với tên cột của loại nạp; mỗi hàng kèm `row` là số dòng trong file (dòng 1 là tên cột). */
export function buildRows(table: CsvTable, config: ImportKindConfig): BuiltRows {
  const names = table.header.map(normalizeHeader);
  const known = new Set(config.columns);
  const indexOf = new Map<string, number>();
  names.forEach((n, i) => {
    if (known.has(n) && !indexOf.has(n)) indexOf.set(n, i);
  });
  const missing = config.required.filter((c) => !indexOf.has(c));
  const ignored = table.header.filter((_h, i) => {
    const n = names[i] ?? '';
    return n !== '' && (!known.has(n) || indexOf.get(n) !== i);
  });
  const rows = table.rows.map((cells, r) => {
    const out: Record<string, string | number> = { row: table.lineNumbers[r] ?? r + 2 };
    for (const [column, i] of indexOf) out[column] = unquoteFormula((cells[i] ?? '').trim());
    return out;
  });
  return { rows, missing, ignored };
}

/**
 * File CSV dòng lỗi: các dòng Lỗi (và Trùng) của file gốc, giữ nguyên các cột đã nạp, thêm cột ket_qua và ly_do.
 * Chỉ dùng dữ liệu đã có trong trình duyệt của Admin; không gửi đi đâu.
 */
export function errorRowsCsv(
  table: CsvTable,
  config: ImportKindConfig,
  result: ImportResult,
  include: ImportRowStatus[] = ['LOI', 'TRUNG'],
): string {
  const names = table.header.map(normalizeHeader);
  const columns = config.columns.filter((c) => names.includes(c));
  const byLine = new Map<number, string[]>();
  table.lineNumbers.forEach((line, i) => byLine.set(line, table.rows[i] ?? []));
  const lines = result.rows
    .filter((r) => include.includes(r.status))
    .map((r) => {
      const cells = byLine.get(r.row) ?? [];
      const out: Record<string, string | number> = { dong: r.row };
      for (const c of columns) out[c] = cells[names.indexOf(c)] ?? '';
      out.ket_qua = r.status === 'LOI' ? 'Lỗi' : r.status === 'TRUNG' ? 'Trùng' : 'Hợp lệ';
      out.ly_do = [r.message ?? '', ...(r.warnings ?? [])].filter(Boolean).join(' | ');
      return out;
    });
  return toCsv(lines, [
    { key: 'dong', label: 'dong' },
    ...columns.map((c) => ({ key: c, label: c })),
    { key: 'ket_qua', label: 'ket_qua' },
    { key: 'ly_do', label: 'ly_do' },
  ]);
}

/** File mật khẩu tạm của lần nạp Người dùng: tên đăng nhập và mật khẩu (giao từng người). */
export function passwordsCsv(passwords: { username: string; password: string }[]): string {
  return toCsv(passwords, [
    { key: 'username', label: 'ten_dang_nhap' },
    { key: 'password', label: 'mat_khau_tam' },
  ]);
}
