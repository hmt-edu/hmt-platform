import { describe, expect, it } from 'vitest';
import { canRestore, selectableSubstages } from './leadStage';

const catalogs = {
  childrenOf: (_c: string, _p: string, stage: string | null | undefined) =>
    stage === 'C4'
      ? [
          { value: 'C4A', label: 'Cần gửi thêm thông tin' },
          { value: 'C4C', label: 'Đủ điều kiện tạo cơ hội' },
          { value: 'C4D', label: 'Tạo cơ hội thành công' },
        ]
      : stage === 'C2'
        ? [{ value: 'C2A', label: 'Không nghe máy' }]
        : [],
};

describe('nhóm con chọn tay của lead (R-CRM-41)', () => {
  it('C4 chọn được C4A, C4C nhưng không có C4D (hệ thống gắn)', () => {
    expect(selectableSubstages(catalogs, 'C4').map((o) => o.value)).toEqual(['C4A', 'C4C']);
  });
  it('C1 không có nhóm con để chọn', () => {
    expect(selectableSubstages(catalogs, 'C1')).toEqual([]);
  });
  it('Hoàn tác: C4D không, giai đoạn có nhóm con mà cũ trống không, còn lại được', () => {
    expect(canRestore(catalogs, 'C4', 'C4D')).toBe(false);
    expect(canRestore(catalogs, 'C2', null)).toBe(false);
    expect(canRestore(catalogs, 'C2', 'C2A')).toBe(true);
    expect(canRestore(catalogs, 'C1', null)).toBe(true);
  });
});
