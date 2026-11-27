// K5 Calendar: ngày, tuần, tháng; màu và biểu tượng theo loại; bấm một sự kiện mở khung chi tiết với thao tác
// (Hoàn thành, Dời, Huỷ…). Loại sự kiện, giờ hiển thị, nhóm "theo người / theo phòng" do cấu hình truyền vào.
import { useMemo, useState, type ReactNode } from 'react';
import { Button, IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Icon, type IconName } from '../ui/icons';
import { Popover } from '../ui/Overlays';
import {
  addDays,
  layoutDay,
  monthGrid,
  sameDay,
  startOfDay,
  vnToday,
  vnWall,
  weekDays,
  type CalendarEvent,
} from './calendarLogic';

export type CalendarKind = {
  key: string;
  label: string;
  icon: IconName;
  /** Nền, chữ, viền của sự kiện theo tông của hệ thiết kế. */
  tone: 'info' | 'brand' | 'success' | 'warning' | 'danger' | 'neutral';
};

export type CalendarMode = 'day' | 'week' | 'month';

const TONE: Record<CalendarKind['tone'], string> = {
  info: 'border-info-border bg-info-subtle text-on-info-subtle',
  brand: 'border-brand-200 bg-brand-100 text-brand-800',
  success: 'border-transparent bg-success-subtle text-on-success-subtle',
  warning: 'border-transparent bg-warning-subtle text-on-warning-subtle',
  danger: 'border-transparent bg-danger-subtle text-on-danger-subtle',
  neutral: 'border-transparent bg-surface-subtle text-fg-muted',
};

const WEEKDAY = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
const HOUR_PX = 48; // allow-number: chiều cao một giờ trên lưới (bằng .hmt-calv-col của gói)
const PERCENT = 100; // allow-number: đổi tỉ lệ cột sang phần trăm
const MIN_EVENT_PX = 36; // allow-number: chiều cao tối thiểu của một sự kiện để đủ hai dòng chữ (thiết kế K5)
const TIME_COLUMN_PX = 64; // allow-number: bề rộng cột giờ bên trái lưới (bằng thiết kế K5)
const RESOURCE_COLUMN_PX = 160; // allow-number: bề rộng tối thiểu của một cột người hoặc phòng, hơn thì cuộn ngang
const MAX_MONTH_CHIPS = 2; // allow-number: tối đa 2 sự kiện mỗi ô tháng, dư gộp "+n" (thiết kế K5)

const pad = (n: number) => String(n).padStart(2, '0');
const hhmm = (d: Date) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const dm = (d: Date) => `${pad(d.getDate())}/${pad(d.getMonth() + 1)}`;
const dmy = (d: Date) => `${dm(d)}/${d.getFullYear()}`;

function rangeTitle(mode: CalendarMode, anchor: Date): string {
  if (mode === 'day') return dmy(anchor);
  if (mode === 'week') {
    const days = weekDays(anchor);
    return `${dmy(days[0] ?? anchor)} – ${dmy(days[6] ?? anchor)}`;
  }
  return `Tháng ${anchor.getMonth() + 1}/${anchor.getFullYear()}`;
}

export function CalendarView({
  events: rawEvents,
  kinds,
  mode,
  onModeChange,
  anchor,
  onAnchorChange,
  today = vnToday(),
  startHour,
  endHour,
  resources,
  resourceMode = 'all',
  onResourceModeChange,
  renderDetail,
  now,
  modes = ['day', 'week', 'month'],
  legend,
}: {
  events: CalendarEvent[];
  kinds: CalendarKind[];
  mode: CalendarMode;
  onModeChange: (mode: CalendarMode) => void;
  anchor: Date;
  onAnchorChange: (date: Date) => void;
  today?: Date | undefined;
  /** Khoảng giờ hiện trên lưới ngày, tuần (theo cấu hình của màn, không viết cứng). */
  startHour: number;
  endHour: number;
  /** Danh sách người hoặc phòng để xem theo cột trong chế độ Ngày. */
  resources?: { people: string[]; rooms: string[] } | undefined;
  resourceMode?: 'all' | 'people' | 'rooms' | undefined;
  onResourceModeChange?: ((m: 'all' | 'people' | 'rooms') => void) | undefined;
  /** Nội dung khung chi tiết khi bấm sự kiện (thông tin + nút thao tác). */
  renderDetail: (event: CalendarEvent, close: () => void) => ReactNode;
  /** Giờ hiện tại để vẽ vạch "bây giờ"; không truyền thì không vẽ. */
  now?: Date | undefined;
  /** Các kiểu xem cho chọn (một kiểu thì không hiện nút chọn). */
  modes?: CalendarMode[];
  /** Chú thích thay cho dải chú thích theo loại, Hoàn thành, Huỷ. */
  legend?: ReactNode;
}) {
  // Sự kiện đổi sang giờ treo tường Việt Nam trước khi nhóm theo ngày và vẽ theo giờ (R-HT-07); nội dung chi tiết chỉ dùng id.
  const events = useMemo(
    () => rawEvents.map((e) => ({ ...e, start: vnWall(e.start), end: vnWall(e.end) })),
    [rawEvents],
  );
  const nowWall = useMemo(() => (now ? vnWall(now) : undefined), [now]);
  const kindOf = (key: string) => kinds.find((k) => k.key === key);
  const hours = Array.from({ length: endHour - startHour + 1 }, (_, i) => startHour + i);
  const step = mode === 'day' ? 1 : mode === 'week' ? 7 : 0;
  const shift = (n: number) =>
    mode === 'month'
      ? onAnchorChange(new Date(anchor.getFullYear(), anchor.getMonth() + n, 1))
      : onAnchorChange(addDays(anchor, n * step));

  const resourceColumns = mode === 'day' && resourceMode !== 'all' && resources !== undefined;
  const columns =
    mode === 'day' && resourceMode !== 'all' && resources
      ? (resourceMode === 'people' ? resources.people : resources.rooms).map((r) => ({
          key: r,
          label: r,
          day: anchor,
          filter: (e: CalendarEvent) => e.resource === r,
        }))
      : (mode === 'day' ? [anchor] : weekDays(anchor)).map((d) => ({
          key: d.toISOString(),
          label: '',
          day: d,
          filter: () => true,
        }));

  const eventButton = (e: CalendarEvent, layout: 'grid' | 'month', style?: React.CSSProperties) => {
    const kind = kindOf(e.kind);
    const cancelled = e.status === 'cancelled';
    const done = e.status === 'done';
    return (
      <EventButton
        key={e.id}
        event={e}
        layout={layout}
        style={style}
        icon={kind?.icon ?? 'calendar'}
        toneClass={done || cancelled ? TONE.neutral : TONE[kind?.tone ?? 'neutral']}
        cancelled={cancelled}
        done={done}
        kindLabel={kind?.label ?? e.kind}
        renderDetail={renderDetail}
      />
    );
  };

  const monthDays = useMemo(() => monthGrid(anchor), [anchor]);

  return (
    <div className="overflow-hidden rounded-box border border-border bg-surface">
      <div className="flex flex-wrap items-center gap-2 border-b border-border px-4 py-2.5">
        <Button size="sm" onClick={() => onAnchorChange(startOfDay(today))}>
          Hôm nay
        </Button>
        <IconButton icon="chevronLeft" label="Kỳ trước" onClick={() => shift(-1)} />
        <IconButton icon="chevronRight" label="Kỳ sau" onClick={() => shift(1)} />
        <h2 className="tabular mx-2 font-display text-h3">{rangeTitle(mode, anchor)}</h2>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          {modes.length > 1 && (
            <Segmented
              label="Kiểu xem lịch"
              value={mode}
              onChange={(v) => onModeChange(v as CalendarMode)}
              options={[
                { value: 'day', label: 'Ngày' },
                { value: 'week', label: 'Tuần' },
                { value: 'month', label: 'Tháng' },
              ].filter((o) => modes.includes(o.value as CalendarMode))}
            />
          )}
          {resources && onResourceModeChange && (
            <Segmented
              label="Nhóm lịch"
              value={resourceMode}
              onChange={(v) => onResourceModeChange(v as 'all' | 'people' | 'rooms')}
              options={[
                { value: 'all', label: 'Tất cả' },
                { value: 'people', label: 'Theo người' },
                // Màn không có phòng (Lịch hẹn) không truyền danh sách phòng thì không hiện "Theo phòng".
                ...(resources.rooms.length > 0 ? [{ value: 'rooms', label: 'Theo phòng' }] : []),
              ]}
            />
          )}
        </div>
      </div>
      {legend ?? (
        <ul className="flex flex-wrap gap-3 border-b border-border px-4 py-2 text-caption text-fg-label">
          {kinds.map((k) => (
            <li key={k.key} className="inline-flex items-center gap-1.5">
              <span aria-hidden="true" className={cn('size-3 rounded-tag border', TONE[k.tone])} />
              <Icon name={k.icon} size={16} />
              {k.label}
            </li>
          ))}
          <li className="inline-flex items-center gap-1.5">
            <Icon name="done" size={16} /> Hoàn thành
          </li>
          <li className="inline-flex items-center gap-1.5">
            <Icon name="cancelled" size={16} /> Huỷ
          </li>
        </ul>
      )}

      {mode === 'month' ? (
        <div className="grid grid-cols-7">
          {WEEKDAY.slice(1)
            .concat(WEEKDAY[0] ?? 'CN')
            .map((w) => (
              <div
                key={w}
                className="border-b border-border p-2 text-caption font-semibold text-fg-muted"
              >
                {w}
              </div>
            ))}
          {monthDays.map((d) => {
            const dayEvents = events
              .filter((e) => sameDay(e.start, d))
              .sort((a, b) => a.start.getTime() - b.start.getTime());
            const out = d.getMonth() !== anchor.getMonth();
            const isToday = sameDay(d, today);
            return (
              <div
                key={d.toISOString()}
                className="flex min-h-[104px] flex-col gap-0.5 border-t border-l border-surface-subtle p-1"
              >
                <b
                  className={cn(
                    'tabular self-start px-1 py-0.5 text-caption font-semibold',
                    out && 'font-normal text-fg-muted',
                    isToday && 'rounded-full bg-action text-on-action',
                  )}
                >
                  {d.getDate()}
                </b>
                {dayEvents.slice(0, MAX_MONTH_CHIPS).map((e) => eventButton(e, 'month'))}
                {dayEvents.length > MAX_MONTH_CHIPS && (
                  <button
                    type="button"
                    onClick={() => {
                      onAnchorChange(d);
                      onModeChange('day');
                    }}
                    className="focus-ring self-start rounded-tag px-1.5 text-caption font-semibold text-link hover:bg-hover"
                  >
                    +{dayEvents.length - MAX_MONTH_CHIPS} buổi
                  </button>
                )}
              </div>
            );
          })}
        </div>
      ) : (
        <div className="overflow-x-auto">
          <div
            className="grid min-w-[640px]"
            style={
              resourceColumns
                ? {
                    // Nhiều người: mỗi cột người rộng tối thiểu, bảng cuộn ngang (Đ34).
                    minWidth: RESOURCE_COLUMN_PX * columns.length + TIME_COLUMN_PX,
                    gridTemplateColumns: `${TIME_COLUMN_PX}px repeat(${columns.length}, minmax(${RESOURCE_COLUMN_PX}px, 1fr))`,
                  }
                : {
                    gridTemplateColumns: `${TIME_COLUMN_PX}px repeat(${columns.length}, minmax(0, 1fr))`,
                  }
            }
          >
            <div className="h-12 border-b border-border" />
            {columns.map((c) => {
              const isToday = sameDay(c.day, today);
              return (
                <div
                  key={c.key}
                  className={cn(
                    'flex h-12 flex-col items-center justify-center border-b border-l border-surface-subtle',
                    c.label !== '' && 'items-start px-2',
                  )}
                >
                  {c.label !== '' ? (
                    <b className="text-body font-semibold">{c.label}</b>
                  ) : (
                    <>
                      <span className="text-caption font-semibold text-fg-muted">
                        {WEEKDAY[c.day.getDay()]}
                      </span>
                      <b
                        className={cn(
                          'tabular min-w-7 text-center text-body-lg font-semibold',
                          isToday && 'rounded-full bg-action px-1 text-on-action',
                        )}
                      >
                        {c.day.getDate()}
                      </b>
                    </>
                  )}
                </div>
              );
            })}
            <div className="relative" style={{ height: hours.length * HOUR_PX }}>
              {hours.map((h, i) => (
                <span
                  key={h}
                  className="tabular absolute right-2 -translate-y-1/2 bg-surface px-0.5 text-caption text-fg-muted"
                  style={{ top: i * HOUR_PX }}
                >
                  {pad(h)}:00
                </span>
              ))}
            </div>
            {columns.map((c) => {
              const placed = layoutDay(
                events.filter(c.filter),
                c.day,
                startHour,
                endHour + 1,
                HOUR_PX,
                MIN_EVENT_PX,
              );
              const isToday = sameDay(c.day, today);
              return (
                <div
                  key={c.key}
                  className={cn(
                    'relative border-l border-surface-subtle',
                    isToday && 'bg-brand-50',
                  )}
                  style={{
                    height: hours.length * HOUR_PX,
                    backgroundImage:
                      'repeating-linear-gradient(to bottom, var(--bg-subtle) 0 1px, transparent 1px 48px)',
                  }}
                >
                  {placed.map((p) =>
                    eventButton(p, 'grid', {
                      top: p.top,
                      height: p.height,
                      left: `calc(${(p.lane / p.lanes) * PERCENT}% + 3px)`,
                      width: `calc(${PERCENT / p.lanes}% - 6px)`,
                    }),
                  )}
                  {isToday &&
                    nowWall &&
                    nowWall.getHours() >= startHour &&
                    nowWall.getHours() <= endHour && (
                      <div
                        aria-hidden="true"
                        className="pointer-events-none absolute right-0 left-0 z-[1] h-0.5 bg-focus"
                        style={{
                          top:
                            (nowWall.getHours() - startHour) * HOUR_PX +
                            (nowWall.getMinutes() / 60) * HOUR_PX, // allow-number: 60 phút một giờ
                        }}
                      />
                    )}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

function Segmented({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <div
      role="group"
      aria-label={label}
      className="inline-flex overflow-hidden rounded-control border border-border-strong"
    >
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={value === o.value}
          onClick={() => onChange(o.value)}
          className={cn(
            'focus-ring tap h-[30px] border-r border-border px-3 text-body last:border-r-0',
            value === o.value
              ? 'bg-selected font-semibold text-brand-800'
              : 'bg-surface text-fg-label hover:bg-hover',
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

function EventButton({
  event,
  layout,
  style,
  icon,
  toneClass,
  cancelled,
  done,
  kindLabel,
  renderDetail,
}: {
  event: CalendarEvent;
  layout: 'grid' | 'month';
  style?: React.CSSProperties | undefined;
  icon: IconName;
  toneClass: string;
  cancelled: boolean;
  done: boolean;
  kindLabel: string;
  renderDetail: (event: CalendarEvent, close: () => void) => ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const time = `${hhmm(event.start)}–${hhmm(event.end)}`;
  const status = cancelled ? 'đã huỷ' : done ? 'đã hoàn thành' : '';
  return (
    <Popover
      open={open}
      onOpenChange={setOpen}
      className="w-80"
      trigger={
        <button
          type="button"
          style={style}
          className={cn(
            'focus-ring overflow-hidden rounded-tag border px-1.5 py-0.5 text-left text-caption hover:shadow-2',
            layout === 'grid' ? 'absolute flex flex-col gap-px' : 'flex items-center gap-1',
            toneClass,
            cancelled && 'border-dashed',
          )}
        >
          {/* Tên đọc lấy từ chính chữ trong thẻ (luật axe label-content-name-mismatch): loại sự kiện ở đầu, trạng thái ở cuối chỉ cho trình đọc màn hình. */}
          <span className="sr-only">{kindLabel}: </span>
          <b
            className={cn(
              'flex items-center gap-1 truncate font-semibold whitespace-nowrap',
              (done || cancelled) && 'line-through',
            )}
          >
            <Icon name={icon} size={16} className="shrink-0" />
            <span className="truncate">{event.title}</span>
          </b>
          {layout === 'grid' ? (
            <>
              <span className="tabular truncate">{time}</span>
              {event.subtitle && <span className="truncate">{event.subtitle}</span>}
            </>
          ) : (
            <span className="tabular shrink-0">{hhmm(event.start)}</span>
          )}
          {status && <span className="sr-only">, {status}</span>}
        </button>
      }
    >
      {renderDetail(event, () => setOpen(false))}
    </Popover>
  );
}
