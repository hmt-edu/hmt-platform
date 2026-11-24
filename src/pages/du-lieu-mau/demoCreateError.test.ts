// E-23-38: câu báo khi tạo bộ dữ liệu mẫu lỗi vì hạn mức.
import { describe, expect, it } from 'vitest';
import { DEMO_BRANCH_FULL_CODE, demoCreateErrorText } from './useDemoData';

describe('demoCreateErrorText', () => {
  it('cơ sở đủ bộ: nói rõ nhờ Admin xoá bớt, không bảo người bấm tự xoá', () => {
    const text = demoCreateErrorText(
      DEMO_BRANCH_FULL_CODE,
      'Cơ sở này đã có đủ... Xoá bớt một bộ trước.',
    );
    expect(text).toBe('Cơ sở đã đủ số bộ mẫu, nhờ Admin xoá bớt.');
  });

  it('lỗi khác giữ nguyên câu của máy chủ (kể cả hạn mức của chính người bấm)', () => {
    expect(demoCreateErrorText('HMT_DEMO_QUA_HAN_MUC_NGUOI', 'Bạn đã có đủ số bộ.')).toBe(
      'Bạn đã có đủ số bộ.',
    );
  });
});
