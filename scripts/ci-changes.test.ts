import { execFileSync } from 'node:child_process';
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';

// Bước "Chọn phần CI cần chạy" của ci.yml (Đ281): mọi lỗi thì chạy đủ (full=true, ui=true). Dùng `gh` giả, không gọi mạng.
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
      'full=false\nui=false',
    );
  });

  it('PR đổi src/: chạy đủ, cần bản xem trước', () => {
    expect(run(`printf 'deploy/README.md\\nsrc/a.tsx\\n'`)).toBe('full=true\nui=true');
  });

  it('gh lỗi (không lấy được danh sách file): chạy đủ, cả bản xem trước', () => {
    expect(run('exit 1')).toBe('full=true\nui=true');
  });

  it('gh thành công nhưng danh sách trống: chạy đủ, cả bản xem trước', () => {
    expect(run('exit 0')).toBe('full=true\nui=true');
  });

  it('chạy tay (không phải pull_request): chạy đủ', () => {
    expect(run(`printf 'deploy/README.md\\n'`, { EVENT_NAME: 'workflow_dispatch' })).toBe(
      'full=true\nui=true',
    );
  });
});
