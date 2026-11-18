// CH-05 Khung chương trình: kiểu dữ liệu và hàm thuần. Máy chủ quyết quyền, mã khung, sao chép bài (app.create_curriculum_frame, app.create_curriculum_version);
// giao diện chỉ hiện mã dự kiến (chỉ xem) để người dùng biết bản sẽ tạo ra, mã thật do máy chủ cấp.
export type FrameRow = {
  id: string;
  code: string;
  subject_code: string;
  subject_name: string;
  grade_code: string;
  grade_name: string;
  level_code: 'CB' | 'NC';
  level_name: string;
  year_code: string;
  version: number;
  status_code: 'DANG_DUNG' | 'NGUNG';
  lesson_count: number;
};
export type FramePage = { total: number; rows: FrameRow[] };
export type FrameFilters = {
  status?: string[];
  subject?: string;
  grade?: string;
  level?: string;
  year?: string;
};

export const STATUS_NAME: Record<FrameRow['status_code'], string> = {
  DANG_DUNG: 'Đang dùng',
  NGUNG: 'Ngừng',
};

/** Cấp độ của khung (danh mục CLASS_TYPE, không có Lớp riêng). */
export const LEVEL_OPTIONS = [
  { value: 'CB', label: 'Cơ bản' },
  { value: 'NC', label: 'Nâng cao' },
];

const CENTURY = 100; // allow-number: lấy hai số cuối của năm
/** "2627" → "2026–2027". */
export function yearLabel(code: string): string {
  if (!/^\d{4}$/.test(code)) return code;
  const first = 2000 + Number(code.slice(0, 2)); // allow-number: thế kỷ 21, mã năm học hai số cuối
  return `${first}–${first + 1}`;
}

/** Các năm học để chọn, quanh năm hiện tại: năm trước, năm nay, hai năm sau. Mã "2627" = 2026–2027. */
export function yearOptions(thisYear: number): { value: string; label: string }[] {
  return [thisYear - 1, thisYear, thisYear + 1, thisYear + 2].map((y) => {
    const code = `${String(y % CENTURY).padStart(2, '0')}${String((y + 1) % CENTURY).padStart(2, '0')}`; // allow-number: hai chữ số mỗi năm
    return { value: code, label: yearLabel(code) };
  });
}

/** Mã khung dự kiến: bản đầu không hậu tố, bản kế thêm -v2, -v3 (spec 02). Cùng công thức với app.curriculum_frame_code. */
export function frameCodePreview(
  subject: string,
  grade: string,
  level: string,
  year: string,
  version: number,
): string {
  return `${subject}-${grade}-${level}-${year}${version >= 2 ? `-v${version}` : ''}`; // allow-number: bản đầu không hậu tố
}

/** Số phiên bản kế tiếp của một bộ (môn, khối, cấp độ, năm) từ các bản đã có. */
export function nextVersion(existing: Pick<FrameRow, 'version'>[]): number {
  return existing.reduce((max, f) => Math.max(max, f.version), 0) + 1;
}
