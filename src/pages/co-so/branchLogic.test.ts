import { describe, expect, it } from 'vitest';
import {
  ADDRESS_MAX,
  EMPTY_ROOM_DRAFT,
  foldName,
  roomSummary,
  validateBranch,
  validateRoom,
  type Room,
} from './branchLogic';

const room = (over: Partial<Room>): Room => ({
  id: 'r1',
  branch_id: 'b',
  code: 'P101',
  name: 'Phòng 101',
  capacity: 24,
  is_active: true,
  ...over,
});

describe('QT-08: kiểm biểu mẫu phòng (canvas QT08_loi_phong)', () => {
  it('thêm phòng trống thì báo đủ ba ô', () => {
    expect(Object.keys(validateRoom(EMPTY_ROOM_DRAFT, [], null)).sort()).toEqual([
      'capacity',
      'code',
      'name',
    ]);
  });
  it('mã sai dạng, mã trùng, tên trùng (không phân biệt dấu, hoa thường)', () => {
    const rooms = [room({})];
    expect(validateRoom({ code: 'p101', name: 'A', capacity: '5' }, rooms, null).code).toContain(
      'chữ viết hoa',
    );
    expect(validateRoom({ code: 'P101', name: 'A', capacity: '5' }, rooms, null).code).toContain(
      'đã có',
    );
    expect(
      validateRoom({ code: 'P102', name: 'PHONG 101', capacity: '5' }, rooms, null).name,
    ).toContain('đã có');
  });
  it('câu báo trùng nêu tên cơ sở; sức chứa 0 báo «phải lớn hơn 0» (QT08_loi_phong)', () => {
    const rooms = [room({})];
    const label = 'CS5 Mỹ Đình';
    expect(validateRoom({ code: 'P101', name: 'A', capacity: '5' }, rooms, null, label).code).toBe(
      'Mã P101 đã có trong CS5 Mỹ Đình.',
    );
    expect(
      validateRoom({ code: 'P102', name: 'PHONG 101', capacity: '5' }, rooms, null, label).name,
    ).toBe('Tên phòng này đã có trong CS5 Mỹ Đình.');
    expect(validateRoom({ code: 'P9', name: 'X', capacity: '0' }, [], null).capacity).toBe(
      'Sức chứa phải lớn hơn 0.',
    );
    expect(validateRoom({ code: 'P9', name: 'X', capacity: '' }, [], null).capacity).toBe(
      'Nhập sức chứa, là số lớn hơn 0.',
    );
  });
  it('sức chứa 0, âm, lẻ, trống đều bị chặn', () => {
    for (const c of ['0', '-3', '2.5', '']) {
      expect(validateRoom({ code: 'P9', name: 'X', capacity: c }, [], null).capacity).toBeDefined();
    }
  });
  it('sửa phòng: không kiểm mã, tên của chính nó không bị coi là trùng', () => {
    const rooms = [room({})];
    expect(validateRoom({ code: '', name: 'Phòng 101', capacity: '30' }, rooms, 'r1')).toEqual({});
  });
});

describe('QT-08: kiểm biểu mẫu cơ sở', () => {
  it('tên bắt buộc; địa chỉ không quá giới hạn', () => {
    expect(validateBranch('', '').name).toBeDefined();
    expect(validateBranch('CS5', 'a'.repeat(ADDRESS_MAX + 1)).address).toBeDefined();
    expect(validateBranch('CS5', 'a'.repeat(ADDRESS_MAX))).toEqual({});
  });
});

describe('QT-08: tiện ích', () => {
  it('foldName bỏ dấu và gộp khoảng trắng', () => {
    expect(foldName('  Phòng   Đào ')).toBe('phong dao');
  });
  it('tóm tắt số phòng', () => {
    expect(roomSummary([room({}), room({ id: 'r2', is_active: false })])).toBe(
      '2 phòng (1 đang dùng)',
    );
  });
});
