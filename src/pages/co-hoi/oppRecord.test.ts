import { describe, expect, it } from 'vitest';
import {
  oppHistoryValue,
  oppPayload,
  toOppDraft,
  validateOppDraft,
  type OppDraft,
} from './oppRecord';
import type { OppRecord } from './oppTypes';

const draft = (patch: Partial<OppDraft> = {}): OppDraft => ({
  need: '',
  student_name: 'Em Ba',
  student_birth_date: '',
  student_birth_year: '2011',
  school: '',
  self_rating: '',
  goal: '',
  supporter_id: '',
  ...patch,
});

describe('validateOppDraft', () => {
  it('hợp lệ thì không có lỗi', () => {
    expect(validateOppDraft(draft(), 'L5')).toEqual({});
  });
  it('năm sinh sai dạng', () => {
    expect(
      validateOppDraft(draft({ student_birth_year: '12' }), 'L1').student_birth_year,
    ).toContain('4 chữ số');
  });
  it('R-CRM-03: từ L5 không xoá trống tên học sinh', () => {
    expect(validateOppDraft(draft({ student_name: ' ' }), 'L5').student_name).toBeDefined();
    expect(validateOppDraft(draft({ student_name: '' }), 'L3').student_name).toBeUndefined();
  });
  it('R-CRM-03: từ L5 cần năm sinh, có ngày sinh thì đủ (năm lấy từ ngày)', () => {
    expect(
      validateOppDraft(draft({ student_birth_year: '' }), 'L6').student_birth_year,
    ).toBeDefined();
    expect(
      validateOppDraft(draft({ student_birth_year: '', student_birth_date: '2011-03-15' }), 'L6'),
    ).toEqual({});
    expect(validateOppDraft(draft({ student_birth_year: '' }), 'L4')).toEqual({});
  });
});

describe('oppPayload', () => {
  it('nhập năm thì gửi năm', () => {
    expect(oppPayload(draft()).student_birth_year).toBe(2011);
  });
  it('không nhập năm nhưng có ngày sinh thì không gửi năm (hàm DB lấy từ ngày)', () => {
    const p = oppPayload(draft({ student_birth_year: '', student_birth_date: '2012-05-01' }));
    expect('student_birth_year' in p).toBe(false);
    expect(p.student_birth_date).toBe('2012-05-01');
  });
  it('xoá cả năm và ngày sinh thì gửi rỗng', () => {
    const p = oppPayload(draft({ student_birth_year: '', student_birth_date: '' }));
    expect(p.student_birth_year).toBeNull();
    expect(p.student_birth_date).toBeNull();
  });
  it('ô trống thành null, ô có chữ được cắt khoảng trắng', () => {
    const p = oppPayload(draft({ need: '  ôn thi  ', school: '' }));
    expect(p.need).toBe('ôn thi');
    expect(p.school).toBeNull();
  });
});

describe('toOppDraft', () => {
  it('đổi null thành chuỗi rỗng, năm thành chữ', () => {
    const d = toOppDraft({
      need: null,
      student_name: 'A',
      student_birth_date: null,
      student_birth_year: 2010,
      school: null,
      self_rating: null,
      goal: null,
      supporter_id: null,
    } as unknown as OppRecord);
    expect(d.need).toBe('');
    expect(d.student_birth_year).toBe('2010');
  });
});

describe('oppHistoryValue', () => {
  const names: Record<string, string> = {
    'OPP_STAGE|L5': 'Đồng ý tham gia test',
    'TEST_SKIP_REASON|KHAC': 'Khác',
  };
  const catalogs = { name: (c: string, code: string | null | undefined) => names[`${c}|${code}`] };
  const record = { owner_id: 'u1', owner_name: 'Hà', supporter_id: null, supporter_name: null };
  const fmt = oppHistoryValue(catalogs, record);
  it('giai đoạn kèm mã, lý do bỏ qua chỉ tên', () => {
    expect(fmt('stage_code', 'L5')).toBe('L5 Đồng ý tham gia test');
    expect(fmt('skip_reason_code', 'KHAC')).toBe('Khác');
  });
  it('người phụ trách hiện tên, người khác là "nhân sự khác"', () => {
    expect(fmt('owner_id', 'u1')).toBe('Hà');
    expect(fmt('owner_id', 'u2')).toBe('nhân sự khác');
  });
  it('cột không biết thì để mặc định', () => {
    expect(fmt('need', 'x')).toBeNull();
  });
});
