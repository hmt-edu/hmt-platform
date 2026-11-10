import { describe, expect, it } from 'vitest';
import { buildOpsEntries, cellOf, countOpsMarked, missingNote, patchDraft } from './opsLogic';
import type { OpsSheet, OpsStudent } from './sessionTypes';

const s1: OpsStudent = {
  student_id: 'a',
  student_code: 'HS1',
  full_name: 'An',
  ops_status_code: 'CO_MAT',
  contact_reason_code: null,
  ops_note: null,
  teacher_status_code: null,
};
const s2: OpsStudent = {
  ...s1,
  student_id: 'b',
  student_code: 'HS2',
  full_name: 'Bình',
  ops_status_code: null,
};
const sheet: OpsSheet = {
  session: {
    id: 's',
    status_code: 'DA_CHOT',
    session_no: 1,
    session_date: '2026-10-20',
    start_time: '18:00',
    end_time: '19:30',
    class_id: 'c',
    class_code: 'L',
    subject_name: 'Toán',
  },
  statuses: [],
  reasons: [
    { code: 'KHONG_NGHE_MAY', name: 'Không nghe máy', requires_note: false },
    { code: 'KHAC', name: 'Khác', requires_note: true },
  ],
  listed: true,
  students: [s1, s2],
};

describe('bản nháp điểm danh vận hành', () => {
  it('sửa về đúng giá trị đã lưu thì bỏ khỏi bản nháp', () => {
    const d1 = patchDraft({}, s1, { status: 'VANG_CO_PHEP' });
    expect(Object.keys(d1)).toEqual(['a']);
    expect(Object.keys(patchDraft(d1, s1, { status: 'CO_MAT' }))).toEqual([]);
  });
  it('chỉ gửi em đã sửa, ghi chú rỗng thành null', () => {
    const d = patchDraft({}, s2, { reason: 'KHONG_NGHE_MAY' });
    expect(buildOpsEntries([s1, s2], d)).toEqual([
      { student_id: 'b', status_code: null, contact_reason_code: 'KHONG_NGHE_MAY', note: null },
    ]);
  });
  it('đếm em đã có trạng thái kể cả bản nháp', () => {
    expect(countOpsMarked([s1, s2], {})).toBe(1);
    expect(countOpsMarked([s1, s2], patchDraft({}, s2, { status: 'DI_MUON' }))).toBe(2);
    expect(cellOf(s2, {}).note).toBe('');
  });
  it('lý do "Khác" thiếu ghi chú bị báo', () => {
    const d = patchDraft({}, s2, { reason: 'KHAC' });
    expect(missingNote(sheet, d)).toEqual(['Bình']);
    expect(missingNote(sheet, patchDraft(d, s2, { note: 'Bận' }))).toEqual([]);
  });
});
