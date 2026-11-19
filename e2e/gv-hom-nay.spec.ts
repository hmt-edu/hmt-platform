// GV-02 Hôm nay (cổng giáo viên). Cả hai bài dùng dữ liệu giả do bài chặn lời gọi app.teacher_my_sessions (hàm của Code 2, bài pgTAP riêng) để kiểm
// cách hiện; không phụ thuộc buổi trong cơ sở dữ liệu (bài GV-05 dựng buổi hôm nay cho cùng tài khoản gv.cs5, nên "hôm nay trống" không thể dựa vào dữ liệu thật).
import { expect, test } from '@playwright/test';
import { PASSWORD, expectAccessible, loginStaff } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD.');

// Lời gọi sang địa chỉ Supabase là khác nguồn gốc: trả kèm tiêu đề CORS và trả lời luôn lời hỏi trước (OPTIONS).
const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
};

test('GV-02: hôm nay không có buổi dạy thì báo trống kèm buổi tiếp theo, có đường dẫn sang Lịch dạy', async ({
  page,
}) => {
  const next = {
    session_id: 'n',
    class_id: 'c',
    class_code: 'LNEXT',
    subject_name: 'Toán',
    session_no: 2,
    session_date: '2030-01-07',
    start_time: '19:30:00',
    end_time: '21:00:00',
    type_code: 'CHINH',
    status_code: 'DA_CHOT',
    my_role: 'GIAO_VIEN',
    has_content: false,
    deadline_at: '2030-01-08T05:00:00Z',
    pending_reason: null,
  };
  // Lời gọi đầu (hôm nay) trả rỗng; lời gọi thứ hai (tìm buổi tiếp theo, p_limit = 1) trả một buổi.
  await page.route('**/rest/v1/rpc/teacher_my_sessions*', (route) => {
    if (route.request().method() === 'OPTIONS')
      return route.fulfill({ status: 204, headers: cors });
    const body = route.request().postDataJSON() as { p_limit?: number } | null;
    const rows = body?.p_limit === 1 ? [next] : [];
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      headers: cors,
      body: JSON.stringify({ total: rows.length, rows }),
    });
  });
  await loginStaff(page, 'gv.cs5');
  await expect(page).toHaveURL(/\/gv$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Hôm nay' })).toBeVisible();
  await expect(page.getByText('Hôm nay bạn không có buổi dạy')).toBeVisible();
  await expect(page.getByText('Buổi tiếp theo: Thứ Hai 07/01 19:30.')).toBeVisible();
  await expect(page.getByRole('heading', { name: 'VIỆC SẮP TRỄ HẠN', exact: true })).toHaveCount(0);
  await expect(page.getByRole('link', { name: 'Xem lịch dạy' })).toBeVisible();
  await expectAccessible(page);
});

test('GV-02: có buổi: nhóm việc sắp trễ hạn và danh sách buổi hôm nay; buổi quá hạn không vào nhóm (R-V2-37)', async ({
  page,
}) => {
  // Ngày buổi đặt xa trong quá khứ để "đã kết thúc" đúng mọi giờ chạy; chỉ hạn (deadline_at) đặt theo giờ hiện tại.
  const base = {
    class_id: 'c',
    subject_name: 'Toán',
    session_date: '2020-01-01',
    type_code: 'CHINH',
    my_role: 'GIAO_VIEN',
    has_content: false,
    pending_reason: null,
  };
  const inHours = (h: number) => new Date(Date.now() + h * 3_600_000).toISOString();
  const rows = [
    {
      ...base,
      session_id: 'a',
      class_code: 'LDONE',
      session_no: 9,
      start_time: '08:00:00',
      end_time: '09:30:00',
      status_code: 'DONE',
      deadline_at: inHours(-2),
    },
    {
      ...base,
      session_id: 'b',
      class_code: 'LSAP',
      session_no: 6,
      start_time: '14:00:00',
      end_time: '15:30:00',
      status_code: 'DA_CHOT',
      deadline_at: inHours(1),
    },
    {
      ...base,
      session_id: 'c',
      class_code: 'LQUA',
      session_no: 3,
      start_time: '18:00:00',
      end_time: '19:30:00',
      status_code: 'DA_CHOT',
      deadline_at: inHours(-1),
    },
  ];
  await page.route('**/rest/v1/rpc/teacher_my_sessions*', (route) =>
    route.request().method() === 'OPTIONS'
      ? route.fulfill({ status: 204, headers: cors })
      : route.fulfill({
          status: 200,
          contentType: 'application/json',
          headers: cors,
          body: JSON.stringify({ total: rows.length, rows }),
        }),
  );
  await loginStaff(page, 'gv.cs5');
  await expect(page.getByText(/^(Thứ|Chủ Nhật) .*\d{2}\/\d{2}$/)).toBeVisible();
  const urgent = page.getByRole('region', { name: 'VIỆC SẮP TRỄ HẠN' });
  await expect(urgent.getByRole('listitem')).toHaveCount(1);
  await expect(urgent.getByText('Toán · LSAP · Buổi 6')).toBeVisible();
  await expect(urgent.getByText('Còn 1 giờ')).toBeVisible();
  const today = page.getByRole('region', { name: /BUỔI HÔM NAY/ });
  await expect(today.getByRole('listitem')).toHaveCount(3);
  await expect(today.getByText('Đã hoàn tất')).toBeVisible();
  await expect(today.getByText('Cần hoàn tất')).toHaveCount(2);
  // T2-23: thẻ buổi bấm được, mở trang các bước của buổi.
  await expect(today.getByRole('link', { name: /LSAP/ })).toHaveAttribute('href', '/gv/buoi/b');
  await expect(page.getByText(/quá hạn/i)).toHaveCount(0);
  await expectAccessible(page);
});
