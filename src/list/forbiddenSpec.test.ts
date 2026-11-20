import { describe, expect, it } from 'vitest';
import { HmtError } from '../lib/db';
import { forbiddenBody, listForbiddenOf } from './forbiddenSpec';

// So canvas TC01, TC04, TC08, TC10, TC13, BH01, BH06 (*_khong_quyen): khung «Không có quyền» của danh sách K03.
describe('khung «Không có quyền» của danh sách (canvas *_khong_quyen)', () => {
  it('chỉ lỗi HMT_KHONG_CO_QUYEN mới hiện khung không có quyền', () => {
    expect(
      listForbiddenOf(
        new HmtError('HMT_KHONG_CO_QUYEN', 'x'),
        'khoản tiền vào',
        'Bán hàng và thu chi',
      ),
    ).toEqual({ subject: 'khoản tiền vào', module: 'Bán hàng và thu chi' });
    expect(listForbiddenOf(new HmtError('HMT_LOI_KHAC', 'x'), 'phiếu thu', 'M')).toBeUndefined();
    expect(listForbiddenOf(new Error('mạng'), 'phiếu thu', 'M')).toBeUndefined();
    expect(listForbiddenOf(null, 'phiếu thu', 'M')).toBeUndefined();
  });

  it('câu giải thích nêu vai trò và phân hệ đúng như canvas', () => {
    expect(forbiddenBody(['Giáo viên'], 'Bán hàng và thu chi')).toBe(
      'Vai trò Giáo viên chưa được cấp quyền xem phân hệ Bán hàng và thu chi. Nếu cần xem, hãy liên hệ quản trị viên của trung tâm.',
    );
    expect(forbiddenBody([], 'Bán hàng và thu chi')).toContain('Tài khoản này chưa được cấp quyền');
  });
});
