// HT-04 Nộp bài (cổng Học tập, điện thoại và máy tính): chọn quá giới hạn trang bị chặn; nộp thành công (tải ảnh lên một lần rồi chốt một lần);
// chốt hỏng rồi «Thử lại» chỉ chốt lại, KHÔNG tải ảnh lên lần hai (soát 02:35, F-24-06 3).
// Máy chủ kho tệp chưa có ở môi trường kiểm thử: chặn lời gọi bằng page.route (như e2e QT-17); chỉ đăng nhập bằng tài khoản giả hs900001.
import { expect, test, type Page } from '@playwright/test';
import { loginStudent, PASSWORD } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');

const ASSIGNMENT_ID = '00000000-0000-4000-8000-0000000000a1';
const STUDENT_ID = '00000000-0000-4000-8000-0000000000b1';
// Ảnh PNG 1×1 hợp lệ để trình duyệt nén được bằng canvas.
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  'base64',
);
const png = (n: number) => ({ name: `bai-${n}.png`, mimeType: 'image/png', buffer: PNG });
const json = (body: unknown, status = 200) => ({
  status,
  contentType: 'application/json',
  body: JSON.stringify(body),
});

interface Calls {
  upload: number;
  submit: number;
  submitIds: string[];
}

async function stub(
  page: Page,
  opts: { maxPages: number; failFirstSubmit?: boolean },
): Promise<Calls> {
  const calls: Calls = { upload: 0, submit: 0, submitIds: [] };
  await page.route('**/rest/v1/rpc/portal_children', (r) =>
    r.fulfill(json([{ id: STUDENT_ID, code: 'HS900001', full_name: 'Em giả E2E' }])),
  );
  await page.route('**/rest/v1/rpc/portal_assignment', (r) =>
    r.fulfill(
      json({
        assignment: {
          id: ASSIGNMENT_ID,
          title: 'Bài tập E2E nộp bài',
          description: 'Làm bài rồi chụp ảnh nộp.',
          due_at: '2099-01-01T10:00:00Z',
          class_code: 'LOP-E2E',
          subject_name: 'Toán',
          allow_resubmit: true,
          allow_late: true,
        },
        window_state: 'CON_HAN',
        can_submit: true,
        submission: null,
        result: null,
        files: [],
      }),
    ),
  );
  await page.route('**/rest/v1/rpc/file_upload_limits', (r) =>
    r.fulfill(json({ max_mb: 20, max_count: 10, max_total_mb: 50, max_pages: opts.maxPages })),
  );
  await page.route('**/functions/v1/file-upload', (r) => {
    calls.upload++;
    const sent = (r.request().postDataJSON() as { files: unknown[] }).files.length;
    return r.fulfill(
      json({ files: Array.from({ length: sent }, (_, i) => ({ id: `tep-${calls.upload}-${i}` })) }),
    );
  });
  await page.route('**/rest/v1/rpc/lms_submit_assignment', (r) => {
    calls.submit++;
    calls.submitIds = (r.request().postDataJSON() as { p_file_ids: string[] }).p_file_ids;
    if (opts.failFirstSubmit && calls.submit === 1)
      return r.fulfill(
        json({ message: 'Đã quá hạn nộp bài này.', hint: 'HMT_LMS_QUA_HAN', code: 'P0001' }, 400),
      );
    return r.fulfill(
      json({
        submission_id: 's1',
        attempt: 1,
        is_late: false,
        submitted_at: '2026-11-25T01:00:00Z',
      }),
    );
  });
  return calls;
}

async function openAssignment(page: Page) {
  await loginStudent(page, 'hs900001');
  await expect(page).toHaveURL(/\/hoc$/);
  await page.goto(`/hoc/bai-tap/${ASSIGNMENT_ID}`);
  await expect(page.getByRole('heading', { name: 'Bài tập E2E nộp bài' })).toBeVisible();
}

test('HT-04: chọn quá số trang tối đa của cả bài thì bị chặn, không thêm ảnh nào', async ({
  page,
}) => {
  await stub(page, { maxPages: 2 });
  await openAssignment(page);
  await page.getByLabel('Chọn tệp bài làm').setInputFiles([png(1), png(2), png(3)]);
  await expect(page.getByText(/Mỗi bài nộp tối đa 2 trang\./)).toBeVisible();
  await expect(page.getByText(/trang đã chọn/)).toHaveCount(0);
});

test('HT-04: chọn ảnh, xem lại, nộp: tải lên MỘT lần rồi chốt MỘT lần với đủ mã tệp theo thứ tự', async ({
  page,
}) => {
  const calls = await stub(page, { maxPages: 20 });
  await openAssignment(page);
  await page.getByLabel('Chọn tệp bài làm').setInputFiles([png(1), png(2)]);
  await expect(page.getByText('2 trang đã chọn')).toBeVisible();
  await page.getByRole('button', { name: 'Xem lại trước khi nộp' }).click();
  await expect(page.getByText(/Xem lại · 2 trang/)).toBeVisible();
  await page.getByRole('button', { name: 'Nộp bài' }).click();
  await expect.poll(() => calls.submit).toBe(1);
  expect(calls.upload).toBe(1);
  expect(calls.submitIds).toEqual(['tep-1-0', 'tep-1-1']);
});

test('HT-04: chốt hỏng rồi «Thử lại» chỉ chốt lại, không tải ảnh lên lần hai', async ({ page }) => {
  const calls = await stub(page, { maxPages: 20, failFirstSubmit: true });
  await openAssignment(page);
  await page.getByLabel('Chọn tệp bài làm').setInputFiles([png(1), png(2)]);
  await page.getByRole('button', { name: 'Xem lại trước khi nộp' }).click();
  await page.getByRole('button', { name: 'Nộp bài' }).click();
  await expect(page.getByText('Đã quá hạn nộp bài này.')).toBeVisible();
  await page.getByRole('button', { name: 'Thử lại' }).click();
  await expect.poll(() => calls.submit).toBe(2);
  expect(calls.upload).toBe(1);
  expect(calls.submitIds).toEqual(['tep-1-0', 'tep-1-1']);
});
