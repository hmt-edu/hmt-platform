import { describe, expect, it } from 'vitest';
import type { AppointmentRow } from '../lich-hen/appointmentTypes';
import { weekEvent, weekState } from './weekLogic';

const now = new Date('2030-03-05T10:00:00+07:00');
const row = (over: Partial<AppointmentRow>): AppointmentRow => ({
  id: 'a',
  activity_code: 'GOI_DIEN',
  scheduled_at: '2030-03-05T14:00:00+07:00',
  title: 'Gọi lại',
  status: 'CHUA_LAM',
  owner_id: 'u',
  owner_name: null,
  lead_id: 'l',
  lead_code: 'LD1',
  opportunity_id: null,
  opportunity_code: null,
  student_test_id: null,
  student_test_code: null,
  is_auto_reminder: false,
  record_code: 'LD1',
  record_label: 'Phụ huynh thử',
  cancel_reason_code: null,
  branch_code: 'CS1',
  ...over,
});

describe('Lịch tuần của «Việc của tôi»', () => {
  it('màu ô: đã hoàn thành, quá hạn, chưa làm', () => {
    expect(weekState(row({ status: 'HOAN_THANH' }), now)).toBe('done');
    expect(weekState(row({ scheduled_at: '2030-03-05T09:00:00+07:00' }), now)).toBe('overdue');
    expect(weekState(row({}), now)).toBe('open');
  });

  it('chữ trên ô: loại hoạt động và hồ sơ; lịch của phiếu kiểm tra ghi «Test»', () => {
    expect(weekEvent(row({}), 'Gọi', now, 30).title).toBe('Gọi · Phụ huynh thử');
    expect(weekEvent(row({ student_test_id: 't' }), 'Gọi', now, 30).title).toBe(
      'Test · Phụ huynh thử',
    );
  });
});
