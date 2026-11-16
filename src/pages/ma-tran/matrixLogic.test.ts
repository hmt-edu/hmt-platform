// QT-05: ô quyền, bản nháp so với hiện hành, danh sách thay đổi gửi hàm lưu, ô khoá của phân hệ Quản trị.
import { describe, expect, it } from 'vitest';
import {
  baseMap,
  cellKey,
  changesOf,
  countForRole,
  describeChange,
  isLockedCell,
  NO_SCOPE,
  scopeAt,
  setCell,
  type Draft,
  type PermissionRow,
} from './matrixLogic';

const rows: PermissionRow[] = [
  {
    role_code: 'SALES',
    module_code: 'LEAD',
    action_code: 'XEM',
    scope_code: 'CO_SO',
    is_active: true,
  },
  {
    role_code: 'SALES',
    module_code: 'LEAD',
    action_code: 'TAO',
    scope_code: 'CUA_TOI',
    is_active: true,
  },
  {
    role_code: 'SALES',
    module_code: 'LEAD',
    action_code: 'HUY',
    scope_code: 'CO_SO',
    is_active: false,
  },
];
const base = baseMap(rows);
const k = (a: string) => cellKey('SALES', 'LEAD', a);

describe('QT-05 ma trận quyền', () => {
  it('bản hiện hành: dòng không hoạt động coi như không có quyền', () => {
    expect(base.get(k('XEM'))).toBe('CO_SO');
    expect(base.has(k('HUY'))).toBe(false);
    expect(scopeAt(base, new Map(), k('HUY'))).toBe(NO_SCOPE);
  });
  it('sửa một ô vào bản nháp, hiện ra giá trị mới', () => {
    const d = setCell(base, new Map(), k('XEM'), 'TOAN_HE_THONG');
    expect(scopeAt(base, d, k('XEM'))).toBe('TOAN_HE_THONG');
    expect(d.size).toBe(1);
  });
  it('đặt lại đúng giá trị hiện hành thì ô không còn «đã sửa»', () => {
    const d1 = setCell(base, new Map(), k('XEM'), 'TOAN_HE_THONG');
    expect(setCell(base, d1, k('XEM'), 'CO_SO').size).toBe(0);
    expect(setCell(base, new Map(), k('HUY'), NO_SCOPE).size).toBe(0);
  });
  it('danh sách thay đổi gửi hàm lưu: vai trò, phân hệ, hành động, phạm vi (rỗng = tắt)', () => {
    let d: Draft = setCell(base, new Map(), k('XEM'), NO_SCOPE);
    d = setCell(base, d, k('SUA'), 'CO_SO');
    expect(changesOf(d)).toEqual([
      { role: 'SALES', module: 'LEAD', action: 'XEM', scope: '' },
      { role: 'SALES', module: 'LEAD', action: 'SUA', scope: 'CO_SO' },
    ]);
    expect(countForRole(d, 'SALES')).toBe(2);
    expect(countForRole(d, 'CSKH')).toBe(0);
  });
  it('phân hệ Quản trị chỉ ADMIN: ô của vai trò khác bị khoá', () => {
    expect(isLockedCell('SALES', 'ADMIN')).toBe(true);
    expect(isLockedCell('ADMIN', 'ADMIN')).toBe(false);
    expect(isLockedCell('SALES', 'LEAD')).toBe(false);
  });
  it('câu mô tả thay đổi trong lịch sử', () => {
    const names = {
      role: () => 'CSKH',
      module: () => 'Ticket',
      action: () => 'Giao việc',
      scope: (c: string | null) => (c ? 'Cơ sở mình' : 'Không có'),
    };
    expect(
      describeChange(
        {
          version_no: 9,
          role_code: 'CSKH',
          module_code: 'TICKET',
          action_code: 'GIAO_VIEC',
          from_scope: null,
          to_scope: 'CO_SO',
        },
        names,
      ),
    ).toBe('CSKH: Ticket · Giao việc, Không có → Cơ sở mình');
  });
});
