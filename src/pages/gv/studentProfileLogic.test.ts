import { describe, expect, it } from 'vitest';
import {
  criteriaText,
  criterionText,
  homeworkText,
  sessionLabel,
  summaryAttendance,
  summaryScore,
} from './studentProfileLogic';

describe('hồ sơ học sinh rút gọn (GV-13)', () => {
  it('summaryAttendance: chưa điểm danh, có mặt n/m buổi', () => {
    expect(summaryAttendance({ marked: 0, present: 0 })).toBe('Chưa điểm danh');
    expect(summaryAttendance({ marked: 4, present: 3 })).toBe('Có mặt 3/4 buổi');
  });
  it('summaryScore: null là Chưa có điểm (không phải 0), có điểm hiện dấu phẩy', () => {
    expect(summaryScore(null)).toBe('Chưa có điểm');
    expect(summaryScore(4.1)).toBe('TB 4,1');
  });
  it('criterionText: đã đánh giá hiện điểm, ngược lại ghi chưa đánh giá', () => {
    expect(criterionText({ name: 'Thái độ', state: 'DA_DANH_GIA', score: 4 })).toBe('Thái độ 4');
    expect(criterionText({ name: 'Kiến thức', state: 'CHUA_DANH_GIA', score: null })).toBe(
      'Kiến thức: chưa đánh giá',
    );
    expect(criterionText({ name: 'Vận dụng', state: null, score: null })).toBe(
      'Vận dụng: chưa đánh giá',
    );
  });
  it('criteriaText: em vắng không chấm; em có mặt nối các tiêu chí', () => {
    const c = [
      { name: 'Thái độ', state: 'DA_DANH_GIA', score: 4 },
      { name: 'Kiến thức', state: 'DA_DANH_GIA', score: 5 },
    ];
    expect(criteriaText({ attendance_code: 'VANG_CO_PHEP', criteria: [] })).toBe('Không chấm');
    expect(criteriaText({ attendance_code: 'CO_MAT', criteria: c })).toBe(
      'Thái độ 4 · Kiến thức 5',
    );
    expect(criteriaText({ attendance_code: 'DI_MUON', criteria: [] })).toBe('Chưa có tiêu chí');
  });
  it('homeworkText: có điểm, không điểm, chưa có', () => {
    expect(homeworkText(null)).toBe('Chưa có BTVN');
    expect(homeworkText({ status_code: 'DA_CHAM', status_name: 'Đã chấm', score: 4 })).toBe(
      'BTVN: Đã chấm (4)',
    );
    expect(
      homeworkText({ status_code: 'KHONG_AP_DUNG', status_name: 'Không áp dụng', score: null }),
    ).toBe('BTVN: Không áp dụng');
  });
  it('sessionLabel: Buổi n · dd/mm', () => {
    expect(sessionLabel({ session_no: 5, session_date: '2026-10-24' })).toBe('Buổi 5 · 24/10');
    expect(sessionLabel({ session_no: null, session_date: '2026-10-24' })).toBe('Buổi · 24/10');
  });
});
