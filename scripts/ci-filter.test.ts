import { execFileSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';
import { isDbOnly, isSkippable, needsE2e, needsFullCi, touchesUi } from './ci-filter';

describe('bộ lọc CI (Đ281, Q-C3)', () => {
  it('chỉ deploy/: bỏ DB + Playwright và bản xem trước', () => {
    const files = ['deploy/README.md', 'deploy/.github/workflows/backup.yml'];
    expect(needsFullCi(files)).toBe(false);
    expect(touchesUi(files)).toBe(false);
  });

  it('deploy/ cùng src/: chạy đủ, cần bản xem trước', () => {
    const files = ['deploy/README.md', 'src/pages/don-hang/OrderRecordPage.tsx'];
    expect(needsFullCi(files)).toBe(true);
    expect(touchesUi(files)).toBe(true);
  });

  it('chỉ .github/: chạy đủ', () => {
    expect(needsFullCi(['.github/workflows/deploy-staging.yml'])).toBe(true);
    expect(needsFullCi(['.github/workflows/ci.yml'])).toBe(true);
  });

  it('thư mục mới, file lạ: mặc định chạy đủ', () => {
    expect(needsFullCi(['tools/moi/chay.sh'])).toBe(true);
    expect(needsFullCi(['file-la.xyz'])).toBe(true);
    expect(needsFullCi(['deploy/README.md', 'thu-muc-moi/a.txt'])).toBe(true);
  });

  it('docs, design, *.md: được bỏ; scripts/, supabase/: chạy đủ', () => {
    expect(needsFullCi(['docs/TIEN-DO.md', 'design/hmt-p0-p2/x.html', 'README.md'])).toBe(false);
    expect(needsFullCi(['CLAUDE.md', 'docs/a.md'])).toBe(false);
    expect(needsFullCi(['scripts/check-all.sh'])).toBe(true);
    expect(needsFullCi(['supabase/migrations/20261028000063_x.sql'])).toBe(true);
    expect(needsFullCi(['package.json'])).toBe(true);
  });

  it('không có danh sách file (lỗi lấy file): chạy đủ, kể cả bản xem trước', () => {
    expect(needsFullCi([])).toBe(true);
    expect(touchesUi([])).toBe(true);
  });

  it('Playwright (needsE2e): chỉ migration, test pgTAP, tài liệu thì bỏ; src, e2e, Edge Function, seed, cấu hình, file lạ thì chạy', () => {
    expect(
      needsE2e(['supabase/migrations/x.sql', 'supabase/tests/database/a.test.sql', 'docs/a.md']),
    ).toBe(false);
    expect(needsE2e(['docs/a.md', 'deploy/README.md'])).toBe(false);
    expect(needsE2e(['supabase/migrations/x.sql', 'src/a.ts'])).toBe(true);
    expect(needsE2e(['e2e/a.spec.ts'])).toBe(true);
    expect(needsE2e(['supabase/functions/login/index.ts'])).toBe(true);
    expect(needsE2e(['supabase/seed.sql'])).toBe(true);
    expect(needsE2e(['playwright.config.ts'])).toBe(true);
    expect(needsE2e(['supabase/config.toml'])).toBe(true);
    expect(needsE2e(['thu-muc-la/a.txt'])).toBe(true);
    expect(needsE2e([])).toBe(true);
  });

  it('isDbOnly chỉ nhận migrations và tests của supabase', () => {
    expect(isDbOnly('supabase/migrations/a.sql')).toBe(true);
    expect(isDbOnly('supabase/tests/database/a.sql')).toBe(true);
    expect(isDbOnly('supabase/functions/a.ts')).toBe(false);
    expect(isDbOnly('supabase/seed.sql')).toBe(false);
  });

  it('isSkippable không nhận nhầm tên giống (docsx/, deployment/)', () => {
    expect(isSkippable('docsx/a.ts')).toBe(false);
    expect(isSkippable('deployment/a.ts')).toBe(false);
    expect(isSkippable('src/doc.md')).toBe(true);
  });

  it('chạy như lệnh (đọc stdin): kết quả full và ui', () => {
    const run = (input: string) =>
      execFileSync('node', ['scripts/ci-filter.ts'], { input, encoding: 'utf8' }).trim();
    expect(run('deploy/README.md\n')).toBe('full=false\nui=false\ne2e=false');
    expect(run('deploy/README.md\nsrc/a.tsx\n')).toBe('full=true\nui=true\ne2e=true');
    expect(run('.github/workflows/ci.yml\n')).toBe('full=true\nui=true\ne2e=true');
    expect(run('')).toBe('full=true\nui=true\ne2e=true');
  });
});
