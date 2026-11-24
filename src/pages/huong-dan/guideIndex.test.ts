import { describe, expect, it } from 'vitest';
import {
  GUIDE_GROUPS,
  defaultSectionFor,
  sectionsFor,
  GUIDE_SECTIONS,
  GUIDE_SLUG_ALIASES,
  findSection,
  neighbours,
} from './guideIndex';
import { stripFrontmatter } from './frontmatter';

// Tệp trong docs/huong-dan KHÔNG có phần đầu (frontmatter) thì không phải bài người dùng: chỉ các tệp này được phép.
const NOT_GUIDE = new Set(['README.md', 'CHUP-ANH.md', 'KE-NGHIEP-VU.md', 'video-huong-dan.md']);

// Liệt kê tệp thật bằng chính cơ chế guideIndex dùng (Vite glob), gồm cả thư mục con.
const raw = import.meta.glob<string>('../../../docs/huong-dan/**/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
});
const PREFIX = '../../../docs/huong-dan/';
const found = Object.keys(raw).map((path) => path.slice(PREFIX.length));

describe('Danh mục Hướng dẫn (guideIndex)', () => {
  it('mọi tệp .md trong docs/huong-dan có phần đầu thì vào danh mục; không có thì phải nằm trong danh sách ngoại lệ', () => {
    const registered = new Set(GUIDE_SECTIONS.map((s) => s.file));
    const lech = found.filter((f) => {
      const hasHead = (raw[`${PREFIX}${f}`] ?? '').startsWith('---');
      return hasHead ? !registered.has(f) : !NOT_GUIDE.has(f.slice(f.lastIndexOf('/') + 1));
    });
    expect(
      lech,
      `Thêm phần đầu (title, group…) vào bài, hoặc đưa vào NOT_GUIDE: ${lech.join(', ')}`,
    ).toEqual([]);
  });

  it('mọi mục trỏ tới tệp có thật', () => {
    const ghost = GUIDE_SECTIONS.filter((s) => !found.includes(s.file)).map((s) => s.file);
    expect(ghost).toEqual([]);
  });

  it('slug và số thứ tự không trùng; mục đầu giữ slug mặc định bat-dau', () => {
    const slugs = GUIDE_SECTIONS.map((s) => s.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
    const nos = GUIDE_SECTIONS.map((s) => s.no).filter((n) => n !== undefined);
    expect(new Set(nos).size).toBe(nos.length);
    expect(GUIDE_SECTIONS[0]?.slug).toBe('bat-dau');
  });
});

describe('Menu gọn (A-23-37)', () => {
  it('mọi mục thuộc đúng một nhóm có tiêu đề; không còn bài trùng nội dung cũ', () => {
    const keys = new Set(GUIDE_GROUPS.map((g) => g.key));
    expect(GUIDE_SECTIONS.every((s) => keys.has(s.group))).toBe(true);
    const files = GUIDE_SECTIONS.map((s) => s.file);
    for (const old of ['chung.md', 'sale.md', 'cskh.md', 'ke-toan.md', 'truong-co-so.md'])
      expect(files).not.toContain(old);
  });
  it('địa chỉ cũ đổi sang mục mới có thật', () => {
    for (const to of Object.values(GUIDE_SLUG_ALIASES)) expect(findSection(to)).toBeDefined();
    expect(findSection('sale')?.slug).toBe('theo-vai-tu-van');
  });
  it('bài trước / bài sau theo đúng thứ tự menu; đầu không có bài trước, cuối không có bài sau', () => {
    expect(neighbours(GUIDE_SECTIONS[0]!.slug).prev).toBeUndefined();
    expect(neighbours(GUIDE_SECTIONS[0]!.slug).next?.slug).toBe(GUIDE_SECTIONS[1]!.slug);
    expect(neighbours(GUIDE_SECTIONS[GUIDE_SECTIONS.length - 1]!.slug).next).toBeUndefined();
  });
});

// Số trên menu phải khớp số ở dòng tiêu đề của bài (B-23-38): mục có số ở tiêu đề thì menu hiện đúng số đó.
const sources = raw;

describe('Số mục trên menu khớp tiêu đề bài', () => {
  it('tiêu đề bài bắt đầu bằng «<số>. » thì số đó bằng số mục trên menu', () => {
    const lech: string[] = [];
    for (const s of GUIDE_SECTIONS) {
      const text = stripFrontmatter(sources[`${PREFIX}${s.file}`] ?? '');
      const m = /^# (\d+[a-z]?)\.\s/.exec(text);
      if (m && m[1] !== s.no) lech.push(`${s.file}: tiêu đề ${m[1]}, menu ${s.no}`);
    }
    expect(lech).toEqual([]);
  });
});

describe('Hướng dẫn cổng Giáo viên (A-23-38)', () => {
  it('chỉ hiện bài gắn cổng Giáo viên (phần chung, bài Giáo viên, hỏi đáp); không có bài vai CRM; mở đầu bằng bài Giáo viên', () => {
    const slugs = sectionsFor('gv').map((s) => s.slug);
    expect(slugs).toEqual(expect.arrayContaining(['chung-dang-nhap', 'giao-vien', 'hoi-dap']));
    expect(slugs).not.toContain('theo-vai-ke-toan');
    expect(slugs).not.toContain('bat-dau');
    expect(defaultSectionFor('gv').slug).toBe('giao-vien');
    expect(defaultSectionFor('crm').slug).toBe('bat-dau');
  });
  it('bài trước/sau của cổng Giáo viên không nhảy sang bài CRM', () => {
    const n = neighbours('giao-vien', 'gv');
    expect(sectionsFor('gv').map((x) => x.slug)).toContain(n.prev?.slug);
    expect(n.next).toMatchObject({ slug: 'giao-vien-gv1-hom-nay' });
    expect(neighbours('giao-vien-gv13-cham-kiem-tra', 'gv').next).toMatchObject({
      slug: 'hoi-dap',
    });
    expect(neighbours('hoi-dap', 'gv').next).toBeUndefined();
  });
});
