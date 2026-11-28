// TT-02 trên điện thoại: bản ghi phiếu tái tục không tràn ngang (chữ ẩn của thanh giai đoạn từng làm trang rộng gấp đôi màn).
import { expect, test } from '@playwright/test';
import pg from 'pg';

import { DB_URL } from './bao-gia-seed';
import { seedGhiDanh } from './ghi-danh-seed';
import { DOMAIN, PASSWORD, enterAs } from './helpers';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng phiếu tái tục giả).');

let ticketId = '';

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const seed = await seedGhiDanh(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'BAN_HANG', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const user = await db.query<{ id: string }>('select id from auth.users where email = $1', [
      `cskh.cs5@${DOMAIN}`,
    ]);
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [user.rows[0]?.id],
    );
    await db.query('set local role authenticated');
    const created = await db.query<{ id: string }>(
      `select app.create_upsale_ticket_from_enrollment($1, 'Tạo cho bài kiểm giao diện') ->> 'id' as id`,
      [seed.learning.code],
    );
    ticketId = created.rows[0]?.id ?? '';
    await db.query('commit');
  } catch (e) {
    await db.query('rollback').catch(() => undefined);
    throw e;
  } finally {
    await db.end();
  }
});

test('TT-02 rộng 390px: trang không tràn ngang', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await enterAs(page, 'cskh.cs5');
  await page.goto(`/crm/tai-tuc/${ticketId}`);
  await expect(page.getByRole('heading', { name: 'Tái tục của' })).toBeVisible();
  const overflow = await page.evaluate<number>(
    'document.documentElement.scrollWidth - document.documentElement.clientWidth',
  );
  expect(overflow).toBeLessThanOrEqual(0);
});
