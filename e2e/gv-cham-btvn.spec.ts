// GV-08 và GV-07: màn Chấm BTVN buổi trước và màn Chấm nhận xét (cổng Giáo viên). Dữ liệu giả dựng bằng SQL trực tiếp rồi dọn sau bài: lớp có hai buổi,
// buổi 1 có giao BTVN (bốn em giả), buổi 2 (hôm nay, Đã chốt) là buổi chấm. Luật R-GV-11: 5 trạng thái, điểm 1–5, vắng buổi giao bài = Không áp dụng,
// vắng buổi chấm = Nộp sau (suy từ điểm danh); Q-243: hai người cùng sửa thì từ chối lưu.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { DOMAIN, PASSWORD, expectAccessible, loginStaffUntil } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng buổi học giả).');
test.describe.configure({ mode: 'serial' });

const MARK = 'E2EGV08';
const tag = (project: string) => (project === 'dien-thoai' ? 'DT' : 'MT');
const classCode = (project: string) => `${MARK}-${tag(project)}`;
let gradingSession = '';
let assignedSession = '';

async function withDb<T>(run: (db: pg.Client) => Promise<T>): Promise<T> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    return await run(db);
  } finally {
    await db.end();
  }
}

async function clear(db: pg.Client, project: string) {
  const code = classCode(project);
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const sessions = `(select id from app.class_session where class_id in (select id from app.class where code = $1))`;
  for (const table of [
    'homework_result',
    'session_review_score',
    'session_student_review',
    'session_review_criterion',
  ]) {
    await db.query(`delete from app.${table} where session_id in ${sessions}`, [code]);
  }
  await db.query(`delete from app.session_attendance where session_id in ${sessions}`, [code]);
  await db.query(`delete from app.session_content_line where session_id in ${sessions}`, [code]);
  await db.query(`delete from app.session_content where session_id in ${sessions}`, [code]);
  await db.query(
    'delete from app.class_session where class_id in (select id from app.class where code = $1)',
    [code],
  );
  await db.query('delete from app.class where code = $1', [code]);
  await db.query('delete from app.student where code like $1', [`${MARK}-${tag(project)}-%`]);
  await db.query('delete from app.parent where code = $1', [`${MARK}-${tag(project)}-P`]);
  await db.query('commit');
}

// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  const project = testInfo.project.name;
  await withDb(async (db) => {
    await clear(db, project);
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    const branch = (await db.query<{ id: string }>("select id from app.branch where code = 'CS5'"))
      .rows[0]!.id;
    const teacher = (
      await db.query<{ id: string }>('select id from app.user_account where login_name = $1', [
        `gv.cs5@${DOMAIN}`,
      ])
    ).rows[0]!.id;
    const cls = (
      await db.query<{ id: string }>(
        `insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
         values ($1, $2, '2627', 'TOAN', 'K08', 'CB', 'A', current_date - 7, 3) returning id`,
        [classCode(project), branch],
      )
    ).rows[0]!.id;
    const session = async (no: number, date: string) =>
      (
        await db.query<{ id: string }>(
          `insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code)
           values ($1, $2, $3, ${date}, '18:00', '19:30', $4, 'DA_CHOT') returning id`,
          [cls, branch, no, teacher],
        )
      ).rows[0]!.id;
    assignedSession = await session(1, 'current_date - 7');
    gradingSession = await session(2, 'current_date');
    await db.query(
      "insert into app.session_content (session_id, branch_id, homework_text) values ($1, $2, 'Bài 1 đến bài 5 trang 42')",
      [assignedSession, branch],
    );
    const parent = (
      await db.query<{ id: string }>(
        "insert into app.parent (code, full_name, phone, branch_id) values ($1, 'Phụ huynh giả E2E', '0900000001', $2) returning id",
        [`${MARK}-${tag(project)}-P`, branch],
      )
    ).rows[0]!.id;
    // A, C: có mặt cả hai buổi. B: vắng buổi giao bài, có mặt buổi chấm. D: có mặt buổi giao bài, vắng buổi chấm.
    const plan: [string, string, string, string][] = [
      ['A', 'Em giả E2E An', 'CO_MAT', 'CO_MAT'],
      ['B', 'Em giả E2E Bình', 'VANG_KHONG_PHEP', 'CO_MAT'],
      ['C', 'Em giả E2E Chi', 'CO_MAT', 'DI_MUON'],
      ['D', 'Em giả E2E Dũng', 'CO_MAT', 'VANG_CO_PHEP'],
    ];
    for (const [key, name, first, second] of plan) {
      const student = (
        await db.query<{ id: string }>(
          `insert into app.student (code, parent_id, full_name, birth_year, branch_id) values ($1, $2, $3, 2012, $4) returning id`,
          [`${MARK}-${tag(project)}-${key}`, parent, name, branch],
        )
      ).rows[0]!.id;
      for (const [sid, status] of [
        [assignedSession, first],
        [gradingSession, second],
      ] as const) {
        await db.query(
          `insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code)
           values ($1, $2, $3, $4, $5)`,
          [sid, cls, branch, student, status],
        );
      }
    }
    await db.query('commit');
  });
});

// eslint-disable-next-line no-empty-pattern
test.afterAll(async ({}, testInfo) => {
  await withDb((db) => clear(db, testInfo.project.name));
});

const row = (page: import('@playwright/test').Page, name: string) =>
  page.getByRole('listitem').filter({ has: page.getByText(name, { exact: true }) });

test('GV-08: chấm BTVN buổi trước; em vắng buổi giao bài đặt sẵn Không áp dụng; em vắng buổi này ở mục riêng', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${gradingSession}/cham-btvn`);
  await expect(page.getByRole('heading', { level: 1, name: /Chấm BTVN buổi trước/ })).toBeVisible();
  await expect(page.getByText(/Bài 1 đến bài 5 trang 42/)).toBeVisible();
  await expectAccessible(page);
  await expect(page.getByText('Học sinh có mặt · 3')).toBeVisible();
  await expect(page.getByText('Có trạng thái 1/3')).toBeVisible();
  await expect(
    row(page, 'Em giả E2E Bình').getByText('Vắng buổi giao bài', { exact: true }),
  ).toBeVisible();
  await expect(
    row(page, 'Em giả E2E Bình').getByRole('button', { name: /Không áp dụng/ }),
  ).toHaveAttribute('aria-pressed', 'true');
  await expect(page.getByText('Em vắng buổi này · 1')).toBeVisible();

  const save = page.getByRole('button', { name: 'Lưu', exact: true });
  await expect(save).toBeDisabled();
  // Đã chấm mà chưa chọn điểm: chặn, nêu lý do.
  await row(page, 'Em giả E2E An')
    .getByRole('button', { name: /Đã chấm/ })
    .click();
  await save.click();
  await expect(page.getByRole('alert').filter({ hasText: 'Chọn điểm 1–5.' })).toBeVisible();
  await row(page, 'Em giả E2E An').getByRole('button', { name: '4', exact: true }).click();
  await row(page, 'Em giả E2E Chi')
    .getByRole('button', { name: /Không làm/ })
    .click();
  await expect(page.getByText('Có trạng thái 3/3')).toBeVisible();
  await save.click();
  await expect(page.getByText('Đã lưu chấm BTVN').first()).toBeVisible();

  await page.reload();
  await expect(
    row(page, 'Em giả E2E An').getByRole('button', { name: '4', exact: true }),
  ).toHaveAttribute('aria-pressed', 'true');
  await expect(
    row(page, 'Em giả E2E Chi').getByRole('button', { name: /Không làm/ }),
  ).toHaveAttribute('aria-pressed', 'true');
  // Không làm không phải điểm 0: không hiện ô điểm.
  await expect(row(page, 'Em giả E2E Chi').getByRole('group', { name: /Điểm 1–5/ })).toHaveCount(0);
});

test('GV-04: bước Chấm BTVN buổi trước hiện tiến độ thật và mở được màn GV-08', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${gradingSession}`);
  const step = page.getByRole('list', { name: 'Các bước của buổi' }).getByRole('listitem').nth(3);
  await expect(step).toContainText('3/3 em có mặt đã có trạng thái');
  await expect(step).toContainText('Xong');
  await step.getByRole('link', { name: 'Mở' }).click();
  await expect(page).toHaveURL(new RegExp(`/gv/buoi/${gradingSession}/cham-btvn$`));
});

test('GV-08: bài Nộp sau của em vắng buổi chấm cập nhật ngay trên màn, không mở lại buổi cũ', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${gradingSession}/cham-btvn`);
  await expect(page.getByRole('heading', { name: 'Bài Nộp sau chờ cập nhật · 1' })).toBeVisible();
  const late = row(page, 'Em giả E2E Dũng');
  await expect(late.getByText('Vắng buổi chấm')).toBeVisible();
  await late.getByRole('button', { name: 'Đã chấm' }).click();
  await late.getByRole('button', { name: '3', exact: true }).click();
  await late.getByRole('button', { name: 'Cập nhật' }).click();
  await expect(page.getByText('Đã cập nhật bài Nộp sau').first()).toBeVisible();
  await expect(page.getByRole('heading', { name: /Bài Nộp sau chờ cập nhật/ })).toHaveCount(0);
});

test('GV-08: người khác vừa sửa thì từ chối lưu, «Giữ của tôi» lưu lại bản của mình (Q-243)', async ({
  page,
}, testInfo) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${gradingSession}/cham-btvn`);
  await row(page, 'Em giả E2E An').getByRole('button', { name: '5', exact: true }).click();
  // Người khác (trợ giảng) lưu trước: tăng phiên bản dòng.
  await withDb((db) =>
    db.query(
      `update app.homework_result set score = 2, version = version + 1
        where session_id = $1 and student_id = (select id from app.student where code = $2)`,
      [assignedSession, `${MARK}-${tag(testInfo.project.name)}-A`],
    ),
  );
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Ô này vừa được người khác sửa, tải lại để xem.')).toBeVisible();
  await page.getByRole('button', { name: 'Giữ của tôi' }).click();
  await expect(
    row(page, 'Em giả E2E An').getByRole('button', { name: '5', exact: true }),
  ).toHaveAttribute('aria-pressed', 'true');
  // Tải lại phiên bản mới làm màn dựng lại (key đổi theo phiên bản): chờ xong rồi mới bấm Lưu, nếu không bấm trúng bản cũ sắp bị thay
  // thì thông báo thành công không hiện (bài từng nháy).
  await page.waitForLoadState('networkidle');
  await expect(page.getByText('Ô này vừa được người khác sửa, tải lại để xem.')).toHaveCount(0);
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu chấm BTVN').first()).toBeVisible();
  await page.reload();
  await expect(
    row(page, 'Em giả E2E An').getByRole('button', { name: '5', exact: true }),
  ).toHaveAttribute('aria-pressed', 'true');
});

test('GV-07: mở nhận xét, chấm ô 4 trạng thái, tắt tiêu chí, lưu một lần; em vắng không chấm', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${gradingSession}/cham-nhan-xet`);
  await expect(page.getByRole('heading', { level: 1, name: /Chấm nhận xét/ })).toBeVisible();
  await expect(page.getByText('Chưa mở nhận xét của buổi')).toBeVisible();
  await page.getByRole('button', { name: 'Mở nhận xét của buổi' }).click();
  await expect(page.getByText('Đủ 0/3 em có mặt')).toBeVisible();
  await expectAccessible(page);

  const card = page.getByRole('region', { name: /Thẻ chấm Em giả E2E An/ });
  await expect(card).toBeVisible();
  await card
    .getByRole('group', { name: 'Tập trung của Em giả E2E An' })
    .getByRole('button', { name: 'Mức 4' })
    .click();
  await card
    .getByRole('group', { name: 'Chủ động của Em giả E2E An' })
    .getByRole('button', { name: 'Chưa đủ căn cứ' })
    .click();
  await expect(card.getByText('Đã đánh giá · Mức 4')).toBeVisible();
  await expect(card.getByText('Chưa đủ căn cứ (không tính điểm)')).toBeVisible();
  await expect(card.getByText(/Đã chấm 2\/9/)).toBeVisible();
  await card.getByLabel('Nhận xét chung').fill('Tập trung tốt');
  // Tắt một tiêu chí: cả buổi Không áp dụng.
  await page.getByRole('button', { name: 'Tắt tiêu chí Ghi nhớ' }).click();
  await expect(page.getByText('Đang áp dụng 8/9')).toBeVisible();
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await expect(page.getByText('Đã lưu nhận xét').first()).toBeVisible();

  await page.reload();
  const again = page.getByRole('region', { name: /Thẻ chấm Em giả E2E An/ });
  await expect(
    again
      .getByRole('group', { name: 'Tập trung của Em giả E2E An' })
      .getByRole('button', { name: 'Mức 4' }),
  ).toHaveAttribute('aria-pressed', 'true');
  await expect(again.getByLabel('Nhận xét chung')).toHaveValue('Tập trung tốt');
  await expect(again.getByText('Không áp dụng cả buổi (tắt ở Tiêu chí của buổi)')).toBeVisible();

  // Em vắng: không chấm.
  await page.getByRole('button', { name: /Em giả E2E Dũng/ }).click();
  await expect(page.getByText('Em vắng: không chấm nhận xét (R-GV-04).')).toBeVisible();
});

test('GV-07X: xuất nhận xét của một em ra ảnh PNG: tải file, hiện «Đã xuất»; còn thay đổi chưa lưu thì khoá nút', async ({
  page,
}) => {
  await loginStaffUntil(page, 'gv.cs5', /\/gv$/);
  await page.goto(`/gv/buoi/${gradingSession}/cham-nhan-xet`);
  await expect(page.getByRole('heading', { level: 1, name: /Chấm nhận xét/ })).toBeVisible();
  await page.getByRole('button', { name: /Em giả E2E An/ }).click();
  const exportBtn = page.getByRole('button', { name: 'Xuất nhận xét', exact: true });
  await expect(exportBtn).toBeEnabled();
  // Sửa mà chưa lưu: khoá nút xuất (khung «Chưa lưu thay đổi»).
  await page.getByLabel('Nhận xét chung').fill('Tập trung tốt, sửa chưa lưu');
  await expect(exportBtn).toBeDisabled();
  await expect(page.getByText(/chưa bấm Lưu\. Lưu xong mới xuất được/)).toBeVisible();
  await page.getByLabel('Nhận xét chung').fill('Tập trung tốt');
  await expect(exportBtn).toBeEnabled();
  await exportBtn.click();
  const dialog = page.getByRole('dialog', { name: 'Xuất nhận xét' });
  await expect(dialog).toBeVisible();
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    dialog.getByRole('button', { name: 'Xuất', exact: true }).click(),
  ]);
  expect(download.suggestedFilename()).toMatch(/-Em-gia-E2E-An\.png$/);
  await expect(page.getByText('Đã xuất nhận xét').first()).toBeVisible();
  await expect(page.getByRole('button', { name: /Em giả E2E An.*Đã xuất/ })).toBeVisible();
});
