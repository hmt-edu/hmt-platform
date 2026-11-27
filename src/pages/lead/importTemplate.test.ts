import { describe, expect, it } from 'vitest';
import { parseCsv } from './importCsv';
import { autoMap, missingRequired } from './importMapping';
import { dropSampleRows, leadTemplateCsv } from './importTemplate';

const sources = [
  { name: 'Nguồn A', channels: ['Kênh 1', 'Kênh 2'] },
  { name: 'Nguồn B', channels: [] },
];

describe('File mẫu nhập lead', () => {
  const text = leadTemplateCsv(sources);

  it('có BOM, mọi cột được tự ghép, đủ cột bắt buộc', () => {
    expect(text.charCodeAt(0)).toBe(0xfeff);
    const table = parseCsv(text);
    const mapping = autoMap(table.header);
    expect(mapping).not.toContain(null);
    expect(missingRequired(mapping)).toEqual([]);
    expect(table.header).toContain('SĐT *');
  });

  it('liệt kê nguồn, kênh đang dùng; mọi dòng [MẪU] bị bỏ khi nhập', () => {
    const table = parseCsv(text);
    expect(table.rows).toHaveLength(4);
    expect(text).toContain('Kênh 2');
    expect(text).toContain('Nguồn B');
    expect(dropSampleRows(table).rows).toEqual([]);
  });

  it('giữ dòng thật và đúng số dòng trong file', () => {
    const table = parseCsv(`${text}Chị Thử,0900000002,,,,,,\r\n`);
    const kept = dropSampleRows(table);
    expect(kept.rows.map((r) => r[0])).toEqual(['Chị Thử']);
    expect(kept.lineNumbers).toEqual([6]);
  });
});
