import { describe, expect, it } from 'vitest';
import { FORBIDDEN_CODE, HmtError } from '../lib/db';
import { queryErrorSpec } from './queryError';

describe('màn lỗi tải dữ liệu', () => {
  it('không quyền thì không có nút Thử lại', () => {
    const s = queryErrorSpec(new HmtError(FORBIDDEN_CODE, 'x'), 'ticket');
    expect(s).toEqual({
      kind: 'forbidden',
      title: 'Bạn không có quyền xem ticket',
      canRetry: false,
    });
  });
  it('không tìm thấy thì không có nút Thử lại', () => {
    const s = queryErrorSpec(new HmtError('HMT_KHONG_TIM_THAY', 'x'), 'phiếu');
    expect(s).toEqual({ kind: 'not-found', title: 'Không tìm thấy phiếu', canRetry: false });
  });
  it('lỗi khác (mạng) thì có nút Thử lại', () => {
    const s = queryErrorSpec(new Error('Failed to fetch'), 'cấu hình SLA');
    expect(s).toEqual({ kind: 'error', title: 'Chưa tải được cấu hình SLA', canRetry: true });
  });
  it('lỗi nghiệp vụ (mã HMT_*) hiện câu tiếng Việt của lỗi, không nhắc mạng, không Thử lại (D-23-38)', () => {
    const s = queryErrorSpec(
      new HmtError('HMT_TINH_NANG_TAT', 'Phân hệ chưa bật ở cơ sở này.'),
      'phiếu',
    );
    expect(s).toEqual({
      kind: 'error',
      title: 'Chưa tải được phiếu',
      canRetry: false,
      detail: 'Phân hệ chưa bật ở cơ sở này.',
    });
  });
  it('lỗi chung HMT_LOI (không rõ nguyên nhân) vẫn cho Thử lại', () => {
    const s = queryErrorSpec(new HmtError('HMT_LOI', 'Có lỗi xảy ra, thử lại sau.'), 'phiếu');
    expect(s.canRetry).toBe(true);
    expect(s.detail).toBeUndefined();
  });
});
