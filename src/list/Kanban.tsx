// K2 Kanban: cột theo giai đoạn, thẻ, số thẻ, nút + thêm nhanh. Kéo thả chỉ đi tới khi luật yêu cầu; nút "⋮"
// trên thẻ là cách thay thế cho bàn phím, màn hình cảm ứng. Luật nằm ở `rule`, khung không biết giai đoạn nào.
import { useState, type ReactNode } from 'react';
import { IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { DropdownMenu } from '../ui/Overlays';
import type { MoveRule } from './kanbanLogic';

export type KanbanColumn<Card> = {
  code: string;
  label: string;
  cards: Card[];
};

export function KanbanBoard<Card>({
  columns,
  cardKey,
  renderCard,
  cardLabel,
  rule,
  onMove,
  onBlocked,
  onAdd,
  note,
}: {
  columns: KanbanColumn<Card>[];
  cardKey: (card: Card) => string;
  renderCard: (card: Card) => ReactNode;
  /** Tên thẻ cho nút "⋮" và trình đọc màn hình. */
  cardLabel: (card: Card) => string;
  rule: MoveRule;
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
              <ul className="flex flex-col gap-2">
                {column.cards.map((card) => {
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
