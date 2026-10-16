import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

// Kiểm hệ thiết kế: mọi biến mà hmt-theme.css tham chiếu phải có trong token của gói, và khoá theme của
// Tailwind không được trùng tên biến token (trùng thì Tailwind xuất var(--x) = var(--x), mất giá trị).
const ROOT = process.cwd();

function withoutComments(css: string): string {
  return css.replace(/\/\*[\s\S]*?\*\//g, '');
}

function declared(css: string): string[] {
  return Array.from(css.matchAll(/^\s*(--[a-z0-9-]+)\s*:/gm), (m) => m[1] ?? '');
}

function referenced(css: string): string[] {
  return Array.from(css.matchAll(/var\((--[a-z0-9-]+)\)/g), (m) => m[1] ?? '');
}

const tokens = withoutComments(
  readFileSync(join(ROOT, 'design/hmt-p0-p2/ds/hmt/handoff/hmt-tokens.css'), 'utf8'),
);
const theme = withoutComments(readFileSync(join(ROOT, 'src/styles/hmt-theme.css'), 'utf8'));

const tokenNames = new Set(declared(tokens));
const themeBlock = /@theme inline \{([\s\S]*?)\n\}/.exec(theme)?.[1] ?? '';
const themeKeys = declared(themeBlock);

describe('hmt-theme.css', () => {
  it('đọc được token của gói và khối theme', () => {
    expect(tokenNames.size).toBeGreaterThan(80);
    expect(themeKeys.length).toBeGreaterThan(80);
  });

  it('mọi var(--…) trong khối theme trỏ tới token của gói hoặc biến khai báo trong tệp theme', () => {
    const own = new Set([...declared(theme), ...tokenNames]);
    const missing = referenced(themeBlock).filter((name) => !own.has(name));
    expect(missing).toEqual([]);
  });

  it('khoá theme không trùng tên biến token (tránh vòng lặp var)', () => {
    expect(themeKeys.filter((key) => tokenNames.has(key))).toEqual([]);
  });

  it('chữ trắng chỉ đặt trên nền đủ đậm: nút chính dùng brand-600, không dùng #EF6926', () => {
    expect(tokens).toMatch(/--action-primary-bg:\s*var\(--brand-600\)/);
    expect(theme).not.toMatch(/--color-action:\s*var\(--brand-500\)/);
  });

  it('không còn giá trị tạm: chiều cao hàng bảng và viền thông báo lấy từ token của gói', () => {
    expect(tokens).toMatch(/--table-row-height:\s*36px/);
    expect(tokens).toMatch(/--success-border:\s*#BAD9C4/i);
    expect(theme).toMatch(/--spacing-row:\s*var\(--table-row-height\)/);
    expect(theme).toMatch(/--color-success-border:\s*var\(--success-border\)/);
    expect(theme).toMatch(/--color-warning-border:\s*var\(--warning-border\)/);
    expect(theme).toMatch(/--color-danger-border:\s*var\(--danger-border\)/);
    expect(theme).not.toMatch(/color-mix/);
  });
});
