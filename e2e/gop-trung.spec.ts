// P3f-2: hộp Gộp trùng lead, cơ hội (TS-10) mở từ Hành động ở trang bản ghi. Dữ liệu giả dựng bằng hàm nghiệp vụ (xem gop-trung-seed.ts).
import { expect, test, type Page } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible } from './helpers';
import { DB_URL, clearMark, seed, setupOf, type Seeded } from './gop-trung-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng lead, cơ hội giả).');
test.describe.configure({ mode: 'serial' });

let seeded: Seeded;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seeded = await seed(setupOf(testInfo.project.name));
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await clearMark(setupOf(testInfo.project.name).mark);
});

async function openRecord(page: Page, account: string, path: string) {
  await enterAs(page, account);
  await expect(page).toHaveURL(/\/crm$/);
  await page.goto(path);
  await expect(page.getByRole('heading', { level: 1, name: /^(Lead|Cơ hội)$/ })).toBeVisible();
}

async function openMerge(page: Page, title: string) {
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Gộp trùng' }).click();
  const dialog = page.getByRole('dialog', { name: title });
  await expect(dialog).toBeVisible();
  return dialog;
}

test('Lead: gợi ý bản cùng SĐT, chưa xác nhận thì chưa gộp được; xác nhận rồi gộp, bản kia thành Đã gộp', async ({
  page,
}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, `/crm/lead/${seeded.lead.a.id}`);
  const dialog = await openMerge(page, 'Gộp lead trùng');
  await expect(dialog.getByText(/^Hai lead cùng SĐT/)).toBeVisible();
  // Bản gợi ý đầu tiên được chọn sẵn, hiện so sánh và danh sách chuyển sang.
  await expect(
    dialog.getByRole('heading', {
      name: `Chuyển từ ${seeded.lead.b.code} sang ${seeded.lead.a.code}`,
    }),
  ).toBeVisible();
  await expect(dialog.getByText(/Gọi lại hỏi lịch học/)).toBeVisible();
  await expect(dialog.getByText(/PH nhắn Zalo hỏi học phí lớp 9\./)).toBeVisible();
  await expect(dialog.getByText('Lịch hẹn (1)')).toBeVisible();
  await expect(dialog.getByText('Ghi chú (2)')).toBeVisible();
  const submit = dialog.getByRole('button', { name: `Gộp vào ${seeded.lead.a.code}` });
  await expect(submit).toBeDisabled();
  await expectAccessible(page);
  await dialog.getByRole('checkbox', { name: /Gộp không hoàn tác được/ }).check();
  await expect(submit).toBeEnabled();
  await submit.click();
  await expect(page.getByText(`Đã gộp vào ${seeded.lead.a.code}.`).first()).toBeVisible();
  await expect(dialog).toBeHidden();
  // Bản bị gộp: chỉ đọc, ghi "đã gộp vào" bản giữ lại, không còn mục Gộp trùng.
  await page.goto(`/crm/lead/${seeded.lead.b.id}`);
  await expect(page.getByText(/Lead này đã gộp vào/)).toContainText(seeded.lead.a.code);
  await expect(page.getByRole('button', { name: 'Hành động' })).toHaveCount(0);
});

test('Cơ hội: chọn giữ bản kia thì gộp vào bản kia và mở bản đó', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, `/crm/co-hoi/${seeded.opp.a.id}`);
  const dialog = await openMerge(page, 'Gộp cơ hội trùng');
  await expect(dialog.getByText(/^Hai cơ hội cùng phụ huynh/)).toBeVisible();
  await expect(
    dialog.getByRole('heading', {
      name: `Chuyển từ ${seeded.opp.b.code} sang ${seeded.opp.a.code}`,
    }),
  ).toBeVisible();
  // Đổi bản giữ lại: bản đang mở gộp vào bản kia, xác nhận phải tick lại.
  await dialog.getByRole('radio', { name: `Giữ lại ${seeded.opp.b.code}` }).check();
  await expect(
    dialog.getByRole('heading', {
      name: `Chuyển từ ${seeded.opp.a.code} sang ${seeded.opp.b.code}`,
    }),
  ).toBeVisible();
  const submit = dialog.getByRole('button', { name: `Gộp vào ${seeded.opp.b.code}` });
  await expect(submit).toBeDisabled();
  await dialog.getByRole('checkbox', { name: /Gộp không hoàn tác được/ }).check();
  await submit.click();
  await expect(page).toHaveURL(new RegExp(`/crm/co-hoi/${seeded.opp.b.id}$`));
  await page.goto(`/crm/co-hoi/${seeded.opp.a.id}`);
  await expect(page.getByText(/Cơ hội này đã gộp vào/)).toContainText(seeded.opp.b.code);
});

test('Lead không trùng ai: hộp báo chưa thấy bản trùng, nút Gộp mờ', async ({ page }, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  await openRecord(page, setup.account, `/crm/lead/${seeded.lead.alone.id}`);
  const dialog = await openMerge(page, 'Gộp lead trùng');
  await expect(dialog.getByText(/Không thấy lead nào trùng với/)).toBeVisible();
  await expect(dialog.getByRole('button', { name: 'Gộp', exact: true })).toBeDisabled();
});
