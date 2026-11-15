// GV-13 Học sinh (hồ sơ rút gọn cho giáo viên): kiểu dữ liệu và hàm thuần. Máy chủ (app.teacher_student_profile) quyết quyền và tính mọi số (R-GV-13);
// trang chỉ đặt chữ. Không có số điện thoại, học phí, thông tin phụ huynh.
import { scoreText } from './classOverviewLogic';

export type ProfileCriterion = { name: string; state: string | null; score: number | null };
export type ProfileSession = {
  session_id: string;
  session_no: number | null;
  session_date: string;
  status_code: string;
  attendance_code: string | null;
  attendance_name: string | null;
  criteria: ProfileCriterion[];
  homework: { status_code: string; status_name: string | null; score: number | null } | null;
};
export type StudentProfile = {
  student: { id: string; code: string; full_name: string };
  class: { id: string; code: string; subject_name: string | null };
  branch_name: string | null;
  summary: { marked: number; present: number; avg_score: number | null };
  sessions: ProfileSession[];
};

/** "Có mặt 3/4 buổi gần đây" hoặc "Chưa điểm danh". */
export function summaryAttendance(
  s: Pick<StudentProfile['summary'], 'marked' | 'present'>,
): string {
  return s.marked === 0 ? 'Chưa điểm danh' : `Có mặt ${s.present}/${s.marked} buổi`;
}

/** Điểm tiêu chí trung bình: "TB 4,1" hoặc "Chưa có điểm" (ô trống không phải 0, R-GV-02). */
export function summaryScore(avg: number | null): string {
  return scoreText(avg);
}

/** Điểm một tiêu chí trong buổi: số có dấu phẩy, hoặc nhãn trạng thái khi chưa có điểm (Chưa đánh giá). */
export function criterionText(c: ProfileCriterion): string {
  if (c.state === 'DA_DANH_GIA' && c.score !== null) return `${c.name} ${c.score}`;
  return `${c.name}: chưa đánh giá`;
}

/** Cột "Điểm tiêu chí" của một buổi: các tiêu chí đang bật nối bằng " · "; em vắng buổi đó thì "Không chấm". */
export function criteriaText(s: Pick<ProfileSession, 'attendance_code' | 'criteria'>): string {
  const present = s.attendance_code === 'CO_MAT' || s.attendance_code === 'DI_MUON';
  if (!present) return 'Không chấm';
  if (s.criteria.length === 0) return 'Chưa có tiêu chí';
  return s.criteria.map(criterionText).join(' · ');
}

/** Cột BTVN: "BTVN: Đã chấm (4)", "BTVN: Không áp dụng", hoặc "Chưa có BTVN". */
export function homeworkText(h: ProfileSession['homework']): string {
  if (h === null) return 'Chưa có BTVN';
  const name = h.status_name ?? h.status_code;
  return h.score === null ? `BTVN: ${name}` : `BTVN: ${name} (${h.score})`;
}

/** "Buổi 5 · 24/10" */
export function sessionLabel(s: Pick<ProfileSession, 'session_no' | 'session_date'>): string {
  const d = `${s.session_date.slice(8, 10)}/${s.session_date.slice(5, 7)}`; // allow-number: cắt chuỗi yyyy-mm-dd
  return `${s.session_no === null ? 'Buổi' : `Buổi ${s.session_no}`} · ${d}`;
}
