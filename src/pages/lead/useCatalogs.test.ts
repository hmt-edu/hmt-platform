import { describe, expect, it } from 'vitest';
import { activeOptions, childOptions, filterOptions, type CatalogItem } from './useCatalogs';

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
