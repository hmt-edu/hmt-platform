import { describe, expect, it } from 'vitest';
import {
  addInputErrors,
  catalogMode,
  childLevelName,
  flattenTree,
  rootLabel,
  summaryLine,
  type CatalogNode,
  type CatalogSummary,
  SESSION_TYPE_CATALOG,
  sessionFormLabel,
} from './catalogLogic';

const node = (
  id: string,
  parent: string | null,
  order: number,
  extra: Partial<CatalogNode> = {},
): CatalogNode => ({
  id,
  catalog_code: parent ? 'CON' : 'GOC',
  code: id.toUpperCase(),
  name: id,
  sort_order: order,
  is_active: true,
  is_locked: false,
  parent_id: parent,
  ...extra,
});

describe('QT-07: cây mục thành danh sách phẳng', () => {
  it('mục cha rồi các mục con, sắp theo thứ tự trong từng nhóm', () => {
    const rows = flattenTree([
      node('b', null, 2),
      node('a', null, 1),
      node('b2', 'b', 2),
      node('b1', 'b', 1),
      node('a1', 'a', 1),
    ]);
    expect(rows.map((r) => `${r.node.id}:${r.depth}`)).toEqual([
      'a:0',
      'a1:1',
      'b:0',
      'b1:1',
      'b2:1',
    ]);
  });
  it('Q-132: số thứ tự hiển thị đếm lại từ 1 trong từng nhóm cùng cha (không dùng số lưu trong DB)', () => {
    const rows = flattenTree([
      node('t', null, 2),
      node('c1', 't', 7),
      node('c2', 't', 8),
      node('s', null, 1),
      node('s1', 's', 20),
    ]);
    const by = Object.fromEntries(rows.map((r) => [r.node.id, r.rank]));
    expect([by.s, by.t]).toEqual([1, 2]);
    expect([by.c1, by.c2]).toEqual([1, 2]);
    expect(by.s1).toBe(1);
  });
  it('first, last theo nhóm cùng cha: ▲ mờ ở mục đầu, ▼ mờ ở mục cuối', () => {
    const rows = flattenTree([node('a', null, 1), node('b', null, 2), node('b1', 'b', 1)]);
    const by = Object.fromEntries(rows.map((r) => [r.node.id, r]));
    expect([by.a?.first, by.a?.last]).toEqual([true, false]);
    expect([by.b?.first, by.b?.last]).toEqual([false, true]);
    expect([by.b1?.first, by.b1?.last]).toEqual([true, true]);
  });
  it('hai mục trùng thứ tự vẫn có thứ tự ổn định (theo id)', () => {
    const rows = flattenTree([node('y', null, 1), node('x', null, 1)]);
    expect(rows.map((r) => r.node.id)).toEqual(['x', 'y']);
  });
  it('tên tầng con để ghi nút "Thêm kênh"; tầng cuối không có', () => {
    const levels = [
      { code: 'A', name: 'Loại nguồn' },
      { code: 'B', name: 'Nguồn' },
      { code: 'C', name: 'Kênh' },
    ];
    expect(childLevelName(levels, 0)).toBe('Nguồn');
    expect(childLevelName(levels, 1)).toBe('Kênh');
    expect(childLevelName(levels, 2)).toBeNull();
  });
});

describe('QT-06: nhãn và tóm tắt danh mục', () => {
  const base: CatalogSummary = {
    code: 'X',
    name: 'X',
    kind: 'MO',
    is_read_only: false,
    description: null,
    levels: [{ code: 'X', name: 'X', total: 6, active: 6 }],
  };
  it('kiểu danh mục: chỉ xem thắng khoá, khoá là danh mục hệ thống, còn lại mở', () => {
    expect(catalogMode(base)).toBe('open');
    expect(catalogMode({ ...base, kind: 'HE_THONG' })).toBe('locked');
    expect(catalogMode({ ...base, kind: 'MO', is_read_only: true })).toBe('view');
    expect(catalogMode({ ...base, kind: 'HE_THONG', is_read_only: true })).toBe('view');
  });
  it('Q-128: tên danh mục gốc hiện theo spec 06 (Nguồn lead, Tỉnh, phường); danh mục khác giữ tên trong DB', () => {
    expect(rootLabel('SOURCE_TYPE', 'Loại nguồn')).toBe('Nguồn lead');
    expect(rootLabel('PROVINCE', 'Tỉnh/Thành phố')).toBe('Tỉnh, phường');
    expect(rootLabel('ACTIVITY_TYPE', 'Loại hoạt động')).toBe('Loại hoạt động');
  });
  it('danh mục chưa có mục nào: "Chưa có mục"', () => {
    expect(summaryLine({ ...base, levels: [{ code: 'X', name: 'X', total: 0, active: 0 }] })).toBe(
      'Chưa có mục',
    );
  });
  it('tóm tắt: số mục, số mục con theo tên tầng, "chỉ đổi tên" cho danh mục khoá', () => {
    expect(summaryLine(base)).toBe('6 mục');
    const nested: CatalogSummary = {
      ...base,
      kind: 'HE_THONG',
      levels: [
        { code: 'G', name: 'Giai đoạn cơ hội', total: 8, active: 8 },
        { code: 'S', name: 'Giai đoạn con cơ hội', total: 62, active: 60 },
      ],
    };
    expect(summaryLine(nested)).toBe('8 mục · 62 mục · chỉ đổi tên');
    // Q-128: tầng có đơn vị riêng theo mã tầng.
    const source: CatalogSummary = {
      ...base,
      levels: [
        { code: 'SOURCE_TYPE', name: 'Loại nguồn', total: 4, active: 4 },
        { code: 'SOURCE', name: 'Nguồn', total: 12, active: 12 },
        { code: 'SOURCE_CHANNEL', name: 'Kênh', total: 14, active: 14 },
      ],
    };
    expect(summaryLine(source)).toBe('4 loại · 12 nguồn · 14 kênh');
    const stage: CatalogSummary = {
      ...base,
      kind: 'HE_THONG',
      levels: [
        { code: 'OPP_STAGE', name: 'Giai đoạn cơ hội', total: 8, active: 8 },
        { code: 'OPP_SUBSTAGE', name: 'Giai đoạn con cơ hội', total: 62, active: 60 },
      ],
    };
    expect(summaryLine(stage)).toBe('8 giai đoạn · 62 nhóm con · chỉ đổi tên');
  });
});

describe('hộp Thêm mục: kiểm mã ở ô nhập', () => {
  it('mã chữ thường được chấp nhận vì sẽ đổi thành chữ hoa', () => {
    expect(addInputErrors('video')).toEqual({});
  });
  it('mã có dấu, khoảng trắng hoặc bắt đầu bằng gạch dưới bị báo', () => {
    expect(addInputErrors('MỚI').code).toContain('chữ viết hoa không dấu');
    expect(addInputErrors('A B').code).toBeDefined();
    expect(addInputErrors('_AB').code).toBeDefined();
  });
  it('mã trống chưa báo lỗi ở ô (nút Thêm mục bị khoá đến khi nhập)', () => {
    expect(addInputErrors('')).toEqual({});
  });
});

describe('A25 Danh mục Loại buổi: cột Form nhận xét (sửa được)', () => {
  it('mã DIEM là Form điểm, mã khác hoặc chưa tải là 9 tiêu chí (R-V2-19, R-V2-20)', () => {
    expect(sessionFormLabel('DIEM')).toBe('Form điểm');
    expect(sessionFormLabel('TIEU_CHI')).toBe('9 tiêu chí');
    expect(sessionFormLabel(undefined)).toBe('9 tiêu chí');
  });
  it('chỉ danh mục SESSION_TYPE có cột này', () => {
    expect(SESSION_TYPE_CATALOG).toBe('SESSION_TYPE');
  });
});
