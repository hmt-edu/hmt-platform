// Logic thuần của hộp «Hoàn tất buổi» (GV-09): liệt kê việc còn thiếu của buổi, mỗi mục có đường đi tới; đủ hết thì có dấu Đúng hạn / Trễ hạn.
// Luật: R-GV-04, R-GV-05 (hạn hoàn tất), R-GIO-06. R-GV-08: việc Done do hệ thống, màn này KHÔNG đổi tình trạng buổi.
import type { AttendanceStudent } from './attendanceLogic';
import type { SessionOverview } from './sessionContent';
import { buildSteps, hoursLeft, type SessionStep } from './sessionSteps';

export type MissingItem = {
  key: SessionStep['key'] | 'other';
  title: string;
  /** Câu tóm tắt: «2 em chưa điểm danh». */
  summary: string;
  /** Tên em còn thiếu (tối đa như máy chủ trả; điểm danh lấy từ bảng điểm danh). */
  names: string[];
  /** Số em không hiện tên (khi tên bị cắt). */
  more: number;
  /** Đường dẫn bấm «Đi tới»; null = không có (lý do chung của máy chủ). */
  path: string | null;
};

const PATH: Record<SessionStep['key'], string> = {
  attendance: 'diem-danh',
  content: 'noi-dung',
  grading: 'cham-nhan-xet',
  homework: 'cham-btvn',
};

export function stepPathOf(sessionId: string, key: SessionStep['key']): string {
  return `/gv/buoi/${sessionId}/${PATH[key]}`;
}

function rest(total: number, names: string[]): number {
  return Math.max(0, total - names.length);
}

/**
 * Các mục còn thiếu của buổi. `attendanceNames`: tên em chưa điểm danh (null = chưa tải, chỉ hiện số).
 * Chỉ liệt kê bước đang cần làm (Chưa làm / Đang làm); bước Chờ hoặc Bỏ qua không tính.
 */
export function buildMissing(o: SessionOverview, attendanceNames: string[] | null): MissingItem[] {
  const items: MissingItem[] = [];
  for (const step of buildSteps(o)) {
    if (step.state !== 'TODO' && step.state !== 'DOING') continue;
    const path = stepPathOf(o.session_id, step.key);
    if (step.key === 'attendance') {
      const left = o.attendance_total - o.attendance_marked;
      const names = attendanceNames ?? [];
      items.push({
        key: step.key,
        title: step.title,
        summary: `${left} em chưa điểm danh`,
        names,
        more: attendanceNames ? rest(left, names) : 0,
        path,
      });
    } else if (step.key === 'grading') {
      items.push({
        key: step.key,
        title: step.title,
        summary: `${o.grading_present - o.grading_done} em có mặt chưa chấm đủ`,
        names: o.grading_missing,
        more: rest(o.grading_present - o.grading_done, o.grading_missing),
        path,
      });
    } else if (step.key === 'homework') {
      items.push({
        key: step.key,
        title: step.title,
        summary: `${o.homework_present - o.homework_done} em có mặt thiếu trạng thái BTVN`,
        names: o.homework_missing,
        more: rest(o.homework_present - o.homework_done, o.homework_missing),
        path,
      });
    } else {
      items.push({
        key: step.key,
        title: step.title,
        summary: 'Chưa nhập nội dung buổi',
        names: [],
        more: 0,
        path,
      });
    }
  }
  // Máy chủ còn lý do khác mà các bước đều đủ: vẫn báo, không có nút Đi tới.
  if (items.length === 0 && o.pending_reason) {
    items.push({
      key: 'other',
      title: 'Việc khác',
      summary: o.pending_reason,
      names: [],
      more: 0,
      path: null,
    });
  }
  return items;
}

/** Tên các em chưa điểm danh từ bảng điểm danh (chỉ em chưa có trạng thái). */
export function unmarkedNames(students: AttendanceStudent[]): string[] {
  return students.filter((s) => s.teacher_status_code === null).map((s) => s.full_name);
}

export type CompletionStamp = { kind: 'ON_TIME' | 'LATE'; text: string };

/**
 * Dấu hạn lúc đủ việc: so GIỜ HIỆN TẠI với hạn hoàn tất của máy chủ (`deadline_at`).
 * Không phải «dấu hệ thống» ghi lúc Done (DB chưa có cột này): buổi đã Done thì không đóng dấu (trả null).
 */
export function stampOf(o: SessionOverview, now: Date): CompletionStamp | null {
  if (o.status_code === 'DONE') return null;
  const left = hoursLeft(o.deadline_at, now);
  return left >= 0
    ? { kind: 'ON_TIME', text: 'Đúng hạn' }
    : { kind: 'LATE', text: `Trễ hạn ${-left} giờ` };
}
