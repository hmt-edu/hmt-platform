// Hàm thuần của trung tâm thông báo (CHUNG-12): đường dẫn mở bản ghi, nhãn thời gian tương đối, lọc "chưa đọc".
export type NotificationRow = {
  id: string;
  kind: string;
  title: string;
  entity_type: string | null;
  entity_id: string | null;
  actor_id: string | null;
  read_at: string | null;
  created_at: string;
};

const PATHS: Record<string, (id: string) => string> = {
  LEAD: (id) => `/crm/lead/${id}`,
  OPPORTUNITY: (id) => `/crm/co-hoi/${id}`,
  PARENT: (id) => `/crm/phu-huynh/${id}`,
  STUDENT: (id) => `/crm/hoc-sinh/${id}`,
  STUDENT_TEST: (id) => `/crm/phieu-kiem-tra/${id}`,
  QUOTATION: (id) => `/crm/bao-gia/${id}`,
  SALES_ORDER: (id) => `/crm/don-hang/${id}`,
  RECEIPT: (id) => `/crm/phieu-thu/${id}`,
  USER_ACCOUNT: (id) => `/crm/quan-tri/nguoi-dung/${id}`,
};

/** Nơi mở bản ghi của thông báo; null khi thông báo không gắn bản ghi hoặc loại bản ghi chưa có màn. */
export function notificationPath(
  n: Pick<NotificationRow, 'entity_type' | 'entity_id'>,
): string | null {
  if (!n.entity_type || !n.entity_id) return null;
  return PATHS[n.entity_type]?.(n.entity_id) ?? null;
}

const MINUTE_MS = 60_000; // allow-number: số mili giây trong một phút
const HOUR_MIN = 60; // allow-number: số phút trong một giờ
const DAY_HOUR = 24; // allow-number: số giờ trong một ngày

/** "Vừa xong", "10 phút trước", "2 giờ trước", "3 ngày trước". */
export function timeAgo(iso: string, now: Date): string {
  const minutes = Math.max(0, Math.floor((now.getTime() - new Date(iso).getTime()) / MINUTE_MS));
  if (minutes < 1) return 'Vừa xong';
  if (minutes < HOUR_MIN) return `${minutes} phút trước`;
  const hours = Math.floor(minutes / HOUR_MIN);
  if (hours < DAY_HOUR) return `${hours} giờ trước`;
  return `${Math.floor(hours / DAY_HOUR)} ngày trước`;
}
