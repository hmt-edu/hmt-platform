import { describe, expect, it } from 'vitest';
import { describePolicyChange, formatPolicyValue } from './policyHistory';

describe('Lịch sử chính sách (CH-04)', () => {
  it('dòng tạo hiện «Tạo mới»', () => {
    expect(describePolicyChange({ action: 'I', changes: null })).toBe('Tạo mới');
  });
  it('dòng sửa nối các thay đổi dạng «Nhãn: cũ → mới»', () => {
    expect(
      describePolicyChange({
        action: 'U',
        changes: { max_value: [8, 9], is_active: [true, false] },
      }),
    ).toBe('Mức tối đa: 8 → 9; Trạng thái: Đang dùng → Ngừng');
  });
  it('đúng/sai, danh sách, «Áp dụng cho», cơ sở rỗng và ô trống', () => {
    expect(formatPolicyValue('requires_approval', true)).toBe('Có');
    expect(formatPolicyValue('requires_approval', false)).toBe('Không');
    expect(formatPolicyValue('applies_to', ['BAO_GIA', 'DON'])).toBe('Báo giá, Đơn');
    expect(formatPolicyValue('branch_ids', [])).toBe('Tất cả cơ sở');
    expect(formatPolicyValue('valid_to', null)).toBe('—');
  });
  it('khoá lạ giữ nguyên tên cột; sửa không có chi tiết hiện «Sửa»', () => {
    expect(describePolicyChange({ action: 'U', changes: { khac: ['a', 'b'] } })).toBe(
      'khac: a → b',
    );
    expect(describePolicyChange({ action: 'U', changes: {} })).toBe('Sửa');
  });
});
