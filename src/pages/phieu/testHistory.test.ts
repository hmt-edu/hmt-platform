import { describe, expect, it } from 'vitest';
import { TEST_FIELD_LABELS, testHistoryValue } from './testHistory';

const names: Record<string, string> = {
  'SUBJECT|TOAN': 'Toán',
  'TEST_CANCEL_REASON|OM': 'Con ốm',
};
const catalogs = { name: (c: string, code: string | null | undefined) => names[`${c}|${code}`] };
const record = { owner_id: 'u1', owner_name: 'Hà', grader_id: 'g1', grader_name: 'Cô Lan' };
const fmt = testHistoryValue(catalogs, record);

describe('testHistoryValue', () => {
  it('trạng thái hiện chữ tiếng Việt', () => {
    expect(fmt('status_code', 'TEACHER_REVIEW')).toBe('Chờ giáo viên chấm');
    expect(fmt('status_code', 'COMPLETED')).toBe('Hoàn thành');
  });
  it('điểm kiểu Việt Nam; giờ test có ngày giờ', () => {
    expect(fmt('score', 7.5)).toBe('7,5/10');
    expect(fmt('scheduled_at', '2026-10-15T11:00:00Z')).toContain('15/10/2026');
  });
  it('mã danh mục thành tên', () => {
    expect(fmt('subject_code', 'TOAN')).toBe('Toán');
    expect(fmt('cancel_reason_code', 'OM')).toBe('Con ốm');
  });
  it('người: tên hiện tại, người khác là "nhân sự khác"', () => {
    expect(fmt('owner_id', 'u1')).toBe('Hà');
    expect(fmt('owner_id', 'u2')).toBe('nhân sự khác');
    expect(fmt('grader_id', 'g1')).toBe('Cô Lan');
    expect(fmt('grader_id', 'g2')).toBe('giáo viên khác');
  });
  it('cờ nhập thay (R-CRM-11)', () => {
    expect(fmt('result_on_behalf', true)).toBe('Có');
    expect(TEST_FIELD_LABELS.result_on_behalf).toBe('Nhập thay');
  });
  it('cột không biết thì để mặc định', () => {
    expect(fmt('exam_name', 'Đề 1')).toBeNull();
  });
});
