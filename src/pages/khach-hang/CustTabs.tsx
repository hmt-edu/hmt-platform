// Thanh tab của bản ghi Khách hàng (KH-02, KH-05): Tổng quan, Các con, Đơn hàng… Tab chưa có dữ liệu hiện mờ kèm chú thích.
import { cn } from '../../ui/cn';

export type TabDef = { key: string; label: string; note?: string | undefined };

export function CustTabs({
  tabs,
  active,
  onChange,
}: {
  tabs: TabDef[];
  active: string;
  onChange: (key: string) => void;
}) {
  return (
    <div
      role="tablist"
      aria-label="Nội dung bản ghi"
      className="flex flex-wrap gap-1 border-b border-border"
    >
      {tabs.map((t) => (
        <button
          key={t.key}
          type="button"
          role="tab"
          aria-selected={active === t.key}
          disabled={t.note !== undefined}
          title={t.note}
          onClick={() => onChange(t.key)}
          className={cn(
            'focus-ring -mb-px border-b-2 px-3 py-2 text-body',
            active === t.key
              ? 'border-brand-600 font-semibold text-brand-700'
              : 'border-transparent text-fg-muted hover:text-fg',
            t.note !== undefined && 'cursor-not-allowed opacity-50',
          )}
        >
          {t.label}
        </button>
      ))}
    </div>
  );
}
