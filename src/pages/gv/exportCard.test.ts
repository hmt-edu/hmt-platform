import { describe, expect, it } from 'vitest';
import {
  buildExamCard,
  buildReviewCard,
  canExport,
  cardFileName,
  hasCard,
  wrapText,
} from './exportCard';
import type { ExamSheet } from './exam';
import type { ReviewSheet } from './review';

const session = {
  session_id: 's1',
  status_code: 'DA_CHOT',
  type_code: 'CHINH',
  session_no: 4,
  session_date: '2026-11-18',
  start_time: '18:00:00',
  end_time: '19:30:00',
  class_code: 'CS1-2627-DAI-K09-CB-A-001',
  subject_name: 'Đại số 9',
};
const sheet: ReviewSheet = {
  session,
  criteria: [
    {
      criterion_id: 'c1',
      name: 'Tập trung',
      group_code: 'THAI_DO',
      enabled: true,
      hint: null,
      levels: null,
    },
    {
      criterion_id: 'c2',
      name: 'Ghi nhớ',
      group_code: 'TIEP_THU',
      enabled: true,
      hint: null,
      levels: null,
    },
    {
      criterion_id: 'c3',
      name: 'Đã tắt',
      group_code: 'TIEP_THU',
      enabled: false,
      hint: null,
      levels: null,
    },
  ],
  students: [],
};
const present = {
  student_id: 'st1',
  full_name: 'Trần Gia Hân',
  attendance_code: 'CO_MAT',
  attendance_name: 'Có mặt',
  scores: { c1: { state: 'DA_DANH_GIA', score: 4 }, c2: { state: 'CHUA_DU_CAN_CU', score: null } },
  comment: '  Con tập trung tốt.  ',
  improvement: '',
  average: 4,
} as const;

describe('phiếu buổi thường (GV-07X)', () => {
  const card = buildReviewCard(sheet, present);
  it('gom theo nhóm, chỉ tiêu chí đang bật, ô chưa đủ căn cứ in «—»', () => {
    expect(card?.sections.map((s) => s.title)).toEqual(['Thái độ', 'Tiếp thu kiến thức']);
    expect(card?.sections[0]?.rows).toEqual([{ label: 'Tập trung', value: '4' }]);
    expect(card?.sections[1]?.rows).toEqual([{ label: 'Ghi nhớ', value: '—' }]);
  });
  it('lời nhắn cắt khoảng trắng, định hướng trống thì null, không in điểm trung bình', () => {
    expect(card?.message).toBe('Con tập trung tốt.');
    expect(card?.improvement).toBeNull();
    expect(JSON.stringify(card)).not.toContain('average');
  });
  it('tiêu đề, dòng buổi', () => {
    expect(card?.title).toBe('Đại số 9 · Buổi 4');
    expect(card?.subtitle).toBe('CS1-2627-DAI-K09-CB-A-001 · 18/11/2026 · 18:00–19:30');
  });
  it('em vắng không có phiếu', () => {
    expect(buildReviewCard(sheet, { ...present, attendance_code: 'VANG_CP' })).toBeNull();
    expect(hasCard('VANG_CP')).toBe(false);
    expect(hasCard(null)).toBe(false);
  });
  it('chỉ xuất khi có phiếu và không còn thay đổi chưa lưu', () => {
    expect(canExport({ attendance_code: 'CO_MAT' }, false)).toBe(true);
    expect(canExport({ attendance_code: 'CO_MAT' }, true)).toBe(false);
    expect(canExport({ attendance_code: 'VANG_CP' }, false)).toBe(false);
  });
});

describe('phiếu buổi kiểm tra (GV-07X)', () => {
  const exam: ExamSheet = {
    session,
    exam: {
      scope_text: 'Phương trình bậc nhất',
      max_score: 10,
      entry_mode: 'NHOM',
      max_memory: 3,
      max_understand: 3,
      max_apply: 4,
    },
    students: [],
  };
  const st = {
    student_id: 'st1',
    full_name: 'Trần Gia Hân',
    attendance_code: 'DI_MUON',
    attendance_name: 'Đi muộn',
    score: { total: 8.5, memory: 3, understand: 2.5, apply: 3, graded: true },
    comment: 'Làm bài tốt',
    improvement: 'Ôn thêm',
  };
  it('ba nhóm kèm điểm tối đa và điểm tổng, dấu phẩy thập phân', () => {
    const card = buildExamCard(exam, st);
    expect(card?.sections[0]).toEqual({
      title: 'Phạm vi kiến thức',
      rows: [{ label: 'Phương trình bậc nhất', value: '' }],
    });
    expect(card?.sections[1]?.rows.map((r) => `${r.label}=${r.value}`)).toEqual([
      'Ghi nhớ (tối đa 3)=3',
      'Hiểu (tối đa 3)=2,5',
      'Vận dụng (tối đa 4)=3',
      'Điểm tổng (tối đa 10)=8,5',
    ]);
  });
  it('chưa chấm thì in «—»; chưa có cấu hình hoặc em vắng thì không có phiếu', () => {
    const card = buildExamCard(exam, { ...st, score: null });
    expect(card?.sections[1]?.rows.at(-1)?.value).toBe('—');
    expect(buildExamCard({ ...exam, exam: null }, st as never)).toBeNull();
    expect(buildExamCard(exam, { ...st, attendance_code: 'VANG_KP' })).toBeNull();
  });
});

describe('tên file và ngắt dòng', () => {
  it('bỏ dấu, không ký tự lạ', () => {
    expect(cardFileName('CS1-2627-DAI', '2026-11-18', 'Đặng Thị Ánh (giả)', 'png')).toBe(
      'CS1-2627-DAI-2026-11-18-Dang-Thi-Anh-gia.png',
    );
  });
  it('ngắt dòng theo độ rộng, giữ xuống dòng sẵn có', () => {
    const measure = (s: string) => s.length;
    expect(wrapText('một hai ba bốn năm', 10, measure)).toEqual(['một hai ba', 'bốn năm']);
    expect(wrapText('a\nb', 10, measure)).toEqual(['a', 'b']);
  });
});
