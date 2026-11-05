// P3c-2: trang Lead (TS-02), Tạo lead (TS-03, TS-14), lịch hẹn (TS-13). Dữ liệu giả dựng bằng create_lead, tìm bằng dấu riêng.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, enterAs, expectAccessible, isPhone, pickOption } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lead giả).');
test.describe.configure({ mode: 'serial' });

// `low`: Tuyển sinh (không có quyền Giao việc cho lịch hẹn); `high`: Trưởng cơ sở (có). Mỗi dự án một dấu và một cặp tài khoản.
const SETUPS = {
  'may-tinh': { mark: 'E2ERECMT', low: 'sale.cs5', high: 'truongcs.cs5', phone: 100 },
  'dien-thoai': { mark: 'E2ERECDT', low: 'cskh.cs5', high: 'kiem.cs5', phone: 200 },
} as const;
type Setup = { mark: string; low: string; high: string; phone: number };
const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

type Seeded = { main: string; merged: string; mainId: string; phoneBase: number };
let seeded: Seeded;

async function clear(db: pg.Client, mark: string): Promise<void> {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const ids = `(select id from app.lead where parent_name like $1)`;
  await db.query(`delete from app.note where entity_type = 'LEAD' and entity_id in ${ids}`, [
    `%${mark}%`,
  ]);
  await db.query(`delete from app.appointment where lead_id in ${ids}`, [`%${mark}%`]);
  await db.query('delete from app.lead where parent_name like $1', [`%${mark}%`]);
  await db.query('delete from app.parent where full_name like $1', [`%${mark}%`]);
  await db.query('commit');
}

async function seed(setup: Setup): Promise<Seeded> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, setup.mark);
    const run = Date.now().toString(36).slice(-4).toUpperCase();
    const phoneBase = (Date.now() % 1e6) * 1000 + setup.phone;
    const names = {
      main: `Chị ${setup.mark} chính ${run}`,
      merged: `Chị ${setup.mark} gộp ${run}`,
    };
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.low}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const ids: string[] = [];
    for (const [i, name] of [names.main, names.merged].entries()) {
      const res = await db.query<{ id: string }>(
        `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
           'student_name', 'Em Thử', 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
           'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
        [
          name,
          `0${String(phoneBase + i)
            .padStart(9, '0')
            .slice(-9)}`,
        ],
      );
      ids.push(res.rows[0]?.id ?? '');
    }
    await db.query('reset role');
    await db.query(
      `update app.lead set record_status = 'DA_GOP', merged_into_id = $2 where id = $1`,
      [ids[1], ids[0]],
    );
    await db.query('commit');
    return { ...names, mainId: ids[0] ?? '', phoneBase };
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
  seeded = await seed(setupOf(testInfo.project.name));
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

async function openRecord(page: Page, account: string, id: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto(`/crm/lead/${id}`);
  await expect(page.getByRole('heading', { level: 1, name: 'Lead' })).toBeVisible();
}

const toastText = (page: Page, text: string | RegExp) => page.getByText(text).first();

test('Trang Lead: thông tin, thanh giai đoạn, nút liên kết, ghi chú và hoạt động; có Gộp trùng (quyền Duyệt), không có Đính kèm', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.low, seeded.mainId);
  await expect(
    page.getByRole('heading', { level: 2, name: new RegExp(seeded.main) }),
  ).toBeVisible();
  // Đường dẫn trên thanh trên: Tuyển sinh > Lead (liên kết về danh sách) > tên lead.
  const crumbs = page.getByRole('navigation', { name: 'Đường dẫn' });
  await expect(crumbs.getByRole('link', { name: 'Lead' })).toHaveAttribute('href', '/crm/lead');
  await expect(crumbs.getByText(new RegExp(seeded.main))).toHaveAttribute('aria-current', 'page');
  await expect(page.getByRole('heading', { name: 'Thông tin phụ huynh' })).toBeVisible();
  await expect(page.getByRole('heading', { name: 'Thông tin học sinh' })).toBeVisible();
  const stage = page.getByRole('navigation', { name: 'Giai đoạn' });
  await expect(stage.getByRole('button', { name: /^C1/ })).toHaveAttribute('aria-current', 'step');
  await expect(page.getByRole('button', { name: 'Lịch hẹn: 0' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Cơ hội: 0' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Tạo', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Assign', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Lên lịch hẹn' })).toBeVisible();
  await expect(page.getByRole('button', { name: /^Đính kèm \(\d+\)$/ })).toHaveCount(0);
  await expect(page.getByText(/^Hoạt động sắp tới \(0\)/)).toBeVisible();
  await page.getByRole('button', { name: 'Hành động' }).click();
  await expect(page.getByRole('menuitem', { name: 'Giao người phụ trách' })).toBeVisible();
  await expect(page.getByRole('menuitem', { name: 'Gộp trùng' })).toBeVisible();
  await page.keyboard.press('Escape');
  await expectAccessible(page);
});

test('Sửa rồi Lưu; thiếu thông tin thì báo tại ô; Huỷ không lưu', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.low, seeded.mainId);
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Họ tên', { exact: true }).fill('');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Nhập họ tên phụ huynh.')).toBeVisible();
  await page.getByLabel('Họ tên', { exact: true }).fill(seeded.main);
  await page.getByLabel('Số điện thoại', { exact: true }).fill('12345');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Số điện thoại cần đủ 10 số, bắt đầu bằng 0.')).toBeVisible();
  await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
  await page.getByRole('button', { name: 'Sửa', exact: true }).click();
  await page.getByLabel('Nhu cầu', { exact: true }).fill('Ôn thi vào lớp 10 (E2E)');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(toastText(page, 'Đã lưu.')).toBeVisible();
  await expect(page.getByRole('article').getByText('Ôn thi vào lớp 10 (E2E)')).toBeVisible();
  // Lịch sử thay đổi hiện ở cột Ghi chú và hoạt động.
  await expect(
    page.getByRole('region', { name: 'Ghi chú & hoạt động' }).getByText('Nhu cầu'),
  ).toBeVisible();
});

// Hộp chọn nhóm con khi đổi giai đoạn (R-CRM-41): chọn nhóm con rồi bấm "Chuyển giai đoạn".
async function pickSubstage(page: Page, code: string) {
  const dialog = page.getByRole('dialog');
  await expect(dialog.getByRole('button', { name: 'Chuyển giai đoạn' })).toBeDisabled();
  await dialog.getByRole('combobox', { name: 'Sub-stage' }).click();
  await page.getByRole('option', { name: new RegExp(`^${code}`) }).click();
  await dialog.getByRole('button', { name: 'Chuyển giai đoạn' }).click();
}

test('Đổi giai đoạn tự do có Hoàn tác, bắt chọn nhóm con; đổi nhóm con', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.low, seeded.mainId);
  const stage = page.getByRole('navigation', { name: 'Giai đoạn' });
  await stage.getByRole('button', { name: /^C3/ }).click();
  // R-CRM-41: sang C3 phải chọn nhóm con; chưa chọn thì nút chưa bấm được; lead chưa đổi.
  await expect(page.getByRole('dialog').getByText('Chuyển sang C3 Không có nhu cầu')).toBeVisible();
  await pickSubstage(page, 'C3A');
  await expect(toastText(page, 'Đã chuyển sang C3 Không có nhu cầu.')).toBeVisible();
  await expect(stage.getByRole('button', { name: /^C3/ })).toHaveAttribute('aria-current', 'step');
  await page.getByRole('button', { name: 'Hoàn tác' }).click();
  await expect(stage.getByRole('button', { name: /^C1/ })).toHaveAttribute('aria-current', 'step');
  // Lùi về giai đoạn trước cũng được (đổi tự do hai chiều).
  await stage.getByRole('button', { name: /^C4/ }).click();
  await pickSubstage(page, 'C4A');
  await expect(stage.getByRole('button', { name: /^C4/ })).toHaveAttribute('aria-current', 'step');
  await stage.getByRole('button', { name: /^C2/ }).click();
  await pickSubstage(page, 'C2B');
  await expect(stage.getByRole('button', { name: /^C2/ })).toHaveAttribute('aria-current', 'step');
  await page.getByRole('combobox', { name: 'Sub-stage' }).click();
  await page.getByRole('option', { name: /^C2A/ }).click();
  await expect(toastText(page, 'Đã đổi nhóm con.')).toBeVisible();
  await expect(page.getByText('C2A', { exact: false }).first()).toBeVisible();
  // Về C1 (không có nhóm con) đổi luôn, không hỏi.
  await stage.getByRole('button', { name: /^C1/ }).click();
  await expect(stage.getByRole('button', { name: /^C1/ })).toHaveAttribute('aria-current', 'step');
});

test('Tạo lead: ô bắt buộc báo tại ô; tạo xong về trang Lead; SĐT trùng hiện hộp cảnh báo', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await enterAs(page, setup.low);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/lead');
  await page.getByRole('button', { name: 'Tạo', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/lead\/moi$/);
  await expect(page.getByRole('heading', { level: 2, name: 'Lead mới' })).toBeVisible();
  // Giai đoạn đầu (mờ) và Sub-stage "Chưa có"; Tỉnh/Thành phố đứng trên Phường/Xã, Phường mờ đến khi chọn Tỉnh.
  const stageBar = page.getByRole('navigation', { name: 'Giai đoạn' });
  await expect(stageBar.getByRole('button', { name: /^C1/ })).toHaveAttribute(
    'aria-current',
    'step',
  );
  await expect(page.getByLabel('Sub-stage')).toHaveValue('Chưa có');
  const province = await page.getByRole('combobox', { name: 'Tỉnh/Thành phố' }).boundingBox();
  const ward = await page.getByRole('combobox', { name: 'Phường/Xã' }).boundingBox();
  expect((province?.y ?? 0) < (ward?.y ?? 0)).toBe(true);
  await expect(page.getByRole('combobox', { name: 'Phường/Xã' })).toBeDisabled();
  // Ô bắt buộc còn trống: viền cam, nền cam nhạt; bấm Lưu thì báo lỗi, viền đỏ.
  await expect(page.getByLabel('Họ tên', { exact: true })).toHaveAttribute(
    'data-required-empty',
    'true',
  );
  await expect(page.getByRole('combobox', { name: 'Source', exact: true })).toHaveAttribute(
    'data-required-empty',
    'true',
  );
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Nhập họ tên phụ huynh.')).toBeVisible();
  await expect(page.getByText('Chọn source.')).toBeVisible();
  await expect(page.getByLabel('Họ tên', { exact: true })).toHaveAttribute('aria-invalid', 'true');
  await expect(page.getByRole('combobox', { name: 'Source', exact: true })).toHaveAttribute(
    'aria-invalid',
    'true',
  );

  const phone = `0${String(seeded.phoneBase + 50)
    .padStart(9, '0')
    .slice(-9)}`;
  const fill = async (name: string) => {
    await page.getByLabel('Họ tên', { exact: true }).fill(name);
    await page.getByLabel('Số điện thoại', { exact: true }).fill(phone);
    await pickOption(page, page.getByRole('combobox', { name: 'Source', exact: true }), 'Website');
  };
  const first = `Chị ${setup.mark} tạo ${Date.now().toString(36).slice(-4).toUpperCase()}`;
  await fill(first);
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page).toHaveURL(/\/crm\/lead\/[0-9a-f-]{36}$/);
  await expect(toastText(page, /^Đã tạo lead LD\d+\./)).toBeVisible();
  await expect(page.getByRole('heading', { level: 2, name: new RegExp(first) })).toBeVisible();

  // Về danh sách, bấm vào dòng (không phải liên kết) thì mở đúng lead vừa tạo.
  const createdUrl = page.url();
  await page.goto('/crm/lead');
  await page.getByRole('searchbox').fill(first);
  const row = page.getByRole(isPhone(page) ? 'listitem' : 'row').filter({ hasText: first });
  await expect(row).toHaveCount(1);
  await row.getByText('Website').click();
  await expect(page).toHaveURL(createdUrl);
  await expect(page.getByRole('heading', { level: 2, name: new RegExp(first) })).toBeVisible();

  // Tạo lại cùng số: hộp cảnh báo, không có "Gắn vào hồ sơ có sẵn" vì chưa có hồ sơ phụ huynh để gắn.
  await page.goto('/crm/lead/moi');
  await fill(`${first} hai`);
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  const dialog = page.getByRole('dialog', { name: 'Số điện thoại này đã có khách hàng' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByText('Lead đã có')).toBeVisible();
  await expect(dialog.getByRole('link', { name: new RegExp(first) })).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Gắn vào hồ sơ có sẵn' })).toHaveCount(0);
  await dialog.getByRole('button', { name: 'Vẫn tạo mới' }).click();
  await expect(page).toHaveURL(/\/crm\/lead\/[0-9a-f-]{36}$/);
  await expect(
    page.getByRole('heading', { level: 2, name: new RegExp(`${first} hai`) }),
  ).toBeVisible();
});

test('Lịch hẹn: tạo, dời (Tuyển sinh không đổi được người phụ trách), hoàn thành, huỷ lý do Khác', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.low, seeded.mainId);
  const create = async (note: string) => {
    await page.getByRole('button', { name: 'Lên lịch hẹn' }).click();
    const dialog = page.getByRole('dialog', { name: 'Tạo lịch hẹn' });
    await expect(dialog.getByLabel('Gắn với')).toHaveValue(new RegExp(seeded.main));
    await expect(dialog.getByRole('button', { name: 'Tạo lịch hẹn' })).toBeDisabled();
    await dialog.getByRole('button', { name: 'Ngày mai' }).click();
    await dialog.getByRole('button', { name: '09:00' }).click();
    await dialog.getByLabel('Ghi chú').fill(note);
    await dialog.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
    await expect(toastText(page, 'Đã tạo lịch hẹn.')).toBeVisible();
  };
  await create('Gọi lại E2E một');
  const upcoming = page.getByRole('region', { name: 'Hoạt động sắp tới' });
  await expect(upcoming.getByText('Gọi điện · Gọi lại E2E một')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Lịch hẹn: 1' })).toBeVisible();

  // Dời: người phụ trách chỉ đọc khi không có quyền Giao việc; ghi chú dời vào ghi chú của hồ sơ.
  await upcoming.getByRole('button', { name: 'Dời' }).click();
  const move = page.getByRole('dialog', { name: 'Dời lịch hẹn' });
  await expect(move.getByText('Lịch hiện tại')).toBeVisible();
  await expect(move.getByLabel('Người phụ trách')).toHaveAttribute('readonly', '');
  await move.getByRole('button', { name: 'Ngày kia' }).click();
  await move.getByRole('button', { name: '10:00' }).click();
  await move.getByLabel('Ghi chú').fill('PH bận E2E');
  await move.getByRole('button', { name: 'Dời lịch' }).click();
  await expect(toastText(page, 'Đã dời lịch hẹn.')).toBeVisible();
  await expect(
    page.getByText(/Dời lịch hẹn "Gọi lại E2E một" từ .* Ghi chú: PH bận E2E/),
  ).toBeVisible();

  // Hoàn thành.
  await upcoming.getByRole('button', { name: 'Hoàn thành' }).click();
  await expect(toastText(page, 'Đã hoàn thành lịch hẹn.')).toBeVisible();
  await expect(upcoming.getByText('Gọi lại E2E một')).toHaveCount(0);

  // Huỷ: lý do "Khác" bắt ghi chú.
  await create('Gọi lại E2E hai');
  await upcoming.getByRole('button', { name: 'Huỷ' }).click();
  const cancel = page.getByRole('alertdialog', { name: 'Huỷ lịch hẹn' });
  await cancel.getByRole('combobox', { name: 'Lý do' }).click();
  await page.getByRole('option', { name: 'Khác' }).click();
  await expect(cancel.getByRole('button', { name: 'Huỷ lịch hẹn' })).toBeDisabled();
  await cancel.getByLabel('Ghi chú').fill('Khách đổi ý');
  await cancel.getByRole('button', { name: 'Huỷ lịch hẹn' }).click();
  await expect(toastText(page, 'Đã huỷ lịch hẹn.')).toBeVisible();
  await expect(upcoming.getByText('Gọi lại E2E hai')).toHaveCount(0);
});

test('Trưởng cơ sở đổi người phụ trách khi dời lịch hẹn', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.high, seeded.mainId);
  await page.getByRole('button', { name: 'Lên lịch hẹn' }).click();
  const dialog = page.getByRole('dialog', { name: 'Tạo lịch hẹn' });
  await dialog.getByRole('button', { name: 'Ngày mai' }).click();
  await dialog.getByRole('button', { name: '14:00' }).click();
  await dialog.getByLabel('Ghi chú').fill('Lịch của trưởng E2E');
  await dialog.getByRole('button', { name: 'Tạo lịch hẹn' }).click();
  await expect(toastText(page, 'Đã tạo lịch hẹn.')).toBeVisible();
  const upcoming = page.getByRole('region', { name: 'Hoạt động sắp tới' });
  await upcoming.getByRole('button', { name: 'Dời' }).click();
  const move = page.getByRole('dialog', { name: 'Dời lịch hẹn' });
  await move.getByRole('combobox', { name: 'Người phụ trách' }).click();
  await page.getByRole('option', { name: 'Sale CS5 (giả)', exact: true }).click();
  await move.getByRole('button', { name: 'Ngày kia' }).click();
  await move.getByRole('button', { name: '10:00' }).click();
  await move.getByRole('button', { name: 'Dời lịch' }).click();
  await expect(toastText(page, 'Đã dời lịch hẹn.')).toBeVisible();
  await expect(upcoming.getByText(/· Sale CS5 \(giả\)/)).toBeVisible();
  await expect(page.getByText(/Người phụ trách mới: Sale CS5 \(giả\)\./)).toBeVisible();
});

test('Lead đã gộp chỉ đọc; không có lead thì báo không tìm thấy', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  const merged = (
    await db.query<{ id: string }>('select id from app.lead where parent_name = $1', [
      seeded.merged,
    ])
  ).rows[0]?.id;
  await db.end();
  await openRecord(page, setup.low, merged ?? '');
  await expect(page.getByText(/Lead này đã gộp vào LD\d+, chỉ đọc\./)).toBeVisible();
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Assign', exact: true })).toHaveCount(0);
  await expect(page.getByRole('button', { name: 'Lên lịch hẹn' })).toHaveCount(0);
  await page.goto('/crm/lead/00000000-0000-0000-0000-000000000000');
  await expect(page.getByRole('heading', { name: 'Không tìm thấy lead' })).toBeVisible();
});
