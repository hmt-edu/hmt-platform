import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { cn } from './cn';

/**
 * Bảng dòng dùng chung cho Báo giá và Đơn hàng (Q-72, Q-73): MỘT HÀNG MỘT DÒNG, chữ không xuống hàng,
 * cột không vừa thì cuộn ngang trong khung (không bẻ hàng, không thành thẻ, kể cả điện thoại).
 * Khớp khung canvas BH02_* (HMT Platform v146) và BH05_* (canvas bổ sung): bảng rộng theo nội dung, tối thiểu bằng khung.
 *
 * - Ô không bao giờ xuống hàng; cột nào có chữ dài thì đặt `truncate` (bề rộng tối đa, cắt bằng …) và `title`.
 * - `below` vẽ một hàng phụ ngay dưới dòng (lỗi, cảnh báo, ghi chú của dòng) trải hết bề ngang.
 * - Khung cuộn có `relative` để chữ sr-only không thoát ra ngoài vùng cuộn làm trang tràn ngang (nguyên nhân Đơn sửa 1280 tràn 90px).
 */
export type LineColumn<Row> = {
  key: string;
  header: ReactNode;
  /** Cột không có tiêu đề nhìn thấy (nút bỏ dòng): chỉ đọc cho trình đọc màn hình. */
  headerSrOnly?: string;
  align?: 'left' | 'right' | 'center';
  /** Bề rộng cố định của cột (lớp Tailwind, ví dụ 'w-24'). */
  width?: string;
  /** Cột cắt chữ dài: bề rộng tối đa của chữ (lớp Tailwind, ví dụ 'max-w-56'). */
  truncate?: string;
  /** Chữ đầy đủ của ô cắt (hiện khi rê chuột). */
  title?: (row: Row) => string;
  cell: (row: Row, index: number) => ReactNode;
};

const ACCENT = {
  danger: 'shadow-[inset_3px_0_0_var(--color-danger)]',
  warning: 'shadow-[inset_3px_0_0_var(--color-warning-solid)]',
} as const;

const ALIGN = { left: 'text-left', right: 'text-right', center: 'text-center' } as const;

export function LineTable<Row>({
  caption,
  columns,
  rows,
  rowKey,
  rowClassName,
  rowLabel,
  rowBusy,
  rowAccent,
  below,
  scrollFocusable = false,
  empty,
}: {
  caption: string;
  columns: LineColumn<Row>[];
  rows: Row[];
  rowKey: (row: Row) => string;
  rowClassName?: ((row: Row) => string | undefined) | undefined;
  /** Tên nhóm hàng (dòng và hàng phụ của nó), ví dụ "Dòng 1": đọc được và tìm được theo tên. */
  rowLabel?: ((row: Row, index: number) => string) | undefined;
  /** Dòng đang tính giá: báo bận cho trình đọc màn hình. */
  rowBusy?: ((row: Row) => boolean) | undefined;
  /** Viền màu bên trái dòng (khung BH02_sua: dòng lỗi viền đỏ, dòng vượt trần viền vàng). */
  rowAccent?: ((row: Row) => 'danger' | 'warning' | undefined) | undefined;
  /** Hàng phụ dưới dòng; trả null thì không có hàng phụ. */
  below?: ((row: Row, index: number) => ReactNode) | undefined;
  /** Vùng cuộn nhận bàn phím (bảng chỉ đọc, không ô nào bấm được). */
  scrollFocusable?: boolean | undefined;
  empty?: ReactNode | undefined;
}) {
  // Q-82: vệt mờ ở mép phải khi còn cột bị che; mất khi đã cuộn tới cuối (hoặc bảng vừa khung).
  const scroller = useRef<HTMLDivElement>(null);
  const [hasMore, setHasMore] = useState(false);
  const measure = useCallback(() => {
    const el = scroller.current;
    if (el) setHasMore(el.scrollWidth - el.scrollLeft - el.clientWidth > 1);
  }, []);
  useEffect(() => {
    const el = scroller.current;
    if (!el) return;
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(el);
    if (el.firstElementChild) observer.observe(el.firstElementChild);
    return () => observer.disconnect();
  }, [measure, rows.length]);
  if (rows.length === 0 && empty !== undefined) {
    return <div className="rounded-box border border-border bg-surface">{empty}</div>;
  }
  return (
    <div className="relative rounded-box border border-border bg-surface">
      <div
        ref={scroller}
        onScroll={measure}
        className="line-scroll relative overflow-x-auto rounded-box"
        {...(scrollFocusable ? { tabIndex: 0, role: 'region', 'aria-label': caption } : {})}
      >
        <table aria-label={caption} className="w-max min-w-full border-collapse text-body">
          <thead className="bg-surface-subtle text-caption font-semibold text-fg-label">
            <tr className="h-table-head">
              {columns.map((c) => (
                <th
                  key={c.key}
                  scope="col"
                  className={cn(
                    'px-2.5 whitespace-nowrap first:pl-4 last:pr-4',
                    ALIGN[c.align ?? 'left'],
                    c.width,
                  )}
                >
                  {c.headerSrOnly ? <span className="sr-only">{c.headerSrOnly}</span> : c.header}
                </th>
              ))}
            </tr>
          </thead>
          {rows.map((row, index) => {
            const extra = below?.(row, index);
            return (
              <tbody
                key={rowKey(row)}
                className={cn('border-t border-border', rowClassName?.(row))}
                {...(rowLabel ? { 'aria-label': rowLabel(row, index) } : {})}
                {...(rowBusy?.(row) ? { 'aria-busy': true } : {})}
              >
                <tr>
                  {columns.map((c) => (
                    <td
                      key={c.key}
                      className={cn(
                        'px-2.5 py-2 align-middle whitespace-nowrap first:pl-4 last:pr-4',
                        ALIGN[c.align ?? 'left'],
                        c.width,
                        c === columns[0] && rowAccent?.(row) === 'danger' && ACCENT.danger,
                        c === columns[0] && rowAccent?.(row) === 'warning' && ACCENT.warning,
                      )}
                    >
                      {c.truncate ? (
                        <span
                          className={cn('block truncate', c.truncate)}
                          {...(c.title ? { title: c.title(row) } : {})}
                        >
                          {c.cell(row, index)}
                        </span>
                      ) : (
                        c.cell(row, index)
                      )}
                    </td>
                  ))}
                </tr>
                {extra ? (
                  <tr>
                    <td colSpan={columns.length} className="px-4 pt-0 pb-2 text-caption">
                      {extra}
                    </td>
                  </tr>
                ) : null}
              </tbody>
            );
          })}
        </table>
      </div>
      {hasMore && (
        <span
          aria-hidden="true"
          data-testid="line-table-fade"
          className="pointer-events-none absolute top-0 right-0 bottom-3 w-10 rounded-r-box bg-linear-to-l from-surface to-transparent"
        />
      )}
    </div>
  );
}
