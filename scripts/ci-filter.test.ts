import { execFileSync } from 'node:child_process';
import { describe, expect, it } from 'vitest';
import {
  isCore,
  isMigration,
  isMoney,
  isSkippable,
  needsE2e,
  needsFullCi,
  touchesUi,
} from './ci-filter';

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

  it('Playwright (needsE2e, Q-21): chỉ khi có migration hoặc đụng tiền; PR khác thì bỏ (check:all trên máy)', () => {
    // Có migration: chạy.
    expect(needsE2e(['supabase/migrations/x.sql', 'supabase/tests/database/a.test.sql'])).toBe(
      true,
    );
    // Đụng tiền: đơn hàng, phiếu thu, số dư (theo đường dẫn).
    expect(needsE2e(['src/pages/don-hang/OrderRecordPage.tsx'])).toBe(true);
    expect(needsE2e(['src/pages/phieu-thu/ReceiptRecordPage.tsx'])).toBe(true);
    expect(needsE2e(['src/pages/so-du/Ledger.tsx'])).toBe(true);
    expect(needsE2e(['e2e/don-hang-duyet.spec.ts'])).toBe(true);
    expect(needsE2e(['e2e/phieu-thu.spec.ts'])).toBe(true);
    expect(needsE2e(['src/lib/format.ts'])).toBe(true);
    // PR khác: bỏ Playwright (giao diện không đụng tiền, Edge Function, seed, cấu hình, công cụ).
    expect(needsE2e(['src/pages/lead/LeadListPage.tsx'])).toBe(false);
    expect(needsE2e(['src/pages/nguoi-dung/UserDialogs.tsx', 'e2e/nguoi-dung.spec.ts'])).toBe(
      false,
    );
    expect(needsE2e(['supabase/functions/login/index.ts'])).toBe(false);
    expect(needsE2e(['supabase/seed.sql', 'playwright.config.ts', 'scripts/seed-users.ts'])).toBe(
      false,
    );
    expect(needsE2e(['.github/workflows/ci.yml'])).toBe(false);
    // Tài liệu, thiết kế: bỏ như trước. Không có danh sách file: chạy.
    expect(needsE2e(['docs/a.md', 'deploy/README.md'])).toBe(false);
    expect(needsE2e([])).toBe(true);
  });

  it('isMigration và isMoney theo đường dẫn', () => {
    expect(isMigration('supabase/migrations/a.sql')).toBe(true);
    expect(isMigration('supabase/tests/database/a.sql')).toBe(false);
    expect(isMoney('supabase/tests/database/064_b2_phieu_thu.test.sql')).toBe(true);
    expect(isMoney('supabase/tests/database/043_p5a_don_hang.test.sql')).toBe(true);
    expect(isMoney('supabase/tests/database/060_t4b_nap_nguoi_dung.test.sql')).toBe(false);
    // Q-36, Q-39: báo giá, gói bán, bảng giá và các phần sắp có cũng là đụng tiền.
    expect(isMoney('src/pages/bao-gia/QuotationRecordPage.tsx')).toBe(true);
    expect(isMoney('src/pages/goi-ban/PackageListPage.tsx')).toBe(true);
    expect(isMoney('src/pages/bang-gia/PriceBoardPage.tsx')).toBe(true);
    expect(isMoney('e2e/bao-gia.spec.ts')).toBe(true);
    expect(isMoney('e2e/goi-ban.spec.ts')).toBe(true);
    expect(isMoney('e2e/bang-gia.spec.ts')).toBe(true);
    expect(isMoney('supabase/tests/database/037_p5a_bao_gia.test.sql')).toBe(true);
    expect(isMoney('supabase/tests/database/066_bang_gia_theo_goi.test.sql')).toBe(true);
    for (const dir of ['cong-no', 'thu-no-dau-ky', 'voucher', 'hoan-phi'])
      expect(isMoney(`src/pages/${dir}/Trang.tsx`)).toBe(true);
    // Phần không đụng tiền vẫn không tính.
    expect(isMoney('src/pages/lead/LeadListPage.tsx')).toBe(false);
    expect(isMoney('e2e/nguoi-dung.spec.ts')).toBe(false);
    expect(isMoney('e2e/bao-gia-seed.ts')).toBe(true);
  });

  it('isCore: lõi truy cập (đăng nhập, phiên, menu theo quyền) cũng chạy Playwright', () => {
    expect(isCore('src/lib/auth/claims.ts')).toBe(true);
    expect(isCore('src/nav/access.ts')).toBe(true);
    // Q-66: khung hồ sơ dùng chung cũng chạy; src/ui/ thì không.
    expect(isCore('src/record/Detail.tsx')).toBe(true);
    expect(needsE2e(['src/record/Detail.tsx'])).toBe(true);
    expect(isCore('src/ui/Chatter.tsx')).toBe(false);
    expect(needsE2e(['src/ui/Chatter.tsx'])).toBe(false);
    expect(isCore('src/lib/db.ts')).toBe(false);
    expect(needsE2e(['src/nav/crmMenu.ts'])).toBe(true);
    expect(needsE2e(['src/lib/auth/AuthProvider.tsx'])).toBe(true);
    expect(needsE2e(['src/pages/bao-gia/QuotationRecordPage.tsx'])).toBe(true);
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
    expect(run('deploy/README.md\nsrc/a.tsx\n')).toBe('full=true\nui=true\ne2e=false');
    expect(run('src/pages/don-hang/a.tsx\n')).toBe('full=true\nui=true\ne2e=true');
    expect(run('.github/workflows/ci.yml\n')).toBe('full=true\nui=true\ne2e=false');
    expect(run('')).toBe('full=true\nui=true\ne2e=true');
  });
});
