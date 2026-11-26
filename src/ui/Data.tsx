// Hiển thị dữ liệu: nhãn trạng thái, khung chờ, phân trang, bảng (K03), thanh thao tác hàng loạt.
import { useId, useState, type MouseEvent, type ReactNode } from 'react';
import { formatNumber } from '../lib/format';
import { Button, IconButton } from './Button';
import { cn } from './cn';
import { Icon, type IconName } from './icons';
import { NARROW_TABLE, useMedia } from './useMedia';

export type TagTone = 'neutral' | 'success' | 'warning' | 'danger' | 'info' | 'brand';

// Theo .hmt-tag của gói: cao 22px, bo 4px, chữ 12/500; nền nhạt, chữ đậm đủ tương phản.
const TAG_TONES: Record<TagTone, string> = {
  neutral: 'bg-surface-subtle text-fg-label',
  success: 'bg-success-subtle text-on-success-subtle',
  warning: 'bg-warning-subtle text-on-warning-subtle',
  danger: 'bg-danger-subtle text-on-danger-subtle',
  info: 'bg-info-subtle text-on-info-subtle',
  brand: 'bg-brand-100 text-brand-800',
};

/** Thẻ trạng thái: luôn có chữ, kèm chấm hoặc biểu tượng khi cần (không chỉ dùng màu). */
export function Tag({
  tone = 'neutral',
  icon,
  dot = false,
  children,
}: {
  tone?: TagTone | undefined;
  icon?: IconName | undefined;
  /** Chấm tròn cùng màu chữ ở đầu thẻ (kiểu "Hôm nay 16:00"). */
  dot?: boolean | undefined;
  children: ReactNode;
}) {
  return (
    <span
      className={cn(
        'inline-flex h-[22px] items-center gap-1 rounded-tag px-2 text-caption font-medium whitespace-nowrap',
        TAG_TONES[tone],
      )}
    >
      {dot && <span aria-hidden="true" className="size-2 shrink-0 rounded-full bg-current" />}
      {icon && <Icon name={icon} size={16} />}
      {children}
    </span>
  );
}

/** Mã nghiệp vụ (CO000121, DH-CS1-2610-0001): chữ số đều chiều rộng, màu phụ. */
export function Code({ children }: { children: ReactNode }) {
  return (
    <span className="tabular text-caption font-medium tracking-[0.01em] text-fg-muted">
      {children}
    </span>
  );
}

/** Khung chờ cho nội dung có cấu trúc; tắt hiệu ứng khi người dùng giảm chuyển động. */
export function Skeleton({ className }: { className?: string | undefined }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        'block h-4 animate-pulse rounded-tag bg-surface-subtle motion-reduce:animate-none',
        className,
      )}
    />
  );
}

/** Phân trang: "1–25 trên 1.287", nút trang trước / sau. Đổi trang giữ nguyên bộ lọc. */
export function Pagination({
  page,
  pageSize,
  total,
  onPageChange,
}: {
  /** Trang hiện tại, tính từ 1. */
  page: number;
  pageSize: number;
  total: number;
  onPageChange: (page: number) => void;
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const from = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const to = Math.min(total, page * pageSize);
  return (
    <nav
      aria-label="Phân trang"
      className="flex flex-wrap items-center justify-between gap-2 text-caption font-semibold text-fg-muted"
    >
      <p className="tabular" aria-live="polite">
        {formatNumber(from)}–{formatNumber(to)} trên {formatNumber(total)} · {pageSize} dòng mỗi
        trang
      </p>
      {pages > 1 && (
        <div className="flex items-center gap-2">
          <IconButton
            icon="chevronLeft"
            label="Trang trước"
            disabled={page <= 1}
            onClick={() => onPageChange(page - 1)}
          />
          <span className="tabular text-fg" aria-current="page">
            Trang {page}/{pages}
          </span>
          <IconButton
            icon="chevronRight"
            label="Trang sau"
            disabled={page >= pages}
            onClick={() => onPageChange(page + 1)}
          />
        </div>
      )}
    </nav>
  );
}

/** Nút nhóm (Group By) của bảng: tên, số dòng, nhóm con hoặc dòng của nhóm lá. */
export type TableGroup<Row> = {
  key: string;
  label: string;
  count: number;
  children: TableGroup<Row>[];
  rows: Row[];
  /** Nhóm lá tải dòng khi mở (Group By ở máy chủ): đang tải, và nút "Xem thêm" khi còn dòng chưa tải. */
  loading?: boolean | undefined;
  more?: { remaining: number; loading: boolean; onMore: () => void } | undefined;
};

type DisplayItem<Row> =
  | { kind: 'group'; group: TableGroup<Row>; depth: number; open: boolean }
  | { kind: 'row'; row: Row }
  | { kind: 'more'; group: TableGroup<Row>; depth: number }
  | { kind: 'loading'; group: TableGroup<Row>; depth: number };

/** `toggled`: các nhóm người dùng đã đảo trạng thái so với mặc định (mặc định mở, hoặc đóng khi `defaultOpen` sai). */
function flatten<Row>(
  groups: TableGroup<Row>[],
  toggled: ReadonlySet<string>,
  defaultOpen: boolean,
  depth = 0,
): DisplayItem<Row>[] {
  return groups.flatMap<DisplayItem<Row>>((group) => {
    const open = defaultOpen !== toggled.has(group.key);
    const leaf: DisplayItem<Row>[] = [
      ...group.rows.map((row) => ({ kind: 'row' as const, row })),
      ...(group.loading && group.rows.length === 0
        ? [{ kind: 'loading' as const, group, depth: depth + 1 }]
        : []),
      ...(group.more ? [{ kind: 'more' as const, group, depth: depth + 1 }] : []),
    ];
    const inner: DisplayItem<Row>[] = open
      ? group.children.length > 0
        ? flatten(group.children, toggled, defaultOpen, depth + 1)
        : leaf
      : [];
    return [{ kind: 'group' as const, group, depth, open }, ...inner];
  });
}

export type SortState = { key: string; direction: 'asc' | 'desc' } | null;

export type Column<Row> = {
  key: string;
  header: string;
  cell: (row: Row) => ReactNode;
  /** Số, tiền, ngày giờ: canh phải, chữ số đều cột. */
  numeric?: boolean | undefined;
  sortable?: boolean | undefined;
  /** Cột làm tiêu đề thẻ khi bảng thành danh sách thẻ trên điện thoại (mặc định: cột đầu). */
  primary?: boolean | undefined;
  className?: string | undefined;
};

/** Thanh thao tác hàng loạt: hiện khi chọn ít nhất một dòng, đọc số đã chọn cho trình đọc màn hình. */
export function BulkActionBar({
  count,
  onClear,
  children,
}: {
  count: number;
  onClear: () => void;
  children: ReactNode;
}) {
  if (count === 0) return null;
  return (
    <div className="flex flex-wrap items-center gap-2 rounded-control border border-brand-200 bg-selected px-3 py-2 text-on-selected">
      <p aria-live="polite" className="font-medium">
        Đã chọn {count}
      </p>
      <div className="flex flex-1 flex-wrap items-center gap-2">{children}</div>
      <Button variant="ghost" onClick={onClear}>
        Bỏ chọn
      </Button>
    </div>
  );
}

// Theo .hmt-table của gói: đầu cột 32px nền xám nhạt, hàng 36px, lề ô 10px (ô đầu, ô cuối 16px).
const CELL = 'px-2.5 align-middle first:pl-4 last:pr-4';
const CHECKBOX = 'size-4 accent-[var(--action-primary-bg)]';

/**
 * Bảng danh sách (K03). Dưới 640px tự thành danh sách thẻ: cột đầu là tiêu đề thẻ,
 * các cột khác thành cặp nhãn và giá trị.
 */
export function Table<Row>({
  caption,
  scrollFocusable = false,
  columns,
  rows,
  rowKey,
  rowLabel,
  loading = false,
  empty,
  sort = null,
  onSortChange,
  selected,
  onSelectedChange,
  skeletonRows = 5,
  groups,
  groupsDefaultOpen = true,
  onGroupToggle,
  rowMuted,
  onRowClick,
  keepHeader = false,
}: {
  /** Tên bảng cho trình đọc màn hình. */
  caption: string;
  /** Bảng rộng cuộn ngang mà không có ô nào bấm được (Dòng đơn): cho vùng cuộn nhận bàn phím để người dùng bàn phím cuộn được. */
  scrollFocusable?: boolean | undefined;
  columns: Column<Row>[];
  rows: Row[];
  rowKey: (row: Row) => string;
  /** Tên dòng để đọc ô chọn: "Chọn <tên>". */
  rowLabel: (row: Row) => string;
  loading?: boolean | undefined;
  /** Nội dung khi không có dòng nào (StateView gọn). */
  empty: ReactNode;
  sort?: SortState | undefined;
  onSortChange?: ((sort: SortState) => void) | undefined;
  /** Có thì bảng chọn nhiều dòng được. */
  selected?: ReadonlySet<string> | undefined;
  onSelectedChange?: ((selected: Set<string>) => void) | undefined;
  skeletonRows?: number | undefined;
  /** Có thì bảng hiện theo nhóm (Group By), `rows` chỉ dùng để chọn tất cả và đếm. */
  groups?: TableGroup<Row>[] | undefined;
  /** Mặc định các nhóm mở; đặt sai thì mọi nhóm đóng tới khi người dùng mở (nhóm tải dòng khi mở). */
  groupsDefaultOpen?: boolean | undefined;
  /** Báo khi người dùng mở hoặc đóng một nhóm (để tải dòng của nhóm lá). */
  onGroupToggle?: ((key: string, open: boolean) => void) | undefined;
  /** Dòng làm mờ (bản đã gộp: chỉ đọc). */
  rowMuted?: ((row: Row) => boolean) | undefined;
  /** Bấm vào chỗ trống của dòng thì mở bản ghi (bấm nút, liên kết, ô chọn trong dòng vẫn làm việc của chúng). */
  onRowClick?: ((row: Row) => void) | undefined;
  /** Không có dòng nào vẫn hiện đủ đầu cột, `empty` nằm trong thân bảng (hồ sơ 360°: tab trống vẫn thấy cột). */
  keepHeader?: boolean | undefined;
}) {
  const [toggled, setToggled] = useState<ReadonlySet<string>>(new Set());
  const items: DisplayItem<Row>[] = groups
    ? flatten(groups, toggled, groupsDefaultOpen)
    : rows.map((row) => ({ kind: 'row' as const, row }));
  const toggleGroup = (key: string) => {
    const next = new Set(toggled);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    setToggled(next);
    onGroupToggle?.(key, groupsDefaultOpen !== next.has(key));
  };
  const narrow = useMedia(NARROW_TABLE);
  const headingId = useId();
  const selectable = selected !== undefined && onSelectedChange !== undefined;
  const keys = rows.map(rowKey);
  const allSelected = selectable && keys.length > 0 && keys.every((k) => selected.has(k));
  const someSelected = selectable && keys.some((k) => selected.has(k));

  const toggleRow = (key: string) => {
    if (!selectable) return;
    const next = new Set(selected);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    onSelectedChange(next);
  };
  const toggleAll = () => {
    if (!selectable) return;
    const next = new Set(selected);
    if (allSelected) keys.forEach((k) => next.delete(k));
    else keys.forEach((k) => next.add(k));
    onSelectedChange(next);
  };
  const rowClick = (row: Row) =>
    onRowClick
      ? {
          onClick: (event: MouseEvent<HTMLElement>) => {
            if ((event.target as HTMLElement).closest('a,button,input,label,select,textarea'))
              return;
            onRowClick(row);
          },
        }
      : {};
  const toggleSort = (key: string) => {
    if (!onSortChange) return;
    if (sort?.key !== key) onSortChange({ key, direction: 'asc' });
    else if (sort.direction === 'asc') onSortChange({ key, direction: 'desc' });
    else onSortChange(null);
  };

  const isEmpty = !loading && (groups ? groups.length === 0 : rows.length === 0);
  if (isEmpty && !keepHeader) {
    return <div className="rounded-card border border-border bg-surface">{empty}</div>;
  }

  // Bảng trống giữ đầu cột cũng hiện dạng bảng trên điện thoại (cuộn ngang) vì thẻ không có đầu cột.
  if (narrow && !isEmpty) {
    const first = columns.find((c) => c.primary) ?? columns[0];
    const rest = columns.filter((c) => c !== first);
    return (
      <ul aria-label={caption} aria-busy={loading || undefined} className="flex flex-col gap-2">
        {loading
          ? Array.from({ length: skeletonRows }, (_, i) => (
              <li key={i} className="rounded-card border border-border bg-surface p-3">
                <Skeleton className="mb-2 w-1/2" />
                <Skeleton className="w-3/4" />
              </li>
            ))
          : items.map((item) => {
              if (item.kind === 'group') {
                return (
                  <li key={item.group.key} style={{ paddingLeft: `${item.depth * 12}px` }}>
                    <GroupToggle group={item.group} open={item.open} onToggle={toggleGroup} />
                  </li>
                );
              }
              if (item.kind === 'loading') {
                return (
                  <li key={`${item.group.key}#loading`} className="p-3">
                    <Skeleton className="w-3/4" />
                  </li>
                );
              }
              if (item.kind === 'more') {
                return (
                  <li
                    key={`${item.group.key}#more`}
                    style={{ paddingLeft: `${item.depth * 12}px` }}
                  >
                    <MoreButton group={item.group} />
                  </li>
                );
              }
              const row = item.row;
              const key = rowKey(row);
              return (
                <li
                  key={key}
                  {...rowClick(row)}
                  className={cn(
                    'rounded-card border border-border bg-surface p-3',
                    onRowClick && 'cursor-pointer',
                    selectable && selected.has(key) && 'border-l-[3px] border-l-action bg-selected',
                    rowMuted?.(row) && 'opacity-55',
                  )}
                >
                  <div className="flex items-start gap-3">
                    {selectable && (
                      <span className="flex size-11 shrink-0 items-center justify-center">
                        <input
                          type="checkbox"
                          className={CHECKBOX}
                          checked={selected.has(key)}
                          onChange={() => toggleRow(key)}
                          aria-label={`Chọn ${rowLabel(row)}`}
                        />
                      </span>
                    )}
                    <div className="min-w-0 flex-1">
                      <div className="font-medium">{first?.cell(row)}</div>
                      <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1">
                        {rest.map((column) => (
                          <div key={column.key} className="contents">
                            <dt className="text-caption font-semibold text-fg-muted">
                              {column.header}
                            </dt>
                            <dd className={cn('min-w-0', column.numeric && 'tabular')}>
                              {column.cell(row)}
                            </dd>
                          </div>
                        ))}
                      </dl>
                    </div>
                  </div>
                </li>
              );
            })}
      </ul>
    );
  }

  return (
    <div
      className="overflow-x-auto rounded-box border border-border bg-surface"
      {...(scrollFocusable ? { tabIndex: 0, role: 'region', 'aria-label': caption } : {})}
    >
      <table className="w-full border-collapse text-body" aria-busy={loading || undefined}>
        <caption id={headingId} className="sr-only">
          {caption}
        </caption>
        <thead className="sticky top-0 bg-surface-subtle text-caption font-semibold text-fg-label">
          <tr className="h-table-head">
            {selectable && (
              <th scope="col" className="w-11 px-3 text-left">
                <input
                  type="checkbox"
                  className={CHECKBOX}
                  checked={allSelected}
                  ref={(node) => {
                    if (node) node.indeterminate = someSelected && !allSelected;
                  }}
                  onChange={toggleAll}
                  aria-label="Chọn tất cả dòng trong trang"
                />
              </th>
            )}
            {columns.map((column) => {
              const active = sort?.key === column.key ? sort.direction : null;
              return (
                <th
                  key={column.key}
                  scope="col"
                  aria-sort={
                    active === 'asc' ? 'ascending' : active === 'desc' ? 'descending' : undefined
                  }
                  className={cn(
                    CELL,
                    'font-medium whitespace-nowrap',
                    column.numeric ? 'text-right' : 'text-left',
                  )}
                >
                  {column.sortable && onSortChange ? (
                    <button
                      type="button"
                      onClick={() => toggleSort(column.key)}
                      className="focus-ring inline-flex items-center gap-1 rounded-tag"
                    >
                      {column.header}
                      <Icon
                        name={
                          active === 'asc' ? 'sortAsc' : active === 'desc' ? 'sortDesc' : 'sort'
                        }
                        size={16}
                      />
                    </button>
                  ) : (
                    column.header
                  )}
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>
          {isEmpty && (
            <tr>
              <td colSpan={columns.length + (selectable ? 1 : 0)}>{empty}</td>
            </tr>
          )}
          {loading
            ? Array.from({ length: skeletonRows }, (_, i) => (
                <tr key={i} className="h-row border-b border-surface-subtle last:border-b-0">
                  {selectable && <td className={CELL} />}
                  {columns.map((column) => (
                    <td key={column.key} className={CELL}>
                      <Skeleton className="w-3/4" />
                    </td>
                  ))}
                </tr>
              ))
            : items.map((item) => {
                if (item.kind === 'group') {
                  return (
                    <tr key={item.group.key} className="h-[34px] bg-canvas">
                      <td
                        colSpan={columns.length + (selectable ? 1 : 0)}
                        style={{ paddingLeft: `${16 + item.depth * 20}px` }}
                      >
                        <GroupToggle group={item.group} open={item.open} onToggle={toggleGroup} />
                      </td>
                    </tr>
                  );
                }
                if (item.kind === 'loading') {
                  return (
                    <tr key={`${item.group.key}#loading`} className="h-row">
                      <td
                        colSpan={columns.length + (selectable ? 1 : 0)}
                        style={{ paddingLeft: `${16 + item.depth * 20}px` }}
                      >
                        <Skeleton className="w-1/3" />
                      </td>
                    </tr>
                  );
                }
                if (item.kind === 'more') {
                  return (
                    <tr key={`${item.group.key}#more`} className="h-[34px]">
                      <td
                        colSpan={columns.length + (selectable ? 1 : 0)}
                        style={{ paddingLeft: `${16 + item.depth * 20}px` }}
                      >
                        <MoreButton group={item.group} />
                      </td>
                    </tr>
                  );
                }
                const row = item.row;
                const key = rowKey(row);
                const isSelected = selectable && selected.has(key);
                return (
                  <tr
                    key={key}
                    {...rowClick(row)}
                    className={cn(
                      'h-row border-b border-surface-subtle last:border-b-0 hover:bg-hover',
                      onRowClick && 'cursor-pointer',
                      isSelected && 'bg-selected shadow-[inset_3px_0_0_var(--border-selected)]',
                      rowMuted?.(row) && 'opacity-55',
                    )}
                  >
                    {selectable && (
                      <td className={CELL}>
                        <input
                          type="checkbox"
                          className={CHECKBOX}
                          checked={isSelected}
                          onChange={() => toggleRow(key)}
                          aria-label={`Chọn ${rowLabel(row)}`}
                        />
                      </td>
                    )}
                    {columns.map((column) => (
                      <td
                        key={column.key}
                        className={cn(
                          CELL,
                          'py-1.5',
                          column.numeric && 'tabular text-right whitespace-nowrap',
                          column.className,
                        )}
                      >
                        {column.cell(row)}
                      </td>
                    ))}
                  </tr>
                );
              })}
        </tbody>
      </table>
    </div>
  );
}

function GroupToggle<Row>({
  group,
  open,
  onToggle,
}: {
  group: TableGroup<Row>;
  open: boolean;
  onToggle: (key: string) => void;
}) {
  return (
    <button
      type="button"
      aria-expanded={open}
      onClick={() => onToggle(group.key)}
      className="focus-ring tap inline-flex min-h-8 items-center gap-1.5 rounded-control text-left text-body font-semibold"
    >
      <Icon name={open ? 'chevronDown' : 'chevronRight'} size={16} />
      {group.label}
      <span className="tabular font-medium text-fg-muted">({group.count})</span>
    </button>
  );
}

/** Nút "Xem thêm" cuối một nhóm lá còn dòng chưa tải. */
function MoreButton<Row>({ group }: { group: TableGroup<Row> }) {
  if (!group.more) return null;
  return (
    <Button variant="text" loading={group.more.loading} onClick={group.more.onMore}>
      Xem thêm (còn {group.more.remaining})
    </Button>
  );
}
