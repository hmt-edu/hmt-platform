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

// File trong docs/huong-dan không phải bài hướng dẫn người dùng: không đưa vào menu.
const NOT_GUIDE = new Set(['README.md', 'CHUP-ANH.md', 'KE-NGHIEP-VU.md']);

// Liệt kê file thật bằng chính cơ chế guideIndex dùng (Vite glob), không cần thư viện Node.
const found = Object.keys(import.meta.glob('../../../docs/huong-dan/*.md', { query: '?raw' })).map(
  (path) => path.slice(path.lastIndexOf('/') + 1),
);

describe('Danh mục Hướng dẫn (guideIndex)', () => {
  it('mọi file .md trong docs/huong-dan đều có trong danh mục (không có tài liệu «vô hình»)', () => {
    const registered = new Set(GUIDE_SECTIONS.map((s) => s.file));
    const missing = found.filter((f) => !NOT_GUIDE.has(f) && !registered.has(f));
    expect(missing, `Chưa đăng ký trong guideIndex.ts: ${missing.join(', ')}`).toEqual([]);
  });

  it('mọi mục trỏ tới file có thật', () => {
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
const sources = import.meta.glob<string>('../../../docs/huong-dan/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
});

describe('Số mục trên menu khớp tiêu đề bài', () => {
  it('tiêu đề bài bắt đầu bằng «<số>. » thì số đó bằng số mục trên menu', () => {
    const lech: string[] = [];
    for (const s of GUIDE_SECTIONS) {
      const text = sources[`../../../docs/huong-dan/${s.file}`] ?? '';
      const m = /^# (\d+[a-z]?)\.\s/.exec(text);
      if (m && m[1] !== s.no) lech.push(`${s.file}: tiêu đề ${m[1]}, menu ${s.no}`);
    }
    expect(lech).toEqual([]);
  });
});

describe('Hướng dẫn cổng Giáo viên (A-23-38)', () => {
  it('chỉ hiện thao tác cơ bản, bài Giáo viên và hỏi đáp; mở đầu bằng bài Giáo viên', () => {
    expect(sectionsFor('gv').map((s) => s.slug)).toEqual([
      'thao-tac-co-ban',
      'giao-vien',
      'hoi-dap',
    ]);
    expect(defaultSectionFor('gv').slug).toBe('giao-vien');
    expect(defaultSectionFor('crm').slug).toBe('bat-dau');
  });
  it('bài trước/sau của cổng Giáo viên không nhảy sang bài CRM', () => {
    expect(neighbours('giao-vien', 'gv')).toMatchObject({
      prev: { slug: 'thao-tac-co-ban' },
      next: { slug: 'hoi-dap' },
    });
    expect(neighbours('hoi-dap', 'gv').next).toBeUndefined();
  });
});
