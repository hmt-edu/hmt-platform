import { describe, expect, it } from 'vitest';
import {
  metaFromSource,
  parseFrontmatterFields,
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
