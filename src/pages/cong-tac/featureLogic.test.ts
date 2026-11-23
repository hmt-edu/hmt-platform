// QT-10: không có dòng công tắc là Tắt; đếm cơ sở đang bật; tên gọn của phân hệ.
import { describe, expect, it } from 'vitest';
import { enabledCount, isEnabled, shortName, type FeatureFlag } from './featureLogic';

const flags: FeatureFlag[] = [
  { module_code: 'BAN_HANG', branch_id: 'cs5', enabled: true },
  { module_code: 'BAN_HANG', branch_id: 'cs1', enabled: false },
  { module_code: 'HOC_TAP', branch_id: 'cs5', enabled: true },
];

describe('QT-10 công tắc tính năng', () => {
  it('không có dòng công tắc thì Tắt (mặc định)', () => {
    expect(isEnabled(flags, 'BAN_HANG', 'cs2')).toBe(false);
    expect(isEnabled(flags, 'BAO_CAO', 'cs5')).toBe(false);
  });
  it('dòng có enabled = true thì Bật, enabled = false thì Tắt', () => {
    expect(isEnabled(flags, 'BAN_HANG', 'cs5')).toBe(true);
    expect(isEnabled(flags, 'BAN_HANG', 'cs1')).toBe(false);
  });
  it('đếm số cơ sở đang bật của một phân hệ', () => {
    expect(enabledCount(flags, 'BAN_HANG')).toBe(1);
    expect(enabledCount(flags, 'BAO_CAO')).toBe(0);
  });
  it('tên gọn bỏ phần mô tả trong ngoặc', () => {
    expect(shortName('Bán hàng (lead, cơ hội, test, báo giá)')).toBe('Bán hàng');
    expect(shortName('Cổng giáo viên')).toBe('Cổng giáo viên');
  });
});

import { withSwitch } from './featureLogic';

describe('withSwitch: phân hệ không có công tắc (QT-10)', () => {
  it('bỏ «Cổng giáo viên», giữ các phân hệ khác theo thứ tự', () => {
    const rows = [
      { code: 'BAN_HANG', name: 'Bán hàng' },
      { code: 'CONG_GIAO_VIEN', name: 'Cổng giáo viên' },
      { code: 'HOC_TAP', name: 'Học tập' },
    ];
    expect(withSwitch(rows).map((m) => m.code)).toEqual(['BAN_HANG', 'HOC_TAP']);
  });
});
