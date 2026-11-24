import { describe, expect, it } from 'vitest';
import {
  metaFromSource,
  parseFrontmatterFields,
  parentKey,
  sortGuideMetas,
  splitFrontmatter,
  stripFrontmatter,
} from './frontmatter';

const bai = (head: string) => `---\n${head}\n---\n\n# Bài\n\nNội dung.\n`;

describe('Phần đầu bài hướng dẫn (A-23-42)', () => {
  it('tách phần đầu khỏi thân bài; tệp không có phần đầu giữ nguyên', () => {
    expect(splitFrontmatter(bai('title: A')).body.trim().startsWith('# Bài')).toBe(true);
    expect(splitFrontmatter('# Không có\n').raw).toBeNull();
    expect(splitFrontmatter('---\nchưa đóng\n# Bài').raw).toBeNull();
    expect(stripFrontmatter(bai('title: A')).includes('title:')).toBe(false);
  });
  it('đọc chuỗi, mảng, dấu ngoặc kép; bỏ dòng trống và ghi chú', () => {
    expect(
      parseFrontmatterFields('title: Vai: Kế toán\n# ghi chú\n\nscreens: [TS-01, "TS-02"]'),
    ).toEqual({
      title: 'Vai: Kế toán',
      screens: ['TS-01', 'TS-02'],
    });
    expect(() => parseFrontmatterFields('không có dấu hai chấm')).toThrow();
  });
  it('dựng mục lục: mặc định cổng CRM, slug từ đường dẫn thư mục con', () => {
    const m = metaFromSource(
      'tu-van/nhap-lead-tu-file.md',
      bai(
        'title: Nhập lead\ngroup: vai\npriority: P1\nflow: ts2\nscreens: [TS-04]\nchecked: 2026-11-24',
      ),
    );
    expect(m).toMatchObject({
      slug: 'tu-van-nhap-lead-tu-file',
      group: 'vai',
      portals: ['crm'],
      priority: 'P1',
      flow: 'ts2',
      screens: ['TS-04'],
      checked: '2026-11-24',
    });
  });
  it('tệp không có phần đầu không phải bài (null); phần đầu sai khuôn thì báo lỗi nêu tên tệp', () => {
    expect(metaFromSource('README.md', '# Mô tả')).toBeNull();
    expect(() => metaFromSource('x.md', bai('group: vai'))).toThrow(/x\.md.*title/);
    expect(() => metaFromSource('x.md', bai('title: A\ngroup: la'))).toThrow(/group/);
    expect(() => metaFromSource('x.md', bai('title: A\ngroup: vai\nportals: [tv]'))).toThrow(
      /portals/,
    );
    expect(() => metaFromSource('x.md', bai('title: A\ngroup: vai\norder: abc'))).toThrow(/order/);
    expect(() => metaFromSource('x.md', bai('title: A\ngroup: vai\nslug: Sai Slug'))).toThrow(
      /slug/,
    );
  });
  it('sắp theo nhóm, rồi order, rồi đường dẫn', () => {
    const mk = (file: string, group: string, order: number) =>
      metaFromSource(file, bai(`title: ${file}\ngroup: ${group}\norder: ${order}`))!;
    const out = sortGuideMetas([
      mk('b.md', 'tra-cuu', 1),
      mk('z.md', 'vai', 2),
      mk('a.md', 'vai', 2),
      mk('c.md', 'bat-dau', 9),
    ]);
    expect(out.map((x) => x.file)).toEqual(['c.md', 'a.md', 'z.md', 'b.md']);
  });
});

describe('Phần đầu kiểu quy cách đợt 1 (id, ten, vai, uu_tien…)', () => {
  it('đọc được: tên, nhóm vai, slug từ id, ưu tiên, mã màn, cổng theo vai', () => {
    const text = `---\nid: BH1\nten: Lập báo giá\nvai: [tu-van, giao-vien]\nphan_he: ban-hang\nma_man: [BH-01, BH-02]\nuu_tien: P1\ncap_nhat: 2026-11-24\n---\n\n# x\n`;
    const m = metaFromSource('ban-hang-thu-chi/BH1-lap-bao-gia.md', text);
    expect(m).toMatchObject({
      title: 'Lập báo giá',
      group: 'vai',
      slug: 'bh1',
      flow: 'BH1',
      priority: 'P1',
      checked: '2026-11-24',
      screens: ['BH-01', 'BH-02'],
      portals: ['crm', 'gv'],
    });
  });
});

describe('Khoá cha của menu (A-23-49)', () => {
  it('parentKey bỏ dấu, chữ thường, gạch nối', () => {
    expect(parentKey('Chăm sóc khách hàng')).toBe('cham-soc-khach-hang');
    expect(parentKey('Đào tạo')).toBe('dao-tao');
    expect(parentKey('quan-tri')).toBe('quan-tri');
  });

  it('parent lấy từ «parent», không có thì từ «phan_he»', () => {
    const a = metaFromSource('x/a.md', '---\nten: A\nphan_he: Thu chi\n---\nthân');
    expect(a?.parent).toBe('thu-chi');
    const b = metaFromSource('x/b.md', '---\nten: B\nphan_he: thu-chi\nparent: dao-tao\n---\nthân');
    expect(b?.parent).toBe('dao-tao');
    const c = metaFromSource('x/c.md', '---\ntitle: C\ngroup: bat-dau\n---\nthân');
    expect(c?.parent).toBeUndefined();
  });
});
