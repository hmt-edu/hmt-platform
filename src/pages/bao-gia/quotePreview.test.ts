import { describe, expect, it } from 'vitest';
import { blankRow, giftRow, type EditRow } from './quoteEdit';
import {
  errorLineNo,
  isComplete,
  percentText,
  previewCandidates,
  remapLineNo,
  waitingStatus,
} from './quotePreview';

const FULL: EditRow = {
  ...blankRow(),
  studentId: 's1',
  packageId: 'p1',
  mode: 'OFF',
  quantity: '10',
};

describe('quotePreview', () => {
  it('dòng đủ gói, hình thức, số lượng mới tính được', () => {
    expect(isComplete(FULL)).toBe(true);
    expect(isComplete({ ...FULL, quantity: '' })).toBe(false);
    expect(isComplete({ ...FULL, mode: '' })).toBe(false);
    expect(isComplete({ ...FULL, packageId: '' })).toBe(false);
    expect(isComplete({ ...FULL, discounts: [{ policyId: 'a', name: 'A', value: 'x' }] })).toBe(
      false,
    );
  });

  it('chỉ dòng đã chọn em được gửi xem thử; dòng chưa chọn em chờ chọn em', () => {
    const noStudent = { ...FULL, studentId: '' };
    const sent = previewCandidates([noStudent, FULL]);
    expect(sent.map((c) => c.rowKey)).toEqual([FULL.key]);
    expect(waitingStatus(noStudent)).toEqual({ status: 'needs-student' });
    expect(waitingStatus(FULL)).toEqual({ status: 'pending' });
    expect(waitingStatus(blankRow())).toEqual({ status: 'incomplete' });
  });

  it('đọc và đổi số dòng trong câu lỗi của máy chủ', () => {
    expect(errorLineNo('Dòng 2: số lượng quà không quá 1.')).toBe(2);
    expect(errorLineNo('Bạn không có quyền')).toBeNull();
    expect(remapLineNo('Dòng 2: số lượng quà không quá 1.', 5)).toBe(
      'Dòng 5: số lượng quà không quá 1.',
    );
  });

  it('số thập phân kiểu Việt', () => {
    expect(percentText(23.3)).toBe('23,3');
    expect(percentText(10)).toBe('10');
  });

  it('dòng quà đủ chính sách và số lượng thì xem thử được; chưa chọn em thì chờ chọn em', () => {
    const gift = giftRow({
      id: 'g1',
      name: 'Quà',
      gift_package: {
        id: 'tl1',
        code: 'TL',
        name: 'Gói quà',
        package_type_code: 'TL',
        unit_code: 'BO',
      },
    });
    expect(isComplete(gift)).toBe(false);
    const ready = { ...gift, quantity: '1' };
    expect(isComplete(ready)).toBe(true);
    expect(waitingStatus(ready)).toEqual({ status: 'needs-student' });
    expect(previewCandidates([{ ...ready, studentId: 's1' }]).map((c) => c.line.kind)).toEqual([
      'GIFT',
    ]);
  });
});
