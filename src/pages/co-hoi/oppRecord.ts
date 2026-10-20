// Trang Cơ hội (TS-08): bản nháp của biểu mẫu Sửa, kiểm tra ô bắt buộc, đổi nháp thành dữ liệu gửi update_opportunity,
// nhãn và giá trị lịch sử. Hàm thuần, có kiểm thử. Luật thật ở update_opportunity (R-CRM-03, 26, 27); chỗ này chặn sớm.
import type { LeadCatalogs } from '../lead/useCatalogs';
import { stageIndex } from './oppStage';
import type { OppRecord } from './oppTypes';

/** Chỉ các ô được sửa ở trang cơ hội: thông tin học sinh, nhu cầu, người hỗ trợ (phụ huynh, nguồn sửa ở nơi khác). */
export type OppDraft = {
  need: string;
  student_name: string;
  student_birth_date: string;
  student_birth_year: string;
  school: string;
  self_rating: string;
  goal: string;
  supporter_id: string;
};

export type OppDraftErrors = Partial<Record<keyof OppDraft, string>>;

export function toOppDraft(record: OppRecord): OppDraft {
  return {
    need: record.need ?? '',
    student_name: record.student_name ?? '',
    student_birth_date: record.student_birth_date ?? '',
    student_birth_year: record.student_birth_year === null ? '' : String(record.student_birth_year),
    school: record.school ?? '',
    self_rating: record.self_rating ?? '',
    goal: record.goal ?? '',
    supporter_id: record.supporter_id ?? '',
  };
}

const YEAR = /^\d{4}$/; // allow-number: năm sinh bốn chữ số
/** Từ giai đoạn này trở lên bắt buộc có tên và năm sinh học sinh (R-CRM-03). */
const STUDENT_REQUIRED_FROM = 'L5';

/** Chặn sớm ô sai dạng; từ L5 trở lên không cho xoá trống tên, năm sinh (năm sinh lấy từ ngày sinh nếu có). */
export function validateOppDraft(draft: OppDraft, stage: string): OppDraftErrors {
  const errors: OppDraftErrors = {};
  const year = draft.student_birth_year.trim();
  if (year !== '' && !YEAR.test(year)) errors.student_birth_year = 'Năm sinh gồm 4 chữ số.';
  if (stageIndex(stage) >= stageIndex(STUDENT_REQUIRED_FROM)) {
    if (draft.student_name.trim() === '') {
      errors.student_name = 'Cơ hội từ L5 trở lên bắt buộc có tên học sinh.';
    }
    if (year === '' && draft.student_birth_date === '') {
      errors.student_birth_year = 'Cơ hội từ L5 trở lên bắt buộc có năm sinh học sinh.';
    }
  }
  return errors;
}

const blank = (value: string) => (value.trim() === '' ? null : value.trim());

/**
 * Dữ liệu gửi update_opportunity. Năm sinh: nhập thì gửi năm; không nhập mà có ngày sinh thì chỉ gửi ngày sinh (hàm DB lấy
 * năm từ ngày); cả hai trống thì gửi rỗng để xoá.
 */
export function oppPayload(draft: OppDraft): Record<string, unknown> {
  const year = draft.student_birth_year.trim();
  const date = blank(draft.student_birth_date);
  const payload: Record<string, unknown> = {
    need: blank(draft.need),
    student_name: blank(draft.student_name),
    student_birth_date: date,
    school: blank(draft.school),
    self_rating: blank(draft.self_rating),
    goal: blank(draft.goal),
    supporter_id: blank(draft.supporter_id),
  };
  if (year !== '') payload.student_birth_year = Number(year);
  else if (date === null) payload.student_birth_year = null;
  return payload;
}

/** Cột lịch sử của cơ hội → tên hiện cho người dùng (cột không có tên là cột kỹ thuật, không hiện). */
export const OPP_FIELD_LABELS: Record<string, string> = {
  need: 'Nhu cầu',
  student_name: 'Tên học sinh',
  student_birth_date: 'Ngày sinh',
  student_birth_year: 'Năm sinh',
  school: 'Trường học',
  self_rating: 'Học lực tự đánh giá',
  goal: 'Mục tiêu',
  owner_id: 'Nhân sự phụ trách',
  supporter_id: 'Nhân sự hỗ trợ',
  stage_code: 'Giai đoạn',
  substage_code: 'Sub-stage',
  skip_reason_code: 'Lý do bỏ qua test',
  skip_note: 'Ghi chú bỏ qua test',
  record_status: 'Trạng thái',
};

const CATALOG_OF_FIELD: Record<string, string> = {
  stage_code: 'OPP_STAGE',
  substage_code: 'OPP_SUBSTAGE',
  skip_reason_code: 'TEST_SKIP_REASON',
};

/** Đổi giá trị thô của lịch sử thành chữ: mã danh mục thành tên (giai đoạn kèm mã); người thì tên hiện tại. */
export function oppHistoryValue(
  catalogs: Pick<LeadCatalogs, 'name'>,
  record: Pick<OppRecord, 'owner_id' | 'owner_name' | 'supporter_id' | 'supporter_name'>,
) {
  return (column: string, value: unknown): string | null => {
    if (typeof value !== 'string' || value === '') return null;
    const catalog = CATALOG_OF_FIELD[column];
    if (catalog) {
      const name = catalogs.name(catalog, value);
      return name ? (catalog === 'TEST_SKIP_REASON' ? name : `${value} ${name}`) : value;
    }
    if (column === 'owner_id')
      return value === record.owner_id ? (record.owner_name ?? 'nhân sự khác') : 'nhân sự khác';
    if (column === 'supporter_id')
      return value === record.supporter_id
        ? (record.supporter_name ?? 'nhân sự khác')
        : 'nhân sự khác';
    if (column === 'record_status') return value === 'DA_GOP' ? 'Đã gộp' : 'Đang dùng';
    return null;
  };
}
