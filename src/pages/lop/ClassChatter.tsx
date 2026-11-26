// Cột «Ghi chú & hoạt động» của lớp: dùng ở hồ sơ lớp (LOP-02) và màn Sửa lớp (LOP-03).
import { RecordChatter } from '../../features/chatter/RecordChatter';
import type { ClassRecord } from './classTypes';

const STEP_LABEL: Record<string, string> = {
  NHAP: 'Nháp',
  DA_TRINH: 'Đã trình',
  DA_XAC_NHAN: 'Đã xác nhận',
  DA_DUYET: 'Đã duyệt',
  DA_DONG: 'Đã đóng',
};

// Tên trường và giá trị trong lịch sử thay đổi của lớp (không hiện mã thô như DA_DUYET).
const CHATTER_FORMAT = {
  coveredByEvents: ['status_code'],
  labels: { status_code: 'Tình trạng', max_students: 'Sĩ số tối đa', start_date: 'Ngày bắt đầu' },
  value: (column: string, value: unknown): string | null =>
    column === 'status_code' && typeof value === 'string' ? (STEP_LABEL[value] ?? null) : null,
};

const EVENT_LABEL: Record<string, string> = {
  TAO: 'Tạo lớp',
  SUA: 'Sửa thông tin',
  SUA_LICH: 'Đổi lịch',
  TRINH: 'Trình',
  XAC_NHAN: 'Xác nhận',
  DUYET: 'Duyệt',
  TU_CHOI: 'Từ chối',
  VE_NHAP: 'Đưa về Nháp',
  DONG: 'Đóng lớp',
  HUY: 'Huỷ lớp',
};

export function ClassChatter({ record }: { record: ClassRecord }) {
  return (
    <RecordChatter
      entityType="CLASS"
      entityId={record.id}
      format={CHATTER_FORMAT}
      createdText="Tạo lớp."
      canWrite
      events={record.events.map((e, i) => ({
        kind: 'system' as const,
        id: `ev-${i}`,
        at: e.created_at,
        author: '',
        text: `${EVENT_LABEL[e.event_code] ?? e.event_code}${e.note ? `: ${e.note}` : ''}`,
      }))}
    />
  );
}
