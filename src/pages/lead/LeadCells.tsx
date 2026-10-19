import type { ReactNode } from 'react';

/** Hai dòng xếp dọc trong một ô: dòng chính, dòng phụ nhỏ màu phụ (SĐT dưới tên, kênh dưới nguồn). */
export function Stacked({ top, bottom }: { top: ReactNode; bottom?: ReactNode }) {
  return (
    <span className="flex flex-col gap-0.5 py-1">
      {top}
      {bottom && <span className="text-caption text-fg-muted">{bottom}</span>}
    </span>
  );
}
