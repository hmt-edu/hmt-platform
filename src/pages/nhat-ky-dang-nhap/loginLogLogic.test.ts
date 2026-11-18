import { describe, expect, it } from 'vitest';
import { EMPTY_LOG_STATE } from './loginLogConfig';
import { buildExportFilters, buildLoginFilters, summarizeExportFilters } from './loginLogLogic';

describe('QT-12 nhật ký đăng nhập, xuất file', () => {
  it('đăng nhập: tìm, một kết quả, khoảng ngày', () => {
    const f = buildLoginFilters({
      ...EMPTY_LOG_STATE,
      search: ' an@x ',
      quick: { result: ['SAI_MAT_KHAU'] },
      conditions: [{ id: '1', field: 'at', op: 'from', value: '2026-11-10' }],
    });
    expect(f).toMatchObject({ q: 'an@x', result: 'SAI_MAT_KHAU' });
    expect(typeof f.from).toBe('string');
  });
  it('đăng nhập: chọn hai kết quả thì không lọc kết quả', () => {
    expect(
      buildLoginFilters({ ...EMPTY_LOG_STATE, quick: { result: ['SAI_MAT_KHAU', 'KHOA_TAM'] } }),
    ).toEqual({});
  });
  it('xuất file: phân hệ và ngày đến (loại trừ ngày kế)', () => {
    const f = buildExportFilters({
      ...EMPTY_LOG_STATE,
      conditions: [
        { id: '1', field: 'module', op: 'eq', value: 'LEAD' },
        { id: '2', field: 'at', op: 'to', value: '2026-11-10' },
      ],
    });
    expect(f.module).toBe('LEAD');
    expect(typeof f.to).toBe('string');
  });
  it('tóm tắt bộ lọc xuất', () => {
    expect(summarizeExportFilters({})).toBe('Không lọc');
    expect(summarizeExportFilters({ a: 1 })).toBe('a: 1');
  });
});
