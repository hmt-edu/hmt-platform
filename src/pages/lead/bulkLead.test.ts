import { describe, expect, it } from 'vitest';
import { skippedLines } from './skippedLines';
import { EMPTY_LEAD_STATE } from './leadConfig';
import { buildLeadFilters } from './leadFilters';

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
