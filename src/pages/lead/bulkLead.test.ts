import { describe, expect, it } from 'vitest';
import { skippedLines } from './skippedLines';
import { EMPTY_LEAD_STATE } from './leadConfig';
import { buildLeadFilters } from './leadFilters';
import { importBatchOption } from './importBatch';

describe('Huỷ lead hàng loạt, «Thùng rác»', () => {
  it('lọc «Thùng rác» gửi trash; «hiện lead đã gộp» chỉ gửi include_merged', () => {
    const of = (status: string[]) => buildLeadFilters({ ...EMPTY_LEAD_STATE, quick: { status } });
    expect(of(['trash'])).toEqual({ trash: true });
    expect(of(['merged'])).toEqual({ include_merged: true });
  });

  it('dòng bỏ qua nêu mã và lý do; lead không xem được thì không nêu mã', () => {
    expect(
      skippedLines({
        done: 1,
        skipped: [
          { id: 'a', code: 'LD000001', reason: 'Lead đã có 1 lịch hẹn nên không huỷ được.' },
          { id: 'b', code: null, reason: 'Bạn chỉ huỷ được lead của cơ sở mình.' },
        ],
      }),
    ).toEqual([
      'LD000001: Lead đã có 1 lịch hẹn nên không huỷ được.',
      'Lead không xem được: Bạn chỉ huỷ được lead của cơ sở mình.',
    ]);
  });
});

describe('lọc «Lần nhập» (R-CRM-45)', () => {
  it('gửi import_batch_id', () => {
    const state = {
      ...EMPTY_LEAD_STATE,
      conditions: [{ id: 'c1', field: 'import_batch', op: 'eq' as const, value: 'lo-1' }],
    };
    expect(buildLeadFilters(state)).toEqual({ import_batch_id: 'lo-1' });
  });

  it('nhãn lựa chọn nêu tệp, người nhập và số còn lại', () => {
    const option = importBatchOption({
      id: 'lo-1',
      created_at: '2026-11-27T07:05:00Z',
      file_name: null,
      importer_name: 'Giả Một',
      branch_code: 'CS1',
      imported_count: 3,
      active_count: 2,
    });
    expect(option.label).toBe('27/11/2026 14:05 · Giả Một · còn 2/3 lead');
  });
});
