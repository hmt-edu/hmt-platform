// Nhãn và giá trị lịch sử của phiếu kiểm tra (cột nhật ký → chữ người dùng đọc). Hàm thuần, có kiểm thử.
import { formatDateTime } from '../../lib/format';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { formatScore } from './testLogic';
import { STATUS_LABEL, type TestRecord, type TestStatus } from './testTypes';

/** Cột lịch sử của phiếu → tên hiện cho người dùng (cột không có tên là cột kỹ thuật, không hiện). */
export const TEST_FIELD_LABELS: Record<string, string> = {
  status_code: 'Trạng thái',
  status_reason: 'Lý do lùi, mở lại',
  scheduled_at: 'Giờ test',
  exam_name: 'Đề test',
  subject_code: 'Môn',
  grade_code: 'Khối',
  mode_code: 'Hình thức test',
  level_code: 'Cấp độ đề',
  owner_id: 'Người phụ trách',
  grader_id: 'GV chấm',
  room_id: 'Phòng',
  test_branch_id: 'Cơ sở test',
  score: 'Điểm',
  result_note: 'Nhận xét',
  suggested_level_code: 'Trình độ đề xuất',
  suggested_framework_code: 'Phân loại đề xuất',
  cancel_reason_code: 'Lý do huỷ',
  cancel_note: 'Ghi chú huỷ',
  result_on_behalf: 'Nhập thay',
};

const CATALOG_OF_FIELD: Record<string, string> = {
  subject_code: 'SUBJECT',
  grade_code: 'GRADE',
  mode_code: 'TEST_MODE',
  level_code: 'TEST_LEVEL',
  suggested_level_code: 'LEVEL',
  suggested_framework_code: 'FRAMEWORK_LEVEL',
  cancel_reason_code: 'TEST_CANCEL_REASON',
};

/** Đổi giá trị thô của lịch sử thành chữ: mã danh mục thành tên, trạng thái, giờ, điểm; người thì tên hiện tại. */
export function testHistoryValue(
  catalogs: Pick<LeadCatalogs, 'name'>,
  record: Pick<TestRecord, 'owner_id' | 'owner_name' | 'grader_id' | 'grader_name'>,
) {
  return (column: string, value: unknown): string | null => {
    if (column === 'status_code' && typeof value === 'string') {
      return STATUS_LABEL[value as TestStatus] ?? value;
    }
    if (column === 'scheduled_at' && typeof value === 'string') return formatDateTime(value);
    if (column === 'score' && (typeof value === 'number' || typeof value === 'string')) {
      return formatScore(Number(value));
    }
    if (column === 'result_on_behalf')
      return value === true ? 'Có' : value === false ? 'Không' : null;
    if (typeof value !== 'string' || value === '') return null;
    const catalog = CATALOG_OF_FIELD[column];
    if (catalog) return catalogs.name(catalog, value) ?? value;
    if (column === 'owner_id') {
      return value === record.owner_id ? (record.owner_name ?? 'nhân sự khác') : 'nhân sự khác';
    }
    if (column === 'grader_id') {
      return value === record.grader_id
        ? (record.grader_name ?? 'giáo viên khác')
        : 'giáo viên khác';
    }
    if (column === 'room_id' || column === 'test_branch_id') return 'đã đổi';
    return null;
  };
}
