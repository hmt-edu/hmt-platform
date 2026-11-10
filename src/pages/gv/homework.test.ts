import { describe, expect, it } from 'vitest';
import {
  anyDirty,
  buildSaveItems,
  countWithStatus,
  draftError,
  initialDraft,
  isGradingEditable,
  isRowDirty,
  needsScore,
  withStatus,
  type Draft,
  type GradingRow,
} from './homework';

const row = (over: Partial<GradingRow> = {}): GradingRow => ({
  student_id: 's1',
  full_name: 'Em A',
  attendance_code: 'CO_MAT',
  absent_at_assignment: false,
  result: null,
  ...over,
});

describe('Chấm BTVN buổi trước (GV-08)', () => {
  it('chỉ Đã chấm và Làm chưa xong có điểm', () => {
    expect(needsScore('DA_CHAM')).toBe(true);
    expect(needsScore('LAM_CHUA_XONG')).toBe(true);
    for (const s of ['KHONG_LAM', 'NOP_SAU', 'KHONG_AP_DUNG', null] as const)
      expect(needsScore(s)).toBe(false);
  });

  it('em vắng buổi giao bài: đặt sẵn Không áp dụng; em thường: chưa chọn', () => {
    expect(initialDraft(row({ absent_at_assignment: true })).status).toBe('KHONG_AP_DUNG');
    expect(initialDraft(row()).status).toBeNull();
  });

  it('kết quả đã lưu thành bản nháp ban đầu', () => {
    const r = row({ result: { status_code: 'DA_CHAM', score: 4, note: 'tốt', version: 2 } });
    expect(initialDraft(r)).toEqual({ status: 'DA_CHAM', score: 4, note: 'tốt' });
  });

  it('đổi sang trạng thái không điểm thì bỏ điểm (Không làm không phải điểm 0)', () => {
    const d: Draft = { status: 'DA_CHAM', score: 5, note: '' };
    expect(withStatus(d, 'KHONG_LAM').score).toBeNull();
    expect(withStatus(d, 'LAM_CHUA_XONG').score).toBe(5);
  });

  it('lỗi: chưa chọn trạng thái, thiếu điểm', () => {
    expect(draftError({ status: null, score: null, note: '' })).toBe('Chọn một trạng thái.');
    expect(draftError({ status: 'DA_CHAM', score: null, note: '' })).toBe('Chọn điểm 1–5.');
    expect(draftError({ status: 'KHONG_LAM', score: null, note: '' })).toBeNull();
  });

  it('lô lưu chỉ gồm em đã sửa, kèm phiên bản dòng (0 nếu chưa có)', () => {
    const rows = [
      row(),
      row({
        student_id: 's2',
        result: { status_code: 'NOP_SAU', score: null, note: null, version: 3 },
      }),
    ];
    const drafts = {
      s1: { status: 'DA_CHAM', score: 4, note: ' ok ' } as Draft,
      s2: initialDraft(rows[1]!),
    };
    expect(buildSaveItems(rows, drafts)).toEqual([
      { student_id: 's1', status_code: 'DA_CHAM', score: 4, note: 'ok', expected_version: 0 },
    ]);
    drafts.s2 = { status: 'KHONG_LAM', score: null, note: '' };
    expect(buildSaveItems(rows, drafts)?.[1]?.expected_version).toBe(3);
  });

  it('có dòng sửa dở thì không lưu được', () => {
    const rows = [row()];
    expect(buildSaveItems(rows, { s1: { status: 'DA_CHAM', score: null, note: '' } })).toBeNull();
  });

  it('đếm em đã có trạng thái và nhận ra thay đổi chưa lưu', () => {
    const rows = [row(), row({ student_id: 's2', absent_at_assignment: true })];
    expect(countWithStatus(rows, {})).toBe(1);
    expect(anyDirty(rows, {})).toBe(false);
    expect(isRowDirty(rows[0]!, { status: 'KHONG_LAM', score: null, note: '' })).toBe(true);
    expect(anyDirty(rows, { s1: { status: 'KHONG_LAM', score: null, note: '' } })).toBe(true);
  });

  it('chỉ buổi Đã chốt mới chấm được', () => {
    expect(isGradingEditable('DA_CHOT')).toBe(true);
    for (const s of ['NHAP', 'DONE', 'HUY_KHONG_PHI']) expect(isGradingEditable(s)).toBe(false);
  });
});
