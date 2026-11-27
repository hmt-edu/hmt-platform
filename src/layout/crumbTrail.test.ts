import { describe, expect, it } from 'vitest';
import { fromOf, mergeTrail, trailOf, type Crumb } from './crumbTrail';

const oppPage: Crumb[] = [
  { label: 'Tuyển sinh' },
  { label: 'Cơ hội', to: '/crm/co-hoi' },
  { label: 'Em Giả A · Phụ huynh Giả B' },
];
const own: Crumb[] = [
  { label: 'Tuyển sinh' },
  { label: 'Phiếu Test', to: '/crm/phieu-kiem-tra' },
  { label: 'PKT000001 · Em Giả A' },
];

describe('trailOf', () => {
  it('mục cuối (tên bản ghi) trỏ về chính trang gốc để bấm quay lại', () => {
    expect(trailOf({ crumbs: oppPage, here: '/crm/co-hoi/abc' })).toEqual([
      { label: 'Tuyển sinh' },
      { label: 'Cơ hội', to: '/crm/co-hoi' },
      { label: 'Em Giả A · Phụ huynh Giả B', to: '/crm/co-hoi/abc' },
    ]);
  });
});

describe('mergeTrail', () => {
  it('không có trang gốc thì giữ đường dẫn theo menu', () => {
    expect(mergeTrail(null, own, '/crm/phieu-kiem-tra/x')).toEqual(own);
  });
  it('mở từ bản ghi cha: chỉ thêm tên trang đích, bỏ tầng danh sách ở giữa (H1)', () => {
    const from = trailOf({ crumbs: oppPage, here: '/crm/co-hoi/abc' });
    expect(mergeTrail(from, own, '/crm/phieu-kiem-tra/x').map((c) => c.label)).toEqual([
      'Tuyển sinh',
      'Cơ hội',
      'Em Giả A · Phụ huynh Giả B',
      'PKT000001 · Em Giả A',
    ]);
  });
  it('quay lại trang đã đi qua thì cắt đường dẫn tới đó, không nối dài', () => {
    const toTest = mergeTrail(
      trailOf({ crumbs: oppPage, here: '/crm/co-hoi/abc' }),
      own,
      '/crm/phieu-kiem-tra/x',
    );
    const back = mergeTrail(
      trailOf({ crumbs: toTest, here: '/crm/phieu-kiem-tra/x' }),
      oppPage,
      '/crm/co-hoi/abc',
    );
    expect(back.map((c) => c.label)).toEqual([
      'Tuyển sinh',
      'Cơ hội',
      'Em Giả A · Phụ huynh Giả B',
    ]);
    expect(back[2]?.to).toBeUndefined();
  });
  it('mở một dòng từ danh sách lọc theo cha: bỏ tầng danh sách, giữ bản ghi cha (H1)', () => {
    const filtered: Crumb[] = [
      ...trailOf({ crumbs: oppPage, here: '/crm/co-hoi/abc' }),
      { label: 'Phiếu Test' },
    ];
    const from = trailOf({
      crumbs: filtered,
      here: '/crm/phieu-kiem-tra?co-hoi=abc',
      dropLast: true,
    });
    expect(mergeTrail(from, own, '/crm/phieu-kiem-tra/x').map((c) => c.label)).toEqual([
      'Tuyển sinh',
      'Cơ hội',
      'Em Giả A · Phụ huynh Giả B',
      'PKT000001 · Em Giả A',
    ]);
    expect(from[2]?.to).toBe('/crm/co-hoi/abc');
  });
  it('trang đích là danh sách (chỉ nhóm và mục) cũng nối tiếp', () => {
    const list: Crumb[] = [{ label: 'Tuyển sinh' }, { label: 'Lịch hẹn' }];
    expect(
      mergeTrail(trailOf({ crumbs: oppPage, here: '/crm/co-hoi/abc' }), list, '/crm/lich-hen').map(
        (c) => c.label,
      ),
    ).toEqual(['Tuyển sinh', 'Cơ hội', 'Em Giả A · Phụ huynh Giả B', 'Lịch hẹn']);
  });
});

describe('fromOf', () => {
  it('đọc đường dẫn gốc hợp lệ, bỏ qua dữ liệu lạ', () => {
    expect(fromOf({ from: [{ label: 'A', to: '/a' }] })).toEqual([{ label: 'A', to: '/a' }]);
    expect(fromOf(null)).toBeNull();
    expect(fromOf({ from: 'x' })).toBeNull();
    expect(fromOf({ from: [{ nhan: 1 }] })).toBeNull();
  });
});
