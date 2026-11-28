// Cụm Lớp: LOP-03 tạo lớp, LOP-01 danh sách và tìm, LOP-02 hồ sơ, LOP-05 Trình, LOP-06 Huỷ, LOP-08 lịch tuần.
// Dùng Trưởng cơ sở CS5 giả; bật công tắc VAN_HANH_LOP cho CS5 bằng SQL trước bài (cờ bật ở production bằng migration, Q-262).
// Lớp tạo trong bài có mã cũ riêng của từng dự án (máy tính, điện thoại) để tìm đúng lớp của mình; không xoá lớp (huỷ là đổi tình trạng).
import { expect, test } from '@playwright/test';
import pg from 'pg';
import { PASSWORD, enterAs, expectAccessible } from './helpers';

const DB_URL = process.env.DB_URL ?? '';
test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL.');
test.describe.configure({ mode: 'serial' });

test.beforeAll(async () => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    // Lớp chung bắt buộc có khung chương trình (R-LOP-07): khung giả Toán cơ bản cho mọi khối của năm học đang chọn.
    const year = new Date().getFullYear();
    const yearCode = `${String(year).slice(2)}${String(year + 1).slice(2)}`;
    await db.query(
      `insert into app.curriculum_frame (code, subject_code, grade_code, level_code, year_code)
       select 'E2ELOP-' || code || '-' || $1, 'TOAN', code, 'CB', $1 from app.catalog_item where catalog_code = 'GRADE'
       on conflict do nothing`,
      [yearCode],
    );
  } finally {
    await db.end();
  }
});

const legacy = (project: string) =>
  `E2ELOP-${project === 'dien-thoai' ? 'DT' : 'MT'}-${Date.now().toString(36).toUpperCase()}`;

test('LOP-03 tạo lớp, LOP-01 tìm, LOP-02 hồ sơ, LOP-05 Trình, LOP-06 Huỷ', async ({
  page,
}, testInfo) => {
  // Một bài dài (tạo, tìm, Trình, Huỷ) nên cho thời gian gấp ba mặc định.
  test.setTimeout(90_000);
  const mark = legacy(testInfo.project.name);
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/lop/tao');
  await expect(page.getByRole('heading', { level: 2, name: 'Tạo lớp mới' })).toBeVisible();
  await expectAccessible(page);

  // Nút Lưu nháp khi còn thiếu: báo từng trường.
  await page.getByRole('button', { name: 'Lưu nháp' }).click();
  await expect(page.getByText('Chọn môn học.')).toBeVisible();

  const year = new Date().getFullYear();
  await page
    .getByLabel('Năm học', { exact: true })
    .selectOption(`${String(year).slice(2)}${String(year + 1).slice(2)}`);
  await page.getByLabel('Mã lớp cũ (Sheet)').fill(mark);
  await page.getByLabel('Môn học', { exact: true }).selectOption({ label: 'Toán' });
  await page.getByLabel('Khối', { exact: true }).selectOption({ index: 5 });
  await page.getByLabel('Phân loại', { exact: true }).selectOption({ label: 'Cơ bản' });
  await page.getByLabel('Trình độ', { exact: true }).selectOption({ index: 1 });
  // LOP-03 (anh Trường chốt 20/11): Hình thức học là ô chọn (mặc định Offline); Tổ chức lớp không phải ô nhập, tự suy từ Phân loại (Cơ bản = Học chung).
  await expect(page.getByLabel('Hình thức học')).toHaveValue('OFF');
  await page.getByLabel('Hình thức học').selectOption({ label: 'OMO' });
  await expect(page.locator('dt', { hasText: 'Tổ chức lớp' }).locator('+ dd')).toHaveText(
    'Học chung',
  );
  await expect(page.getByRole('combobox', { name: 'Tổ chức lớp' })).toHaveCount(0);
  // A50: Khung chương trình và Bài bắt đầu là ô chọn (lấy từ khung ở CH-05). R-LOP-07: lớp chung bắt buộc có khung.
  await page.getByRole('button', { name: 'Lưu nháp' }).click();
  await expect(page.getByText('Lớp chung bắt buộc có khung chương trình.')).toBeVisible();
  await expect(page.getByText(/^Còn \d+ chỗ chưa hợp lệ/)).toBeVisible();
  await expect(page.getByLabel('Bài bắt đầu')).toBeDisabled();
  await page.getByRole('combobox', { name: 'Khung chương trình' }).selectOption({ index: 1 });
  await page.getByLabel('Tổng số buổi').fill('12');
  await page.getByLabel('Ngày bắt đầu').fill('2027-01-05');
  // Một khung giờ Thứ 3 (ngày 05/01/2027 là Thứ 3).
  // Time Table tab theo thứ như bản ghi: một bảng và một nút thêm cho thứ đang chọn, mặc định Thứ 2.
  await expect(page.getByRole('tab', { name: /^(Thứ|Chủ nhật)/ })).toHaveCount(7);
  await expect(page.getByRole('tab', { name: 'Thứ 2' })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByRole('button', { name: /^Thêm khung giờ/ })).toHaveCount(1);
  await page.getByRole('tab', { name: 'Thứ 3' }).click();
  await page.getByRole('button', { name: 'Thêm khung giờ Thứ 3' }).click();
  await expect(page.getByRole('tab', { name: /^Thứ 3\s*1$/ })).toBeVisible();
  await expect(page.getByLabel('Thứ 3 giờ bắt đầu')).toBeVisible();
  await expectAccessible(page);
  // «Xem trước ngày kết thúc dự kiến»: tính ở máy chủ từ khung giờ đang nhập, chưa lưu.
  await expect(page.locator('dt', { hasText: 'Kết thúc dự kiến' }).locator('+ dd')).toHaveText(
    /^\d{2}\/\d{2}\/\d{4}$/,
  );
  await page.getByRole('button', { name: 'Lưu nháp' }).click();
  await expect(page).toHaveURL(/\/crm\/lop\/[0-9a-f-]{36}$/);
  const recordUrl = page.url();
  await expect(page.getByText(/CS5-\d{4}-/).first()).toBeVisible();
  await expect(page.getByText('Nháp').first()).toBeVisible();
  await expect(page.getByText('OMO').first()).toBeVisible();
  // Canvas LOP05: câu theo tình trạng; Nháp có khung giờ thì «sửa được thông tin», lớp không thuộc nhóm có câu giải thích.
  await expect(page.getByText('Lớp ở Nháp: sửa được thông tin.')).toBeVisible();
  await expect(page.getByText('Lớp không thuộc nhóm nào.', { exact: false })).toBeVisible();
  await expect(page.getByText('Học chung').first()).toBeVisible();
  // Chi tiết lớp theo khuôn chung: Time Table 7 tab theo thứ; Học sinh và Buổi học là smart button (không còn bảng tab lặp bên dưới).
  await expect(page.getByRole('tab', { name: /^Thứ 3/ })).toBeVisible();
  await expect(page.getByRole('tab', { name: /^Học sinh/ })).toHaveCount(0);
  await expect(page.getByRole('tab', { name: /^Buổi học/ })).toHaveCount(0);
  // Nút Sửa hiện ở thanh trên (lớp Nháp), không chỉ trong menu Hành động.
  await expect(page.getByRole('button', { name: 'Sửa', exact: true })).toBeVisible();
  // Smart button mở danh sách của lớp, có nút quay lại lớp.
  await page.getByRole('button', { name: /^Học sinh/ }).click();
  await expect(page).toHaveURL(/\/crm\/lop\/[0-9a-f-]{36}\/hoc-sinh$/);
  // Đường dẫn trên thanh trên có tên trang (không «…»), và «Xếp thêm» mở danh sách Ghi danh lọc Chờ xếp lớp.
  const crumbs = page.getByRole('navigation', { name: 'Đường dẫn' }).first();
  await expect(crumbs).toContainText('· Học sinh');
  const studentsUrl = page.url();
  await page.getByRole('button', { name: 'Xếp thêm' }).click();
  await expect(page).toHaveURL(/\/crm\/ghi-danh\?loc=cho-xep-lop$/);
  await page.goto(studentsUrl);
  await page.getByRole('button', { name: /^Quay lại lớp/ }).click();
  await expect(page).toHaveURL(recordUrl);
  await page.getByRole('button', { name: /^Buổi học/ }).click();
  await expect(page).toHaveURL(/\/crm\/buoi-hoc\?lop=[0-9a-f-]{36}$/);
  await page.getByRole('button', { name: /^Quay lại lớp/ }).click();
  await expect(page).toHaveURL(recordUrl);

  // LOP-01: tìm theo mã cũ (R-LOP-15).
  await page.goto('/crm/lop');
  await expect(page.getByRole('heading', { level: 1, name: 'Lớp' })).toBeVisible();
  await page.getByPlaceholder('Tìm mã lớp hoặc mã cũ…').fill(mark);
  await expect(page.getByRole('link', { name: /^CS5-/ }).first()).toBeVisible();
  await expect(page.getByText(`mã cũ ${mark}`).first()).toBeVisible();

  // LOP-05 Trình, LOP-06 Huỷ ngay trên lớp vừa tạo.
  await page.goto(recordUrl);
  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Trình' }).click();
  await page.getByRole('button', { name: 'Trình', exact: true }).click();
  await expect(page.getByText('Trình xong.').first()).toBeVisible();
  await expect(page.getByText('Đã trình').first()).toBeVisible();
  await expect(
    page.getByText('Lớp đã trình, đang chờ quản lý cơ sở xác nhận.', { exact: false }),
  ).toBeVisible();

  await page.getByRole('button', { name: 'Hành động' }).click();
  await page.getByRole('menuitem', { name: 'Huỷ lớp' }).click();
  await page.getByRole('button', { name: 'Huỷ lớp' }).last().click();
  await expect(page.getByText('Huỷ lớp xong.').first()).toBeVisible();
});

test('LOP-03 sửa lớp đã duyệt: Time Table mở đúng thứ có khung, không tràn ngang trang', async ({
  page,
}) => {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  let classId: string;
  try {
    // Tạo và duyệt một lớp Thứ 4 bằng chính các hàm nghiệp vụ, dưới quyền Trưởng cơ sở CS5 giả.
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', id,
         'claims', jsonb_build_object('sub', id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account where login_name = 'truongcs.cs5@thu.hoamatoan.invalid'`,
    );
    const created = await db.query<{ id: string }>(
      `select app.create_class(jsonb_build_object(
         'branch_id', (select id from app.branch where code = 'CS5'), 'year_code', '2627', 'subject_code', 'TOAN',
         'grade_code', 'K06', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', '2027-01-06', 'total_sessions', 4,
         'curriculum_ref', (select code from app.curriculum_frame where subject_code = 'TOAN' and grade_code = 'K06' limit 1),
         'slots', jsonb_build_array(jsonb_build_object('weekday', 3, 'start_time', '18:00', 'end_time', '19:30',
           'repeat_weeks', 1, 'first_date', '2027-01-06')))) ->> 'id' as id`,
    );
    classId = created.rows[0]?.id ?? '';
    for (const status of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET'])
      await db.query('select app.transition_class($1, $2)', [classId, status]);
    await db.query('commit');
  } finally {
    await db.end();
  }

  await enterAs(page, 'truongcs.cs5');
  await page.goto(`/crm/lop/${classId}/sua`);
  await expect(page.getByLabel('Áp dụng thay đổi Time Table từ ngày')).toBeVisible();
  // weekday 3 là Thứ 4.
  await expect(page.getByRole('tab', { name: /^Thứ 4/ })).toHaveAttribute('aria-selected', 'true');
  await expect(page.getByLabel('Thứ 4 giờ bắt đầu')).toHaveValue(/^18:00/);
  const overflow = await page.evaluate<number>(
    'document.documentElement.scrollWidth - document.documentElement.clientWidth',
  );
  expect(overflow).toBeLessThanOrEqual(0);
  await expectAccessible(page);
});

test('LOP-08: lịch tuần cơ sở mở được, đổi tuần', async ({ page }) => {
  await enterAs(page, 'truongcs.cs5');
  await page.goto('/crm/lich-tuan');
  await expect(page.getByRole('heading', { level: 1, name: 'Lịch tuần cơ sở' })).toBeVisible();
  await page.getByRole('button', { name: 'Tuần sau' }).click();
  await page.getByRole('button', { name: 'Theo giáo viên' }).click();
  await expect(page.getByRole('button', { name: 'Theo giáo viên' })).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expectAccessible(page);
});
