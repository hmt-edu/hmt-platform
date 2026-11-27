import { describe, expect, it } from 'vitest';
import { buildEntries } from '../chatter/entries';
import { contactErrors, type ContactDraft } from './contactForm';

const NOW = new Date('2026-11-27T03:00:00Z');
const ok: ContactDraft = {
  channel: 'GOI_DIEN',
  result: 'NGHE_MAY',
  body: 'Hỏi thăm giả',
  nextDate: null,
  nextTime: '',
};

describe('R-CRM-43: biểu mẫu ghi nhận liên hệ', () => {
  it('đủ kênh, kết quả, nội dung thì không lỗi; hẹn lần sau không bắt buộc', () => {
    expect(contactErrors(ok, null, NOW)).toEqual({});
  });

  it('chặn thiếu kênh, kết quả, nội dung', () => {
    const errors = contactErrors({ ...ok, channel: '', result: '', body: '  ' }, null, NOW);
    expect(Object.keys(errors)).toEqual(['channel', 'result', 'body']);
  });

  it('chặn hẹn lần sau thiếu giờ hoặc ở quá khứ', () => {
    expect(contactErrors({ ...ok, nextDate: NOW }, null, NOW).next).toBeDefined();
    const past = new Date(NOW.getTime() - 1);
    expect(
      contactErrors({ ...ok, nextDate: past, nextTime: '09:00' }, past, NOW).next,
    ).toBeDefined();
  });

  it('ghi chú có kênh thành mục liên hệ ở dòng thời gian, ghi chú thường thì không', () => {
    const note = { author_name: 'A', body: 'x', mention_names: [], at: NOW.toISOString() };
    const entries = buildEntries(
      [
        { ...note, id: '1', contact_channel: 'Zalo', contact_result: 'Từ chối' },
        { ...note, id: '2', contact_channel: null },
      ],
      [],
      { labels: {} },
      null,
    );
    expect(entries.map((e) => (e.kind === 'note' ? e.contact : null))).toEqual([
      'Zalo · Từ chối',
      undefined,
    ]);
  });
});
