import { describe, expect, it } from 'vitest';
import {
  groupsOf,
  natureText,
  statusName,
  typeName,
  validateTicket,
  type TicketCategory,
} from './ticketLogic';

const cat = (over: Partial<TicketCategory>): TicketCategory => ({
  code: 'GV_01_05',
  name: 'Học sinh nghỉ nhiều',
  group_code: 'GV_01',
  group_name: 'Học sinh',
  nature_code: 'HO_TRO',
  requires_student: true,
  requires_class: true,
  ...over,
});

describe('GV-14 ticketLogic', () => {
  it('tên loại, tình trạng, tính chất', () => {
    expect(typeName('GV')).toBe('Ticket giáo viên');
    expect(typeName('KN')).toBe('Khiếu nại');
    expect(statusName('DANG_XU_LY')).toBe('Đang xử lý');
    expect(statusName('LA')).toBe('LA');
    expect(natureText('HO_TRO')).toBe('Cần hỗ trợ');
    expect(natureText('PHAN_ANH')).toBe('Phản ánh');
    expect(natureText(null)).toBe('Chưa xếp');
  });
  it('validateTicket: thiếu nhóm, nhóm con, tiêu đề, mô tả', () => {
    expect(
      validateTicket({
        groupCode: '',
        category: undefined,
        classId: '',
        studentId: '',
        title: ' ',
        description: '',
      }),
    ).toEqual({
      group: 'Chọn nhóm.',
      category: 'Chọn nhóm con.',
      title: 'Nhập tiêu đề.',
      description: 'Mô tả là bắt buộc.',
    });
  });
  it('validateTicket: lớp và học sinh bắt buộc theo nhóm con', () => {
    const base = { groupCode: 'GV_01', title: 't', description: 'd' };
    expect(validateTicket({ ...base, category: cat({}), classId: '', studentId: '' })).toEqual({
      class: 'Nhóm con này bắt buộc chọn lớp.',
      student: 'Nhóm con này bắt buộc chọn học sinh.',
    });
    expect(
      validateTicket({
        ...base,
        category: cat({ requires_student: false, requires_class: false }),
        classId: '',
        studentId: '',
      }),
    ).toEqual({});
    expect(validateTicket({ ...base, category: cat({}), classId: 'c', studentId: 's' })).toEqual(
      {},
    );
  });
  it('groupsOf: nhóm không trùng, giữ thứ tự', () => {
    expect(
      groupsOf([
        cat({}),
        cat({ code: 'GV_01_06' }),
        cat({ code: 'GV_02_01', group_code: 'GV_02', group_name: 'Phụ huynh' }),
      ]),
    ).toEqual([
      { code: 'GV_01', name: 'Học sinh' },
      { code: 'GV_02', name: 'Phụ huynh' },
    ]);
  });
});
