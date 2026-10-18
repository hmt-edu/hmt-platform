import { describe, expect, it } from 'vitest';
import { HOME_BLOCKS, visibleHomeBlocks } from './homeBlocks';

const only =
  (...keys: string[]) =>
  (module: string, action: string) =>
    keys.includes(`${module}|${action}`);

describe('khối của Trang chủ hiện theo quyền và công tắc tính năng', () => {
  it('có quyền xem lịch hẹn và phân hệ bật thì thấy khối lịch hẹn', () => {
    const shown = visibleHomeBlocks(HOME_BLOCKS, only('APPOINTMENT|XEM'), () => true);
    expect(shown.map((b) => b.id)).toEqual(['appointments']);
  });

  it('không có quyền xem lịch hẹn thì không thấy', () => {
    expect(visibleHomeBlocks(HOME_BLOCKS, only('LEAD|XEM'), () => true)).toEqual([]);
  });

  it('phân hệ tắt ở cơ sở thì ẩn dù có quyền', () => {
    expect(visibleHomeBlocks(HOME_BLOCKS, only('APPOINTMENT|XEM'), () => false)).toEqual([]);
  });
});
