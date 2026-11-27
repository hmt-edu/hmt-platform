import { describe, expect, it } from 'vitest';
import {
  EMPTY_EM_DRAFT,
  addEmText,
  draftOfStudent,
  emLabel,
  emPayload,
  emptyListText,
  fullListText,
  pickEmText,
  uniqueEms,
  validateEmDraft,
  type ProspectStudent,
  dirtyEmIds,
  unsavedEmText,
  studentLabel,
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
    expect(validateEmDraft(EMPTY_EM_DRAFT, false, NOW).fullName).toBe('Nhập họ tên của học sinh.');
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
      'Từ giai đoạn L5 trở lên mỗi học sinh bắt buộc có năm sinh.',
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
    expect(fullListText(5, 5)).toBe('Đã đủ 5 học sinh');
    expect(fullListText(4, 5)).toBeNull();
    expect(fullListText(9, null)).toBeNull();
  });
  it('chữ theo canvas TS-02/TS-08: danh sách trống, hộp Thêm em, con có sẵn', () => {
    expect(emptyListText('OPPORTUNITY')).toBe(
      'Cơ hội chưa có học sinh. Bấm “+ Thêm học sinh” để ghi họ tên, năm sinh của học sinh.',
    );
    expect(addEmText.note('OPPORTUNITY')).toBe(
      'Thêm học sinh chỉ ghi nhận vào cơ hội. Hồ sơ học sinh được tạo khi tạo phiếu kiểm tra hoặc duyệt đơn.',
    );
    expect(addEmText.existingNote('Chị Lê Thu Hằng', 'PH000061')).toBe(
      'Con đã có hồ sơ của phụ huynh Chị Lê Thu Hằng (PH000061).',
    );
    expect(emLabel({ ...em, full_name: null })).toBe('Học sinh chưa có tên');
  });
});

describe('Chọn em khi tạo cơ hội (TS-06)', () => {
  const a: ProspectStudent = { ...em, id: 'a', full_name: 'Lê Gia Huy', birth_year: 2012 };
  const b: ProspectStudent = { ...em, id: 'b', full_name: '  le  gia HUY ', birth_year: 2012 };
  const c: ProspectStudent = { ...em, id: 'c', full_name: 'Lê Gia Huy', birth_year: 2013 };
  const d: ProspectStudent = {
    ...em,
    id: 'd',
    full_name: null,
    student_id: 's1',
    birth_year: null,
  };
  it('em trùng họ tên (không dấu, hoa thường, khoảng trắng) và năm sinh gộp một dòng', () => {
    expect(uniqueEms([a, b, c]).map((x) => x.id)).toEqual(['a', 'c']);
  });
  it('em gắn hồ sơ học sinh gộp theo hồ sơ', () => {
    expect(uniqueEms([d, { ...d, id: 'e' }]).map((x) => x.id)).toEqual(['d']);
  });
  it('chữ theo canvas TS-06', () => {
    expect(pickEmText.tooMany(5)).toBe('Chọn tối đa 5 học sinh.');
    expect(pickEmText.addToExisting).toBe('Thêm học sinh vào cơ hội cũ');
  });
});

describe('Thông tin học sinh một khối (A-26-01)', () => {
  it('năm sinh để trống mà có ngày sinh thì gửi năm của ngày sinh; trống cả hai thì null', () => {
    const d = { ...EMPTY_EM_DRAFT, fullName: 'Em A' };
    expect(emPayload({ ...d, birthDate: '2013-05-05' }).birth_year).toBe(2013);
    expect(emPayload({ ...d, birthDate: '2013-05-05', birthYear: '2012' }).birth_year).toBe(2012);
    expect(emPayload(d).birth_year).toBeNull();
  });

  const em = (id: string, patch: Partial<ProspectStudent> = {}): ProspectStudent => ({
    id,
    position: 1,
    student_id: null,
    student_code: null,
    full_name: `Em ${id}`,
    birth_date: null,
    birth_year: null,
    school: null,
    self_rating: null,
    goal: null,
    ...patch,
  });

  it('chỉ tính em từ số 2, chưa gắn hồ sơ, bản nháp khác dữ liệu đã lưu', () => {
    const list = [em('a'), em('b'), em('c'), em('d', { student_id: 's' })];
    const changed = (s: ProspectStudent) => ({ ...draftOfStudent(s), goal: 'Mới' });
    expect(
      dirtyEmIds(list, {
        a: changed(list[0]!),
        b: changed(list[1]!),
        c: { ...draftOfStudent(list[2]!), school: '  ' },
        d: changed(list[3]!),
      }),
    ).toEqual(['b']);
  });

  it('câu báo nêu tên em còn chưa lưu', () => {
    expect(unsavedEmText(['An', 'Bình'])).toBe(
      'Còn thay đổi chưa lưu ở học sinh: An, Bình. Chọn thẻ học sinh đó rồi bấm Lưu.',
    );
  });
});

describe('studentLabel: tên và năm sinh tách nhau (F-26-05)', () => {
  it('năm sinh và mã học sinh là chữ phụ, không ghép vào tên', () => {
    expect(studentLabel({ full_name: 'Em Giả', birth_year: 2012, student_code: 'HS-1' })).toEqual({
      label: 'Em Giả',
      hint: 'sinh 2012 · HS-1',
    });
  });
  it('không có năm sinh thì không có chữ phụ; chưa có tên thì ghi rõ', () => {
    expect(studentLabel({ full_name: '  ', birth_year: null })).toEqual({
      label: 'Học sinh chưa có tên',
    });
  });
});
