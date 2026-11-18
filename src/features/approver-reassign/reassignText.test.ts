import { describe, expect, it } from 'vitest';
import { noteForReassign, reassignReasonText, suggestedReasonCode } from './reassignText';

describe('Chuyển người duyệt: chữ hiển thị (R-V2-44)', () => {
  it('nêu đúng vì sao người đã chốt không duyệt được', () => {
    expect(reassignReasonText('BI_KHOA')).toContain('khoá');
    expect(reassignReasonText('MAT_QUYEN')).toContain('quyền Duyệt');
    expect(reassignReasonText('QUA_HAN')).toContain('quá hạn');
    expect(reassignReasonText(null)).toBe('');
  });
  it('gợi ý sẵn lý do theo tình trạng', () => {
    expect(suggestedReasonCode('BI_KHOA')).toBe('BI_KHOA');
    expect(suggestedReasonCode('QUA_HAN')).toBe('QUA_HAN_XU_LY');
    expect(suggestedReasonCode('MAT_QUYEN')).toBe('');
  });
  it('ghi chú trống thành null', () => {
    expect(noteForReassign('  ')).toBeNull();
    expect(noteForReassign(' ghi chú ')).toBe('ghi chú');
  });
});
