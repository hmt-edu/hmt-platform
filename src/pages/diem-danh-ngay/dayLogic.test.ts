import { describe, expect, it } from 'vitest';
import { countsText, noticeText, stateName, stateTone } from './dayLogic';

const zero = { CO_MAT: 0, DI_MUON: 0, VANG_CO_PHEP: 0, VANG_KHONG_PHEP: 0, CHUA: 0 };

describe('BUOI-15 dayLogic', () => {
  it('tên và màu tình trạng ghi', () => {
    expect(stateName('GHI_DU')).toBe('Ghi đủ');
    expect(stateName('GHI_DO')).toBe('Ghi dở');
    expect(stateName('CHUA_GHI')).toBe('Chưa ghi');
    expect(stateName('CHUA_CO_DANH_SACH')).toBe('Chưa có danh sách');
    expect(stateTone('GHI_DU')).toBe('success');
    expect(stateTone('GHI_DO')).toBe('warning');
    expect(stateTone('CHUA_GHI')).toBe('danger');
    expect(stateTone('CHUA_CO_DANH_SACH')).toBe('neutral');
  });
  it('bộ đếm chỉ nêu mục khác 0', () => {
    expect(countsText(zero)).toBe('—');
    expect(countsText({ ...zero, CO_MAT: 7, DI_MUON: 1, CHUA: 2 })).toBe(
      'Có mặt 7 · Muộn 1 · Chưa 2',
    );
    expect(countsText({ ...zero, VANG_CO_PHEP: 1, VANG_KHONG_PHEP: 3 })).toBe('Phép 1 · KP 3');
  });
  it('cột Lưu ý', () => {
    expect(noticeText(0)).toBe('—');
    expect(noticeText(2)).toBe('PH báo nghỉ 2');
  });
});
