// Chọn kiểu và chữ của màn lỗi tải dữ liệu (CLAUDE.md «Trải nghiệm»: thử lại khi lỗi mạng). Hàm thuần, có kiểm thử.
import { errorOf, FORBIDDEN_CODE } from '../lib/db';

export type QueryErrorKind = 'forbidden' | 'not-found' | 'error';
export type QueryErrorSpec = {
  kind: QueryErrorKind;
  title: string;
  canRetry: boolean;
  /** Câu tiếng Việt của lỗi nghiệp vụ (mã HMT_*): hiện thay cho nhắc kiểm tra mạng. */
  detail?: string;
};

/** Mã lỗi chung khi không biết nguyên nhân (mạng hay máy chủ): vẫn cho Thử lại. Mọi mã HMT_* khác là lỗi nghiệp vụ. */
const GENERIC_CODE = 'HMT_LOI';

/** `subject`: danh từ đứng sau «xem», «tìm thấy», «tải được» (ví dụ «ticket», «phiếu», «cấu hình SLA»). */
export function queryErrorSpec(error: unknown, subject: string): QueryErrorSpec {
  const known = error ? errorOf(error) : null;
  const code = known?.code ?? '';
  if (code === FORBIDDEN_CODE)
    return { kind: 'forbidden', title: `Bạn không có quyền xem ${subject}`, canRetry: false };
  if (code === 'HMT_KHONG_TIM_THAY')
    return { kind: 'not-found', title: `Không tìm thấy ${subject}`, canRetry: false };
  // Lỗi nghiệp vụ (hàm cơ sở dữ liệu trả mã HMT_* kèm câu tiếng Việt): Thử lại không đổi được kết quả, nên hiện câu của lỗi, không nhắc kiểm tra mạng.
  if (known && code !== '' && code !== GENERIC_CODE)
    return {
      kind: 'error',
      title: `Chưa tải được ${subject}`,
      canRetry: false,
      detail: known.message,
    };
  return { kind: 'error', title: `Chưa tải được ${subject}`, canRetry: true };
}
