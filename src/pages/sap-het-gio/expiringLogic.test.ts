import { describe, expect, it } from 'vitest';
import {
  dateText,
  expiringIntro,
  hoursText,
  noUpsaleText,
  statusName,
  statusTone,
} from './expiringLogic';

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

describe('GD-07 câu theo canvas', () => {
  it('Hết giờ chưa có phiếu: chờ đợt quét đêm; trạng thái khác gạch ngang', () => {
    expect(noUpsaleText('HET_GIO')).toBe('Chưa có phiếu · chờ đợt quét đêm');
    expect(noUpsaleText('SAP_HET_GIO')).toBe('—');
  });
  it('câu giới thiệu lấy ngưỡng từ tham số, không viết cứng', () => {
    const t = expiringIntro(7, 21, '20/11/2026');
    expect(t).toContain('≤ 7 giờ');
    expect(t).toContain('≤ 21 ngày');
    expect(t).toContain('20/11/2026');
  });
  it('chưa đọc được tham số thì chỉ còn câu đầu', () => {
    expect(expiringIntro(null, 30, 'x')).toBe(
      'Mỗi dòng là một học sinh trong một lớp; giờ còn là tổng các ghi danh còn hiệu lực.',
    );
  });
});
