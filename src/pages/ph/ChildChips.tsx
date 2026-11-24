// Chip chọn con dùng chung cho các màn PH-02..05: ẩn khi chỉ một con (anh chốt, ghi chú gói thiết kế học tập và phụ huynh).
import { cn } from '../../ui/cn';
import type { PortalChild } from '../hoc/portalData';

export function ChildChips({
  items,
  value,
  onChange,
}: {
  items: PortalChild[];
  value: string;
  onChange: (id: string) => void;
}) {
  if (items.length < 2) return null;
  return (
    <div role="group" aria-label="Chọn con" className="flex flex-wrap gap-2">
      {items.map((c) => (
        <button
          key={c.id}
          type="button"
          aria-pressed={c.id === value}
          onClick={() => onChange(c.id)}
          className={cn(
            'focus-ring min-h-11 rounded-full border px-4',
            c.id === value
              ? 'border-transparent bg-selected font-medium text-on-selected'
              : 'border-border bg-surface',
          )}
        >
          {c.full_name}
        </button>
      ))}
    </div>
  );
}
