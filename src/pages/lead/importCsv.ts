// Đọc file CSV nhập lead (TS-04) ở trình duyệt. Chấp nhận UTF-8 có hoặc không có BOM, dấu phân cách "," hoặc ";" (Excel tiếng
// Việt hay xuất ";"), ô đặt trong ngoặc kép có thể chứa dấu phân cách, xuống dòng và ngoặc kép đôi (""). Dòng đầu là tên cột.
// Không chạy công thức nào: ô chỉ là chữ.

export type CsvTable = {
  header: string[];
  /** Dòng dữ liệu (không gồm dòng tên cột); mỗi dòng có đúng bằng số cột của tên cột. */
  rows: string[][];
  /** Số dòng trong file của từng dòng dữ liệu (dòng 1 là tên cột), để báo lỗi đúng dòng. */
  lineNumbers: number[];
  delimiter: ',' | ';';
};

const BOM = '﻿';

/** Chọn dấu phân cách theo dòng đầu (ngoài ngoặc kép): nhiều hơn thì thắng, hoà thì ",". */
export function detectDelimiter(text: string): ',' | ';' {
  let commas = 0;
  let semis = 0;
  let quoted = false;
  for (const ch of text) {
    if (ch === '"') quoted = !quoted;
    else if (!quoted && (ch === '\n' || ch === '\r')) break;
    else if (!quoted && ch === ',') commas += 1;
    else if (!quoted && ch === ';') semis += 1;
  }
  return semis > commas ? ';' : ',';
}

/** Tách văn bản CSV thành các dòng ô. Dòng trống hẳn bị bỏ. Ném lỗi (tiếng Việt) khi ngoặc kép không đóng. */
export function parseCsv(input: string): CsvTable {
  const text = input.startsWith(BOM) ? input.slice(1) : input;
  const delimiter = detectDelimiter(text);
  const records: { cells: string[]; line: number }[] = [];
  let cells: string[] = [];
  let cell = '';
  let quoted = false;
  let line = 1;
  let startLine = 1;
  const pushCell = () => {
    cells.push(cell);
    cell = '';
  };
  const pushRecord = () => {
    pushCell();
    if (cells.some((c) => c.trim() !== '')) records.push({ cells, line: startLine });
    cells = [];
  };
  for (let i = 0; i < text.length; i += 1) {
    const ch = text.charAt(i);
    if (quoted) {
      if (ch === '"') {
        if (text.charAt(i + 1) === '"') {
          cell += '"';
          i += 1;
        } else quoted = false;
      } else {
        if (ch === '\n') line += 1;
        cell += ch;
      }
    } else if (ch === '"' && cell === '') quoted = true;
    else if (ch === delimiter) pushCell();
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text.charAt(i + 1) === '\n') i += 1;
      pushRecord();
      line += 1;
      startLine = line;
    } else cell += ch;
  }
  if (quoted) throw new Error('File CSV có ô chưa đóng ngoặc kép. Kiểm tra lại file rồi chọn lại.');
  if (cell !== '' || cells.length > 0) pushRecord();

  const first = records[0];
  if (!first) throw new Error('File trống: chưa có dòng nào.');
  const header = first.cells.map((c) => c.trim());
  const width = header.length;
  const body = records.slice(1);
  return {
    header,
    rows: body.map((r) => Array.from({ length: width }, (_, i) => (r.cells[i] ?? '').trim())),
    lineNumbers: body.map((r) => r.line),
    delimiter,
  };
}
