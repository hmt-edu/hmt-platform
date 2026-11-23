import { describe, expect, it } from 'vitest';
import { taskFeatureOffMessage } from './taskFeature';

const on = (set: string[]) => (feature: string) => set.includes(feature);

describe('công tắc tính năng của phiếu nghiệp vụ', () => {
  it('AFTERSALE tắt thì chặn mọi loại phiếu', () => {
    expect(taskFeatureOffMessage('CAP_NHAT_HO_SO', on([]), 'CS5')).toBe(
      'Tính năng Chăm sóc khách hàng chưa bật ở cơ sở này.',
    );
  });
  it('phân hệ riêng tắt (Chuyển lớp) thì chặn kèm tên loại phiếu', () => {
    expect(taskFeatureOffMessage('CHUYEN_LOP', on(['AFTERSALE']), 'CS5')).toBe(
      'Tính năng Chuyển lớp chưa bật ở cơ sở này.',
    );
  });
  it('bật đủ thì không chặn; loại không có phân hệ riêng chỉ cần AFTERSALE', () => {
    expect(taskFeatureOffMessage('CHUYEN_LOP', on(['AFTERSALE', 'CHUYEN_LOP']), 'CS5')).toBeNull();
    expect(taskFeatureOffMessage('CHUYEN_PHI', on(['AFTERSALE']), 'CS5')).toBeNull();
  });
});
