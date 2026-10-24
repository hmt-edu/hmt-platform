import { describe, expect, it } from 'vitest';
import { parseCsv } from './importCsv';
import {
  autoMap,
  buildImportRows,
  importSummary,
  missingRequired,
  setColumnField,
  unmappedColumns,
  type CatalogLookup,
} from './importMapping';

const lookup: CatalogLookup = {
  findSource: (t) =>
    t.toLowerCase() === 'website' ? { code: 'WEBSITE', typeCode: 'MARKETING' } : undefined,
  findChannel: (_s, t) => (t.toLowerCase() === 'form' ? 'WEBSITE_FORM' : undefined),
};

describe('autoMap', () => {
  it('đoán cột theo tên, không phân biệt hoa thường và dấu', () => {
    const m = autoMap([
      'Họ tên phụ huynh',
      'Số điện thoại',
      'Tên học sinh',
      'Nguồn',
      'Kênh',
      'Ghi chú KH',
      'Mã nội bộ',
    ]);
    expect(m).toEqual([
      'parent_name',
      'parent_phone',
      'student_name',
      'source',
      'channel',
      'need',
      null,
    ]);
  });
  it('một trường chỉ nhận cột đầu tiên khớp', () => {
    expect(autoMap(['SĐT', 'Số điện thoại'])).toEqual(['parent_phone', null]);
  });
});

describe('ghép cột', () => {
  it('chọn trường đang dùng ở cột khác thì cột kia thành chưa ghép', () => {
    expect(setColumnField(['parent_name', 'parent_phone'], 1, 'parent_name')).toEqual([
      null,
      'parent_name',
    ]);
  });
  it('bỏ ghép một cột bằng null', () => {
    expect(setColumnField(['parent_name', 'parent_phone'], 0, null)).toEqual([
      null,
      'parent_phone',
    ]);
  });
  it('báo trường bắt buộc còn thiếu và cột chưa ghép', () => {
    expect(missingRequired(['parent_name', null])).toEqual(['SĐT']);
    expect(missingRequired(['parent_name', 'parent_phone'])).toEqual([]);
    expect(unmappedColumns(['A', 'B', 'C'], ['parent_name', null, 'need'])).toEqual(['B']);
  });
});

describe('buildImportRows', () => {
  const table = parseCsv(
    'Họ tên;SĐT;Nguồn;Kênh;Ghi chú;Năm sinh\nChị A;0912345678;Website;Form;Hỏi lớp 9;2012\nAnh B;0987111222;Tiktok;;;\n',
  );
  const mapping = autoMap(table.header);
  const rows = buildImportRows(table, mapping, lookup);
  it('có số dòng trong file và đổi tên nguồn, kênh sang mã', () => {
    expect(rows[0]).toEqual({
      row: 2,
      parent_name: 'Chị A',
      parent_phone: '0912345678',
      need: 'Hỏi lớp 9',
      student_birth_year: '2012',
      source_code: 'WEBSITE',
      source_type_code: 'MARKETING',
      channel_code: 'WEBSITE_FORM',
    });
  });
  it('nguồn không có trong danh mục thì gửi nguyên chữ để hàm báo lỗi, bỏ ô trống', () => {
    expect(rows[1]).toEqual({
      row: 3,
      parent_name: 'Anh B',
      parent_phone: '0987111222',
      source_code: 'Tiktok',
    });
  });
});

describe('importSummary', () => {
  it('chỉ nêu dòng bỏ qua khi có', () => {
    expect(importSummary({ imported: 3, duplicates: 0, errors: 0 })).toBe('Đã nhập 3 lead.');
    expect(importSummary({ imported: 2, duplicates: 1, errors: 2 })).toBe(
      'Đã nhập 2 lead. Bỏ qua 1 dòng trùng SĐT, 2 dòng lỗi.',
    );
  });
});
