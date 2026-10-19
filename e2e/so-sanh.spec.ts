// Chụp từng màn ở trạng thái mặc định, đặt cạnh ảnh thiết kế (design/hmt-platform/screens/<MÃ>.png),
// lưu docs/so-sanh/<MÃ>.jpg (đã nén) để đưa vào mô tả PR. Chỉ chạy khi đặt SO_SANH=1:
//   SO_SANH=1 npx playwright test e2e/so-sanh.spec.ts --project=may-tinh
// Chạy xong thì chạy lại `npm run db:seed-users` (kịch bản đổi mật khẩu học sinh giả để vào cổng Học tập).
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, test, type Browser, type Page } from '@playwright/test';
import { generateSync } from 'otplib';
import pg from 'pg';
import { DOMAIN, PASSWORD, fillLogin, loginStaff, loginStudent, signOut } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
// Playwright chạy từ thư mục gốc của repo.
const DESIGN_DIRS = [
  join(process.cwd(), 'design', 'hmt-platform', 'screens'),
  join(process.cwd(), 'design', 'hmt-p3', 'png'),
];
// Mặc định ảnh ra thư mục tạm để không ghi đè ảnh đã lưu trong repo; chỉ ghi vào docs/so-sanh khi đặt SO_SANH_GHI_VAO_REPO=1
// (màn mới dựng, hoặc anh yêu cầu chụp lại).
const OUT_DIR = process.env.SO_SANH_GHI_VAO_REPO
  ? join(process.cwd(), 'docs', 'so-sanh')
  : join(tmpdir(), 'hmt-so-sanh');
const DESKTOP = { width: 1440, height: 900 };
const PHONE = { width: 390, height: 844 };
const JPEG_QUALITY = 70;

test.skip(
  !process.env.SO_SANH || !PASSWORD || !DB_URL,
  'Chỉ chạy khi SO_SANH=1 và có SEED_PASSWORD, DB_URL.',
);
test.describe.configure({ mode: 'serial' });

/** Ghép ảnh thiết kế (nếu có) và ảnh bản dựng thành một ảnh JPEG. */
async function save(browser: Browser, page: Page, code: string, suffix = '') {
  await page.waitForTimeout(400);
  // Che mã QR và khoá TOTP: là bí mật, kể cả của tài khoản giả.
  const shot = await page.screenshot({
    type: 'png',
    mask: [page.locator('img[alt^="Mã QR"]'), page.locator('code')],
  });
  const designPath = DESIGN_DIRS.map((dir) => join(dir, `${code}.png`)).find((p) => existsSync(p));
  const design = designPath ? readFileSync(designPath).toString('base64') : null;
  const narrow = suffix !== '';
  const composer = await browser.newPage({
    viewport: { width: design ? 1800 : narrow ? 480 : 1000, height: 800 },
  });
  const figure = (title: string, data: string, width: string) =>
    `<figure style="margin:0;width:${width}"><figcaption style="font:600 14px system-ui;padding:6px 0">${title}</figcaption>` +
    `<img src="data:image/png;base64,${data}" style="width:100%;border:1px solid #bbb;display:block"></figure>`;
  await composer.setContent(
    `<body style="margin:0;padding:12px;background:#fff"><div style="display:flex;gap:16px;align-items:flex-start">` +
      (design ? figure(`${code} · Thiết kế`, design, narrow ? '70%' : '50%') : '') +
      figure(
        `${code} · Bản dựng${suffix ? ` (${suffix})` : ''}`,
        shot.toString('base64'),
        design ? (narrow ? '30%' : '50%') : '100%',
      ) +
      `</div></body>`,
  );
  mkdirSync(OUT_DIR, { recursive: true });
  const name = `${code}${suffix ? '-dien-thoai' : ''}.jpg`;
  await composer.screenshot({
    path: join(OUT_DIR, name),
    type: 'jpeg',
    quality: JPEG_QUALITY,
    fullPage: true,
  });
  await composer.close();
}

async function clearTotp(email: string) {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  await db.query(
    'delete from auth.mfa_factors where user_id = (select id from auth.users where email = $1)',
    [email],
  );
  await db.end();
}

test('màn đăng nhập và các trang đơn (K11)', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await page.goto('/dang-nhap');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await save(browser, page, 'CHUNG-01');
  await page.goto('/quen-mat-khau');
  await save(browser, page, 'CHUNG-04');
  await page.goto('/dat-mat-khau');
  await save(browser, page, 'CHUNG-05');
  await page.goto('/khong-dang-nhap-duoc');
  await save(browser, page, 'CHUNG-08');
  await page.goto('/khong-ton-tai');
  await save(browser, page, 'CHUNG-17');

  await page.setViewportSize(PHONE);
  await page.goto('/dang-nhap');
  await save(browser, page, 'CHUNG-01', 'điện thoại');
  await page.goto('/dang-nhap/hoc-sinh');
  await save(browser, page, 'CHUNG-06', 'điện thoại');
});

test('hai bước, khung CRM của Admin, hồ sơ cá nhân, chọn cổng', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await clearTotp(`admin.cs1@${DOMAIN}`);
  await loginStaff(page, 'admin.cs1');
  await expect(page).toHaveURL(/\/thiet-lap-hai-buoc$/);
  await expect(page.locator('code')).toBeVisible();
  await save(browser, page, 'CHUNG-03');
  const secret = (await page.locator('code').first().textContent())?.trim() ?? '';
  await page.getByRole('button', { name: 'Tiếp', exact: true }).click();
  await page.getByLabel('Mã xác thực').fill(generateSync({ secret }));
  await page.getByRole('button', { name: 'Hoàn tất' }).click();
  await expect(page).toHaveURL(/\/crm$/);
  await page.getByRole('button', { name: 'Quản trị', exact: true }).click();
  await save(browser, page, 'CHUNG-10');
  await page.goto('/crm/tai-khoan');
  await expect(page.getByText('Thiết bị 1')).toBeVisible();
  await save(browser, page, 'CHUNG-13');
  await page.goto('/chon-cong');
  await expect(page.getByText('Lịch dạy, điểm danh, chấm nhận xét, bài tập về nhà.')).toBeVisible();
  await save(browser, page, 'CHUNG-25');

  await page.setViewportSize(PHONE);
  await page.goto('/crm');
  await page.getByRole('button', { name: 'Mở menu' }).click();
  await save(browser, page, 'CHUNG-10', 'điện thoại');
  await page.keyboard.press('Escape');
  await page.setViewportSize(DESKTOP);
  await signOut(page);
  await fillLogin(page, 'Email', `admin.cs1@${DOMAIN}`);
  await expect(page).toHaveURL(/\/xac-thuc-hai-buoc$/);
  await save(browser, page, 'CHUNG-02');
});

test('không có quyền, phân hệ chưa bật, hết phiên', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await page.clock.install();
  await loginStaff(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/quan-tri/nguoi-dung');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await save(browser, page, 'CHUNG-16');
  await page.clock.fastForward('01:05:00');
  await expect(page.getByRole('dialog', { name: 'Phiên làm việc đã hết' })).toBeVisible();
  await save(browser, page, 'CHUNG-09');
  await page.getByRole('button', { name: 'Đăng nhập lại' }).click();
  await page.clock.setSystemTime(new Date());

  await fillLogin(page, 'Email', `cskh.cs1@${DOMAIN}`);
  await expect(page).toHaveURL(/\/crm/);
  await page.goto('/crm/lead');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  await save(browser, page, 'CHUNG-24');
});

test('khung cổng Giáo viên và cổng Học tập', async ({ page, browser }) => {
  await page.setViewportSize(DESKTOP);
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await save(browser, page, 'GV-01');
  await page.setViewportSize(PHONE);
  await save(browser, page, 'GV-01', 'điện thoại');
  await signOut(page);

  await page.setViewportSize(DESKTOP);
  await loginStudent(page, 'hs900001');
  await expect(page).toHaveURL(/\/doi-mat-khau$/);
  await save(browser, page, 'CHUNG-07');
  const newPassword = `Moi${Date.now()}a`;
  await page.getByLabel('Mật khẩu mới', { exact: true }).fill(newPassword);
  await page.getByLabel('Nhập lại mật khẩu mới', { exact: true }).fill(newPassword);
  await page.getByRole('button', { name: 'Đổi mật khẩu và tiếp tục' }).click();
  await expect(page).toHaveURL(/\/hoc$/);
  await save(browser, page, 'HT-09');
  await page.setViewportSize(PHONE);
  await save(browser, page, 'HT-09', 'điện thoại');
});

// TS-01, TS-01b, TS-05: Lead danh sách, Kanban, hộp Giao. Dựng sáu lead giả của Trưởng CS5 (Tuyển sinh đang bật ở CS5) để giống bản vẽ.
test('Lead: danh sách, Kanban, hộp Giao (TS-01, TS-01b, TS-05)', async ({ page, browser }) => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query("delete from app.lead where parent_name like '%(so sánh)%'");
    await db.query("delete from app.parent where full_name like '%(so sánh)%'");
    await db.query('commit');
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`truongcs.cs5@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const leads = [
      [
        'Chị Lê Thu Hằng',
        'Lê Gia Huy',
        '0912000121',
        'FACEBOOK_ADS',
        'FACEBOOK_ADS_LEAD_FORM',
        'C4',
        'C4D',
      ],
      ['Anh Phạm Văn Tú', 'Phạm Minh Khôi', '0903000124', 'WEBSITE', null, 'C4', 'C4C'],
      ['Anh Vũ Đức Long', null, '0938000130', 'HOTLINE', null, 'C2', 'C2A'],
      ['Anh Bùi Quang Vinh', null, '0919000109', 'EVENT', 'EVENT_INDOOR', 'C1', null],
      [
        'Chị Trần Thị Mai',
        'Trần Bảo Long',
        '0985000127',
        'REFERRAL',
        'REFERRAL_BY_HMT',
        'C4',
        'C4B',
      ],
      [
        'Chị Đặng Thu Phương',
        'Đặng Minh Châu',
        '0914000133',
        'COLD_CALL',
        'COLD_CALL_FLYER',
        'C1',
        null,
      ],
    ] as const;
    const types: Record<string, string> = {
      FACEBOOK_ADS: 'MARKETING',
      WEBSITE: 'MARKETING',
      HOTLINE: 'MARKETING',
      EVENT: 'EVENT',
      REFERRAL: 'REFERRAL',
      COLD_CALL: 'TELEMARKETING',
    };
    for (const [parent, student, phone, source, channel] of leads) {
      await db.query(
        `select app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text, 'student_name', $3::text,
           'source_type_code', $4::text, 'source_code', $5::text, 'channel_code', $6::text))`,
        [`${parent} (so sánh)`, phone, student, types[source], source, channel],
      );
    }
    await db.query('reset role');
    await db.query(
      `update app.lead set stage_code = x.stage, substage_code = x.sub
         from (values ('Chị Lê Thu Hằng', 'C4', 'C4D'), ('Anh Phạm Văn Tú', 'C4', 'C4C'), ('Anh Vũ Đức Long', 'C2', 'C2A'),
                      ('Chị Trần Thị Mai', 'C4', 'C4B')) as x (name, stage, sub)
        where parent_name = x.name || ' (so sánh)'`,
    );
    await db.query(
      `update app.lead set next_appointment_at = x.at
         from (values ('Chị Lê Thu Hằng', (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '14 hours') at time zone 'Asia/Ho_Chi_Minh'),
                      ('Anh Phạm Văn Tú', now() - interval '7 days'), ('Anh Vũ Đức Long', now() - interval '9 days'),
                      ('Chị Trần Thị Mai', now() + interval '3 days'),
                      ('Chị Đặng Thu Phương', (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '17 hours') at time zone 'Asia/Ho_Chi_Minh'))
              as x (name, at) where parent_name = x.name || ' (so sánh)'`,
    );
    await db.query('commit');
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }

  await page.setViewportSize(DESKTOP);
  await loginStaff(page, 'truongcs.cs5');
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto('/crm/lead');
  await page.getByRole('searchbox').fill('(so sánh)');
  await expect(page.getByText('1–6 / 6')).toBeVisible();
  await page.getByRole('searchbox').fill('');
  await page.getByRole('button', { name: 'Filters', exact: true }).click();
  await page.getByLabel('Tôi phụ trách', { exact: true }).check();
  await page.keyboard.press('Escape');
  await expect(page.getByText('1–6 / 6')).toBeVisible();
  await page.getByLabel(/^Chọn LD\d+ Chị Lê Thu Hằng/).check();
  await page.getByLabel(/^Chọn LD\d+ Anh Phạm Văn Tú/).check();
  await save(browser, page, 'TS01');
  await page.getByRole('button', { name: 'Assign', exact: true }).click();
  await expect(page.getByRole('dialog', { name: 'Assign lead' })).toBeVisible();
  await save(browser, page, 'TS05');
  await page.keyboard.press('Escape');
  await page.getByRole('button', { name: 'Bỏ chọn' }).click();
  await page.getByRole('button', { name: 'Kanban', exact: true }).click();
  await expect(page.getByRole('region', { name: /^C1 Data mới/ })).toBeVisible();
  await save(browser, page, 'TS01b');
  await page.setViewportSize(PHONE);
  await page.getByRole('button', { name: 'Danh sách', exact: true }).click();
  await save(browser, page, 'TS01', 'điện thoại');
});
