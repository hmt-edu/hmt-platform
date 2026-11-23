import { describe, expect, it } from 'vitest';
import { statusDialogSpec } from './statusDialog';

const base = { from: 'DANG_XU_LY', to: 'DA_XU_LY', ticketType: 'DN' as const, businessType: null };

describe('hộp thoại đổi trạng thái (CSN-04)', () => {
  it('huỷ bắt buộc lý do', () => {
    const s = statusDialogSpec({ ...base, to: 'DA_HUY' });
    expect(s.noteRequired).toBe(true);
    expect(s.noteLabel).toBe('Lý do huỷ');
  });
  it('mở lại ticket đã đóng bắt buộc lý do mở lại', () => {
    const s = statusDialogSpec({ ...base, from: 'DA_DONG', to: 'DANG_XU_LY' });
    expect(s.title).toBe('Mở lại ticket');
    expect(s.noteRequired).toBe(true);
  });
  it('đóng ticket có nghiệp vụ đi kèm là đóng làm tay, bắt buộc ghi chú', () => {
    const s = statusDialogSpec({
      ...base,
      from: 'DA_XU_LY',
      to: 'DA_DONG',
      businessType: 'BAO_LUU',
    });
    expect(s.title).toBe('Đóng ticket làm tay');
    expect(s.noteRequired).toBe(true);
  });
  it('đóng khiếu nại không bắt buộc ghi chú (bắt buộc mức hài lòng ở chỗ khác)', () => {
    const s = statusDialogSpec({ ...base, from: 'DA_XU_LY', to: 'DA_DONG', ticketType: 'KN' });
    expect(s.title).toBe('Đóng khiếu nại');
    expect(s.noteRequired).toBe(false);
  });
  it('chuyển thường không bắt buộc ghi chú', () => {
    const s = statusDialogSpec(base);
    expect(s.noteRequired).toBe(false);
    expect(s.confirmLabel).toBe('Chuyển');
  });
  it('khách huỷ (CS-12): bắt buộc lý do, tiêu đề riêng; không bật thì vẫn là huỷ thường', () => {
    const s = statusDialogSpec({ ...base, to: 'DA_HUY', customerCancel: true });
    expect(s.title).toBe('Khách huỷ ticket');
    expect(s.noteRequired).toBe(true);
    expect(s.confirmLabel).toBe('Xác nhận khách huỷ');
    expect(s.hint).toBe('Bắt buộc. Ghi vào nhật ký ticket (R-CS-05).');
    expect(statusDialogSpec({ ...base, to: 'DA_HUY' }).title).toBeNull();
  });
});
