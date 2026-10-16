// Mốc nhanh của khoảng ngày (Hôm nay, Tuần này, Tháng này, Tháng trước). Tuần bắt đầu từ thứ Hai.

/** Khoảng ngày của một mốc nhanh. Tuần bắt đầu từ thứ Hai. `to` tính hết ngày. */
export function datePresetRange(preset: string, today: Date): { from: Date; to: Date } | null {
  const day = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const DAY = 86_400_000; // allow-number: số mili giây trong một ngày
  const WEEK = 7; // allow-number: số ngày trong tuần
  const endOf = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1).getTime() - 1;
  switch (preset) {
    case 'today':
      return { from: day, to: new Date(endOf(day)) };
    case 'week': {
      const monday = new Date(day.getTime() - ((day.getDay() + WEEK - 1) % WEEK) * DAY);
      return { from: monday, to: new Date(endOf(new Date(monday.getTime() + (WEEK - 1) * DAY))) };
    }
    case 'month':
      return {
        from: new Date(day.getFullYear(), day.getMonth(), 1),
        to: new Date(endOf(new Date(day.getFullYear(), day.getMonth() + 1, 0))),
      };
    case 'last-month':
      return {
        from: new Date(day.getFullYear(), day.getMonth() - 1, 1),
        to: new Date(endOf(new Date(day.getFullYear(), day.getMonth(), 0))),
      };
    default:
      return null;
  }
}
