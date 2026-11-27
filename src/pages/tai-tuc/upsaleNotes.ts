// Câu giải thích theo giai đoạn của phiếu tái tục (TT-02, canvas 9933: TT02_l1, TT02_l5, TT02_l6, TT02_l7). Chỉ chọn câu theo dữ liệu máy chủ đã trả, không tính gì.
export type UpsaleNote = { tone: 'info' | 'warning'; text: string };

export function upsaleStageNote(
  t: {
    stage_code: string;
    substage_code: string | null;
    origin_code: 'HE_THONG' | 'TAY';
  },
  lostReasonName: string | null,
  /** Ngưỡng giờ, ngày từ tham số upsale_hours_left_threshold, upsale_days_left_threshold (không viết cứng); chưa đọc được thì bỏ phần ngưỡng. */
  thresholds: { hours: number | null; days: number | null },
  /** Số đếm thật của phiếu: câu không được nói «đã gửi», «đã có đơn» khi số bằng 0 (anh Trường 27/11). */
  counts: { sentQuotes: number; orders: number },
  /** Người xem đang có nút «Giao» trên màn (điện thoại và người không có quyền thì không). */
  canAssign: boolean,
): UpsaleNote | null {
  if (t.stage_code === 'L1') {
    if (t.origin_code !== 'HE_THONG') return null;
    const why =
      thresholds.hours !== null && thresholds.days !== null
        ? `giờ còn ≤ ${thresholds.hours} giờ hoặc ngày hết giờ dự kiến ≤ ${thresholds.days} ngày`
        : 'giờ còn ít hoặc sắp tới ngày hết giờ dự kiến';
    return {
      tone: 'info',
      text: `Phiếu do hệ thống tự sinh vì ${why}.${canAssign ? ' Bấm Giao để chọn người phụ trách.' : ''}`,
    };
  }
  if (t.stage_code === 'L5') {
    return {
      tone: 'info',
      text: lostReasonName ? `Không tái tục. Lý do: ${lostReasonName}.` : 'Không tái tục.',
    };
  }
  if (t.stage_code === 'L6') {
    return {
      tone: 'info',
      text:
        t.substage_code === 'L6A' && counts.sentQuotes === 0
          ? 'Phụ huynh đồng ý tái tục. Chờ gửi báo giá.'
          : 'Phụ huynh đồng ý tái tục.',
    };
  }
  if (t.stage_code === 'L7' && counts.orders > 0) {
    return { tone: 'info', text: 'Đã có đơn, chờ phụ huynh đóng tiền.' };
  }
  if (t.stage_code === 'L7' && counts.sentQuotes > 0) {
    return { tone: 'info', text: 'Đã gửi báo giá, chờ phụ huynh đóng tiền.' };
  }
  return null;
}

/** Thứ tự thanh giai đoạn: theo danh mục, riêng «Không tái tục» (L5) đứng cuối vì là nhánh kết thúc, không phải bước đi qua. */
export function orderStages<T extends { value: string }>(stages: T[]): T[] {
  return [...stages.filter((s) => s.value !== 'L5'), ...stages.filter((s) => s.value === 'L5')];
}
