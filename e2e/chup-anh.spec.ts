// E32: chụp ảnh TỰ ĐỘNG cho tài liệu hướng dẫn (docs/huong-dan/*.md, chỗ [ẢNH: ten]). Chạy trên Supabase local với dữ liệu giả (seed), KHÔNG cần staging.
// Chỉ chạy khi CHUP_ANH=1 (xem scripts/chup-anh.sh, docs/huong-dan/CHUP-ANH.md). Ảnh lưu NGOÀI repo: $ANH_OUT (mặc định ~/VanPhongAI/hmt-ca/ANH-HUONG-DAN/<vai>/<ten>.png),
// không commit. Máy tính rộng 1280; cổng Giáo viên cỡ iPhone (390 × 844). Mỗi vai một tệp BAO-CAO.txt: ảnh chụp được, ảnh xấp xỉ (màn gần nhất), ảnh lỗi.
import { mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, enterAsAdmin, loginStaffUntil } from './helpers';
import { ROLES, type Shot } from './chup-anh-ban-do';

const OUT = process.env.ANH_OUT ?? join(homedir(), 'VanPhongAI', 'hmt-ca', 'ANH-HUONG-DAN');
const DESKTOP = { width: 1280, height: 800 };
const PHONE = { width: 390, height: 844 };

test.skip(
  !process.env.CHUP_ANH || !PASSWORD || !process.env.DB_URL,
  'Chỉ chạy khi CHUP_ANH=1 (scripts/chup-anh.sh): cần SEED_PASSWORD và DB_URL.',
);
test.describe.configure({ mode: 'serial' });

// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(
    testInfo.project.name === 'dien-thoai',
    'Kịch bản tự đặt cỡ màn hình, chỉ chạy một dự án.',
  );
});

/** Chụp một ảnh; trả về ghi chú khi không mở được bản ghi vì màn không có dữ liệu mẫu (ảnh thành xấp xỉ). */
async function capture(page: Page, shot: Shot, file: string): Promise<string | null> {
  let note: string | null = null;
  await page.goto(shot.route);
  await page.waitForLoadState('networkidle');
  if (shot.view) {
    const button = page.getByRole('button', { name: shot.view, exact: true });
    if (await button.count()) await button.first().click();
  }
  // Bộ lọc mặc định (vd. «Ngày học: Hôm nay») có thể làm danh sách trống: bấm «Xoá bộ lọc» một lần để thấy dữ liệu mẫu.
  const clearFilter = page.getByRole('button', { name: 'Xoá bộ lọc', exact: true });
  if (shot.row && (await clearFilter.isVisible().catch(() => false))) {
    await clearFilter.click();
    await page.waitForLoadState('networkidle');
  }
  if (shot.row) {
    // Dòng dữ liệu đầu tiên của bảng (bỏ dòng tiêu đề); bấm vào liên kết trong dòng nếu có, nếu không thì bấm dòng. Địa chỉ không đổi = không mở được bản ghi.
    const before = page.url();
    const row = page.getByRole('row').nth(1);
    if (await row.count()) {
      const link = row.getByRole('link').first();
      await ((await link.count()) ? link : row).click({ timeout: 5000 }).catch(() => undefined);
      await page.waitForLoadState('networkidle');
    }
    // Màn trống («Chưa có …», «… sẽ hiện ở đây»), hoặc địa chỉ không đổi: không có bản ghi nào để mở.
    const empty = await page
      .getByText(/^Chưa có |sẽ hiện ở đây|Không có (việc|dòng|bản ghi|kết quả)/)
      .first()
      .isVisible()
      .catch(() => false);
    if (empty || page.url() === before) {
      note = 'không mở được bản ghi (DB giả chưa có dữ liệu loại này)';
    }
  }
  await page.waitForTimeout(400);
  await page.screenshot({ path: file, fullPage: false });
  return note;
}

for (const role of ROLES) {
  test(`Chụp ảnh hướng dẫn: ${role.folder}`, async ({ page }) => {
    test.setTimeout(300_000);
    const dir = join(OUT, role.folder);
    mkdirSync(dir, { recursive: true });
    await page.setViewportSize(role.kind === 'gv' ? PHONE : DESKTOP);
    if (role.kind === 'crm') await enterAs(page, role.account);
    else if (role.kind === 'crm-hai-buoc') await enterAsAdmin(page, role.account);
    else await loginStaffUntil(page, role.account, /\/gv$/);
    const report: string[] = [
      `Vai: ${role.folder} (tài khoản giả ${role.account}); ${new Date().toISOString()}`,
    ];
    for (const shot of role.shots) {
      const file = join(dir, `${shot.name}.png`);
      try {
        const note = await capture(page, shot, file);
        const why = shot.approx ?? note;
        report.push(`${why ? 'XẤP XỈ' : 'ĐÃ CHỤP'}  ${shot.name}${why ? `  (${why})` : ''}`);
      } catch (e) {
        report.push(`LỖI      ${shot.name}  (${String(e).split('\n')[0]?.slice(0, 120)})`);
      }
    }
    writeFileSync(join(dir, 'BAO-CAO.txt'), `${report.join('\n')}\n`);
  });
}
