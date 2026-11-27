import { describe, expect, it } from 'vitest';
import {
  engagementTag,
  hasHiddenMoney,
  parentCards,
  parentFlags,
  studentFlags,
  type ParentSummary,
  type StudentSummary,
} from './summaryLogic';

const common = {
  branch_id: 'b',
  upsale_id: null,
  tickets: { open: 0, overdue: 0 },
  last_contact: null,
  contact_visible: true,
  missing_review: 0,
  days_since_created: 0,
  stale_days: 30,
};
const parent: ParentSummary = {
  ...common,
  children_total: 2,
  studying_names: ['Em Giả'],
  expiring_names: [],
  money: { paid_total: 0, debt: 0, balance: 0, overdue_days: null },
};
const student: StudentSummary = {
  ...common,
  class: null,
  next_session: null,
  hours_left: null,
  expiring: false,
  attendance: { rate: null, window_days: 30, absent_streak: 0 },
  last_score: null,
  care_staff: null,
  absence_limit: 3,
  overdue_days: null,
  engagement: null,
};

describe('Hồ sơ 360°: thẻ tóm tắt và cờ', () => {
  it('hồ sơ ổn thì không có cờ', () => {
    expect(parentFlags(parent)).toEqual([]);
    expect(studentFlags(student)).toEqual([]);
  });
  it('không có quyền xem tiền: ô tiền ghi «Ẩn», cờ nợ quá hạn vẫn hiện (KH02_360_an_tien)', () => {
    const s = {
      ...parent,
      money: { paid_total: null, debt: null, balance: null, overdue_days: 3 },
    };
    expect(hasHiddenMoney(s)).toBe(true);
    expect(parentCards(s).filter((c) => c.value === 'Ẩn')).toHaveLength(3);
    expect(parentCards(s).find((c) => c.key === 'debt')?.note).toBeUndefined();
    expect(parentFlags(s)).toEqual([{ target: 'finance', label: 'Nợ quá hạn 3 ngày' }]);
  });
  it('lâu chưa liên hệ: đếm từ lần liên hệ cuối, chưa liên hệ thì từ ngày tạo', () => {
    expect(parentFlags({ ...parent, days_since_created: 30 })[0]?.target).toBe('contacts');
    expect(
      parentFlags({
        ...parent,
        days_since_created: 99,
        last_contact: { at: '2026-11-20T00:00:00Z', channel: 'Zalo', days: 7 },
      }),
    ).toEqual([]);
    expect(parentFlags({ ...parent, days_since_created: 99, contact_visible: false })).toEqual([]);
  });
  it('vắng liên tiếp chỉ báo từ ngưỡng', () => {
    const at = (n: number) =>
      studentFlags({ ...student, attendance: { ...student.attendance, absent_streak: n } });
    expect(at(2)).toEqual([]);
    expect(at(3)).toEqual([{ target: 'attendance', label: 'Vắng liên tiếp · 3 buổi' }]);
  });
  it('học sinh có đơn quá hạn thì có cờ nợ (R-CRM-44)', () => {
    expect(studentFlags({ ...student, overdue_days: 5 })).toEqual([
      { target: 'finance', label: 'Nợ quá hạn 5 ngày' },
    ]);
  });
  it('Mức gắn bó luôn kèm lý do, mỗi lý do mở đúng chỗ (R-CRM-44)', () => {
    expect(
      engagementTag({ level: 'NGUY_CO', score: 3, reasons: ['NO_QUA_HAN', 'LAU_CHUA_LIEN_HE'] }),
    ).toEqual({
      tone: 'danger',
      label: 'Mức gắn bó: Nguy cơ',
      reasons: [
        { label: 'nợ quá hạn', target: 'finance' },
        { label: 'lâu chưa liên hệ', target: 'contacts' },
      ],
    });
    expect(engagementTag({ level: 'KHOE', score: 0, reasons: [] }).reasons).toEqual([]);
  });
});
