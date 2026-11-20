import { describe, expect, it } from 'vitest';
import {
  EMPTY_EM_DRAFT,
  addEmText,
  draftOfStudent,
  emLabel,
  emPayload,
  emptyListText,
  fullListText,
  validateEmDraft,
  type ProspectStudent,
} from './prospectLogic';

const NOW = 2026;
const em: ProspectStudent = {
  id: 'e1',
  position: 1,
  student_id: null,
  student_code: null,
  full_name: 'Lê Gia Huy',
  birth_date: '2012-03-15',
  birth_year: 2012,
  school: 'THCS Giảng Võ',
  self_rating: null,
  goal: null,
};

describe('Danh sách em: kiểm biểu mẫu (R-CRM-23, R-CRM-03)', () => {
  it('em mới chỉ bắt buộc họ tên; năm sinh không bắt buộc', () => {
    expect(validateEmDraft({ ...EMPTY_EM_DRAFT, fullName: 'Em A' }, false, NOW)).toEqual({});
    expect(validateEmDraft(EMPTY_EM_DRAFT, false, NOW).fullName).toBe('Nhập họ tên của em.');
  });
  it('năm sinh nhập thì 4 chữ số và không ở tương lai', () => {
    const d = { ...EMPTY_EM_DRAFT, fullName: 'Em A' };
    expect(validateEmDraft({ ...d, birthYear: '99' }, false, NOW).birthYear).toBeDefined();
    expect(validateEmDraft({ ...d, birthYear: '2030' }, false, NOW).birthYear).toBeDefined();
    expect(validateEmDraft({ ...d, birthYear: '2014' }, false, NOW)).toEqual({});
  });
  it('từ L5 bắt buộc năm sinh; có ngày sinh thì đủ', () => {
    const d = { ...EMPTY_EM_DRAFT, fullName: 'Em A' };
    expect(validateEmDraft(d, true, NOW).birthYear).toBe(
      'Từ giai đoạn L5 trở lên mỗi em bắt buộc có năm sinh.',
    );
    expect(validateEmDraft({ ...d, birthDate: '2012-03-15' }, true, NOW)).toEqual({});
  });
});

describe('Danh sách em: dữ liệu gửi và câu chữ', () => {
  it('ô trống gửi null, năm sinh thành số, họ tên cắt khoảng trắng', () => {
    expect(emPayload({ ...EMPTY_EM_DRAFT, fullName: '  Em A ', birthYear: '2014' })).toEqual({
      full_name: 'Em A',
      birth_date: null,
      birth_year: 2014,
      school: null,
      self_rating: null,
      goal: null,
    });
  });
  it('mở sửa em lấy đúng giá trị hiện có', () => {
    expect(draftOfStudent(em)).toEqual({
      fullName: 'Lê Gia Huy',
      birthDate: '2012-03-15',
      birthYear: '2012',
      school: 'THCS Giảng Võ',
      selfRating: '',
      goal: '',
    });
  });
  it('«Đã đủ N em» chỉ khi chạm số em tối đa; chưa biết tối đa thì không khoá', () => {
    expect(fullListText(5, 5)).toBe('Đã đủ 5 em');
    expect(fullListText(4, 5)).toBeNull();
    expect(fullListText(9, null)).toBeNull();
  });
  it('chữ theo canvas TS-02/TS-08: danh sách trống, hộp Thêm em, con có sẵn', () => {
    expect(emptyListText('OPPORTUNITY')).toBe(
      'Cơ hội chưa có em. Bấm “+ Thêm em” để ghi họ tên, năm sinh của em.',
    );
    expect(addEmText.note('OPPORTUNITY')).toBe(
      'Thêm em chỉ ghi nhận vào cơ hội. Hồ sơ học sinh được tạo khi tạo phiếu kiểm tra hoặc duyệt đơn.',
    );
    expect(addEmText.existingNote('Chị Lê Thu Hằng', 'PH000061')).toBe(
      'Con đã có hồ sơ của phụ huynh Chị Lê Thu Hằng (PH000061).',
    );
    expect(emLabel({ ...em, full_name: null })).toBe('Em chưa có tên');
  });
});
