// Chọn kiểu và chữ của màn lỗi tải dữ liệu (CLAUDE.md «Trải nghiệm»: thử lại khi lỗi mạng). Hàm thuần, có kiểm thử.
import { errorOf, FORBIDDEN_CODE } from '../lib/db';

export type QueryErrorKind = 'forbidden' | 'not-found' | 'error';
export type QueryErrorSpec = { kind: QueryErrorKind; title: string; canRetry: boolean };

/** `subject`: danh từ đứng sau «xem», «tìm thấy», «tải được» (ví dụ «ticket», «phiếu», «cấu hình SLA»). */
export function queryErrorSpec(error: unknown, subject: string): QueryErrorSpec {
  const code = error ? errorOf(error).code : '';
  if (code === FORBIDDEN_CODE)
    return { kind: 'forbidden', title: `Bạn không có quyền xem ${subject}`, canRetry: false };
  if (code === 'HMT_KHONG_TIM_THAY')
    return { kind: 'not-found', title: `Không tìm thấy ${subject}`, canRetry: false };
  return { kind: 'error', title: `Chưa tải được ${subject}`, canRetry: true };
}
