// CH-06 Danh sách bài học của khung: kiểu dữ liệu và hàm thuần. Máy chủ quyết quyền, mã bài, thứ tự (app.get_curriculum_frame, save_curriculum_lesson, reorder_curriculum_lessons).
export type Lesson = {
  id: string;
  position: number;
  code: string;
  title: string;
  hint: string | null;
};
export type FrameDetail = {
  frame: {
    id: string;
    code: string;
    status_code: 'DANG_DUNG' | 'NGUNG';
    version: number;
    year_code: string;
    subject_name: string;
    grade_name: string;
    level_name: string;
  };
  lessons: Lesson[];
};

/** Danh sách mã bài theo thứ tự mới sau khi dời bài ở vị trí `index` lên (-1) hoặc xuống (+1). Ra ngoài biên thì giữ nguyên. */
export function moveLesson(lessons: Lesson[], index: number, delta: -1 | 1): string[] {
  const ids = lessons.map((l) => l.id);
  const to = index + delta;
  if (index < 0 || index >= ids.length || to < 0 || to >= ids.length) return ids;
  const moved = ids[index];
  const other = ids[to];
  if (moved === undefined || other === undefined) return ids;
  ids[to] = moved;
  ids[index] = other;
  return ids;
}

/** Mã bài sắp cấp cho bài thêm mới: số lớn nhất đã cấp cộng một (chỉ để hiện trong hộp thoại, mã thật do máy chủ cấp). */
export function nextLessonCode(frameCode: string, lessons: Pick<Lesson, 'code'>[]): string {
  const max = lessons.reduce((m, l) => {
    const n = Number(l.code.slice(frameCode.length + 2)); // allow-number: bỏ «-B» sau mã khung
    return Number.isFinite(n) ? Math.max(m, n) : m;
  }, 0);
  return `${frameCode}-B${String(max + 1).padStart(2, '0')}`; // allow-number: độ rộng hai chữ số của số bài
}
