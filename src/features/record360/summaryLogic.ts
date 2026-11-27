// Dựng thẻ tóm tắt và cờ cảnh báo đầu hồ sơ phụ huynh, học sinh (canvas a8d7: KH02_360, KH05_360) từ app.get_parent_summary,
// app.get_student_summary. Số, ngưỡng và quyền xem tiền do máy chủ quyết; ở đây chỉ đổi thành chữ.
import { formatDate, formatMoney, formatNumber } from '../../lib/format';

type LastContact = { at: string; channel: string | null; days: number } | null;
type Tickets = { open: number; overdue: number } | null;

type CommonSummary = {
  branch_id: string;
  upsale_id: string | null;
  tickets: Tickets;
  last_contact: LastContact;
  contact_visible: boolean;
  missing_review: number;
  days_since_created: number;
  stale_days: number;
};

export type ParentSummary = CommonSummary & {
  children_total: number;
  studying_names: string[];
  expiring_names: string[];
  money: {
    paid_total: number | null;
    debt: number | null;
    balance: number | null;
    overdue_days: number | null;
  };
};

export type StudentSummary = CommonSummary & {
  class: { id: string; code: string; subject_name: string } | null;
  next_session: { session_date: string; start_time: string; branch_code: string } | null;
  hours_left: number | null;
  expiring: boolean;
  attendance: { rate: number | null; window_days: number; absent_streak: number };
  last_score: { score: number; max_score: number | null; session_date: string } | null;
  care_staff: { name: string; branch_code: string } | null;
  absence_limit: number;
};

export type SummaryCard = {
  key: string;
  label: string;
  value: string;
  note?: string | undefined;
  danger?: boolean | undefined;
};

export type FlagTarget = 'finance' | 'tickets' | 'upsale' | 'contacts' | 'review' | 'attendance';
export type SummaryFlag = { target: FlagTarget; label: string };

const NONE = '—';
const HIDDEN = 'Ẩn';

const money = (value: number | null) => (value === null ? HIDDEN : formatMoney(value));
const overdue = (days: number | null) => (days === null ? undefined : `Quá hạn ${days} ngày`);

function ticketCard(tickets: Tickets): SummaryCard[] {
  if (!tickets) return [];
  return [
    {
      key: 'tickets',
      label: 'Ticket mở',
      value: String(tickets.open),
      ...(tickets.overdue > 0 ? { note: `${tickets.overdue} quá hạn`, danger: true } : {}),
    },
  ];
}

function contactCard(summary: CommonSummary): SummaryCard[] {
  if (!summary.contact_visible) return [];
  const last = summary.last_contact;
  const ago = last && (last.days === 0 ? 'hôm nay' : `${last.days} ngày trước`);
  return [
    {
      key: 'contact',
      label: 'Lần liên hệ cuối',
      value: last ? formatDate(last.at) : 'Chưa liên hệ',
      note: last ? [last.channel, ago].filter(Boolean).join(' · ') : undefined,
    },
  ];
}

export function parentCards(s: ParentSummary): SummaryCard[] {
  const m = s.money;
  return [
    {
      key: 'children',
      label: 'Con đang học',
      value: `${s.studying_names.length} / ${s.children_total}`,
      note: s.studying_names.join(', ') || undefined,
    },
    { key: 'paid', label: 'Tổng đã đóng', value: money(m.paid_total) },
    {
      key: 'debt',
      label: 'Còn nợ',
      value: money(m.debt),
      ...(m.debt !== null && m.overdue_days !== null
        ? { note: overdue(m.overdue_days), danger: true }
        : {}),
    },
    { key: 'balance', label: 'Số dư', value: money(m.balance) },
    ...ticketCard(s.tickets),
    ...contactCard(s),
  ];
}

/** Có ô tiền bị ẩn thì màn hiện câu giải thích (khung KH02_360_an_tien). */
export const hasHiddenMoney = (s: ParentSummary): boolean =>
  s.money.paid_total === null || s.money.debt === null || s.money.balance === null;

const WEEKDAYS = ['Chủ nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

export function studentCards(s: StudentSummary): SummaryCard[] {
  const next = s.next_session;
  const day = next ? new Date(`${next.session_date}T00:00:00Z`).getUTCDay() : 0;
  return [
    {
      key: 'class',
      label: 'Lớp đang học',
      value: s.class?.subject_name ?? NONE,
      note: s.class?.code,
    },
    {
      key: 'next',
      label: 'Buổi kế tiếp',
      value: next ? `${WEEKDAYS[day] ?? ''} ${formatDate(next.session_date).slice(0, 5)}` : NONE,
      note: next ? `${next.start_time.slice(0, 5)} · ${next.branch_code}` : undefined,
    },
    {
      key: 'hours',
      label: 'Giờ còn lại',
      value: s.hours_left === null ? NONE : `${formatNumber(s.hours_left)} giờ`,
      ...(s.expiring ? { note: 'Sắp hết giờ', danger: true } : {}),
    },
    {
      key: 'attendance',
      label: 'Chuyên cần',
      value: s.attendance.rate === null ? NONE : `${s.attendance.rate}%`,
      note: `${s.attendance.window_days} ngày gần nhất`,
    },
    {
      key: 'score',
      label: 'Điểm gần nhất',
      value: s.last_score ? formatNumber(s.last_score.score) : NONE,
      note: s.last_score ? formatDate(s.last_score.session_date) : undefined,
    },
    ...(s.care_staff
      ? [
          {
            key: 'care',
            label: 'CSKH phụ trách',
            value: s.care_staff.name,
            note: s.care_staff.branch_code,
          },
        ]
      : []),
    ...contactCard(s),
  ];
}

function staleFlag(s: CommonSummary): SummaryFlag[] {
  if (!s.contact_visible) return [];
  // Chưa liên hệ lần nào thì đếm từ ngày tạo hồ sơ.
  const days = s.last_contact?.days ?? s.days_since_created;
  return days >= s.stale_days
    ? [{ target: 'contacts', label: `Lâu chưa liên hệ · ${days} ngày` }]
    : [];
}

const ticketFlag = (t: Tickets): SummaryFlag[] =>
  t && t.overdue > 0 ? [{ target: 'tickets', label: 'Ticket quá hạn' }] : [];

const reviewFlag = (count: number): SummaryFlag[] =>
  count > 0 ? [{ target: 'review', label: `Thiếu nhận xét · ${count} buổi` }] : [];

export function parentFlags(s: ParentSummary): SummaryFlag[] {
  const days = s.money.overdue_days;
  return [
    ...(days === null ? [] : [{ target: 'finance' as const, label: `Nợ quá hạn ${days} ngày` }]),
    ...ticketFlag(s.tickets),
    ...(s.expiring_names.length > 0
      ? [{ target: 'upsale' as const, label: `Sắp hết giờ · ${s.expiring_names.join(', ')}` }]
      : []),
    ...staleFlag(s),
    ...reviewFlag(s.missing_review),
  ];
}

export function studentFlags(s: StudentSummary): SummaryFlag[] {
  const streak = s.attendance.absent_streak;
  return [
    ...(streak >= s.absence_limit
      ? [{ target: 'attendance' as const, label: `Vắng liên tiếp · ${streak} buổi` }]
      : []),
    ...ticketFlag(s.tickets),
    ...(s.expiring
      ? [
          {
            target: 'upsale' as const,
            label:
              s.hours_left === null
                ? 'Sắp hết giờ'
                : `Sắp hết giờ · ${formatNumber(s.hours_left)} giờ`,
          },
        ]
      : []),
    ...staleFlag(s),
    ...reviewFlag(s.missing_review),
  ];
}
