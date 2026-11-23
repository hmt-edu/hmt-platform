import { describe, expect, it } from 'vitest';
import { GUIDE_SECTIONS } from './guideIndex';

// File trong docs/huong-dan không phải bài hướng dẫn người dùng: không đưa vào menu.
const NOT_GUIDE = new Set(['README.md', 'CHUP-ANH.md']);

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
    const nos = GUIDE_SECTIONS.map((s) => s.no);
    expect(new Set(nos).size).toBe(nos.length);
    expect(GUIDE_SECTIONS[0]?.slug).toBe('bat-dau');
  });
});
