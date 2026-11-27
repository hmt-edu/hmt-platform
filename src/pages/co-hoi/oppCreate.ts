// TS-07 Tạo cơ hội trực tiếp (không qua lead, R-CRM-01): bản nháp, kiểm ô bắt buộc, đổi nháp thành dữ liệu gửi
// create_opportunity_direct. Hàm thuần, có kiểm thử. Luật thật ở hàm trong DB; chỗ này chỉ chặn sớm ô trống, sai dạng.
import { BLANK_DRAFT, validateDraft, type DraftErrors, type LeadDraft } from '../lead/leadRecord';

export type OppDraft = LeadDraft & { source_type_code: string };
export type OppDraftErrors = DraftErrors & { source_type_code?: string };

export const BLANK_OPP_DRAFT: OppDraft = { ...BLANK_DRAFT, source_type_code: '' };

const blank = (value: string) => (value.trim() === '' ? null : value.trim());
const digits = (phone: string) => phone.replace(/[\s.-]/g, '');

const STUDENT_FIELDS = [
  'student_name',
  'student_birth_date',
  'student_birth_year',
  'school',
  'self_rating',
  'goal',
] as const;

export function validateOppDraft(
  draft: OppDraft,
  options: { channelRequired: boolean },
): OppDraftErrors {
  const errors: OppDraftErrors = validateDraft(draft, {
    creating: true,
    channelRequired: options.channelRequired,
  });
  if (draft.source_type_code === '') errors.source_type_code = 'Chọn source type.';
  if (options.channelRequired && draft.channel_code === '') errors.channel_code = 'Chọn medium.';
  // Em mới bắt buộc có họ tên (R-CRM-23): đã điền ô khác của em thì phải có tên.
  if (draft.student_name.trim() === '' && STUDENT_FIELDS.some((f) => draft[f].trim() !== '')) {
    errors.student_name = 'Nhập tên học sinh.';
  }
  return errors;
}

/** p_data và p_students của create_opportunity_direct. Không điền ô nào của em thì tạo cơ hội 0 em. */
export function oppCreateArgs(draft: OppDraft) {
  const data = {
    parent_name: draft.parent_name.trim(),
    parent_phone: digits(draft.parent_phone),
    ward_code: blank(draft.ward_code),
    province_code: blank(draft.province_code),
    address: blank(draft.address),
    need: blank(draft.need),
    branch_id: draft.branch_id,
    owner_id: draft.owner_id,
    supporter_id: blank(draft.supporter_id),
    source_type_code: draft.source_type_code,
    source_code: draft.source_code,
    channel_code: blank(draft.channel_code),
    campaign_id: blank(draft.campaign_id),
  };
  const students =
    draft.student_name.trim() === ''
      ? []
      : [
          {
            full_name: draft.student_name.trim(),
            birth_date: blank(draft.student_birth_date),
            birth_year:
              draft.student_birth_year.trim() === '' ? null : Number(draft.student_birth_year),
            school: blank(draft.school),
            self_rating: blank(draft.self_rating),
            goal: blank(draft.goal),
          },
        ];
  return { data, students };
}
