import { describe, expect, it } from 'vitest';
import {
  EMPTY_SLA_EDITS,
  changedOverrides,
  changedRules,
  countChanges,
  slaFieldError,
  type SlaRule,
} from './ticketSla';

const rules: SlaRule[] = [
  { ticket_type: 'KN', priority_code: 'KHAN', response_hours: 2, resolve_hours: 24 },
  { ticket_type: 'DN', priority_code: 'CAO', response_hours: 4, resolve_hours: 48 },
];

describe('CSN-09: thay đổi chưa lưu', () => {
  it('không sửa gì thì không có thay đổi', () => {
    expect(countChanges(rules, [], EMPTY_SLA_EDITS)).toBe(0);
  });
  it('chỉ gửi ô đã đổi; gõ lại đúng giá trị gốc không tính là đổi', () => {
    const edits = {
      rules: { 'KN:KHAN': { response: '3', resolve: '24' }, 'DN:CAO': { response: '4' } },
      overrides: {},
    };
    expect(changedRules(rules, edits)).toEqual([
      { ticket_type: 'KN', priority_code: 'KHAN', response_hours: 3 },
    ]);
  });
  it('hạn riêng: đặt, bỏ, và giữ nguyên', () => {
    const overrides = [
      { code: 'A', name: 'A', resolve_hours_override: 96 },
      { code: 'B', name: 'B', resolve_hours_override: null },
    ];
    const edits = { rules: {}, overrides: { A: null, B: '72', C: '' } };
    expect(changedOverrides(overrides, edits)).toEqual([
      { category_code: 'A', resolve_hours: null },
      { category_code: 'B', resolve_hours: 72 },
    ]);
  });
  it('báo lỗi số giờ không hợp lệ', () => {
    expect(slaFieldError('0')).not.toBeNull();
    expect(slaFieldError('1.5')).not.toBeNull();
    expect(slaFieldError('abc')).not.toBeNull();
    expect(slaFieldError('12')).toBeNull();
    expect(slaFieldError('')).toBeNull();
  });
});
