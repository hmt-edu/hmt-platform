// K2 Kanban: cột theo giai đoạn, thẻ, số thẻ, nút + thêm nhanh. Kéo thả chỉ đi tới khi luật yêu cầu; nút "⋮"
// trên thẻ là cách thay thế cho bàn phím, màn hình cảm ứng. Luật nằm ở `rule`, khung không biết giai đoạn nào.
import { useState, type ReactNode } from 'react';
import { IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { DropdownMenu } from '../ui/Overlays';
import { freeMoveRule, type MoveRule } from './kanbanLogic';

export type KanbanColumn<Card> = {
  code: string;
  label: string;
  cards: Card[];
};

/** Một khúc của thanh tỷ lệ: khoá trạng thái, nhãn, tông màu. */
export type BarSegment = {
  key: string;
  label: string;
  tone: 'success' | 'warning' | 'danger' | 'neutral';
};

/**
 * Thanh tỷ lệ đầu cột (giống Odoo): chia thẻ của cột theo một trạng thái do màn tính, ví dụ "lịch hẹn kế tiếp"
 * (còn hạn, hôm nay, quá hạn, chưa có lịch). Khung nhận cấu hình, không biết trạng thái nào.
 */
export type KanbanBar<Card> = {
  segments: BarSegment[];
  /** Trạng thái của một thẻ (khoá của một khúc). */
  of: (card: Card) => string;
};

const BAR_TONE: Record<BarSegment['tone'], string> = {
  success: 'bg-success-solid',
  warning: 'bg-warning-solid',
  danger: 'bg-danger-solid',
  neutral: 'bg-neutral-300',
};

function ColumnBar<Card>({
  bar,
  cards,
  active,
  onToggle,
  columnLabel,
}: {
  bar: KanbanBar<Card>;
  cards: Card[];
  active: string | null;
  onToggle: (key: string) => void;
  columnLabel: string;
}) {
  const counts = bar.segments.map((seg) => ({
    seg,
    count: cards.filter((c) => bar.of(c) === seg.key).length,
  }));
  const total = counts.reduce((sum, c) => sum + c.count, 0);
  return (
    <div
      role="group"
      aria-label={`Tỷ lệ thẻ của ${columnLabel}`}
      className="flex h-2 gap-0.5 overflow-hidden rounded-full bg-neutral-200"
    >
      {counts
        .filter((c) => c.count > 0)
        .map(({ seg, count }) => (
          <button
            key={seg.key}
            type="button"
            aria-pressed={active === seg.key}
            aria-label={`${seg.label}: ${count} thẻ${active === seg.key ? ' (đang lọc, bấm để bỏ)' : ''}`}
            title={`${seg.label}: ${count}`}
            onClick={() => onToggle(seg.key)}
            style={{ flexGrow: count, flexBasis: 0 }}
            className={cn(
              'focus-ring relative min-w-2 transition-opacity before:absolute before:-inset-y-2 before:inset-x-0 before:content-[""]',
              BAR_TONE[seg.tone],
              active !== null && active !== seg.key && 'opacity-30',
              total === 0 && 'hidden',
            )}
          />
        ))}
    </div>
  );
}

export function KanbanBoard<Card>({
  columns,
  cardKey,
  renderCard,
  cardLabel,
  rule = freeMoveRule(),
  onMove,
  bar,
  onBlocked,
  onAdd,
  note,
}: {
  columns: KanbanColumn<Card>[];
  cardKey: (card: Card) => string;
  renderCard: (card: Card) => ReactNode;
  /** Tên thẻ cho nút "⋮" và trình đọc màn hình. */
  cardLabel: (card: Card) => string;
  /** Luật kéo thả của màn. Không truyền: kéo tự do (chỉ đi tới là tuỳ chọn, xem forwardOnlyRule). */
  rule?: MoveRule | undefined;
  /** Thanh tỷ lệ đầu cột (tuỳ chọn): trạng thái của từng thẻ do màn tính. */
  bar?: KanbanBar<Card> | undefined;
  /** Gọi khi luật cho phép; hàm cơ sở dữ liệu vẫn kiểm lại và có thể từ chối. */
  onMove: (card: Card, from: string, to: string) => void;
  /** Gọi khi giao diện chặn sớm (hiện hộp thoại chặn có lý do). */
  onBlocked: (reason: string, card: Card) => void;
  onAdd?: ((columnCode: string) => void) | undefined;
  /** Dòng chú thích dưới bảng ("Kéo thẻ chỉ thả được vào giai đoạn phía trước…"). */
  note?: string | undefined;
}) {
  const [dragging, setDragging] = useState<{ key: string; from: string; card: Card } | null>(null);
  const [over, setOver] = useState<string | null>(null);
  // Lọc theo khúc của thanh tỷ lệ: mỗi cột một khúc đang chọn (bấm lại để bỏ).
  const [barFilter, setBarFilter] = useState<Record<string, string | null>>({});

  const attempt = (card: Card, from: string, to: string) => {
    const check = rule(from, to);
    if (check.ok) onMove(card, from, to);
    else onBlocked(check.reason, card);
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex gap-3 overflow-x-auto pb-2">
        {columns.map((column) => {
          const verdict = dragging ? rule(dragging.from, column.code) : null;
          const activeSeg = barFilter[column.code] ?? null;
          const shownCards =
            bar && activeSeg ? column.cards.filter((c) => bar.of(c) === activeSeg) : column.cards;
          return (
            <section
              key={column.code}
              aria-label={`${column.label}: ${column.cards.length} thẻ`}
              onDragOver={(e) => {
                if (dragging) {
                  e.preventDefault();
                  setOver(column.code);
                }
              }}
              onDragLeave={() => setOver((o) => (o === column.code ? null : o))}
              onDrop={(e) => {
                e.preventDefault();
                if (dragging) attempt(dragging.card, dragging.from, column.code);
                setDragging(null);
                setOver(null);
              }}
              className={cn(
                'flex w-[280px] shrink-0 flex-col gap-2 rounded-box bg-surface-subtle p-2',
                over === column.code && verdict?.ok && 'outline-2 outline-brand-500',
                over === column.code && verdict && !verdict.ok && 'outline-2 outline-danger-solid',
              )}
            >
              <header className="flex items-center gap-2 px-1.5 py-1 font-display text-h4">
                <h2 className="min-w-0 flex-1">{column.label}</h2>
                <span className="tabular text-caption font-semibold text-fg-muted">
                  {column.cards.length}
                </span>
                {onAdd && (
                  <IconButton
                    icon="plus"
                    label={`Thêm vào ${column.label}`}
                    onClick={() => onAdd(column.code)}
                  />
                )}
              </header>
              {bar && (
                <ColumnBar
                  bar={bar}
                  cards={column.cards}
                  active={activeSeg}
                  columnLabel={column.label}
                  onToggle={(k) =>
                    setBarFilter((m) => ({ ...m, [column.code]: m[column.code] === k ? null : k }))
                  }
                />
              )}
              <ul className="flex flex-col gap-2">
                {shownCards.map((card) => {
                  const key = cardKey(card);
                  return (
                    <li
                      key={key}
                      draggable
                      onDragStart={() => setDragging({ key, from: column.code, card })}
                      onDragEnd={() => {
                        setDragging(null);
                        setOver(null);
                      }}
                      className={cn(
                        'relative cursor-grab rounded-box border border-border bg-surface px-3 py-2.5 shadow-1 hover:border-border-strong',
                        dragging?.key === key && 'opacity-60',
                      )}
                    >
                      {renderCard(card)}
                      <div className="absolute top-1 right-1">
                        <DropdownMenu
                          trigger={
                            <IconButton
                              icon="more"
                              label={`Chuyển giai đoạn: ${cardLabel(card)}`}
                            />
                          }
                          items={columns
                            .filter((c) => c.code !== column.code)
                            .map((target) => ({
                              kind: 'action' as const,
                              label: `Chuyển sang ${target.label}`,
                              onSelect: () => attempt(card, column.code, target.code),
                            }))}
                        />
                      </div>
                    </li>
                  );
                })}
              </ul>
            </section>
          );
        })}
      </div>
      {note && <p className="text-caption text-fg-muted">{note}</p>}
    </div>
  );
}
