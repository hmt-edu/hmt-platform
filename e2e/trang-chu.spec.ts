// Trang chủ CRM theo vai trò (CHUNG-14, TS-12): khối lịch hẹn hôm nay, ranh giới ngày theo giờ Việt Nam.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lịch hẹn giả).');
// Các bài dùng chung một tài khoản và dữ liệu giả: chạy lần lượt.
test.describe.configure({ mode: 'serial' });

// Hai dự án (máy tính, điện thoại) chạy song song nên mỗi dự án dùng một tài khoản sale riêng, dữ liệu riêng.
const SETUPS = {
  'may-tinh': { account: 'sale.cs5', phone: '0900000777' },
  'dien-thoai': { account: 'kiem.cs5', phone: '0900000778' },
} as const;
type Setup = { account: string; phone: string };
function setupOf(projectName: string): Setup {
  return projectName === 'dien-thoai' ? SETUPS['dien-thoai'] : SETUPS['may-tinh'];
}
const TAG = 'E2E trang chủ';

/** Dựng một lead của sale.cs1 kèm lịch hẹn: hôm nay (theo giờ Việt Nam) và quá hạn (hôm qua). Dữ liệu giả. */
async function seedAppointments(setup: Setup): Promise<void> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clearAppointments(db, setup);
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.account}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const lead = await db.query<{ id: string }>(
      `select (app.create_lead(jsonb_build_object('parent_name', 'Chị Trang Chủ', 'parent_phone', $1::text,
         'student_name', 'Em Trang Chủ', 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
         'channel_code', 'FACEBOOK_ADS_LEAD_FORM')) ->> 'id')::uuid as id`,
      [setup.phone],
    );
    const leadId = lead.rows[0]?.id;
    for (const title of [
      `${TAG} ${setup.account} 1`,
      `${TAG} ${setup.account} 2`,
      `${TAG} ${setup.account} quá hạn`,
    ]) {
      await db.query(
        `select app.create_appointment($1::uuid, (select code from app.catalog_item
           where catalog_code = 'ACTIVITY_TYPE' order by sort_order limit 1), now() + interval '2 hours', $2::text)`,
        [leadId, title],
      );
    }
    await db.query('reset role');
    // Đặt lại giờ hẹn: hai lịch giữa trưa hôm nay (giờ Việt Nam), một lịch hôm qua.
    const noon = `(date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '12 hours') at time zone 'Asia/Ho_Chi_Minh'`;
    await db.query(`update app.appointment set scheduled_at = ${noon} where title in ($1, $2)`, [
      `${TAG} ${setup.account} 1`,
      `${TAG} ${setup.account} 2`,
    ]);
    await db.query(
      `update app.appointment set scheduled_at = ${noon} - interval '1 day' where title = $1`,
      [`${TAG} ${setup.account} quá hạn`],
    );
    await db.query('commit');
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}

async function clearAppointments(db: pg.Client, setup: Setup): Promise<void> {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  await db.query("delete from app.appointment where title like $1 || '%'", [
    `${TAG} ${setup.account}`,
  ]);
  await db.query('delete from app.lead where parent_phone = $1', [setup.phone]);
  await db.query('commit');
}

// Playwright bắt tham số đầu là một mẫu object, dù không dùng fixture nào.
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clearAppointments(db, setupOf(testInfo.project.name));
  } finally {
    await db.end();
  }
});

async function openHome(page: Page, account: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Việc của tôi hôm nay' })).toBeVisible();
}

test('Sale thấy lịch hẹn hôm nay và số quá hạn của mình; Admin mới có "Xem thử vai trò"', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await seedAppointments(setup);
  await openHome(page, setup.account);
  const block = page.getByRole('region', { name: 'Lịch hẹn hôm nay' });
  await expect(block.getByText(`${TAG} ${setup.account} 1`)).toBeVisible();
  await expect(block.getByText(`${TAG} ${setup.account} 2`)).toBeVisible();
  await expect(block.getByText(`${TAG} ${setup.account} quá hạn`)).toHaveCount(0);
  await expect(block.getByText('12:00')).toHaveCount(2);
  await expect(page.getByText('Hôm nay', { exact: true })).toBeVisible();
  const today = page.locator('div', { has: page.getByText('Hôm nay', { exact: true }) }).last();
  await expect(today).toContainText('2');
  await expect(page.getByText('Quá hạn', { exact: true })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Mở danh sách' })).toHaveAttribute(
    'href',
    '/crm/lich-hen',
  );
  await expect(page.getByRole('group', { name: 'Xem thử vai trò' })).toHaveCount(0);
  await expectAccessible(page);
});

test('"Hôm nay" theo giờ Việt Nam, không theo múi giờ trình duyệt', async ({
  browser,
}, testInfo) => {
  // Chọn múi giờ trình duyệt để NGÀY ở đó khác ngày ở Việt Nam ngay lúc này (không giả đồng hồ, tránh lệch phiên).
  const vn = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date());
  const get = (type: string) => vn.find((p) => p.type === type)?.value ?? '';
  // UTC-12 chậm hơn Việt Nam 19 giờ; UTC+14 nhanh hơn 7 giờ.
  const timezoneId = Number(get('hour')) < 19 ? 'Etc/GMT+12' : 'Pacific/Kiritimati';
  const dayStart = new Date(`${get('year')}-${get('month')}-${get('day')}T00:00:00+07:00`);
  const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
  const context = await browser.newContext({ timezoneId });
  const page = await context.newPage();
  const bodies: string[] = [];
  page.on('request', (r) => {
    if (r.url().includes('/rpc/list_appointments')) bodies.push(r.postData() ?? '');
  });
  await openHome(page, setupOf(testInfo.project.name).account);
  await expect.poll(() => bodies.length).toBeGreaterThan(0);
  const filters = (JSON.parse(bodies[0] ?? '{}') as { p_filters: { from: string; to: string } })
    .p_filters;
  expect(filters.from).toBe(dayStart.toISOString());
  expect(filters.to).toBe(dayEnd.toISOString());
  await context.close();
});

test('phân hệ Bán hàng tắt ở CS1 thì Sale CS1 không thấy khối lịch hẹn, chỉ thấy câu trung tính', async ({
  page,
}) => {
  await openHome(page, 'sale.cs1');
  await expect(
    page.getByRole('heading', { name: 'Chưa có mục nhắc việc nào cho bạn.' }),
  ).toBeVisible();
  await expect(page.getByRole('region', { name: 'Lịch hẹn hôm nay' })).toHaveCount(0);
});
