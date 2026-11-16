import { describe, expect, it } from 'vitest';
import { dateText, hoursText, statusName, statusTone } from './expiringLogic';

describe('GD-07 expiringLogic', () => {
  it('tên và màu tình trạng', () => {
    expect(statusName('HET_GIO')).toBe('Hết giờ');
    expect(statusName('SAP_HET_GIO')).toBe('Sắp hết giờ');
    expect(statusName('QUA_HAN_CON_GIO')).toBe('Quá hạn gói, còn giờ');
    expect(statusTone('HET_GIO')).toBe('danger');
    expect(statusTone('SAP_HET_GIO')).toBe('warning');
    expect(statusTone('QUA_HAN_CON_GIO')).toBe('neutral');
  });
  it('ngày dd/mm/yyyy, rỗng thì gạch ngang', () => {
    expect(dateText('2026-11-30')).toBe('30/11/2026');
    expect(dateText(null)).toBe('—');
  });
  it('giờ còn kiểu Việt', () => {
    expect(hoursText(3)).toBe('3');
    expect(hoursText(2.5)).toBe('2,5');
    expect(hoursText(0)).toBe('0');
  });
});
