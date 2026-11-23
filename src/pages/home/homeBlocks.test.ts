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

  it('khối việc theo vai trò: mỗi khối hiện theo quyền và công tắc của màn nguồn', () => {
    const ids = (can: (m: string, a: string) => boolean, feature = () => true) =>
      visibleHomeBlocks(HOME_BLOCKS, can, feature).map((b) => b.id);
    // K09c: không có khối «Nhận xét chờ gửi» (CS-16 đã bỏ).
    expect(ids(only('TICKET|SUA'))).toEqual([]);
    expect(ids(only('SESSION|XEM'), () => false)).toEqual([]);
    expect(ids(only('SALES_ORDER|XEM'))).toEqual(['debt']);
    expect(ids(only('CLASS|DUYET'))).toEqual(['classesPending']);
    expect(ids(only('CLASS|DUYET'), () => false)).toEqual([]);
    expect(ids(only('TICKET|XEM'))).toEqual(['tickets']);
    expect(ids(only('SESSION|XEM'))).toEqual(['sessions', 'sessionsToday']);
    expect(ids(only('CLASS|TAO'))).toEqual([]);
    expect(ids((m, a) => m === '*' && a === 'DUYET')).toEqual(['approvals']);
  });
});
