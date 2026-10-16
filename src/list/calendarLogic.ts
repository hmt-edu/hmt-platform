// Logic thuần của Calendar (K5): các ngày của tuần và tháng (tuần bắt đầu thứ Hai), vị trí sự kiện trong ngày,
// xếp các sự kiện trùng giờ cạnh nhau.
export type CalendarEvent = {
  id: string;
  title: string;
  start: Date;
  end: Date;
  /** Loại (khoá trong cấu hình loại của màn): quyết định màu, biểu tượng. */
  kind: string;
  status?: 'open' | 'done' | 'cancelled' | undefined;
  /** Người hoặc phòng (khi xem "Theo người", "Theo phòng"). */
  resource?: string | undefined;
  /** Dòng phụ (mã bản ghi, cơ sở…). */
  subtitle?: string | undefined;
};

const DAY_MS = 86_400_000; // allow-number: số mili giây trong một ngày
const WEEK = 7; // allow-number: số ngày trong tuần
const MS_PER_HOUR = 3_600_000; // allow-number: số mili giây trong một giờ
const MONTH_ROWS = 6; // allow-number: lưới tháng luôn 6 tuần để không nhảy chiều cao

export const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
export const addDays = (d: Date, n: number) =>
  new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
export const sameDay = (a: Date, b: Date) =>
  a.getFullYear() === b.getFullYear() &&
  a.getMonth() === b.getMonth() &&
  a.getDate() === b.getDate();

/** Thứ Hai của tuần chứa ngày `d`. */
export function mondayOf(d: Date): Date {
  const day = startOfDay(d);
  return addDays(day, -((day.getDay() + WEEK - 1) % WEEK));
}

export function weekDays(anchor: Date): Date[] {
  const monday = mondayOf(anchor);
  return Array.from({ length: WEEK }, (_, i) => addDays(monday, i));
}

/** Lưới tháng: 6 tuần, bắt đầu từ thứ Hai của tuần chứa ngày 1. */
export function monthGrid(anchor: Date): Date[] {
  const first = new Date(anchor.getFullYear(), anchor.getMonth(), 1);
  const start = mondayOf(first);
  return Array.from({ length: MONTH_ROWS * WEEK }, (_, i) => addDays(start, i));
}

export type Placed = CalendarEvent & {
  top: number;
  height: number;
  /** Cột và số cột khi các sự kiện trùng giờ đứng cạnh nhau. */
  lane: number;
  lanes: number;
};

/**
 * Vị trí các sự kiện của một ngày trên lưới giờ. `hourHeight` là chiều cao một giờ (px); sự kiện nằm ngoài
 * khoảng giờ hiển thị được kẹp vào mép. Trùng giờ thì chia cột.
 */
export function layoutDay(
  events: CalendarEvent[],
  day: Date,
  startHour: number,
  endHour: number,
  hourHeight: number,
  minHeight = hourHeight / 2,
): Placed[] {
  const origin = startOfDay(day).getTime() + startHour * MS_PER_HOUR;
  const limit = startOfDay(day).getTime() + endHour * MS_PER_HOUR;
  const items = events
    .filter((e) => sameDay(e.start, day))
    .sort((a, b) => a.start.getTime() - b.start.getTime() || a.end.getTime() - b.end.getTime())
    .map((e) => {
      const s = Math.max(origin, Math.min(limit, e.start.getTime()));
      const t = Math.max(s, Math.min(limit, e.end.getTime()));
      return {
        ...e,
        top: ((s - origin) / MS_PER_HOUR) * hourHeight,
        height: Math.max(minHeight, ((t - s) / MS_PER_HOUR) * hourHeight),
        lane: 0,
        lanes: 1,
      };
    });

  // Chia cột theo từng cụm sự kiện chồng lên nhau.
  let cluster: typeof items = [];
  let clusterEnd = -Infinity;
  const flush = () => {
    const laneEnds: number[] = [];
    for (const item of cluster) {
      let lane = laneEnds.findIndex((end) => end <= item.top);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.push(0);
      }
      laneEnds[lane] = item.top + item.height;
      item.lane = lane;
    }
    for (const item of cluster) item.lanes = Math.max(1, laneEnds.length);
    cluster = [];
    clusterEnd = -Infinity;
  };
  for (const item of items) {
    if (cluster.length > 0 && item.top >= clusterEnd) flush();
    cluster.push(item);
    clusterEnd = Math.max(clusterEnd, item.top + item.height);
  }
  flush();
  return items;
}

/** Số mili giây giữa hai ngày theo lịch (dùng để tính "đang ở tuần nào"). */
export function daysBetween(a: Date, b: Date): number {
  return Math.round((startOfDay(b).getTime() - startOfDay(a).getTime()) / DAY_MS);
}
