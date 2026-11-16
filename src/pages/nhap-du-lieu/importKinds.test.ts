import { describe, expect, it } from 'vitest';
import { IMPORT_KIND_ROWS, IMPORT_KINDS, kindConfig, sampleCsvText } from './importKinds';

describe('Bảng chọn loại QT-18 (Q-209)', () => {
  it('đủ 8 loại theo thứ tự nạp đã chốt', () => {
    expect(IMPORT_KIND_ROWS.map((r) => r.title)).toEqual([
      'Người dùng',
      'Lớp',
      'Phụ huynh',
      'Học sinh',
      'Ghi danh',
      'Số dư',
      'Cơ hội',
      'Phiếu test',
    ]);
  });

  it('loại chưa có hàm nạp là "Sắp có" (kind null), loại có hàm trỏ đúng cấu hình', () => {
    const soon = IMPORT_KIND_ROWS.filter((r) => r.kind === null).map((r) => r.title);
    expect(soon).toEqual([]);
    for (const row of IMPORT_KIND_ROWS) {
      if (row.kind) expect(kindConfig(row.kind).title).toBe(row.title);
    }
    expect(IMPORT_KIND_ROWS.filter((r) => r.kind !== null)).toHaveLength(IMPORT_KINDS.length);
  });
});

describe('Loại đào tạo (D1e)', () => {
  it('Lớp và Ghi danh gọi hàm nạp đào tạo; chỉ Ghi danh chặn cả loại khi còn lỗi', () => {
    expect(kindConfig('LOP').training).toBe(true);
    expect(kindConfig('GHI_DANH').training).toBe(true);
    expect(kindConfig('LOP').blockOnError).toBeFalsy();
    expect(kindConfig('GHI_DANH').blockOnError).toBe(true);
    expect(kindConfig('PHIEU_TEST').training).toBe(true);
    expect(kindConfig('PHIEU_TEST').blockOnError).toBeFalsy();
    expect(kindConfig('SO_DU').training).toBe(true);
    expect(kindConfig('SO_DU').blockOnError).toBe(true);
    expect(kindConfig('PHU_HUYNH').training).toBeFalsy();
  });
});

describe('Tải file mẫu', () => {
  it('có dòng tên cột đúng cột hàm nạp nhận và một dòng ví dụ giả, không trùng cột', () => {
    for (const config of IMPORT_KINDS) {
      const [header, example, rest] = sampleCsvText(config).split('\n');
      const cols = (header ?? '').split(',');
      expect(new Set(cols).size).toBe(cols.length);
      for (const required of config.required) expect(cols).toContain(required);
      expect((example ?? '').split(',')).toHaveLength(cols.length);
      expect(rest).toBe('');
    }
  });

  it('không chứa số điện thoại thật: chỉ số mẫu 0900000001', () => {
    const text = IMPORT_KINDS.map((c) => sampleCsvText(c)).join('\n');
    const phones = text.match(/(?<![0-9])0[0-9]{9}(?![0-9])/g) ?? [];
    expect(new Set(phones)).toEqual(new Set(['0900000001']));
  });
});
