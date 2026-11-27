import { describe, expect, it } from 'vitest';
import { orderStamp } from './orderPrint';

describe('Bản in đơn hàng', () => {
  it('nhãn theo đúng tình trạng thật, không có «Đã xác nhận»', () => {
    expect((['NHAP', 'DA_TRINH', 'DA_DUYET', 'HUY'] as const).map(orderStamp)).toEqual([
      'BẢN NHÁP',
      'ĐÃ TRÌNH',
      'ĐÃ DUYỆT',
      'ĐÃ HUỶ',
    ]);
  });
});
