// CS-16 Nhận xét chờ gửi phụ huynh (migration 622): CSKH mở được màn, thấy hai chip; giáo viên không có mục này ở cổng CRM.
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible } from './helpers';
import { DB_URL } from './lich-hen-seed';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');

test('CS-16: CSKH mở Nhận xét chờ gửi, có ô tìm kiếm, không báo thiếu quyền; trang đạt kiểm truy cập', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs1');
  await page.goto('/crm/nhan-xet-cho-gui');
  await expect(
    page.getByRole('heading', { level: 1, name: 'Nhận xét chờ gửi phụ huynh' }),
  ).toBeVisible();
  await expect(page.getByPlaceholder('Tìm tên em hoặc mã lớp…')).toBeVisible();
  await expect(page.getByText('Bạn không có quyền xem trang này')).toHaveCount(0);
  await expectAccessible(page);
});

// C-23-08: đánh dấu đã gửi. Dữ liệu giả dựng bằng SQL (một buổi có em Có mặt kèm lời nhắn của giáo viên); mã có dấu riêng mỗi lần chạy.
test.describe('CS-16 đánh dấu đã gửi', () => {
  test.skip(!DB_URL, 'Cần DB_URL (dựng nhận xét giả).');
  test.skip(({ isMobile }) => isMobile, 'Bài ghi dữ liệu chỉ kiểm trên máy tính.');
  const tag = `MT${Date.now().toString().slice(-6)}`;
  const studentName = `Học sinh E2E NX ${tag}`;
  const message = `Em ${tag} làm bài tốt, cần luyện thêm phần hình học.`;

  test.beforeAll(async () => {
    const db = new pg.Client({ connectionString: DB_URL });
    await db.connect();
    try {
      await db.query('begin');
      await db.query("set local session_replication_role = 'replica'");
      const branch = "(select id from app.branch where code = 'CS1')";
      await db.query(
        `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
        [`PHE2ENX${tag}`, `Phụ huynh E2E NX ${tag}`, `09${tag.slice(-6)}81`],
      );
      await db.query(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch})`,
        [`HSE2ENX${tag}`, `PHE2ENX${tag}`, studentName],
      );
      await db.query(
        `insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
         select $1, id, '2627', 'TOAN', 'K09', 'CB', 'A', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 4 from app.branch where code = 'CS1'`,
        [`LOPE2ENX${tag}`],
      );
      await db.query(
        `insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
         select c.id, c.branch_id, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1, '18:00', '19:30' from app.class c where c.code = $1`,
        [`LOPE2ENX${tag}`],
      );
      await db.query(
        `insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code)
         select s.id, s.class_id, s.branch_id, st.id, 'CO_MAT' from app.class_session s join app.class c on c.id = s.class_id, app.student st
          where c.code = $1 and st.code = $2`,
        [`LOPE2ENX${tag}`, `HSE2ENX${tag}`],
      );
      await db.query(
        `insert into app.session_student_review (attendance_id, session_id, branch_id, teacher_comment)
         select a.id, a.session_id, a.branch_id, $2 from app.session_attendance a join app.student st on st.id = a.student_id where st.code = $1`,
        [`HSE2ENX${tag}`, message],
      );
      await db.query('commit');
    } finally {
      await db.end();
    }
  });

  test('CSKH thấy lời nhắn ở Chờ gửi, bấm Đánh dấu đã gửi thì chuyển sang Đã gửi', async ({
    page,
  }) => {
    await enterAs(page, 'cskh.cs1');
    await page.goto('/crm/nhan-xet-cho-gui');
    await page.getByPlaceholder('Tìm tên em hoặc mã lớp…').fill(studentName);
    const row = page.getByRole('row').filter({ hasText: studentName });
    await expect(row).toContainText('Chờ gửi');
    await row.getByRole('button', { name: 'Đánh dấu đã gửi' }).click();
    // Đã chuyển khỏi Chờ gửi: dòng biến mất khỏi chip hiện tại, hiện ở chip Đã gửi.
    await expect(page.getByRole('row').filter({ hasText: studentName })).toHaveCount(0);
    await page.getByRole('button', { name: 'Filters', exact: true }).click();
    await page.getByLabel(/^Chờ gửi/).uncheck();
    await page.getByLabel(/^Đã gửi/).check();
    await page.keyboard.press('Escape');
    const sent = page.getByRole('row').filter({ hasText: studentName });
    await expect(sent).toContainText('Đã gửi');
    await expect(sent.getByRole('button', { name: 'Đánh dấu đã gửi' })).toHaveCount(0);
  });
});
