import { describe, expect, it } from 'vitest';
import type { NoteRow } from '../../features/chatter/entries';
import { contactHistory } from './upsaleContactHistory';

const note = (id: string, at: string, channel: string | null): NoteRow => ({
  id,
  at,
  author_name: 'CSKH',
  body: 'Nội dung',
  mention_names: [],
  source_label: null,
  contact_channel: channel,
  contact_result: channel ? 'Đã nghe máy' : null,
});

describe('contactHistory', () => {
  it('chỉ lấy lần liên hệ (bỏ ghi chú thường), gộp hai hồ sơ, mới nhất trước', () => {
    const rows = contactHistory([
      note('cu', '2026-11-01T03:00:00Z', 'Zalo'),
      note('ghi-chu', '2026-11-05T03:00:00Z', null),
      note('moi', '2026-11-03T03:00:00Z', 'Gọi điện'),
    ]);
    expect(rows.map((r) => r.id)).toEqual(['moi', 'cu']);
    expect(rows[0]).toMatchObject({ channel: 'Gọi điện', result: 'Đã nghe máy' });
  });
});
