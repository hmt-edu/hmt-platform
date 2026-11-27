import { describe, expect, it } from 'vitest';
import { BLANK_OPP_DRAFT, oppCreateArgs, validateOppDraft, type OppDraft } from './oppCreate';

const OK: OppDraft = {
  ...BLANK_OPP_DRAFT,
  parent_name: ' Phụ huynh Thử ',
  parent_phone: '0900 000 001',
  branch_id: 'b1',
  owner_id: 'u1',
  source_type_code: 'T1',
  source_code: 'S1',
};

describe('tạo cơ hội trực tiếp', () => {
  it('đủ ô bắt buộc thì không có lỗi, không có em thì gửi danh sách rỗng', () => {
    expect(validateOppDraft(OK, { channelRequired: false })).toEqual({});
    const args = oppCreateArgs(OK);
    expect(args.students).toEqual([]);
    expect(args.data).toMatchObject({
      parent_name: 'Phụ huynh Thử',
      parent_phone: '0900000001',
      channel_code: null,
      source_type_code: 'T1',
    });
  });

  it('chặn thiếu source type và thiếu medium khi source có medium', () => {
    const errors = validateOppDraft({ ...OK, source_type_code: '' }, { channelRequired: true });
    expect(errors.source_type_code).toBeDefined();
    expect(errors.channel_code).toBe('Chọn medium.');
  });

  it('đã điền ô của em mà thiếu tên thì chặn', () => {
    const errors = validateOppDraft({ ...OK, school: 'Trường A' }, { channelRequired: false });
    expect(errors.student_name).toBeDefined();
  });

  it('có tên em thì gửi một em', () => {
    const args = oppCreateArgs({ ...OK, student_name: 'Em Thử', student_birth_year: '2014' });
    expect(args.students).toEqual([
      expect.objectContaining({ full_name: 'Em Thử', birth_year: 2014 }),
    ]);
  });
});
