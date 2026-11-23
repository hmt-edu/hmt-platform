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
): UpsaleNote | null {
  if (t.stage_code === 'L1') {
    if (t.origin_code !== 'HE_THONG') return null;
    const why =
      thresholds.hours !== null && thresholds.days !== null
        ? `giờ còn ≤ ${thresholds.hours} giờ hoặc ngày hết giờ dự kiến ≤ ${thresholds.days} ngày`
        : 'giờ còn ít hoặc sắp tới ngày hết giờ dự kiến';
    return {
      tone: 'info',
      text: `Phiếu do hệ thống tự sinh vì ${why}. Bấm Giao để chọn người phụ trách.`,
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
        t.substage_code === 'L6A'
          ? 'Phụ huynh đồng ý tái tục. Chờ gửi báo giá.'
          : 'Phụ huynh đồng ý tái tục.',
    };
  }
  if (t.stage_code === 'L7') {
    return {
      tone: 'info',
      text: 'Đã gửi báo giá, chờ phụ huynh đóng tiền. Đóng đủ thì phiếu tự sang L8 Hoàn thành tái tục.',
    };
  }
  return null;
}
