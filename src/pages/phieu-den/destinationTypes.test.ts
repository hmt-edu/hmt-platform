import { describe, expect, it } from 'vitest';
import { hasSavedDestinationClass, validateDestinationChoice } from './destinationTypes';

describe('CS-07 cơ sở đích', () => {
  it('thiếu lớp hoặc buổi thì báo lỗi, đủ thì qua', () => {
    expect(validateDestinationChoice('', '').classId).toBeDefined();
    expect(validateDestinationChoice('c1', '').startDate).toBeDefined();
    expect(validateDestinationChoice('c1', '2026-11-30')).toEqual({});
  });
  it('chỉ cho Duyệt khi lớp đã được lưu vào phiếu', () => {
    const base = { to_class_id: null, start_date: null } as never;
    expect(hasSavedDestinationClass(base)).toBe(false);
    expect(hasSavedDestinationClass({ to_class_id: 'c', start_date: '2026-11-30' } as never)).toBe(
      true,
    );
  });
});
