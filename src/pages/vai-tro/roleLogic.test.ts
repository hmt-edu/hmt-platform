// QT-04: nhãn cổng vào (có «chỉ xem»), lọc theo tên hoặc mã.
import { describe, expect, it } from 'vitest';
import { filterRoles, portalsLabel, type RoleSummary } from './roleLogic';

const role = (over: Partial<RoleSummary>): RoleSummary => ({
  code: 'SALES',
  name: 'Tuyển sinh',
  default_scope: 'CO_SO',
  portals: ['crm'],
  view_only_portals: [],
  require_mfa: false,
  idle_group: 'staff',
  sort_order: 3,
  users: 2,
  cells: 40,
  ...over,
});

describe('QT-04 vai trò', () => {
  it('cổng vào: tên cổng, ghi «chỉ xem» với cổng chỉ xem, không cổng thì báo chưa có', () => {
    expect(portalsLabel(role({}))).toBe('CRM');
    expect(
      portalsLabel(role({ portals: ['crm', 'gv', 'hoc'], view_only_portals: ['gv', 'hoc'] })),
    ).toBe('CRM, Giáo viên (chỉ xem), Học tập (chỉ xem)');
    expect(portalsLabel(role({ portals: [] }))).toBe('Chưa có cổng');
  });
  it('lọc theo tên hoặc mã, không phân biệt hoa thường', () => {
    const list = [role({}), role({ code: 'CSKH', name: 'Chăm sóc, vận hành lớp' })];
    expect(filterRoles(list, '')).toHaveLength(2);
    expect(filterRoles(list, 'tuyển')).toHaveLength(1);
    expect(filterRoles(list, 'cskh')[0]?.code).toBe('CSKH');
    expect(filterRoles(list, 'không có')).toHaveLength(0);
  });
});
