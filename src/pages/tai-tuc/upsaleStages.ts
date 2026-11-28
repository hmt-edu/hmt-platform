// Hàm thuần cho bản ghi phiếu tái tục (TT-02). Không tính giờ hay tiền: chỉ sắp thứ tự và đọc lại dữ liệu máy chủ đã trả.
import type { UpsaleEvent } from './upsaleTypes';

/** Thứ tự thanh giai đoạn: theo danh mục, riêng «Không tái tục» (L5) đứng cuối vì là nhánh kết thúc, không phải bước đi qua. */
export function orderStages<T extends { value: string }>(stages: T[]): T[] {
  return [...stages.filter((s) => s.value !== 'L5'), ...stages.filter((s) => s.value === 'L5')];
}

/** Campaign: tháng/năm («03/2027») của ngày hết giờ dự kiến (yyyy-mm-dd); chưa có ngày thì trống. */
export function monthOf(date: string | null): string {
  return date ? `${date.slice(5, 7)}/${date.slice(0, 4)}` : '';
}

/** Ngày giao: lần «Giao người phụ trách» mới nhất trong lịch sử phiếu (máy chủ trả theo thứ tự cũ trước). */
export function lastAssignedAt(events: UpsaleEvent[]): string | null {
  return events.filter((e) => e.event_type === 'GIAO').at(-1)?.created_at ?? null;
}
