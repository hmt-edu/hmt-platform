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
  if (d.fullName.trim() === '') errors.fullName = 'Nhập họ tên của học sinh.';
  const year = d.birthYear.trim();
  if (
    year !== '' &&
    (!YEAR.test(year) || Number(year) < MIN_BIRTH_YEAR || Number(year) > nowYear)
  ) {
    errors.birthYear = 'Năm sinh gồm 4 chữ số, không ở tương lai.';
  } else if (requireYear && year === '' && d.birthDate === '') {
    errors.birthYear = 'Từ giai đoạn L5 trở lên mỗi học sinh bắt buộc có năm sinh.';
  }
  return errors;
}

/** Dữ liệu gửi hàm thêm, sửa em. Ô trống gửi null (sửa em thì xoá ô). Năm sinh để trống mà có ngày sinh thì gửi năm của ngày sinh
 * (hàm sửa em nhận null là xoá năm, không tự suy; từ L5 sẽ bị từ chối). */
export function emPayload(d: EmDraft): Record<string, unknown> {
  const blank = (v: string) => (v.trim() === '' ? null : v.trim());
  const year = d.birthYear.trim();
  return {
    full_name: d.fullName.trim(),
    birth_date: d.birthDate === '' ? null : d.birthDate,
    birth_year:
      year !== '' ? Number(year) : d.birthDate !== '' ? Number(d.birthDate.slice(0, 4)) : null,
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
  return `Còn thay đổi chưa lưu ở học sinh: ${names.join(', ')}. Chọn thẻ học sinh đó rồi bấm Lưu.`;
}

/** Câu báo khi bản ghi đã lưu mà em đang chọn bị máy chủ từ chối. */
export function emSaveFailedText(record: 'lead' | 'cơ hội', name: string, message: string): string {
  return `Đã lưu ${record}, chưa lưu được học sinh ${name}: ${message}`;
}

/** Câu khi danh sách đã đủ số em tối đa; null khi còn thêm được. */
export function fullListText(count: number, max: number | null): string | null {
  return max !== null && count >= max ? `Đã đủ ${max} học sinh` : null;
}

/** Tên hiển thị của một em trên thẻ. */
export function emLabel(s: ProspectStudent): string {
  return s.full_name?.trim() ? s.full_name : 'Học sinh chưa có tên';
}

/** Một học sinh trong ô chọn: tên là chữ chính, năm sinh (và mã HS nếu có) là chữ phụ mờ, không ghép vào tên (F-26-05). */
export function studentLabel(s: {
  full_name: string | null;
  birth_year: number | null;
  student_code?: string | null | undefined;
}): { label: string; hint?: string } {
  const label = s.full_name?.trim() ? s.full_name : 'Học sinh chưa có tên';
  const hint = [s.birth_year ? `sinh ${s.birth_year}` : '', s.student_code ?? '']
    .filter((part) => part !== '')
    .join(' · ');
  return hint === '' ? { label } : { label, hint };
}

/** Câu khi danh sách trống. */
export function emptyListText(entity: 'LEAD' | 'OPPORTUNITY'): string {
  return `${entity === 'LEAD' ? 'Lead' : 'Cơ hội'} chưa có học sinh. Bấm “+ Thêm học sinh” để ghi họ tên, năm sinh của học sinh.`;
}

/** Chữ hộp «Thêm em» (K08c). */
export const addEmText = {
  note: (entity: 'LEAD' | 'OPPORTUNITY') =>
    `Thêm học sinh chỉ ghi nhận vào ${entity === 'LEAD' ? 'lead' : 'cơ hội'}. Hồ sơ học sinh được tạo khi tạo phiếu kiểm tra hoặc duyệt đơn.`,
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
  heading: 'Học sinh đưa sang cơ hội',
  none: 'Chưa chọn học sinh nào: cơ hội sẽ không có học sinh. Thêm học sinh sau ở hồ sơ cơ hội.',
  tooMany: (max: number) => `Chọn tối đa ${max} học sinh.`,
  existing:
    'Chọn Mở cơ hội cũ, Thêm học sinh vào cơ hội cũ, hoặc Vẫn tạo thêm để mở thêm một cơ hội.',
  addToExisting: 'Thêm học sinh vào cơ hội cũ',
};
