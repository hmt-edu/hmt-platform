// Hàm thuần cho các hộp chọn lớp (BH-08, GD-03): nhãn thứ, nhãn buổi sắp tới, ngày vào lớp mặc định, lý do mờ. Luật (đúng thứ, đúng buổi, trùng giờ)
// do máy chủ quyết (app.assert_enrol_start_date, app.assert_no_time_clash); giao diện chỉ gợi ý và hiện lý do báo trước.
import { formatDate } from '../../lib/format';
import type { MatchingClass } from './enrollTypes';

export function weekdayLabel(isodow: number): string {
  return isodow === 7 ? 'Chủ nhật' : `Thứ ${isodow + 1}`;
}

/** "03/11 · Thứ 3, buổi 8" cho một buổi sắp tới (date dạng yyyy-mm-dd). */
export function upcomingLabel(date: string, sessionNo: number | null): string {
  const [y, m, d] = date.split('-').map(Number);
  const isodow = y && m && d ? ((new Date(Date.UTC(y, m - 1, d, 12)).getUTCDay() + 6) % 7) + 1 : 1;
  const dm = `${date.slice(8, 10)}/${date.slice(5, 7)}`;
  return `${dm} · ${weekdayLabel(isodow)}${sessionNo ? `, buổi ${sessionNo}` : ''}`;
}

/** Ngày vào lớp gợi ý: buổi sắp tới đầu tiên; lớp chưa có buổi thì trống (người dùng chọn đúng thứ có lịch). */
export function defaultStart(cls: MatchingClass): string {
  return cls.upcoming[0]?.date ?? '';
}

/** Lý do báo trước vì sao lớp mờ (không chọn được), hoặc null. R-GD-15: lớp luân phiên không báo trùng (máy chủ đã tính). */
export function disabledReason(cls: MatchingClass): string | null {
  if (cls.clash_sessions > 0) {
    const f = cls.clash_first;
    // Canvas GD03_trung_gio: nêu buổi trùng đầu tiên (ngày, giờ, lớp) khi máy chủ trả; chưa có thì chỉ nêu số buổi.
    if (f) {
      return `Trùng buổi ${formatDate(f.date)}, ${f.start_time.slice(0, 5)}–${f.end_time.slice(0, 5)} với lớp ${f.class_code} mà em đang học (xét theo từng buổi thật)`;
    }
    return `Trùng ${cls.clash_sessions} buổi với lớp em đang học`;
  }
  return null;
}

/** Tên hình thức học để hiện trong câu cảnh báo. */
const MODE_NAME: Record<string, string> = { OFF: 'Offline', ONL: 'Online', OMO: 'OMO' };

/**
 * Cảnh báo lệch hình thức khi xếp lớp (anh Trường chốt 20/11): CHỈ cảnh báo, không chặn.
 * Lớp OMO nhận cả Offline và Online; lớp Offline hoặc Online lệch hình thức của ghi danh thì nhắc. Thiếu dữ liệu một bên thì không nhắc.
 */
export function deliveryMismatchWarning(
  classMode: string | undefined,
  enrollMode: string | null | undefined,
): string | null {
  if (!classMode || !enrollMode || classMode === 'OMO' || classMode === enrollMode) return null;
  const c = MODE_NAME[classMode] ?? classMode;
  const e = MODE_NAME[enrollMode] ?? enrollMode;
  return `Lớp học ${c}, ghi danh ${e}: lệch hình thức học. Chỉ cảnh báo, vẫn xếp được.`;
}

/** "Còn 4 chỗ" / "Không giới hạn sĩ số". */
export function seatsText(cls: MatchingClass): string {
  return cls.seats_left === null ? 'Không giới hạn sĩ số' : `Còn ${cls.seats_left} chỗ`;
}

/** Gợi ý chọn ngày cho lớp chưa có buổi: "Ngày đúng Thứ 3, Thứ 5, không trước 06/10/2026". */
export function startHint(cls: MatchingClass): string {
  const days = [...cls.weekdays]
    .sort((a, b) => a - b)
    .map(weekdayLabel)
    .join(', ');
  const [y, m, d] = cls.class_start_date.split('-');
  return `Lớp chưa có buổi: chọn ngày đúng ${days || 'thứ có lịch'}, không trước ${d}/${m}/${y}.`;
}

/** Chuyển Date (giờ máy) sang yyyy-mm-dd. */
export function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: hai chữ số
}
export function keyToDate(key: string): Date | null {
  const [y, m, d] = key.split('-').map(Number);
  return y && m && d ? new Date(y, m - 1, d) : null;
}

/** Đọc số giờ gõ vào (chấp nhận dấu phẩy thập phân); trả null nếu không phải số hoặc bằng 0. */
export function parseHours(text: string): number | null {
  const n = Number(text.trim().replace(',', '.'));
  return Number.isFinite(n) && n !== 0 ? n : null;
}

export type EnrollmentNotice = { tone: 'info' | 'warning'; title: string; text: string };

/**
 * Dòng giải thích theo tình trạng và quỹ giờ ở GD-02 (canvas 9933: GD02_cho_xep, _het_gio, _hoc_truoc, _bao_luu, _hoan_phi).
 * Chỉ chọn câu từ số liệu máy chủ đã trả, không tính giờ. Hạn mức âm của «học trước», ngày bảo lưu, mã phiếu chi hoàn phí do máy chủ trả (migration 591); thiếu thì câu bỏ phần đó.
 */
export function enrollmentNotice(
  status: string,
  hours: {
    granted: number;
    gifted: number;
    remaining: number;
    negative_limit_sessions?: number | null | undefined;
    negative_limit_hours?: number | null | undefined;
  },
  extra: {
    holdStart?: string | null | undefined;
    holdEnd?: string | null | undefined;
    refundVoucher?: string | null | undefined;
  } = {},
): EnrollmentNotice | null {
  if (status === 'HOAN_PHI') {
    return {
      tone: 'info',
      title: 'Ghi danh đã hoàn phí.',
      text: extra.refundVoucher
        ? `Ghi danh đã hoàn phí theo phiếu chi ${extra.refundVoucher}. Không sửa được nữa.`
        : 'Không sửa được nữa.',
    };
  }
  if (status === 'BAO_LUU') {
    const range =
      extra.holdStart && extra.holdEnd
        ? ` ${formatDate(extra.holdStart)} đến ${formatDate(extra.holdEnd)}`
        : '';
    return {
      tone: 'info',
      title: range ? `Đang bảo lưu${range}.` : 'Đang bảo lưu.',
      text: 'Giờ còn lại giữ nguyên, em ra khỏi danh sách các buổi trong thời gian này.',
    };
  }
  if (status === 'CHO_XEP_LOP') {
    return {
      tone: 'info',
      title: 'Chưa có lớp.',
      text: 'Bấm Xếp lớp để chọn lớp và ngày vào lớp.',
    };
  }
  if (hours.remaining < 0) {
    return {
      tone: 'warning',
      title: 'Đang học trước, chưa đóng tiền.',
      text: `Quỹ giờ được âm tối đa ${
        hours.negative_limit_sessions != null && hours.negative_limit_hours != null
          ? `${hours.negative_limit_sessions} buổi (${hours.negative_limit_hours} giờ)`
          : 'theo hạn mức «Cho học trước tối đa»'
      }, hiện −${Math.abs(hours.remaining)} giờ. Quá hạn mức thì em bị loại khỏi danh sách các buổi sau, kèm cảnh báo cho vận hành và sale.`,
    };
  }
  if (hours.remaining === 0 && hours.granted + hours.gifted > 0 && status === 'DANG_HOC') {
    return {
      tone: 'warning',
      title: 'Quỹ giờ bằng 0.',
      text: 'Hết phí ở lớp này: học sinh không được điểm danh trừ giờ, hệ thống chặn, không cho âm. Muốn học tiếp: lập phiếu tái tục, hoặc chuyển giờ từ ghi danh khác qua ticket “Chuyển phí”.',
    };
  }
  return null;
}
