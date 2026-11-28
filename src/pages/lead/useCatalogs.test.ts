import { describe, expect, it } from 'vitest';
import {
  CATALOGS,
  activeOptions,
  childOptions,
  filterOptions,
  optionsAppliesTo,
  type CatalogItem,
} from './useCatalogs';

const item = (
  id: string,
  catalog: string,
  code: string,
  parent: string | null,
  active = true,
): CatalogItem => ({
  id,
  catalog_code: catalog,
  code,
  name: `Tên ${code}`,
  is_active: active,
  parent_id: parent,
  requires_note: false,
  applies_to: null,
});

// Hai nguồn: FB (đang dùng, hai kênh đang dùng, một kênh Ngừng), TT (đã Ngừng, hai kênh đang dùng).
const all: CatalogItem[] = [
  item('s1', 'SOURCE', 'FB', null),
  item('s2', 'SOURCE', 'TT', null, false),
  item('c1', 'SOURCE_CHANNEL', 'CHAT', 's1'),
  item('c2', 'SOURCE_CHANNEL', 'COMMENT', 's1'),
  item('c3', 'SOURCE_CHANNEL', 'CU', 's1', false),
  item('c4', 'SOURCE_CHANNEL', 'LIVE', 's2'),
  item('c5', 'SOURCE_CHANNEL', 'SHOP', 's2'),
];
const values = (o: { value: string }[]) => o.map((x) => x.value);

describe('R-V2-43: ô chọn kênh con theo mục cha', () => {
  it('mục cha đang dùng: chỉ các kênh con đang dùng', () => {
    expect(values(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', 'FB'))).toEqual([
      'CHAT',
      'COMMENT',
    ]);
  });
  it('ngừng mục cha: kênh con tự ẩn khỏi ô chọn mới (kể cả kênh đang dùng)', () => {
    expect(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', 'TT')).toEqual([]);
  });
  it('dùng lại mục cha: các kênh đang dùng hiện lại; kênh Ngừng riêng vẫn ẩn', () => {
    const reused = all.map((i) => (i.code === 'TT' ? { ...i, is_active: true } : i));
    expect(values(childOptions(reused, 'SOURCE_CHANNEL', 'SOURCE', 'TT'))).toEqual([
      'LIVE',
      'SHOP',
    ]);
    expect(values(childOptions(reused, 'SOURCE_CHANNEL', 'SOURCE', 'FB'))).not.toContain('CU');
  });
  it('trạng thái từng kênh con giữ nguyên khi mục cha Ngừng (dữ liệu không đổi)', () => {
    expect(all.find((i) => i.code === 'LIVE')?.is_active).toBe(true);
    expect(all.find((i) => i.code === 'CU')?.is_active).toBe(false);
  });
  it('bản ghi cũ vẫn hiện giá trị đã lưu dù kênh hoặc nguồn cha đã Ngừng', () => {
    expect(values(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', 'TT', 'LIVE'))).toEqual(['LIVE']);
    expect(values(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', 'FB', 'CU'))).toEqual([
      'CHAT',
      'COMMENT',
      'CU',
    ]);
  });
  it('mã giữ lại thuộc nguồn khác thì không lẫn vào nguồn đang chọn', () => {
    expect(values(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', 'FB', 'LIVE'))).toEqual([
      'CHAT',
      'COMMENT',
    ]);
  });
  it('chưa chọn mục cha hoặc mã cha không có: không có kênh nào', () => {
    expect(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', null)).toEqual([]);
    expect(childOptions(all, 'SOURCE_CHANNEL', 'SOURCE', 'KHONG_CO')).toEqual([]);
  });
});

describe('Q-127: bộ lọc danh sách liệt kê cả kênh Ngừng, kèm nhãn (ngừng)', () => {
  it('kênh Ngừng riêng và kênh của nguồn Ngừng đều có trong bộ lọc; kênh đang dùng giữ tên', () => {
    const opts = filterOptions(all, 'SOURCE_CHANNEL');
    expect(opts.map((o) => o.value)).toEqual(['CHAT', 'COMMENT', 'CU', 'LIVE', 'SHOP']);
    expect(opts.find((o) => o.value === 'CHAT')?.label).toBe('Tên CHAT');
    expect(opts.find((o) => o.value === 'CU')?.label).toBe('Tên CU (ngừng)');
  });
  it('ô chọn khi tạo hoặc sửa không có kênh Ngừng (R-V2-43)', () => {
    expect(values(activeOptions(all, 'SOURCE_CHANNEL'))).not.toContain('CU');
  });
});

describe('ô chọn danh mục một cấp', () => {
  it('mục Ngừng không hiện ở ô chọn mới, nhưng bản ghi cũ giữ giá trị đã lưu', () => {
    expect(values(activeOptions(all, 'SOURCE'))).toEqual(['FB']);
    expect(values(activeOptions(all, 'SOURCE', 'TT'))).toEqual(['FB', 'TT']);
  });
});

describe('optionsAppliesTo (kênh hệ thống không chọn tay, D-23-38)', () => {
  const channel = (code: string, applies_to: string[] | null): CatalogItem => ({
    id: code,
    catalog_code: 'TICKET_CHANNEL',
    code,
    name: code,
    is_active: true,
    parent_id: null,
    requires_note: false,
    applies_to,
  });
  const all = [
    channel('ZALO', []),
    channel('GOI_DIEN', null),
    channel('PH_KHONG_DONG_Y', ['HE_THONG']),
  ];
  it('chỉ liệt kê mục để trống hoặc có đúng đối tượng', () => {
    expect(optionsAppliesTo(all, 'TICKET_CHANNEL', 'TICKET_TAY').map((o) => o.value)).toEqual([
      'ZALO',
      'GOI_DIEN',
    ]);
    expect(optionsAppliesTo(all, 'TICKET_CHANNEL', 'HE_THONG').map((o) => o.value)).toContain(
      'PH_KHONG_DONG_Y',
    );
  });
});

describe('danh mục được nạp', () => {
  it('có đủ danh mục của màn Điểm danh (ô thiếu danh mục sẽ rỗng mà không báo lỗi)', () => {
    expect(CATALOGS).toContain('ATTENDANCE_STATUS');
    expect(CATALOGS).toContain('ATTENDANCE_CONTACT_REASON');
  });
});

describe('mọi mã danh mục viết trong màn dùng useLeadCatalogs đều được nạp', () => {
  const sources = import.meta.glob<string>('/src/**/*.{ts,tsx}', {
    query: '?raw',
    import: 'default',
    eager: true,
  });
  const used = new Set<string>();
  for (const [path, text] of Object.entries(sources)) {
    if (path.includes('.test.') || !/\buseLeadCatalogs\(/.test(text)) continue;
    for (const m of text.matchAll(
      /\bcatalogs\.(?:name|options|filterOptions|optionsFor|requiresNote|childrenOf)\(\s*'([A-Z_]+)'/g,
    ))
      used.add(m[1] ?? '');
  }

  it('dò được mã trong màn', () => {
    expect(used).toContain('RENEWAL_LOST_REASON');
    expect(used).toContain('RECEIVING_ACCOUNT');
  });
  it('không mã nào thiếu trong CATALOGS (thiếu thì ô chọn rỗng, không chuyển được L5)', () => {
    expect([...used].filter((code) => !CATALOGS.includes(code))).toEqual([]);
  });
});
