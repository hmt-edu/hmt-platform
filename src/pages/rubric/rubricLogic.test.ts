import { describe, expect, it } from 'vitest';
import {
  changedCells,
  changedPhrases,
  phraseKey,
  draftKey,
  emptyCells,
  groupNote,
  subjectSetOf,
  valueOf,
  versionLabel,
  type Rubric,
} from './rubricLogic';

const rubric: Rubric = {
  version: { id: 'v2', version_no: 2, status: 'DANG_DUNG', created_at: '2026-11-18T00:00:00Z' },
  versions: [],
  criteria: [
    {
      id: 'c1',
      code: 'TD_TAP_TRUNG',
      group_code: 'THAI_DO',
      subject_set: 'MOI_MON',
      name: 'Tập trung',
      sort_order: 1,
      is_active: true,
      levels: { '1': 'a', '3': 'c' },
    },
  ],
};

describe('CH-07 rubric', () => {
  it('chữ phụ của nhóm theo bộ', () => {
    expect(groupNote('THAI_DO', 'TOAN')).toBe('Dùng chung mọi môn');
    expect(groupNote('TIEP_THU', 'TOAN')).toBe('Riêng môn Toán');
    expect(groupNote('VAN_DUNG', 'MON_PHU')).toBe('Bộ môn phụ');
  });
  it('nhãn phiên bản', () => {
    expect(versionLabel(rubric.version)).toBe('Phiên bản 2 · đang dùng');
    expect(versionLabel({ ...rubric.version, status: 'NGUNG' })).toBe('Phiên bản 2 · đã ngừng');
  });
  it('chỉ ô đã đổi được gửi, chữ cắt khoảng trắng', () => {
    const c = rubric.criteria[0]!;
    expect(valueOf(c, '1', {})).toBe('a');
    expect(valueOf(c, '2', {})).toBe('');
    const draft = {
      [draftKey('c1', '1')]: 'a',
      [draftKey('c1', '3')]: '  mới ',
      [draftKey('c1', '5')]: ' x',
    };
    expect(changedCells(rubric, draft)).toEqual([
      { criterionId: 'c1', level: 3, description: 'mới' },
      { criterionId: 'c1', level: 5, description: 'x' },
    ]);
  });
  it('báo ô bị xoá trắng', () => {
    expect(emptyCells([{ description: '' }])).toBe(true);
    expect(emptyCells([{ description: 'x' }])).toBe(false);
  });
  it('môn không có trong bảng dùng bộ môn phụ', () => {
    expect(subjectSetOf('TOAN', { TOAN: 'TOAN' })).toBe('TOAN');
    expect(subjectSetOf('VAT_LY', { TOAN: 'TOAN' })).toBe('MON_PHU');
  });
});

describe('CH-07 câu mẫu', () => {
  const rows = [
    { kind: 'THUONG', level: 1, seq: 1, phrase: 'a' },
    { kind: 'THUONG', level: 1, seq: 2, phrase: 'b' },
  ];
  it('chỉ câu đã đổi, cắt khoảng trắng, giữ ô trống để máy chủ chặn', () => {
    const draft = { [phraseKey(rows[0]!)]: '  mới ', [phraseKey(rows[1]!)]: 'b' };
    expect(changedPhrases(rows, draft)).toEqual([
      { kind: 'THUONG', level: 1, seq: 1, phrase: 'mới' },
    ]);
    expect(changedPhrases(rows, { [phraseKey(rows[1]!)]: ' ' })[0]?.phrase).toBe('');
  });
});
