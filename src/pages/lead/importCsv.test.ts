import { describe, expect, it } from 'vitest';
import { detectDelimiter, parseCsv } from './importCsv';

describe('parseCsv', () => {
  it('đọc dấu phẩy, bỏ BOM, đánh số dòng theo file', () => {
    const t = parseCsv('﻿Họ tên,SĐT\nLê Thị Hằng,0912345678\nNguyễn Văn Sơn,0987111222\n');
    expect(t.header).toEqual(['Họ tên', 'SĐT']);
    expect(t.rows).toEqual([
      ['Lê Thị Hằng', '0912345678'],
      ['Nguyễn Văn Sơn', '0987111222'],
    ]);
    expect(t.lineNumbers).toEqual([2, 3]);
    expect(t.delimiter).toBe(',');
  });
  it('đọc dấu chấm phẩy của Excel tiếng Việt', () => {
    const t = parseCsv('Họ tên;SĐT;Ghi chú\nAnh Tú;0903000124;Hỏi lớp 9, buổi tối\n');
    expect(t.delimiter).toBe(';');
    expect(t.rows[0]).toEqual(['Anh Tú', '0903000124', 'Hỏi lớp 9, buổi tối']);
  });
  it('ô trong ngoặc kép chứa dấu phân cách, ngoặc kép đôi và xuống dòng', () => {
    const t = parseCsv('a,b\n"x, y","nói ""có""\ndòng hai"\nz,w\n');
    expect(t.rows[0]).toEqual(['x, y', 'nói "có"\ndòng hai']);
    // Dòng sau ô có xuống dòng vẫn đếm đúng số dòng trong file.
    expect(t.lineNumbers).toEqual([2, 4]);
    expect(t.rows[1]).toEqual(['z', 'w']);
  });
  it('xuống dòng kiểu Windows, bỏ dòng trống, bù ô thiếu', () => {
    const t = parseCsv('a,b,c\r\n1,2\r\n\r\n3,4,5\r\n');
    expect(t.rows).toEqual([
      ['1', '2', ''],
      ['3', '4', '5'],
    ]);
  });
  it('ngoặc kép không đóng thì báo lỗi tiếng Việt', () => {
    expect(() => parseCsv('a,b\n"x,y\n')).toThrow(/chưa đóng ngoặc kép/);
  });
  it('file trống thì báo lỗi', () => {
    expect(() => parseCsv('﻿')).toThrow(/File trống/);
  });
  it('ô bắt đầu bằng = + - @ chỉ là chữ (không có công thức nào được chạy)', () => {
    const t = parseCsv('a\n=1+1\n');
    expect(t.rows[0]).toEqual(['=1+1']);
  });
});

describe('detectDelimiter', () => {
  it('chỉ đếm dấu ngoài ngoặc kép ở dòng đầu', () => {
    expect(detectDelimiter('"a;b;c",d\n')).toBe(',');
    expect(detectDelimiter('a;b;c\n')).toBe(';');
    expect(detectDelimiter('abc\n')).toBe(',');
  });
});
