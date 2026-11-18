// Nhận ra lỗi «máy chủ từ chối quyền» (HMT_KHONG_CO_QUYEN), khác lỗi mạng và lỗi chung: màn giáo viên hiện trạng thái không có quyền thay vì dòng lỗi đỏ.
import { errorOf } from '../../lib/db';

export function isForbidden(error: unknown): boolean {
  return errorOf(error).code === 'HMT_KHONG_CO_QUYEN';
}
