import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { buildGuideIndex } from './vite-huong-dan-muc-luc.ts';

const bai = (title: string, extra = '') =>
  `---\ntitle: ${title}\ngroup: vai\n${extra}---\n\n# ${title}\n`;

describe('Mục lục Hướng dẫn tự sinh (A-23-42)', () => {
  it('đọc cả thư mục con, bỏ tệp không có phần đầu, sắp theo order', () => {
    const dir = mkdtempSync(join(tmpdir(), 'hd-'));
    mkdirSync(join(dir, 'tu-van'));
    writeFileSync(join(dir, 'README.md'), '# Mô tả');
    writeFileSync(join(dir, 'b.md'), bai('B', 'order: 2\n'));
    writeFileSync(join(dir, 'tu-van', 'a.md'), bai('A', 'order: 1\n'));
    const out = buildGuideIndex(dir);
    expect(out.map((m) => m.file)).toEqual(['tu-van/a.md', 'b.md']);
    expect(out[0]?.slug).toBe('tu-van-a');
  });
  it('hai bài cùng slug thì báo lỗi nêu cả hai tệp', () => {
    const dir = mkdtempSync(join(tmpdir(), 'hd-'));
    writeFileSync(join(dir, 'a.md'), bai('A', 'slug: trung\n'));
    writeFileSync(join(dir, 'b.md'), bai('B', 'slug: trung\n'));
    expect(() => buildGuideIndex(dir)).toThrow(/trung.*a\.md.*b\.md/);
  });
});
