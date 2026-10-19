import { describe, expect, it } from 'vitest';
import { EMPTY_APPOINTMENT_STATE } from './appointmentConfig';
import { buildAppointmentFilters, hiddenOverdueBefore } from './appointmentFilters';

const NOW = new Date('2026-10-14T05:00:00Z'); // 12:00 giờ Việt Nam, thứ Tư
const state = (patch: Partial<typeof EMPTY_APPOINTMENT_STATE>) => ({
  ...EMPTY_APPOINTMENT_STATE,
  datePreset: '',
  ...patch,
});

describe('buildAppointmentFilters', () => {
  it('không lọc gì thì bộ lọc rỗng', () => {
    expect(buildAppointmentFilters(state({}), NOW)).toEqual({});
  });
  it('tìm kiếm cắt khoảng trắng, "Của tôi" bật mine', () => {
    expect(
      buildAppointmentFilters(state({ search: '  hằng ', quick: { mine: ['owner'] } }), NOW),
    ).toEqual({
      q: 'hằng',
      mine: true,
    });
  });
  it('trạng thái nhiều lựa chọn là HOẶC', () => {
    expect(
      buildAppointmentFilters(state({ quick: { status: ['open', 'done'] } }), NOW).status,
    ).toEqual(['CHUA_LAM', 'HOAN_THANH']);
  });
  it('Quá hạn: Chưa làm và trước đầu ngày hôm nay theo giờ Việt Nam', () => {
    const f = buildAppointmentFilters(state({ quick: { overdue: ['overdue'] } }), NOW);
    expect(f.status).toEqual(['CHUA_LAM']);
    expect(f.to).toBe('2026-10-13T17:00:00.000Z');
  });
  it('Quá hạn cùng "Hoàn thành" thì không khớp gì', () => {
    const f = buildAppointmentFilters(
      state({ quick: { overdue: ['overdue'], status: ['done'] } }),
      NOW,
    );
    expect(f.status).toEqual(['KHONG_KHOP']);
  });
  it('mốc nhanh Tuần này: từ thứ Hai đến hết Chủ nhật', () => {
    const f = buildAppointmentFilters(state({ datePreset: 'week' }), NOW);
    expect(new Date(String(f.from)).getTime()).toBeLessThan(NOW.getTime());
    expect(new Date(String(f.to)).getTime()).toBeGreaterThan(NOW.getTime());
  });
  it('cửa sổ của Lịch thay mốc nhanh; điều kiện ngày thu hẹp thêm', () => {
    const window = { from: new Date('2026-10-12T00:00:00Z'), to: new Date('2026-10-19T00:00:00Z') };
    const f = buildAppointmentFilters(
      state({
        datePreset: 'month',
        conditions: [{ id: '1', field: 'time', op: 'from', value: '2026-10-15' }],
      }),
      NOW,
      window,
    );
    expect(f.to).toBe('2026-10-19T00:00:00.000Z');
    expect(f.from).toBe('2026-10-14T17:00:00.000Z');
  });
  it('lọc loại hoạt động, người phụ trách, cơ sở', () => {
    const f = buildAppointmentFilters(
      state({
        conditions: [
          { id: '1', field: 'activity', op: 'in', value: ['GOI_DIEN', 'ZALO'] },
          { id: '2', field: 'owner', op: 'eq', value: 'u1' },
          { id: '3', field: 'branch', op: 'eq', value: 'b1' },
        ],
      }),
      NOW,
    );
    expect(f).toMatchObject({ activity: ['GOI_DIEN', 'ZALO'], owner_id: 'u1', branch_id: 'b1' });
  });
});

describe('hiddenOverdueBefore', () => {
  it('có mốc thời gian thì lịch quá hạn trước mốc bị ẩn', () => {
    expect(hiddenOverdueBefore(state({ datePreset: 'week' }), NOW)).toBeInstanceOf(Date);
  });
  it('không có mốc, hoặc đang xem Quá hạn thì không ẩn gì', () => {
    expect(hiddenOverdueBefore(state({}), NOW)).toBeNull();
    expect(
      hiddenOverdueBefore(state({ datePreset: 'week', quick: { overdue: ['overdue'] } }), NOW),
    ).toBeNull();
  });
});
