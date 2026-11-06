// Đồng bộ lịch hẹn giữa màn Lịch hẹn và trang Cơ hội (lỗi 26/10): hoàn thành, mở lại ở một nơi thì nơi kia đổi ngay, kể cả khi dữ liệu
// đã tải trước đó (bộ nhớ đệm một phút), và dòng thời gian của cơ hội có dòng ghi lại (R-CRM-04). Máy tính (thanh bên); dữ liệu giả
// dựng bằng hàm nghiệp vụ (co-hoi-seed.ts) cộng lịch hẹn gắn cơ hội, dấu riêng của bài này.
import { expect, test, type Page } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, isPhone, pickOption } from './helpers';
import { DB_URL, clearMark, seed, type Seeded, type Setup } from './co-hoi-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng cơ hội giả).');
test.describe.configure({ mode: 'serial' });

const SETUPS: Record<string, Setup> = {
  'may-tinh': { mark: 'E2EDBMT', account: 'sale.cs5', phone: 700 },
  'dien-thoai': { mark: 'E2EDBDT', account: 'kiem.cs5', phone: 800 },
};
const setupOf = (project: string): Setup => SETUPS[project] ?? SETUPS['may-tinh']!;

let seeded: Seeded;

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  seeded = await seed(setup);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    for (const [title, days] of [
      [`Hẹn A ${setup.mark}`, 2],
      [`Hẹn B ${setup.mark}`, 3],
    ] as const) {
      await db.query(
        `insert into app.appointment (opportunity_id, branch_id, activity_code, scheduled_at, title, owner_id, status)
         select o.id, o.branch_id, 'GOI_DIEN', now() + ($2 || ' days')::interval, $1::text, o.owner_id, 'CHUA_LAM'
           from app.opportunity o where o.id = $3`,
        [title, String(days), seeded.opportunity.fresh.id],
      );
    }
  } finally {
    await db.end();
  }
});
// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  const setup = setupOf(testInfo.project.name);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query('delete from app.appointment where title like $1', [`%${setup.mark}%`]);
    await db.query('commit');
  } finally {
    await db.end();
  }
  await clearMark(setup.mark);
});

// Thanh bên là các nhóm gập: nhóm của trang đang mở tự mở, nhóm khác phải bấm tên nhóm trước.
async function goMenu(page: Page, group: string, name: string) {
  const nav = page.getByRole('navigation', { name: 'Menu CRM' });
  const link = nav.getByRole('link', { name, exact: true });
  if (!(await link.isVisible()))
    await nav.getByRole('button', { name: new RegExp(`^${group}`) }).click();
  await link.click();
}
const rowOf = (page: Page, title: string) =>
  page.getByRole('table', { name: 'Lịch hẹn' }).getByRole('row').filter({ hasText: title });

async function openAppointments(page: Page, mark: string) {
  await goMenu(page, 'Tuyển sinh', 'Lịch hẹn');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch hẹn' })).toBeVisible();
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Khoảng thời gian' }),
    /^Tất cả thời gian$/,
  );
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(mark);
}

test('Hoàn thành, Mở lại ở màn Lịch hẹn thì trang Cơ hội đổi ngay (không đợi hết bộ nhớ đệm), có dòng ghi lại', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Thanh bên máy tính.');
  const setup = setupOf(testInfo.project.name);
  await enterAs(page, setup.account);
  await expect(page).toHaveURL(/\/crm$/);
  // Mở cơ hội trước: khối "Hoạt động sắp tới" có hai lịch, đã vào bộ nhớ đệm.
  await page.goto(`/crm/co-hoi/${seeded.opportunity.fresh.id}`);
  await expect(page.getByText(/Hoạt động sắp tới \(2\)/i)).toBeVisible();
  // Sang màn Lịch hẹn (điều hướng trong ứng dụng, không tải lại), hoàn thành lịch A.
  await openAppointments(page, setup.mark);
  await rowOf(page, `Hẹn A ${setup.mark}`).getByRole('button', { name: 'Hoàn thành' }).click();
  await expect(page.getByText('Đã hoàn thành lịch hẹn.').first()).toBeVisible();
  // Về trang Cơ hội bằng nút Quay lại: còn một lịch sắp tới, dòng thời gian ghi lại việc vừa làm.
  await page.goBack();
  await expect(page.getByText(/Hoạt động sắp tới \(1\)/i)).toBeVisible();
  await expect(page.getByText(`Hoàn thành lịch hẹn "Hẹn A ${setup.mark}"`)).toBeVisible();
  // Mở lại ở màn Lịch hẹn: trang Cơ hội có lại hai lịch và dòng "Mở lại".
  await openAppointments(page, setup.mark);
  await rowOf(page, `Hẹn A ${setup.mark}`).getByRole('button', { name: 'Mở lại' }).click();
  await page
    .getByRole('alertdialog', { name: 'Mở lại lịch hẹn?' })
    .getByRole('button', { name: 'Mở lại' })
    .click();
  await expect(page.getByText('Đã mở lại lịch hẹn.').first()).toBeVisible();
  await page.goBack();
  await expect(page.getByText(/Hoạt động sắp tới \(2\)/i)).toBeVisible();
  await expect(page.getByText(`Mở lại lịch hẹn "Hẹn A ${setup.mark}"`)).toBeVisible();
});

test('Hoàn thành ở trang Cơ hội thì màn Lịch hẹn đã tải trước đó cũng đổi', async ({
  page,
}, testInfo) => {
  test.skip(isPhone(page), 'Thanh bên máy tính.');
  const setup = setupOf(testInfo.project.name);
  await enterAs(page, setup.account);
  await expect(page).toHaveURL(/\/crm$/);
  // Tải màn Lịch hẹn trước (vào bộ nhớ đệm): lịch B đang "Chưa làm", có nút Hoàn thành.
  await openAppointments(page, setup.mark);
  await expect(
    rowOf(page, `Hẹn B ${setup.mark}`).getByRole('button', { name: 'Hoàn thành' }),
  ).toBeVisible();
  // Sang trang Cơ hội bằng thanh bên và hoàn thành lịch B ở khối "Hoạt động sắp tới".
  await goMenu(page, 'Tuyển sinh', 'Cơ hội');
  await expect(page.getByRole('heading', { level: 1, name: 'Cơ hội' })).toBeVisible();
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  // Chờ danh sách lọc xong theo dấu rồi mới bấm (nếu không có thể mở nhầm cơ hội "Em Mới" của bài khác).
  await page
    .getByRole('table', { name: 'Cơ hội' })
    .getByRole('row')
    .filter({ hasText: seeded.opportunity.fresh.code })
    .getByRole('link', { name: 'Em Mới' })
    .click();
  await expect(page).toHaveURL(new RegExp(`/crm/co-hoi/${seeded.opportunity.fresh.id}$`));
  const upcoming = page.getByRole('region', { name: 'Hoạt động sắp tới' });
  await upcoming
    .getByRole('listitem')
    .filter({ hasText: `Hẹn B ${setup.mark}` })
    .getByRole('button', { name: 'Hoàn thành' })
    .click();
  await expect(page.getByText('Đã hoàn thành lịch hẹn.').first()).toBeVisible();
  // Về màn Lịch hẹn (quay lại hai bước): lịch B đã Hoàn thành, không còn nút Hoàn thành.
  await page.goBack();
  await page.goBack();
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch hẹn' })).toBeVisible();
  // Quay lại thì bộ lọc về mặc định: chọn lại khoảng thời gian và gõ lại dấu bài, nếu không lịch B có thể rơi ra ngoài trang đầu (lỗi chập chờn theo ngày).
  await pickOption(
    page,
    page.getByRole('combobox', { name: 'Khoảng thời gian' }),
    /^Tất cả thời gian$/,
  );
  await page.getByPlaceholder(/Tìm tên, SĐT, mã/).fill(setup.mark);
  await expect(
    rowOf(page, `Hẹn B ${setup.mark}`).getByRole('button', { name: 'Hoàn thành' }),
  ).toHaveCount(0);
  await expect(rowOf(page, `Hẹn B ${setup.mark}`).getByText('Hoàn thành').first()).toBeVisible();
});
