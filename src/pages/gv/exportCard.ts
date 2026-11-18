// GV-07X Xuất nhận xét (A24, Chat duyệt 19/11/2026): LÕI dựng nội dung phiếu nhận xét của một em, hàm thuần, không đụng DB hay giao diện.
// Luật: R-V2-38 (dấu Đã xuất chỉ để nhìn), R-V2-39 (lời nhắn là chữ giáo viên; điểm trung bình chỉ dùng nội bộ: KHÔNG in), R-GV-04 (em vắng không chấm, không có phiếu),
// QĐ-Đ291 (tự gửi tay vào group Zalo; không tự gửi). File tạo ngay trên trình duyệt, không lưu lên máy chủ.
// Phiếu in: tiêu đề lớp, buổi, tên em; buổi thường: các tiêu chí đang bật theo nhóm kèm mức 1–5 (ô không đánh giá in «—»); buổi kiểm tra: điểm tổng hoặc ba nhóm; rồi lời nhắn (nhận xét chung) và định hướng cải thiện.
import {
  GROUP_LABEL,
  GROUP_ORDER,
  isPresent,
  type ReviewSheet,
  type ReviewStudent,
} from './review';
import { GROUPS, PRESENT, type ExamSheet, type ExamStudent } from './exam';

export type CardRow = { label: string; value: string };
export type CardSection = { title: string | null; rows: CardRow[] };
export type ExportCard = {
  kind: 'THUONG' | 'KIEM_TRA';
  title: string;
  subtitle: string;
  studentName: string;
  sections: CardSection[];
  message: string | null;
  improvement: string | null;
};

const DASH = '—';

function vnDate(iso: string): string {
  return `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}`; // allow-number: cắt chuỗi yyyy-mm-dd
}

function clean(text: string | null | undefined): string | null {
  const t = (text ?? '').trim();
  return t === '' ? null : t;
}

function head(session: ReviewSheet['session']): { title: string; subtitle: string } {
  const lesson = session.session_no ? `Buổi ${session.session_no}` : 'Buổi học';
  return {
    title: `${session.subject_name ?? session.class_code} · ${lesson}`,
    subtitle: `${session.class_code} · ${vnDate(session.session_date)} · ${session.start_time.slice(0, 5)}–${session.end_time.slice(0, 5)}`, // allow-number: cắt hh:mm:ss
  };
}

/** Em có phiếu: có mặt hoặc đi muộn (em vắng không chấm, không có nhận xét: R-GV-04). */
export function hasCard(attendanceCode: string | null): boolean {
  return attendanceCode !== null && PRESENT.includes(attendanceCode);
}

/** Điều kiện xuất: có phiếu và không còn thay đổi chưa lưu (khung «Chưa lưu thay đổi»). */
export function canExport(
  student: Pick<ReviewStudent, 'attendance_code'>,
  dirty: boolean,
): boolean {
  return hasCard(student.attendance_code) && !dirty;
}

/** Phiếu buổi thường: tiêu chí ĐANG BẬT gom theo nhóm, mức đã lưu (chưa đánh giá, không áp dụng in «—»). Điểm trung bình không in. */
export function buildReviewCard(sheet: ReviewSheet, student: ReviewStudent): ExportCard | null {
  if (!isPresent(student)) return null;
  const sections: CardSection[] = [];
  for (const group of GROUP_ORDER) {
    const rows = sheet.criteria
      .filter((c) => c.enabled && c.group_code === group)
      .map((c) => {
        const cell = student.scores[c.criterion_id];
        const value =
          cell?.state === 'DA_DANH_GIA' && cell.score !== null ? String(cell.score) : DASH;
        return { label: c.name, value };
      });
    if (rows.length > 0) sections.push({ title: GROUP_LABEL[group] ?? group, rows });
  }
  return {
    kind: 'THUONG',
    ...head(sheet.session),
    studentName: student.full_name,
    sections,
    message: clean(student.comment),
    improvement: clean(student.improvement),
  };
}

function scoreText(v: number | null): string {
  return v === null ? DASH : String(v).replace('.', ',');
}

/** Phiếu buổi kiểm tra: điểm tổng (kèm điểm tối đa) hoặc ba nhóm Ghi nhớ, Hiểu, Vận dụng. */
export function buildExamCard(sheet: ExamSheet, student: ExamStudent): ExportCard | null {
  if (!hasCard(student.attendance_code) || !sheet.exam) return null;
  const exam = sheet.exam;
  const s = student.score;
  const rows: CardRow[] = [];
  if (exam.entry_mode === 'NHOM') {
    for (const g of GROUPS) {
      const max = exam[g.maxKey] as number;
      rows.push({
        label: `${g.label} (tối đa ${scoreText(max)})`,
        value: scoreText(s?.[g.key] ?? null),
      });
    }
  }
  rows.push({
    label: `Điểm tổng (tối đa ${scoreText(exam.max_score)})`,
    value: scoreText(s?.total ?? null),
  });
  const sections: CardSection[] = [{ title: null, rows }];
  const scope = clean(exam.scope_text);
  if (scope) sections.unshift({ title: 'Phạm vi kiến thức', rows: [{ label: scope, value: '' }] });
  return {
    kind: 'KIEM_TRA',
    ...head(sheet.session),
    studentName: student.full_name,
    sections,
    message: clean(student.comment),
    improvement: clean(student.improvement),
  };
}

/** Bỏ dấu và ký tự lạ để đặt tên file: `<mã lớp>-<ngày buổi>-<tên em>.<đuôi>`; không chứa số điện thoại. */
export function cardFileName(
  classCode: string,
  sessionDate: string,
  studentName: string,
  ext: 'png' | 'pdf',
): string {
  const fold = (t: string) =>
    t
      .normalize('NFD')
      .replace(/[̀-ͯ]/g, '')
      .replace(/đ/g, 'd')
      .replace(/Đ/g, 'D')
      .replace(/[^A-Za-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  return `${fold(classCode)}-${sessionDate.slice(0, 10)}-${fold(studentName)}.${ext}`; // allow-number: yyyy-mm-dd
}

/** Ngắt dòng theo độ rộng đo được (để vẽ lên canvas): `measure` trả độ rộng của một đoạn chữ. */
export function wrapText(text: string, maxWidth: number, measure: (s: string) => number): string[] {
  const out: string[] = [];
  for (const para of text.split('\n')) {
    let line = '';
    for (const word of para.split(/\s+/).filter(Boolean)) {
      const next = line === '' ? word : `${line} ${word}`;
      if (line !== '' && measure(next) > maxWidth) {
        out.push(line);
        line = word;
      } else {
        line = next;
      }
    }
    out.push(line);
  }
  return out;
}
