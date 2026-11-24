// PH-05 Lịch học của con (cổng Phụ huynh): giống HT-06, thêm chip chọn con. Chỉ xem.
// Khung PH05_ds, PH05_tai, PH05_trong, PH05_loi (canvas 9189).
import { useState } from 'react';
import { useChildren } from '../hoc/portalData';
import { ScheduleView } from '../hoc/StudentSchedulePage';
import { ChildChips } from './ChildChips';

export function ParentSchedulePage() {
  const children = useChildren();
  const list = children.data ?? [];
  const [picked, setPicked] = useState<string | null>(null);
  const child = list.find((c) => c.id === picked) ?? list[0];
  return (
    <ScheduleView
      key={child?.id}
      childrenQuery={children}
      parentView
      studentId={child?.id}
      chips={<ChildChips items={list} value={child?.id ?? ''} onChange={setPicked} />}
    />
  );
}
