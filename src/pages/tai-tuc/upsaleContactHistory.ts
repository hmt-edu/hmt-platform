// Lịch sử liên hệ của phiếu tái tục: gộp ghi chú «liên hệ» (có kênh) của hồ sơ phụ huynh và học sinh, mới nhất trước.
import type { NoteRow } from '../../features/chatter/entries';

export type ContactHistoryRow = { id: string; at: string; channel: string; result: string };

export function contactHistory(notes: NoteRow[]): ContactHistoryRow[] {
  return notes
    .flatMap((n) =>
      n.contact_channel
        ? [{ id: n.id, at: n.at, channel: n.contact_channel, result: n.contact_result ?? '' }]
        : [],
    )
    .sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
}
