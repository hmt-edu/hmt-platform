// PH-01 Trang chủ cổng Phụ huynh: kiểu dữ liệu của hàm app.ph_home và các hàm đổi chữ (không đoán, không tính tiền, giờ ở trình duyệt).
import { formatDate } from '../../lib/format';

export type HomeChild = {
  id: string;
  full_name: string;
  classes: string[];
  hours_left: number;
  is_low: boolean;
  projected_end: string | null;
  last_session: { date: string; class_code: string; status_name: string | null } | null;
  new_reviews: number;
};

export type HomeAttention =
  | {
      kind: 'GIO_THAP';
      student_id: string;
      student_name: string;
      hours_left: number;
      projected_end: string | null;
    }
  | {
      kind: 'DE_NGHI';
      ticket_id: string;
      title: string;
      student_id: string | null;
      step: number;
      updated_at: string;
    };

export type ParentHome = { children: HomeChild[]; attention: HomeAttention[] };

/** Ngày dạng 19/11 (bỏ năm) cho dòng gọn trên điện thoại. */
export function shortDate(value: string | null | undefined): string {
  return formatDate(value).slice(0, 5);
}

/** 3,0 giờ */
export function hoursText(hours: number): string {
  return `${hours.toLocaleString('vi-VN', { minimumFractionDigits: 1, maximumFractionDigits: 2 })} giờ`;
}

/** Dòng phụ của việc cần chú ý. */
export function attentionLine(item: HomeAttention): string {
  if (item.kind === 'GIO_THAP') {
    const end = item.projected_end ? ` · dự kiến hết ${shortDate(item.projected_end)}` : '';
    return `Còn ${hoursText(item.hours_left)}${end}`;
  }
  return `Bước ${item.step}/4 · cập nhật ${shortDate(item.updated_at)}`;
}

export function attentionTitle(item: HomeAttention): string {
  return item.kind === 'GIO_THAP' ? `Giờ còn của ${item.student_name} thấp` : item.title;
}

/** Dòng «Buổi gần nhất»: 19/11 · B01 · Có mặt (không có điểm danh thì bỏ phần cuối). */
export function lastSessionText(child: HomeChild): string {
  const s = child.last_session;
  if (!s) return 'Chưa có';
  return [shortDate(s.date), s.class_code, s.status_name].filter(Boolean).join(' · ');
}

export function newReviewsText(count: number): string {
  return count > 0 ? `${count} nhận xét` : 'Chưa có';
}
