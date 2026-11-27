// Hàm thuần của «Việc của tôi» (canvas 1bcc, VC01): ba nhóm, đường mở bản ghi, chữ hạn, tiêu đề thẻ. Có kiểm thử.
import { formatDate, formatDateTime, formatTime } from '../../lib/format';
import type { Urgency, WorkCard, WorkItem, WorkPage } from './workTypes';

export const URGENCY_GROUPS: {
  urgency: Urgency;
  count: keyof WorkPage['counts'];
  label: string;
  tone: 'danger' | 'warning' | 'neutral';
  empty: string;
}[] = [
  {
    urgency: 'NOW',
    count: 'now',
    label: 'Làm ngay',
    tone: 'danger',
    empty: 'Không có việc cần làm ngay.',
  },
  {
    urgency: 'TODAY',
    count: 'today',
    label: 'Hôm nay',
    tone: 'warning',
    empty: 'Không có việc hôm nay.',
  },
  {
    urgency: 'SOON',
    count: 'soon',
    label: 'Sắp tới',
    tone: 'neutral',
    empty: 'Không có việc sắp tới.',
  },
];

/** Nút mở của một việc: màn nơi làm việc đó. Việc chờ duyệt đi qua màn «Việc chờ tôi duyệt» (màn chuyên). */
export function itemLink(item: Pick<WorkItem, 'signal' | 'entity_id'>): {
  to: string;
  label: string;
} {
  switch (item.signal) {
    case 'APPOINTMENT':
      return { to: '/crm/lich-hen', label: 'Mở lịch hẹn' };
    case 'TEST':
      return { to: `/crm/phieu-kiem-tra/${item.entity_id}`, label: 'Mở phiếu' };
    case 'APPROVAL':
      return { to: '/crm/viec-cho-duyet', label: 'Mở hồ sơ' };
    case 'SESSION_PENDING':
      return { to: `/crm/buoi-hoc/${item.entity_id}`, label: 'Mở buổi' };
    case 'SESSION_NO_ATTENDANCE':
      return { to: `/crm/buoi-hoc/${item.entity_id}`, label: 'Mở điểm danh' };
    case 'ABSENT_TODAY':
      return { to: '/crm/diem-danh', label: 'Mở điểm danh' };
    case 'RENEWAL':
      return { to: `/crm/tai-tuc/${item.entity_id}`, label: 'Mở hồ sơ' };
  }
}

/** Việc đã quá hạn. Việc chờ duyệt không tính (mốc của nó là lúc đến lượt, luôn ở quá khứ). */
export function isOverdue(item: Pick<WorkItem, 'signal' | 'due_at'>, now: Date): boolean {
  if (item.signal === 'APPROVAL' || item.signal === 'ABSENT_TODAY' || item.signal === 'RENEWAL')
    return false;
  return item.due_at !== null && new Date(item.due_at).getTime() < now.getTime();
}

/** «Hẹn 24/11/2026 14:00», «Hạn …», «Gửi …»; trong hôm nay chỉ ghi giờ. Tái tục đã ghi ngày trong lý do nên bỏ. */
export function dueText(
  item: Pick<WorkItem, 'signal' | 'due_at'>,
  now: Date = new Date(),
): string | null {
  if (item.due_at === null || item.signal === 'RENEWAL') return null;
  const text =
    formatDate(item.due_at) === formatDate(now)
      ? formatTime(item.due_at)
      : formatDateTime(item.due_at);
  const prefix =
    item.signal === 'APPROVAL' ? 'Gửi' : item.signal === 'SESSION_PENDING' ? 'Hạn' : null;
  if (prefix) return `${prefix} ${text}`;
  return item.signal === 'APPOINTMENT' ? `Hẹn ${text}` : text;
}

/** Thẻ gom theo phụ huynh; lead chưa có phụ huynh hiện số điện thoại; việc đứng riêng (buổi, duyệt lớp) lấy tên loại việc. */
export function cardTitle(card: WorkCard): string {
  if (card.parent_name) return card.parent_name;
  if (card.phone) return card.phone;
  return card.items[0]?.signal === 'APPROVAL' ? 'Việc chờ duyệt' : 'Buổi học';
}

export function cardTag(
  card: WorkCard,
  now: Date,
): { label: string; tone: 'danger' | 'warning' | 'neutral' } {
  if (card.items.some((i) => isOverdue(i, now))) return { label: 'Quá hạn', tone: 'danger' };
  const group = URGENCY_GROUPS.find((g) => g.urgency === card.urgency)!;
  return { label: group.label, tone: group.tone };
}
