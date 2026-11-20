// Trang Lead (TS-02, TS-03): kiểu bản ghi, bản nháp của biểu mẫu, kiểm tra ô bắt buộc, đổi nháp thành dữ liệu gửi hàm.
// Hàm thuần, có kiểm thử. Luật thật ở create_lead, update_lead; chỗ này chỉ chặn sớm các ô trống, sai dạng.
import type { ProspectStudent } from '../../features/prospect/prospectLogic';
import { toIsoDate } from '../../lib/dateText';
import type { LeadCatalogs } from './useCatalogs';

export type LeadRecord = {
  id: string;
  code: string;
  /** Danh sách em (app.prospect_students_json). */
  students: ProspectStudent[];
  parent_name: string;
  parent_phone: string;
  ward_code: string | null;
  province_code: string | null;
  address: string | null;
  need: string | null;
  student_name: string | null;
  student_birth_date: string | null;
  student_birth_year: number | null;
  school: string | null;
  self_rating: string | null;
  goal: string | null;
  parent_id: string | null;
  branch_id: string;
  branch_code: string;
  branch_name: string;
  owner_id: string;
  owner_name: string | null;
  supporter_id: string | null;
  supporter_name: string | null;
  source_type_code: string;
  source_code: string;
  channel_code: string | null;
  campaign_id: string | null;
  campaign_name: string | null;
  stage_code: string;
  substage_code: string | null;
  record_status: 'DANG_DUNG' | 'DA_GOP' | 'DA_HUY';
  cancel_reason?: string | null;
  merged_into_id: string | null;
  merged_into_code: string | null;
  assigned_at: string;
  next_appointment_at: string | null;
  created_at: string;
  created_by_name: string | null;
  updated_at: string;
  updated_by_name: string | null;
  legacy_ref: string | null;
  appointments_total: number;
  appointments_open: number;
  opportunities_total: number;
};

export type LeadDraft = {
  parent_name: string;
  parent_phone: string;
  ward_code: string;
  province_code: string;
  address: string;
  need: string;
  student_name: string;
  student_birth_date: string;
  student_birth_year: string;
  school: string;
  self_rating: string;
  goal: string;
  branch_id: string;
  owner_id: string;
  supporter_id: string;
  source_code: string;
  channel_code: string;
  campaign_id: string;
};

export type DraftErrors = Partial<Record<keyof LeadDraft, string>>;

export const BLANK_DRAFT: LeadDraft = {
  parent_name: '',
  parent_phone: '',
  ward_code: '',
  province_code: '',
  address: '',
  need: '',
  student_name: '',
  student_birth_date: '',
  student_birth_year: '',
  school: '',
  self_rating: '',
  goal: '',
  branch_id: '',
  owner_id: '',
  supporter_id: '',
  source_code: '',
  channel_code: '',
  campaign_id: '',
};

export function toDraft(record: LeadRecord): LeadDraft {
  return {
    parent_name: record.parent_name,
    parent_phone: record.parent_phone,
    ward_code: record.ward_code ?? '',
    province_code: record.province_code ?? '',
    address: record.address ?? '',
    need: record.need ?? '',
    student_name: record.student_name ?? '',
    student_birth_date: record.student_birth_date ?? '',
    student_birth_year: record.student_birth_year === null ? '' : String(record.student_birth_year),
    school: record.school ?? '',
    self_rating: record.self_rating ?? '',
    goal: record.goal ?? '',
    branch_id: record.branch_id,
    owner_id: record.owner_id,
    supporter_id: record.supporter_id ?? '',
    source_code: record.source_code,
    channel_code: record.channel_code ?? '',
    campaign_id: record.campaign_id ?? '',
  };
}

const PHONE = /^(0|\+?84)\d{9}$/; // allow-number: SĐT Việt Nam 9 số sau đầu số (cấu trúc số điện thoại)
const YEAR = /^\d{4}$/; // allow-number: năm sinh bốn chữ số

/** Chặn sớm ô trống, sai dạng; thông điệp tiếng Việt hiện tại ô. `channelRequired`: nguồn đã chọn có kênh con. */
export function validateDraft(
  draft: LeadDraft,
  options: { creating: boolean; channelRequired: boolean },
): DraftErrors {
  const errors: DraftErrors = {};
  if (draft.parent_name.trim() === '') errors.parent_name = 'Nhập họ tên phụ huynh.';
  if (!PHONE.test(draft.parent_phone.replace(/[\s.-]/g, ''))) {
    errors.parent_phone = 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.';
  }
  if (draft.student_birth_year.trim() !== '' && !YEAR.test(draft.student_birth_year.trim())) {
    errors.student_birth_year = 'Năm sinh gồm 4 chữ số.';
  }
  if (draft.source_code === '') errors.source_code = 'Chọn source.';
  else if (options.channelRequired && draft.channel_code === '') {
    errors.channel_code = 'Chọn sub-source.';
  }
  if (options.creating) {
    if (draft.owner_id === '') errors.owner_id = 'Chọn nhân sự phụ trách.';
    if (draft.branch_id === '') errors.branch_id = 'Chọn cơ sở.';
  }
  return errors;
}

const blank = (value: string) => (value.trim() === '' ? null : value.trim());

/**
 * Dữ liệu gửi create_lead (có cơ sở, người phụ trách) hoặc update_lead (không có hai ô này: đổi người phụ trách có hàm riêng).
 * Loại nguồn lấy từ nguồn (nguồn thuộc một loại nguồn), người dùng không chọn riêng.
 */
export function draftPayload(
  draft: LeadDraft,
  catalogs: Pick<LeadCatalogs, 'parentCode'>,
  options: { creating: boolean },
): Record<string, unknown> {
  const payload: Record<string, unknown> = {
    parent_name: draft.parent_name.trim(),
    parent_phone: draft.parent_phone.replace(/[\s.-]/g, ''),
    ward_code: blank(draft.ward_code),
    province_code: blank(draft.province_code),
    address: blank(draft.address),
    need: blank(draft.need),
    student_name: blank(draft.student_name),
    student_birth_date: blank(draft.student_birth_date),
    student_birth_year:
      draft.student_birth_year.trim() === '' ? null : Number(draft.student_birth_year),
    school: blank(draft.school),
    self_rating: blank(draft.self_rating),
    goal: blank(draft.goal),
    supporter_id: blank(draft.supporter_id),
    source_type_code: catalogs.parentCode('SOURCE', draft.source_code, 'SOURCE_TYPE') ?? null,
    source_code: draft.source_code,
    channel_code: blank(draft.channel_code),
    campaign_id: blank(draft.campaign_id),
  };
  if (options.creating) {
    payload.branch_id = draft.branch_id;
    payload.owner_id = draft.owner_id;
  }
  return payload;
}

/** Ngày dạng yyyy-mm-dd ↔ Date địa phương của ô ngày. */
export function isoToDate(iso: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  return match ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : null;
}
export const dateToIso = (date: Date | null): string => (date ? toIsoDate(date) : '');

/** Cột lịch sử của lead → tên hiện cho người dùng (cột không có tên là cột kỹ thuật, không hiện). */
export const LEAD_FIELD_LABELS: Record<string, string> = {
  parent_name: 'Họ tên phụ huynh',
  parent_phone: 'Số điện thoại',
  ward_code: 'Phường/Xã',
  province_code: 'Tỉnh/Thành phố',
  address: 'Địa chỉ',
  need: 'Nhu cầu',
  student_name: 'Tên học sinh',
  student_birth_date: 'Ngày sinh',
  student_birth_year: 'Năm sinh',
  school: 'Trường học',
  self_rating: 'Học lực tự đánh giá',
  goal: 'Mục tiêu',
  owner_id: 'Nhân sự phụ trách',
  supporter_id: 'Nhân sự hỗ trợ',
  source_type_code: 'Loại nguồn',
  source_code: 'Source',
  channel_code: 'Sub-source',
  campaign_id: 'Chiến dịch',
  stage_code: 'Giai đoạn',
  substage_code: 'Sub-stage',
  record_status: 'Trạng thái',
};

const CATALOG_OF_FIELD: Record<string, string> = {
  stage_code: 'LEAD_STAGE',
  substage_code: 'LEAD_SUBSTAGE',
  source_type_code: 'SOURCE_TYPE',
  source_code: 'SOURCE',
  channel_code: 'SOURCE_CHANNEL',
  ward_code: 'WARD',
  province_code: 'PROVINCE',
};

/** Đổi giá trị thô của lịch sử thành chữ: mã danh mục thành tên, id chiến dịch thành tên; người thì tên hiện tại. */
export function leadHistoryValue(
  catalogs: Pick<LeadCatalogs, 'name' | 'campaignName'>,
  record: Pick<LeadRecord, 'owner_id' | 'owner_name' | 'supporter_id' | 'supporter_name'>,
) {
  return (column: string, value: unknown): string | null => {
    if (typeof value !== 'string' || value === '') return null;
    const catalog = CATALOG_OF_FIELD[column];
    if (catalog) {
      const name = catalogs.name(catalog, value);
      return name
        ? catalog === 'LEAD_STAGE' || catalog === 'LEAD_SUBSTAGE'
          ? `${value} ${name}`
          : name
        : value;
    }
    if (column === 'campaign_id') return catalogs.campaignName(value) ?? 'chiến dịch khác';
    if (column === 'owner_id')
      return value === record.owner_id ? (record.owner_name ?? 'nhân sự khác') : 'nhân sự khác';
    if (column === 'supporter_id')
      return value === record.supporter_id
        ? (record.supporter_name ?? 'nhân sự khác')
        : 'nhân sự khác';
    if (column === 'record_status')
      return value === 'DA_GOP' ? 'Đã gộp' : value === 'DA_HUY' ? 'Đã huỷ' : 'Đang dùng';
    return null;
  };
}
