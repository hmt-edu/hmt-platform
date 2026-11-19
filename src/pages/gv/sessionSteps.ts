// Logic thuần của màn GV-04 (Buổi dạy): các bước của buổi, tiến độ, hạn hoàn tất.
// Luật: R-GIO-06, R-GV-04, R-GV-05 (hạn hoàn tất = `teacher_session_complete_hours` sau khi buổi kết thúc), R-V2-35 (bước BTVN buổi trước bỏ qua khi
// buổi đầu của lớp hoặc buổi trước không giao BTVN), R-GIO-08 (chưa chốt danh sách thì chưa điểm danh, chưa chấm).
import { EXAM_FORM, type SessionOverview } from './sessionContent';

export type StepState = 'DONE' | 'DOING' | 'TODO' | 'WAIT' | 'SKIP';

export type SessionStep = {
  key: 'attendance' | 'content' | 'grading' | 'homework';
  title: string;
  state: StepState;
  detail: string;
};

export const STATE_LABEL: Record<StepState, string> = {
  DONE: 'Xong',
  DOING: 'Đang làm',
  TODO: 'Chưa làm',
  WAIT: 'Chờ',
  SKIP: 'Bỏ qua',
};

export function buildSteps(o: SessionOverview): SessionStep[] {
  const listed = o.status_code === 'DA_CHOT' || o.status_code === 'DONE';
  const isExam = o.review_form === EXAM_FORM;

  const attendance: SessionStep = !listed
    ? { key: 'attendance', title: 'Điểm danh', state: 'WAIT', detail: 'Chờ chốt danh sách' }
    : {
        key: 'attendance',
        title: 'Điểm danh',
        state:
          o.attendance_total > 0 && o.attendance_marked === o.attendance_total
            ? 'DONE'
            : o.attendance_marked > 0
              ? 'DOING'
              : 'TODO',
        detail: `${o.attendance_marked}/${o.attendance_total} em đã điểm danh`,
      };

  const hasHomework = Boolean(o.homework_text);
  // Buổi Kiểm tra không đòi dòng nội dung (Q-252): bước này xong khi đã có nội dung hoặc BTVN.
  const contentDone = o.has_content || (isExam && hasHomework);
  const content: SessionStep = {
    key: 'content',
    title: 'Nội dung buổi và BTVN',
    state: contentDone ? 'DONE' : 'TODO',
    detail: !listed && !contentDone ? 'Nhập được trước' : contentDetail(o, isExam),
  };

  const grading: SessionStep =
    !listed || attendance.state === 'TODO' || attendance.state === 'WAIT'
      ? {
          key: 'grading',
          title: isExam ? 'Chấm điểm kiểm tra' : 'Chấm nhận xét từng em',
          state: 'WAIT',
          detail: 'Chờ điểm danh',
        }
      : {
          key: 'grading',
          title: isExam ? 'Chấm điểm kiểm tra' : 'Chấm nhận xét từng em',
          state:
            o.grading_present > 0 && o.grading_done === o.grading_present
              ? 'DONE'
              : o.grading_done > 0
                ? 'DOING'
                : 'TODO',
          detail: `${o.grading_done}/${o.grading_present} em có mặt đã chấm đủ`,
        };

  const homework: SessionStep =
    o.prev_homework_state === 'DAU_LOP'
      ? {
          key: 'homework',
          title: 'Chấm BTVN buổi trước',
          state: 'SKIP',
          detail: 'Buổi đầu của lớp, chưa có buổi trước. Không đòi, không chặn',
        }
      : o.prev_homework_state === 'KHONG_GIAO'
        ? {
            key: 'homework',
            title: 'Chấm BTVN buổi trước',
            state: 'SKIP',
            detail: 'Buổi trước không giao BTVN. Không đòi, không chặn',
          }
        : !listed
          ? {
              key: 'homework',
              title: 'Chấm BTVN buổi trước',
              state: 'WAIT',
              detail: 'Chờ điểm danh',
            }
          : // Bước chấm BTVN buổi trước (GV-08): mỗi em có mặt cần một trong 5 trạng thái; em vắng buổi giao bài được đặt sẵn Không áp dụng.
            attendance.state === 'TODO' || attendance.state === 'WAIT'
            ? {
                key: 'homework',
                title: 'Chấm BTVN buổi trước',
                state: 'WAIT',
                detail: 'Chờ điểm danh',
              }
            : {
                key: 'homework',
                title: 'Chấm BTVN buổi trước',
                state:
                  o.homework_done === o.homework_present
                    ? 'DONE'
                    : o.homework_done > 0
                      ? 'DOING'
                      : 'TODO',
                detail:
                  o.homework_present === 0
                    ? 'Không có em có mặt cần chấm'
                    : `${o.homework_done}/${o.homework_present} em có mặt đã có trạng thái`,
              };

  return [attendance, content, grading, homework];
}

function contentDetail(o: SessionOverview, isExam: boolean): string {
  const lines =
    o.content_lines > 0
      ? `${o.content_lines} dòng nội dung`
      : isExam
        ? 'Phạm vi kiểm tra'
        : 'Chưa có dòng nội dung';
  return `${lines} · ${o.homework_text ? 'BTVN đã nhập' : 'Không giao BTVN'}`;
}

/** Tiến độ "x/y bước": bước Bỏ qua không tính vào y. */
export function progressOf(steps: SessionStep[]): { done: number; total: number } {
  const counted = steps.filter((step) => step.state !== 'SKIP');
  return { done: counted.filter((step) => step.state === 'DONE').length, total: counted.length };
}

/** Giờ còn lại tới hạn (làm tròn xuống, nhỏ hơn 0 là quá hạn). */
export function hoursLeft(deadlineIso: string, now: Date): number {
  return Math.floor((new Date(deadlineIso).getTime() - now.getTime()) / 3_600_000); // allow-number: số mili giây một giờ
}

export function deadlineText(deadlineIso: string, now: Date): string {
  const hours = hoursLeft(deadlineIso, now);
  return hours >= 0 ? `còn ${hours} giờ` : `quá hạn ${-hours} giờ`;
}

/** Việc cần làm tiếp theo: bước đầu tiên chưa xong và không phải Bỏ qua/Chờ. */
export function nextStep(steps: SessionStep[]): SessionStep | null {
  return steps.find((step) => step.state === 'TODO' || step.state === 'DOING') ?? null;
}
