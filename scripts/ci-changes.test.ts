import { execFileSync } from 'node:child_process';
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';

// Bước "Chọn phần CI cần chạy" của ci.yml (Đ281): mọi lỗi thì chạy đủ (full=true, ui=true, e2e=true). Dùng `gh` giả, không gọi mạng.
// Mỗi bài chạy bash thật; khi cả bộ test chạy song song trên máy bận, 5 giây mặc định không đủ (trượt chập chờn 06/11): nới riêng cho file này.
vi.setConfig({ testTimeout: 30_000 });
const dirs: string[] = [];
afterEach(() => {
  while (dirs.length > 0) rmSync(dirs.pop() ?? '', { recursive: true, force: true });
});

function run(ghScript: string, env: Record<string, string> = {}): string {
  const dir = mkdtempSync(join(tmpdir(), 'hmt-gh-'));
  dirs.push(dir);
  const gh = join(dir, 'gh');
  writeFileSync(gh, `#!/usr/bin/env bash\n${ghScript}\n`);
  chmodSync(gh, 0o755);
  return execFileSync('bash', ['scripts/ci-changes.sh'], {
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: `${dir}:${process.env.PATH ?? ''}`,
      EVENT_NAME: 'pull_request',
      REPO: 'hmt/hmt-platform',
      PR_NUMBER: '1',
      GITHUB_OUTPUT: '',
      ...env,
    },
  }).trim();
}

describe('scripts/ci-changes.sh (bước chọn phần CI)', () => {
  it('PR chỉ đổi deploy/: bỏ DB + Playwright và bản xem trước', () => {
    expect(run(`printf 'deploy/README.md\\ndeploy/.github/workflows/backup.yml\\n'`)).toBe(
      'full=false\nui=false\ne2e=false',
    );
  });

  it('PR đổi src/: chạy đủ, cần bản xem trước', () => {
    expect(run(`printf 'deploy/README.md\\nsrc/a.tsx\\n'`)).toBe('full=true\nui=true\ne2e=true');
  });

  it('gh lỗi (không lấy được danh sách file): chạy đủ, cả bản xem trước', () => {
    expect(run('exit 1')).toBe('full=true\nui=true\ne2e=true');
  });

  it('gh thành công nhưng danh sách trống: chạy đủ, cả bản xem trước', () => {
    expect(run('exit 0')).toBe('full=true\nui=true\ne2e=true');
  });

  it('PR chỉ đổi migration và test pgTAP: chạy DB, bỏ Playwright', () => {
    expect(
      run(
        `printf 'supabase/migrations/20261105000071_x.sql\\nsupabase/tests/database/062_x.test.sql\\ndocs/a.md\\n'`,
      ),
    ).toBe('full=true\nui=false\ne2e=false');
  });

  it('PR đổi migration cùng seed hoặc Edge Function: chạy cả Playwright', () => {
    expect(run(`printf 'supabase/migrations/x.sql\\nsupabase/seed.sql\\n'`)).toBe(
      'full=true\nui=false\ne2e=true',
    );
    expect(run(`printf 'supabase/functions/login/index.ts\\n'`)).toBe(
      'full=true\nui=false\ne2e=true',
    );
  });

  it('nhãn full-ci buộc chạy đủ, kể cả khi chỉ đổi migration', () => {
    const gh = `case "$*" in *labels*) echo full-ci;; *) printf 'supabase/migrations/x.sql\\n';; esac`;
    expect(run(gh)).toBe('full=true\nui=true\ne2e=true');
  });

  it('nhãn khác không ép chạy đủ', () => {
    const gh = `case "$*" in *labels*) echo bug;; *) printf 'supabase/migrations/x.sql\\n';; esac`;
    expect(run(gh)).toBe('full=true\nui=false\ne2e=false');
  });

  it('chạy tay (không phải pull_request): chạy đủ', () => {
    expect(run(`printf 'deploy/README.md\\n'`, { EVENT_NAME: 'workflow_dispatch' })).toBe(
      'full=true\nui=true\ne2e=true',
    );
  });
});
