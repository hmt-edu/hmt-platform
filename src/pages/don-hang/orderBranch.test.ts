import { describe, expect, it } from 'vitest';
import { intSettingQuery } from '../../lib/db';
import type { SupabaseClient } from '@supabase/supabase-js';
import { branchLabel } from './orderBranch';

describe('Đơn tạo từ báo giá: nhãn cơ sở (C-23-24)', () => {
  it('có tên cơ sở thì hiện «mã tên», cùng kiểu các màn khác', () => {
    expect(branchLabel('CS5', [{ code: 'CS5', name: 'Mỹ Đình' }])).toBe('CS5 Mỹ Đình');
  });
  it('chưa có tên thì hiện mã', () => {
    expect(branchLabel('CS5', [])).toBe('CS5');
  });
});

describe('Hạn hiệu lực báo giá đọc theo cơ sở (C-23-24)', () => {
  const db = {} as SupabaseClient;
  it('khoá truy vấn tách theo cơ sở để không dùng nhầm số chung', () => {
    expect(intSettingQuery(db, 'quotation_validity_days', 'b1').queryKey).toEqual([
      'setting-int',
      'quotation_validity_days',
      'b1',
    ]);
    expect(intSettingQuery(db, 'quotation_validity_days').queryKey).toEqual([
      'setting-int',
      'quotation_validity_days',
    ]);
  });
});
