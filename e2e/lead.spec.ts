// P3c-1b: màn Lead (TS-01 danh sách, TS-01b Kanban, TS-05 hộp Giao). Dữ liệu giả dựng bằng create_lead, tìm bằng dấu riêng.
import { readFileSync } from 'node:fs';
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, expectAccessible, isPhone, loginStaff } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lead giả).');
// Các bài dùng chung dữ liệu giả của dự án: chạy lần lượt.
test.describe.configure({ mode: 'serial' });

// Hai dự án (máy tính, điện thoại) chạy song song trên cùng cơ sở CS5: mỗi dự án có dấu riêng để tìm đúng lead của mình.
const SETUPS = {
  'may-tinh': { mark: 'E2ELEADMT', sale: 'sale.cs5', manager: 'truongcs.cs5' },
  'dien-thoai': { mark: 'E2ELEADDT', sale: 'kiem.cs5', manager: 'kiem.cs5' },
} as const;
type Setup = { mark: string; sale: string; manager: string };
const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

type Seeded = {
  names: Record<'over' | 'today' | 'soon' | 'none' | 'merged' | 'giaoA' | 'giaoB', string>;
};
let seeded: Seeded;

const noonToday = `(date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '12 hours') at time zone 'Asia/Ho_Chi_Minh'`;

async function clear(db: pg.Client, mark: string): Promise<void> {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  await db.query('delete from app.lead where parent_name like $1', [`%${mark}%`]);
  await db.query('delete from app.parent where full_name like $1', [`%${mark}%`]);
  await db.query('commit');
}

async function seedLeads(setup: Setup, project: string): Promise<Seeded> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, setup.mark);
    const run = Date.now().toString(36).slice(-4).toUpperCase();
    const base = (Date.now() % 1e6) * 100 + (project === 'dien-thoai' ? 50 : 0); // số điện thoại giả, hai dự án không trùng nhau
    const kinds = ['over', 'today', 'soon', 'none', 'merged', 'giaoA', 'giaoB'] as const;
    const names = Object.fromEntries(
      kinds.map((k) => [k, `Chị ${setup.mark} ${k} ${run}`]),
    ) as Seeded['names'];
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.sale}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    for (const [i, kind] of kinds.entries()) {
      await db.query(
        `select app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
           'student_name', 'Em ' || $3::text, 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
           'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))`,
        [
          names[kind],
          `0${String(base + i)
            .padStart(9, '0')
            .slice(-9)}`,
          kind,
        ],
      );
    }
    await db.query('reset role');
    const set = (kind: (typeof kinds)[number], sql: string) =>
      db.query(`update app.lead set ${sql} where parent_name = $1`, [names[kind]]);
    await set('over', "next_appointment_at = now() - interval '2 days'");
    await set('today', `next_appointment_at = ${noonToday}`);
    await set('soon', "next_appointment_at = now() + interval '3 days'");
    await set(
      'merged',
      `record_status = 'DA_GOP', merged_into_id = (select id from app.lead where parent_name = '${names.over}')`,
    );
    await db.query('commit');
    return { names };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}

// Playwright bắt tham số đầu là một mẫu object, dù không dùng fixture nào.
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seedLeads(setupOf(testInfo.project.name), testInfo.project.name);
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, setupOf(testInfo.project.name).mark);
  } finally {
    await db.end();
  }
});

async function openLeads(page: Page, account: string, mark: string) {
  await loginStaff(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/lead');
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
  await page.getByRole('searchbox').fill(mark);
  // Tìm kiếm chờ một nhịp rồi mới gọi máy chủ: đợi tới khi chỉ còn sáu lead của dự án (bảy trừ bản đã gộp).
  await expect(page.getByText('1–6 / 6')).toBeVisible();
}

function list(page: Page) {
  return isPhone(page)
    ? page.getByRole('list', { name: 'Lead' })
    : page.getByRole('table', { name: 'Lead' });
}

async function pickFilters(page: Page, labels: string[]) {
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  for (const label of labels) await page.getByLabel(label, { exact: true }).check();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
}

test('Sale thấy danh sách của cơ sở mình, có nút Tạo; không có Nhập, Xuất; tên phụ huynh mở trang Lead', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const salesOnly = testInfo.project.name === 'dien-thoai' ? 'cskh.cs5' : setup.sale;
  await openLeads(page, salesOnly, setup.mark);
  await expect(list(page).getByText(seeded.names.over)).toBeVisible();
  await expect(list(page).getByText(seeded.names.none)).toBeVisible();
  // Đã gộp: ẩn mặc định.
  await expect(list(page).getByText(seeded.names.merged)).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Nhập', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Xuất', exact: true })).toHaveCount(0);
  await expectAccessible(page);
  await page.getByRole('link', { name: seeded.names.over }).click();
  await expect(page).toHaveURL(/\/crm\/lead\/[0-9a-f-]{36}$/);
  await expect(
    page.getByRole('heading', { level: 2, name: new RegExp(seeded.names.over) }),
  ).toBeVisible();
});

test('Lọc nhanh Lịch hẹn: cùng nhóm HOẶC, khác nhóm VÀ, tính ở máy chủ', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.sale, setup.mark);
  await expect(list(page).getByText(seeded.names.none)).toBeVisible();
  await pickFilters(page, ['Quá hạn', 'Hôm nay']);
  await expect(
    page.getByRole('button', { name: /Bỏ điều kiện: Lịch hẹn: Quá hạn hoặc Hôm nay/ }),
  ).toBeVisible();
  await expect(list(page).getByText(seeded.names.over)).toBeVisible();
  await expect(list(page).getByText(seeded.names.today)).toBeVisible();
  await expect(list(page).getByText(seeded.names.soon)).toHaveCount(0);
  await expect(list(page).getByText(seeded.names.none)).toHaveCount(0);
  // Khác nhóm là VÀ: thêm "Tôi phụ trách" (các lead giả do người này tạo nên vẫn còn).
  await pickFilters(page, ['Tôi phụ trách']);
  await expect(list(page).getByText(seeded.names.over)).toBeVisible();
  await page.getByRole('button', { name: 'Xoá tất cả' }).click();
  await page.getByRole('searchbox').fill(setup.mark);
  await pickFilters(page, ['Sắp tới', 'Chưa có lịch hẹn']);
  await expect(list(page).getByText(seeded.names.soon)).toBeVisible();
  await expect(list(page).getByText(seeded.names.none)).toBeVisible();
  await expect(list(page).getByText(seeded.names.over)).toHaveCount(0);
});

test('Bản "Đã gộp" ẩn mặc định, hiện khi chọn Trạng thái bản ghi, mờ và nêu mã bản giữ lại', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.sale, setup.mark);
  await expect(list(page).getByText(seeded.names.over)).toBeVisible();
  await expect(list(page).getByText(seeded.names.merged)).toHaveCount(0);
  await pickFilters(page, ['Đã gộp']);
  await expect(list(page).getByText(seeded.names.merged)).toBeVisible();
  await expect(list(page).getByText(/^vào LD/)).toBeVisible();
  // Kanban không hiện bản đã gộp.
  await page.getByRole('button', { name: 'Kanban', exact: true }).click();
  await expect(page.getByText(seeded.names.over)).toBeVisible();
  await expect(page.getByText(seeded.names.merged)).toHaveCount(0);
});

test('Group By Stage ở máy chủ: số đếm theo nhóm, mở nhóm mới tải dòng', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.sale, setup.mark);
  await page.getByRole('button', { name: 'Group By', exact: true }).click();
  await page.getByRole('button', { name: /^Stage/ }).click();
  if (isPhone(page)) await page.getByRole('button', { name: 'Áp dụng' }).click();
  else await page.keyboard.press('Escape');
  const group = page.getByRole('button', { name: /^C1 Data mới \(\d+\)$/ });
  await expect(group).toBeVisible();
  // Nhóm đóng: chưa có dòng lead nào.
  await expect(page.getByText(seeded.names.over)).toHaveCount(0);
  await group.click();
  await expect(page.getByText(seeded.names.over)).toBeVisible();
});

test('Kanban: số thẻ và thanh màu của cột, chuyển giai đoạn bằng menu ⋮ và Hoàn tác', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.sale, setup.mark);
  await page.getByRole('button', { name: 'Kanban', exact: true }).click();
  const c1 = page.getByRole('region', { name: /^C1 Data mới: \d+ thẻ$/ });
  await expect(c1).toBeVisible();
  await expect(c1.getByText(seeded.names.over)).toBeVisible();
  await expect(c1.getByRole('group', { name: /^Tỷ lệ thẻ của C1/ })).toBeVisible();
  await expectAccessible(page);
  // Cột chưa có lịch hẹn nào thì không vẽ thanh (P0 v5, số 12).
  await expect(
    page
      .getByRole('region', { name: /^C4 Khách hàng tiềm năng/ })
      .getByRole('group', { name: /^Tỷ lệ/ }),
  ).toHaveCount(0);
  // Dấu "+" chỉ ở cột C1 (lead mới luôn bắt đầu ở C1).
  await expect(page.getByRole('button', { name: /^Thêm vào/ })).toHaveCount(1);
  await expect(c1.getByRole('button', { name: /^Thêm vào C1/ })).toBeVisible();

  await c1
    .getByRole('button', {
      name: `Chuyển giai đoạn: ${await cardCode(c1, seeded.names.soon)}`,
    })
    .click();
  await page.getByRole('menuitem', { name: 'Chuyển sang C2 Chưa liên hệ được' }).click();
  await expect(page.getByText(/^Đã chuyển LD\d+ sang C2\./).first()).toBeVisible();
  const c2 = page.getByRole('region', { name: /^C2 Chưa liên hệ được/ });
  await expect(c2.getByText(seeded.names.soon)).toBeVisible();
  await page.getByRole('button', { name: 'Hoàn tác' }).click();
  await expect(page.getByText(/^Đã hoàn tác, LD\d+ về C1/).first()).toBeVisible();
  await expect(c1.getByText(seeded.names.soon)).toBeVisible();
});

async function cardCode(column: ReturnType<Page['getByRole']>, name: string): Promise<string> {
  const card = column.getByRole('listitem').filter({ hasText: name });
  return (
    (
      await card
        .locator('span', { hasText: /^LD\d+$/ })
        .first()
        .textContent()
    )?.trim() ?? ''
  );
}

test('Kéo thả thẻ sang cột khác (máy tính)', async ({ page }, testInfo) => {
  test.skip(
    isPhone(page) || testInfo.project.name === 'dien-thoai',
    'Kéo thả bằng chuột chỉ thử ở máy tính.',
  );
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.sale, setup.mark);
  await page.getByRole('button', { name: 'Kanban', exact: true }).click();
  const card = page.getByRole('listitem').filter({ hasText: seeded.names.none });
  // Kéo thả HTML5 giả lập bằng sự kiện: chuột thật của Playwright không luôn kích hoạt dragstart trên thẻ.
  const target = page.getByRole('region', { name: /^C3 Không có nhu cầu/ });
  const transfer = await page.evaluateHandle('new DataTransfer()');
  await card.dispatchEvent('dragstart', { dataTransfer: transfer });
  await target.dispatchEvent('dragover', { dataTransfer: transfer });
  await target.dispatchEvent('drop', { dataTransfer: transfer });
  await expect(
    page.getByRole('region', { name: /^C3 Không có nhu cầu/ }).getByText(seeded.names.none),
  ).toBeVisible();
  await page.getByRole('button', { name: 'Hoàn tác' }).click();
  await expect(
    page.getByRole('region', { name: /^C1 Data mới/ }).getByText(seeded.names.none),
  ).toBeVisible();
});

test('Trưởng cơ sở xuất file: có nút Xuất, file CSV có BOM và lead trong phạm vi', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.manager, setup.mark);
  await expect(list(page).getByText(seeded.names.over)).toBeVisible();
  const download = page.waitForEvent('download');
  await page.getByRole('button', { name: 'Xuất', exact: true }).click();
  const file = await download;
  expect(file.suggestedFilename()).toMatch(/^lead-\d{4}-\d{2}-\d{2}\.csv$/);
  const path = await file.path();
  const text = readFileSync(path, 'utf8');
  expect(text.startsWith('﻿Mã,Phụ huynh')).toBe(true);
  await expect(page.getByText(/^Đã xuất \d+ dòng\./).first()).toBeVisible();
});

test('Hộp Assign: chọn nhiều lead, giao cho nhân sự cùng cơ sở', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openLeads(page, setup.manager, setup.mark);
  await expect(list(page).getByText(seeded.names.giaoA)).toBeVisible();
  await page.getByLabel(new RegExp(`^Chọn LD\\d+ ${seeded.names.giaoA}`)).check();
  await page.getByLabel(new RegExp(`^Chọn LD\\d+ ${seeded.names.giaoB}`)).check();
  await expect(page.getByText('Đã chọn 2')).toBeVisible();
  await page.getByRole('button', { name: 'Assign', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Assign lead' });
  await expect(dialog.getByText(/^2 lead đã chọn: LD\d+, LD\d+/)).toBeVisible();
  await expectAccessible(page);
  // Chưa chọn nhân sự thì nút Assign mờ.
  await expect(dialog.getByRole('button', { name: 'Assign', exact: true })).toBeDisabled();
  await dialog.getByRole('combobox', { name: 'Nhân sự phụ trách' }).click();
  await page.getByRole('option', { name: /^Sale CS5 \(giả\) · / }).click();
  await dialog.getByRole('button', { name: 'Assign', exact: true }).click();
  await expect(page.getByText('Đã giao 2 lead cho Sale CS5 (giả).').first()).toBeVisible();
  await expect(page.getByText('Đã chọn 2')).toHaveCount(0);
});
