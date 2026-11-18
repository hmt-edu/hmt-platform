// BC-09 Giờ dạy giáo viên: người có quyền Báo cáo (Admin cần hai bước nên dùng Trưởng cơ sở) mở màn thấy tiêu đề, thẻ tổng và bảng hoặc trạng thái trống;
// nhân viên bán hàng không có quyền Báo cáo thì không thấy dữ liệu. Tài khoản giả, không ghi gì vào DB.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (bật phân hệ Báo cáo ở CS5).');

// Phân hệ BAO_CAO tắt mặc định (không có dòng cờ = tắt): màn báo cáo chỉ mở khi cờ bật ở cơ sở của người xem. Bài tự bật ở CS5 và trả lại trạng thái cũ sau bài,
// không dựa vào bài khác để bật hộ (trước đây chạy riêng thì trượt «Phân hệ chưa bật ở cơ sở này»).
let before: boolean | null = null;
async function withDb<T>(fn: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await fn(db);
  } finally {
    await db.end();
  }
}
test.beforeAll(async () => {
  await withDb(async (db) => {
    const r = await db.query<{ enabled: boolean }>(
      "select enabled from app.feature_flag where module_code = 'BAO_CAO' and branch_id = (select id from app.branch where code = 'CS5')",
    );
    before = r.rows[0]?.enabled ?? null;
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'BAO_CAO', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
  });
});
test.afterAll(async () => {
  await withDb(async (db) => {
    await db.query(
      "update app.feature_flag set enabled = $1 where module_code = 'BAO_CAO' and branch_id = (select id from app.branch where code = 'CS5')",
      [before ?? false],
    );
  });
});

test('truongcs.cs5: mở Giờ dạy giáo viên thấy tiêu đề và thẻ tổng', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/bao-cao/gio-day');
  await expect(page.getByRole('heading', { level: 1, name: 'Giờ dạy giáo viên' })).toBeVisible();
  await expect(page.getByText('Tổng giờ dạy')).toBeVisible();
});

test('sale.cs5: không có quyền Báo cáo nên báo không có quyền', async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await page.goto('/crm/bao-cao/gio-day');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Bạn không có quyền xem trang này' }),
  ).toBeVisible();
});
