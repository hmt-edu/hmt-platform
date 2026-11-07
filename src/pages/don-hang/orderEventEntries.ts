// Đổi sự kiện của đơn hàng (get_order.events) thành mục dòng thời gian bên phải (Q-48, Q-51): mỗi lần lưu một mục, không còn khối "Lịch sử xử lý"
// cuối trang. Hàm thuần, có kiểm thử. Tổng tiền lấy từ ảnh chụp ở từng sự kiện (cột total_amount); giao diện không tính tiền.
import { formatMoney } from '../../lib/format';
import type { ChatterEntry } from '../../ui/Chatter';
import type { OrderEvent } from './orderTypes';

const EDITED_FROM_QUOTE = 'Đơn đã sửa so với báo giá';

/** Tách lời nhật ký thành các dòng (migration 080: tiêu đề rồi mỗi thay đổi một dòng). Lời cũ một dòng thì giữ nguyên một dòng. */
export function noteLines(note: string | null | undefined): string[] {
  return (note ?? '')
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l !== '');
}

/** Lý do từ chối hoặc huỷ kèm ghi chú: "Thiếu thông tin: ghi chú". `name` đổi mã lý do thành tên trong danh mục. */
export function reasonLine(
  e: Pick<OrderEvent, 'event_code' | 'reason_code' | 'note'>,
  name: (catalog: string, code: string | null | undefined) => string | undefined,
): string {
  const catalog = e.event_code === 'HUY' ? 'ORDER_CANCEL_REASON' : 'REJECT_REASON';
  const reason = e.reason_code ? (name(catalog, e.reason_code) ?? e.reason_code) : '';
  return [reason, e.note].filter(Boolean).join(': ');
}

/** Tiêu đề và các dòng của sự kiện SUA. Tiêu đề đơn từ báo giá: "Sửa đơn (đã sửa so với báo giá BG-xxx)". */
function editParts(note: string | null): { title: string; lines: string[] } {
  const lines = noteLines(note);
  const first = lines[0] ?? '';
  if (first.startsWith(EDITED_FROM_QUOTE)) {
    // Lời mới: tiêu đề một dòng rồi các thay đổi; lời cũ: "Đơn đã sửa so với báo giá BG-1: dòng 1 …" cùng một dòng.
    const [head = '', ...tail] = first.split(': ');
    const rest = tail.join(': ');
    return {
      title: `Sửa đơn (${head.replace(/^Đơn đã/, 'đã')})`,
      lines: [...(rest ? [rest] : []), ...lines.slice(1)],
    };
  }
  if (first.startsWith('Sửa đơn: '))
    return { title: 'Sửa đơn', lines: [first.slice('Sửa đơn: '.length), ...lines.slice(1)] };
  if (first === 'Sửa đơn') return { title: 'Sửa đơn', lines: lines.slice(1) };
  return { title: 'Sửa đơn', lines };
}

/** Câu gọn cho hộp Duyệt: "BG-1: dòng 1 (LC-TOAN-K09): số giờ 6 → 8; dòng 2 …" từ lời nhật ký "Đơn đã sửa so với báo giá" (cả lời cũ và lời mới). */
export function editedNoteText(note: string): string {
  const lines = noteLines(note);
  const [head = ''] = (lines[0] ?? '').split(': ');
  const code = head.replace(EDITED_FROM_QUOTE, '').trim();
  const { lines: detail } = editParts(note);
  return [code, detail.join('; ')].filter(Boolean).join(': ');
}

/** Dòng "Tổng tiền" của một sự kiện: Tạo, Duyệt hiện số tiền; Sửa hiện cũ → mới khi đổi (cũ lấy từ sự kiện liền trước; liền trước chưa có số thì chỉ hiện số mới). Chính sự kiện thiếu số thì không hiện. */
function totalLine(e: OrderEvent, previous: OrderEvent | undefined): string | undefined {
  if (e.total_amount === null || e.total_amount === undefined) return undefined;
  if (e.event_code === 'SUA') {
    const before = previous?.total_amount;
    // Sự kiện liền trước ghi trước 07/11 (chưa có ảnh chụp): chỉ hiện số mới.
    if (before === null || before === undefined) return `Tổng tiền: ${formatMoney(e.total_amount)}`;
    if (before === e.total_amount) return undefined;
    return `Tổng tiền: ${formatMoney(before)} → ${formatMoney(e.total_amount)}`;
  }
  if (e.event_code === 'TAO' || e.event_code === 'DUYET')
    return `Tổng tiền: ${formatMoney(e.total_amount)}`;
  return undefined;
}

/** Mục dòng thời gian của từng sự kiện đơn (mới nhất xếp trước ở khung chung). */
export function orderEventEntries(
  events: OrderEvent[],
  name: (catalog: string, code: string | null | undefined) => string | undefined,
): ChatterEntry[] {
  const sorted = [...events].sort((a, b) => a.seq - b.seq);
  return sorted.map<ChatterEntry>((e, i) => {
    const base = {
      kind: 'event' as const,
      id: `order-event-${e.seq}`,
      at: e.created_at,
      author: e.actor_name ?? 'Hệ thống',
    };
    const total = totalLine(e, sorted[i - 1]);
    switch (e.event_code) {
      case 'TAO':
        return { ...base, title: 'Tạo đơn hàng', lines: [], total };
      case 'SUA': {
        const { title, lines } = editParts(e.note);
        return { ...base, title, lines, total };
      }
      case 'TRINH':
        // Trình lại chưa sửa từ lần bị từ chối: dòng cảnh báo vàng (Q-29, Q-51).
        return { ...base, title: 'Trình duyệt', lines: [], warning: e.note ?? undefined };
      case 'DUYET':
        return {
          ...base,
          title: e.on_behalf ? 'Duyệt đơn (thay người duyệt)' : 'Duyệt đơn',
          lines: noteLines(e.note),
          total,
        };
      case 'TU_CHOI':
        return { ...base, title: 'Từ chối', lines: [reasonLine(e, name)].filter(Boolean) };
      case 'HUY':
        return {
          ...base,
          title: e.on_behalf ? 'Huỷ đơn (thay người duyệt)' : 'Huỷ đơn',
          lines: [reasonLine(e, name)].filter(Boolean),
        };
    }
  });
}
