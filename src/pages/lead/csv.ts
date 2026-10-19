// Xuất file CSV ở trình duyệt từ kết quả export_leads. Excel đọc được tiếng Việt (có BOM UTF-8); ô bắt đầu bằng
// = + - @ được thêm dấu nháy để Excel không hiểu thành công thức.
import type { ExportRow } from './leadTypes';

const FORMULA_START = /^[=+\-@\t\r]/;
const BOM = '﻿';

export function csvCell(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return '';
  let text = String(value);
  if (FORMULA_START.test(text)) text = `'${text}`;
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/** CSV với dòng tiêu đề; `columns` là cặp (khoá của hàng, tên cột hiện trong file). */
export function toCsv(rows: ExportRow[], columns: { key: string; label: string }[]): string {
  const lines = [
    columns.map((c) => csvCell(c.label)).join(','),
    ...rows.map((row) => columns.map((c) => csvCell(row[c.key])).join(',')),
  ];
  return `${BOM}${lines.join('\r\n')}\r\n`;
}

/** Tải một chuỗi về máy thành file (không gửi đi đâu). */
export function downloadText(
  filename: string,
  text: string,
  mime = 'text/csv;charset=utf-8',
): void {
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}
