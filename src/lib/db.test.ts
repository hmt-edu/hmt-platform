import { describe, expect, it } from 'vitest';
import { HmtError, errorOf, toHmtError } from './db';

describe('errorOf: lỗi bắt trong catch thành câu tiếng Việt', () => {
  it('lỗi do rpc ném ra (HmtError) giữ nguyên mã và câu của hàm cơ sở dữ liệu', () => {
    // Lỗi đã gặp: gọi toHmtError lần nữa cho HmtError (không có hint) làm câu nghiệp vụ thành câu chung.
    const thrown = new HmtError('HMT_SDT_TRUNG', 'Số điện thoại này đã có hồ sơ.');
    const result = errorOf(thrown);
    expect(result.code).toBe('HMT_SDT_TRUNG');
    expect(result.message).toBe('Số điện thoại này đã có hồ sơ.');
    expect(toHmtError(thrown).code).toBe('HMT_LOI');
  });

  it('lỗi thô của Supabase có hint HMT_ thì đổi sang mã và câu nghiệp vụ', () => {
    const result = errorOf({ message: 'Chọn source.', hint: 'HMT_THIEU_NGUON', code: 'P0001' });
    expect(result.code).toBe('HMT_THIEU_NGUON');
    expect(result.message).toBe('Chọn source.');
  });

  it('thiếu quyền ở cơ sở dữ liệu (42501) thì báo không có quyền', () => {
    expect(errorOf({ message: 'permission denied', code: '42501' }).code).toBe(
      'HMT_KHONG_CO_QUYEN',
    );
  });

  it('lỗi lạ (không phải đối tượng lỗi) dùng câu chung, không lộ nội dung kỹ thuật', () => {
    expect(errorOf('hỏng').code).toBe('HMT_LOI');
    expect(errorOf(new Error('connection reset')).message).toBe(
      'Có lỗi xảy ra, thử lại sau. Nếu vẫn lỗi, báo quản trị viên.',
    );
  });
});
