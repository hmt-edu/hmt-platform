// Danh sách em của lead, cơ hội (R-CRM-23): kiểu dữ liệu, kiểm biểu mẫu «Thêm em», «Sửa em», câu chữ. Hàm thuần, có kiểm thử.
// Luật máy chủ (app.add_prospect_student, update_prospect_student, remove_prospect_student) kiểm lại; ở đây chỉ báo sớm cho người dùng.

/** Một em trong danh sách em (khoá của app.prospect_students_json). Em đã gắn hồ sơ học sinh có `student_id`, `student_code`. */
export type ProspectStudent = {
  id: string;
  position: number;
  student_id: string | null;
  student_code: string | null;
  full_name: string | null;
  birth_date: string | null;
  birth_year: number | null;
  school: string | null;
  self_rating: string | null;
  goal: string | null;
};

export type EmDraft = {
  fullName: string;
  birthDate: string;
  birthYear: string;
  school: string;
  selfRating: string;
  goal: string;
};

export const EMPTY_EM_DRAFT: EmDraft = {
  fullName: '',
  birthDate: '',
  birthYear: '',
  school: '',
  selfRating: '',
  goal: '',
};

export function draftOfStudent(s: ProspectStudent): EmDraft {
  return {
    fullName: s.full_name ?? '',
    birthDate: s.birth_date ?? '',
    birthYear: s.birth_year === null ? '' : String(s.birth_year),
    school: s.school ?? '',
    selfRating: s.self_rating ?? '',
    goal: s.goal ?? '',
  };
}

const YEAR = /^\d{4}$/;
const MIN_BIRTH_YEAR = 1900; // allow-number: năm sinh tối thiểu, cùng luật DB (app.student)

export type EmErrors = { fullName?: string; birthYear?: string };

/** Lỗi từng ô. `requireYear`: cơ hội từ L5 trở lên bắt buộc năm sinh (R-CRM-03); ngày sinh đủ thì suy ra năm. `nowYear`: năm hiện tại (truyền vào để kiểm thử). */
export function validateEmDraft(d: EmDraft, requireYear: boolean, nowYear: number): EmErrors {
  const errors: EmErrors = {};
  if (d.fullName.trim() === '') errors.fullName = 'Nhập họ tên của em.';
  const year = d.birthYear.trim();
  if (
    year !== '' &&
    (!YEAR.test(year) || Number(year) < MIN_BIRTH_YEAR || Number(year) > nowYear)
  ) {
    errors.birthYear = 'Năm sinh gồm 4 chữ số, không ở tương lai.';
  } else if (requireYear && year === '' && d.birthDate === '') {
    errors.birthYear = 'Từ giai đoạn L5 trở lên mỗi em bắt buộc có năm sinh.';
  }
  return errors;
}

/** Dữ liệu gửi hàm thêm, sửa em. Ô trống gửi null (sửa em thì xoá ô). */
export function emPayload(d: EmDraft): Record<string, unknown> {
  const blank = (v: string) => (v.trim() === '' ? null : v.trim());
  const year = d.birthYear.trim();
  return {
    full_name: d.fullName.trim(),
    birth_date: d.birthDate === '' ? null : d.birthDate,
    birth_year: year === '' ? null : Number(year),
    school: blank(d.school),
    self_rating: blank(d.selfRating),
    goal: blank(d.goal),
  };
}

/** Em từ số 2 có bản nháp khác dữ liệu đã lưu (em đầu do trang theo dõi; em đã gắn hồ sơ chỉ đọc). */
export function dirtyEmIds(students: ProspectStudent[], drafts: Record<string, EmDraft>): string[] {
  return students
    .slice(1)
    .filter((s) => {
      const d = drafts[s.id];
      return (
        d !== undefined &&
        !s.student_id &&
        JSON.stringify(emPayload(d)) !== JSON.stringify(emPayload(draftOfStudent(s)))
      );
    })
    .map((s) => s.id);
}

/** Câu báo sau khi Lưu mà em khác còn thay đổi chưa lưu. */
export function unsavedEmText(names: string[]): string {
  return `Còn thay đổi chưa lưu ở em: ${names.join(', ')}. Chọn thẻ em đó rồi bấm Lưu.`;
}

/** Câu khi danh sách đã đủ số em tối đa; null khi còn thêm được. */
export function fullListText(count: number, max: number | null): string | null {
  return max !== null && count >= max ? `Đã đủ ${max} em` : null;
}

/** Tên hiển thị của một em trên thẻ. */
export function emLabel(s: ProspectStudent): string {
  return s.full_name?.trim() ? s.full_name : 'Em chưa có tên';
}

/** Câu khi danh sách trống. */
export function emptyListText(entity: 'LEAD' | 'OPPORTUNITY'): string {
  return `${entity === 'LEAD' ? 'Lead' : 'Cơ hội'} chưa có em. Bấm “+ Thêm em” để ghi họ tên, năm sinh của em.`;
}

/** Chữ hộp «Thêm em» (K08c). */
export const addEmText = {
  note: (entity: 'LEAD' | 'OPPORTUNITY') =>
    `Thêm em chỉ ghi nhận vào ${entity === 'LEAD' ? 'lead' : 'cơ hội'}. Hồ sơ học sinh được tạo khi tạo phiếu kiểm tra hoặc duyệt đơn.`,
  existingNote: (parentName: string, parentCode: string) =>
    `Con đã có hồ sơ của phụ huynh ${parentName} (${parentCode}).`,
};

/** Khoá nhận diện một em để gộp em trùng: cùng hồ sơ học sinh, hoặc cùng họ tên (không dấu, không phân biệt hoa thường, một khoảng trắng) và năm sinh. */
export function emKey(s: ProspectStudent): string {
  if (s.student_id) return `S:${s.student_id}`;
  const name = (s.full_name ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/gi, 'd')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
  return `N:${name}|${s.birth_year ?? ''}`;
}

/** Danh sách em của lead để chọn khi tạo cơ hội: em trùng họ tên và năm sinh gộp một dòng (TS-06). Giữ em đứng trước. */
export function uniqueEms(students: ProspectStudent[]): ProspectStudent[] {
  const seen = new Set<string>();
  const out: ProspectStudent[] = [];
  for (const s of students) {
    const key = emKey(s);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(s);
  }
  return out;
}

/** Chữ hộp «Tạo cơ hội từ lead» phần chọn em (TS-06). */
export const pickEmText = {
  heading: 'Em đưa sang cơ hội',
  none: 'Chưa chọn em nào: cơ hội sẽ không có em. Thêm em sau ở hồ sơ cơ hội.',
  tooMany: (max: number) => `Chọn tối đa ${max} em.`,
  existing: 'Chọn Mở cơ hội cũ, Thêm em vào cơ hội cũ, hoặc Vẫn tạo thêm để mở thêm một cơ hội.',
  addToExisting: 'Thêm em vào cơ hội cũ',
};
