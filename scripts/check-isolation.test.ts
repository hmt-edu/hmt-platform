// Kiểm script cách ly (L5) bằng curl, psql giả: mỗi trường hợp phải ra đúng kết quả.
import { execFileSync } from 'node:child_process';
import { chmodSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const SCRIPT = join(__dirname, 'check-isolation.sh');
const PROD_REF = 'prodprodprodprodprod';
const STAGING_REF = 'stagstagstagstagstag';
const PROD_CF = 'a'.repeat(32);
const STAGING_CF = 'b'.repeat(32);
// Mỗi bài chạy bash thật: cho rộng thời gian khi cả bộ kiểm thử chạy song song.
const TIMEOUT_MS = 30_000; // allow-number: thời gian chờ kiểm thử, không phải số nghiệp vụ

interface Fake {
  /** Mã HTTP Management API Supabase trả cho project hmt-prod / hmt-staging. */
  supabaseProd: string;
  supabaseStaging: string;
  /** Project hmt-prod có tồn tại không (health: 401 nếu có, 000 nếu không). */
  prodExists: boolean;
  /** Cloudflare API: token đọc được tài khoản chạy thật / thử nghiệm không. */
  cloudflareProd: boolean;
  cloudflareStaging: boolean;
  /** Mật khẩu DB thử nghiệm vào được hmt-prod không. */
  dbProdOpen: boolean;
}

const good: Fake = {
  supabaseProd: '403',
  supabaseStaging: '200',
  prodExists: true,
  cloudflareProd: false,
  cloudflareStaging: true,
  dbProdOpen: false,
};

function run(fake: Fake): number {
  const bin = mkdtempSync(join(tmpdir(), 'isolation-'));
  const curl = `#!/usr/bin/env bash
url="\${@: -1}"
case "$url" in
  *api.supabase.com/v1/projects/${PROD_REF}*) echo -n ${fake.supabaseProd} ;;
  *api.supabase.com/v1/projects/${STAGING_REF}*) echo -n ${fake.supabaseStaging} ;;
  *${PROD_REF}.supabase.co*) echo -n ${fake.prodExists ? '401' : '000'} ;;
  *api.cloudflare.com/client/v4/accounts/${PROD_CF}*) echo -n '{"success":${fake.cloudflareProd}}' ;;
  *api.cloudflare.com/client/v4/accounts/${STAGING_CF}*) echo -n '{"success":${fake.cloudflareStaging}}' ;;
  *) echo -n 000 ;;
esac
`;
  const psql = `#!/usr/bin/env bash
case "$*" in *postgres.${PROD_REF}*) exit ${fake.dbProdOpen ? 0 : 2} ;; *) exit 0 ;; esac
`;
  writeFileSync(join(bin, 'curl'), curl);
  writeFileSync(join(bin, 'psql'), psql);
  chmodSync(join(bin, 'curl'), 0o755);
  chmodSync(join(bin, 'psql'), 0o755);
  try {
    execFileSync('bash', [SCRIPT], {
      stdio: 'pipe',
      env: {
        PATH: `${bin}:${process.env.PATH ?? ''}`,
        SUPABASE_ACCESS_TOKEN: 'gia',
        STAGING_DB_URL: `postgresql://postgres.${STAGING_REF}:matkhaugia@pooler.example:5432/postgres`,
        STAGING_PROJECT_REF: STAGING_REF,
        PROD_PROJECT_REF: PROD_REF,
        CLOUDFLARE_API_TOKEN: 'gia',
        CLOUDFLARE_ACCOUNT_ID: STAGING_CF,
        PROD_CLOUDFLARE_ACCOUNT_ID: PROD_CF,
      },
    });
    return 0;
  } catch (error) {
    return (error as { status: number }).status;
  }
}

describe('kiểm khoá hmt-platform không chạm hmt-prod (L5)', { timeout: TIMEOUT_MS }, () => {
  it('mọi thứ đúng: qua', () => {
    expect(run(good)).toBe(0);
  });
  it('token Supabase đọc được hmt-prod: chặn', () => {
    expect(run({ ...good, supabaseProd: '200' })).not.toBe(0);
  });
  it('mật khẩu DB thử nghiệm vào được hmt-prod: chặn', () => {
    expect(run({ ...good, dbProdOpen: true })).not.toBe(0);
  });
  it('token Supabase hết hạn (không đọc được cả thử nghiệm): báo lỗi, không coi là đã cách ly', () => {
    expect(run({ ...good, supabaseProd: '401', supabaseStaging: '401' })).not.toBe(0);
  });
  it('PROD_PROJECT_REF gõ sai (project không tồn tại): báo lỗi', () => {
    expect(run({ ...good, prodExists: false })).not.toBe(0);
  });
  it('token Cloudflare thử nghiệm đọc được tài khoản chạy thật: chặn', () => {
    expect(run({ ...good, cloudflareProd: true })).not.toBe(0);
  });
  it('token Cloudflare không đọc được cả tài khoản thử nghiệm: báo lỗi, không coi là đã cách ly', () => {
    expect(run({ ...good, cloudflareStaging: false })).not.toBe(0);
  });
});
