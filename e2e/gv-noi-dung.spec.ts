// GV-06: màn Nội dung buổi và BTVN (cổng Giáo viên). Dữ liệu giả: một lớp và một buổi Đã chốt của giáo viên gv.cs5, dựng bằng SQL trực tiếp
// (không dùng dữ liệu thật) rồi dọn sau bài. Luật R-V2-35: cần ít nhất một dòng nội dung; BTVN trống = không giao; không tự lưu.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, expectAccessible, loginStaffUntil } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng buổi học giả).');
test.describe.configure({ mode: 'serial' });

const MARK = 'E2EGV06';
// Hai dự án (máy tính, điện thoại) chạy song song: mỗi dự án có mã lớp riêng và chỉ dọn lớp của mình.
const classCode = (project: string) => `${MARK}-${project === 'dien-thoai' ? 'DT' : 'MT'}`;
let sessionId = '';

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

async function clear(db: pg.Client, code: string) {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const ids = `(select id from app.class where code = $1)`;
  await db.query(
    `delete from app.session_content_line where session_id in (select id from app.class_session where class_id in ${ids})`,
    [code],
  );
  await db.query(
    `delete from app.session_content where session_id in (select id from app.class_session where class_id in ${ids})`,
    [code],
  );
  await db.query(`delete from app.class_session where class_id in ${ids}`, [code]);
  await db.query('delete from app.class where code = $1', [code]);
  await db.query('commit');
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const code = classCode(testInfo.project.name);
  sessionId = await withDb(async (db) => {
    await clear(db, code);
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const branch = await db.query<{ id: string }>("select id from app.branch where code = 'CS5'");
    const teacher = await db.query<{ id: string }>(
      'select id from app.user_account where login_name = $1',
      [`gv.cs5@${DOMAIN}`],
    );
    const cls = await db.query<{ id: string }>(
      `insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
       values ($1, $2, '2627', 'TOAN', 'K08', 'CB', 'A', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 3) returning id`,
      [code, branch.rows[0]!.id],
    );
    // Giờ kết thúc 23:59: buổi chưa hết giờ nên bước lưu của giáo viên chưa tự Done (A-23-12); để 19:30 thì CI chạy sau 19:30 giờ Việt Nam sẽ Done ngay và khoá ô nhập.
    const session = await db.query<{ id: string }>(
      `insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code)
       values ($1, $2, 1, (now() at time zone 'Asia/Ho_Chi_Minh')::date, '23:00', '23:59', $3, 'DA_CHOT') returning id`,
      [cls.rows[0]!.id, branch.rows[0]!.id, teacher.rows[0]!.id],
    );
    await db.query('commit');
    return session.rows[0]!.id;
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, classCode(testInfo.project.name)));
});

test('GV-06: nhập nội dung, BTVN để trống vẫn lưu được; mở lại thấy đúng', async ({ page }) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${sessionId}/noi-dung`);
  await expect(
    page.getByRole('heading', { level: 1, name: /Nội dung buổi và BTVN/ }),
  ).toBeVisible();
  await expectAccessible(page);
  const save = page.getByRole('button', { name: 'Lưu', exact: true });
  await expect(save).toBeDisabled();

  // Chỉ nhập BTVN, chưa có dòng nội dung: chặn, nói rõ lý do.
  await page.getByLabel('Bài tập về nhà giao mới').fill('Bài 6 đến 10');
  await save.click();
  await expect(
    page.getByRole('alert').filter({ hasText: 'Cần ít nhất một dòng nội dung.' }),
  ).toBeVisible();

  await page.getByLabel('Dòng nội dung 1').fill('Phương trình bậc nhất');
  await page.getByRole('button', { name: 'Thêm dòng' }).click();
  await page.getByLabel('Dòng nội dung 2').fill('Bài tập 1 đến 5');
  await page.getByLabel('Bài tập về nhà giao mới').fill('');
  await save.click();
  await expect(page.getByText('Đã lưu nội dung buổi').first()).toBeVisible();

  await page.reload();
  await expect(page.getByLabel('Dòng nội dung 1')).toHaveValue('Phương trình bậc nhất');
  await expect(page.getByLabel('Dòng nội dung 2')).toHaveValue('Bài tập 1 đến 5');
  await expect(page.getByLabel('Bài tập về nhà giao mới')).toHaveValue('');
});

test('GV-04: màn Buổi dạy hiện các bước và tiến độ; mở bước Nội dung', async ({ page }) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${sessionId}`);
  await expect(page.getByRole('heading', { level: 1, name: /Buổi dạy/ })).toBeVisible();
  const steps = page.getByRole('list', { name: 'Các bước của buổi' }).getByRole('listitem');
  await expect(steps).toHaveCount(4);
  // Bước 2 đã xong ở bài trước (đã lưu hai dòng nội dung).
  await expect(steps.nth(1)).toContainText('Xong');
  await expect(steps.nth(1)).toContainText('2 dòng nội dung');
  // Buổi đầu của lớp: bước 4 bỏ qua.
  await expect(steps.nth(3)).toContainText('Bỏ qua');
  await expectAccessible(page);
  await steps.nth(1).getByRole('link', { name: 'Mở' }).click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${sessionId}/noi-dung$`));
});

test('GV-06: người khác vừa sửa thì từ chối lưu, hộp chọn Giữ của tôi / Lấy của người kia, không ghi đè (Q-243, GV06_xung_dot)', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${sessionId}/noi-dung`);
  await expect(page.getByLabel('Dòng nội dung 1')).toHaveValue('Phương trình bậc nhất');
  await page.getByLabel('Dòng nội dung 1').fill('Bản của tôi');
  // Người khác (trợ giảng) lưu trước: tăng số phiên bản và đổi dòng nội dung.
  await withDb(async (db) => {
    await db.query('update app.session_content set version = version + 1 where session_id = $1', [
      sessionId,
    ]);
    await db.query(
      "update app.session_content_line set line_text = 'Bản của người khác' where session_id = $1 and sort_order = 1",
      [sessionId],
    );
  });
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  // GV06_xung_dot: hộp cho chọn bên nào được ghi; bản nháp của bạn vẫn còn cho tới khi chọn.
  const dialog = page.getByRole('dialog', { name: 'Có ô vừa được người khác sửa' });
  await expect(dialog).toBeVisible();
  await expect(dialog).toContainText('Của bạn: Bản của tôi');
  await expect(dialog).toContainText('Của người kia: Bản của người khác');
  await dialog.getByRole('button', { name: 'Lấy của người kia' }).click();
  await expect(page.getByLabel('Dòng nội dung 1')).toHaveValue('Bản của người khác');
});

test('GV-06: buổi Kiểm tra lưu được khi không có dòng nội dung (Q-252)', async ({ page }) => {
  await withDb((db) =>
    db.query("update app.class_session set type_code = 'KIEM_TRA' where id = $1", [sessionId]),
  );
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${sessionId}/noi-dung`);
  await expect(page.getByText('Buổi kiểm tra: dòng nội dung tuỳ giáo viên.')).toBeVisible();
  await page.getByLabel('Dòng nội dung 1').fill('');
  await page.getByLabel('Bài tập về nhà giao mới').fill('Làm lại bài 3');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu nội dung buổi').first()).toBeVisible();
  await page.reload();
  await expect(page.getByLabel('Bài tập về nhà giao mới')).toHaveValue('Làm lại bài 3');
});

test('GV-06: buổi đã Done chỉ xem', async ({ page }) => {
  await withDb((db) =>
    db.query("update app.class_session set status_code = 'DONE' where id = $1", [sessionId]),
  );
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${sessionId}/noi-dung`);
  await expect(page.getByText(/chỉ xem/)).toBeVisible();
  await expect(page.getByLabel('Dòng nội dung 1')).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Lưu', exact: true })).toBeDisabled();
});
