// Nhóm nút chọn nhanh ngày, giờ (hộp Tạo, Dời lịch hẹn; hộp Tạo, Đổi lịch phiếu kiểm tra).
import { cn } from '../../ui/cn';

export function Chips({
  label,
  items,
  selected,
  onPick,
}: {
  label: string;
  items: { key: string; label: string }[];
  selected: string | null;
  onPick: (key: string) => void;
}) {
  return (
    <div role="group" aria-label={label} className="flex flex-col gap-1">
      <span className="text-caption font-semibold text-fg-label">{label}</span>
      <div className="flex flex-wrap gap-1.5">
        {items.map((item) => (
          <button
            key={item.key}
            type="button"
            aria-pressed={selected === item.key}
            onClick={() => onPick(item.key)}
            className={cn(
              'focus-ring tap h-control-sm rounded-full border px-3 text-caption font-medium',
              selected === item.key
                ? 'border-brand-300 bg-brand-100 text-brand-800'
                : 'border-border-strong bg-surface hover:bg-hover',
            )}
          >
            {item.label}
          </button>
        ))}
      </div>
    </div>
  );
}
