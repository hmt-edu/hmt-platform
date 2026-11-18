// PR 4b: khuôn Chi tiết (K3) trên /dev/chi-tiet và thư viện hộp thoại trên /dev/hop-thoai (dữ liệu giả).
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, expectAccessible, isPhone } from './helpers';

test.skip(!PASSWORD, 'Cần SEED_PASSWORD (tài khoản giả).');

test.beforeEach(async ({ page }) => {
  await enterAs(page, 'sale.cs5');
  await expect(page).toHaveURL(/\/crm$/);
});

test.describe('K3 Chi tiết', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dev/chi-tiet');
    await expect(page.getByRole('button', { name: 'Sửa' })).toBeVisible();
  });

  test('xem → Sửa → Huỷ; trang đạt kiểm truy cập', async ({ page }) => {
    await expectAccessible(page);
    await page.getByRole('button', { name: 'Sửa' }).click();
    await expect(page.getByRole('button', { name: 'Lưu' })).toBeVisible();
    await page.getByRole('button', { name: 'Huỷ', exact: true }).click();
    await expect(page.getByRole('button', { name: 'Sửa' })).toBeVisible();
  });

  test('Tạo mở thẳng khuôn trống; thiếu trường bắt buộc thì Lưu báo lỗi tại chỗ', async ({
    page,
  }) => {
    await page.getByRole('button', { name: 'Tạo', exact: true }).click();
    await expect(page.getByRole('heading', { name: 'Cơ hội mới' })).toBeVisible();
    await page.getByRole('button', { name: 'Lưu' }).click();
    await expect(page.getByText(/bắt buộc|chưa/i).first()).toBeVisible();
  });

  test('SĐT trùng: bấm Lưu hiện hộp cảnh báo trùng, đóng bằng X quay lại biểu mẫu', async ({
    page,
  }) => {
    await page.getByRole('button', { name: 'Tạo', exact: true }).click();
    await page.getByLabel('Họ tên').fill('Nguyễn Văn A');
    await page.getByLabel('Số điện thoại').fill('0912345678');
    await page.getByRole('button', { name: 'Lưu' }).click();
    const dialog = page.getByRole('dialog');
    await expect(dialog.getByText('Số điện thoại này đã có hồ sơ').first()).toBeVisible();
    await expect(dialog.getByRole('button', { name: 'Vẫn tạo mới' })).toBeVisible();
    await expect(dialog.getByRole('button', { name: 'Gắn vào hồ sơ có sẵn' })).toBeVisible();
    await dialog.getByRole('button', { name: 'Đóng' }).click();
    await expect(dialog).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Lưu' })).toBeVisible();
  });

  test('smart button nhiều bản ghi mở danh sách lọc theo cha, có chip và đường dẫn', async ({
    page,
  }) => {
    await page.getByRole('button', { name: /^Lịch hẹn 2/ }).click();
    await expect(page).toHaveURL(/\/dev\/danh-sach\?cha=CO000121/);
    const crumb = page.getByRole('navigation', { name: 'Đường dẫn' }).last();
    await expect(crumb).toContainText('Cơ hội');
    await expect(crumb.getByRole('button', { name: 'CO000121' })).toBeVisible();
    await expect(crumb).toContainText('Lịch hẹn');
    // Danh sách con hiện lịch hẹn của cơ hội cha (không phải danh sách Cơ hội).
    await expect(page.getByText('LH000301').first()).toBeVisible();
    await expect(page.getByText('LH000288').first()).toBeVisible();
    await expect(page.getByText('CO000133')).toHaveCount(0);
  });

  test('chuyển lên L5: sub-stage là của L5 (không còn của L4); sang L7 thì không có sub-stage', async ({
    page,
  }) => {
    await page.getByRole('button', { name: /^L5 / }).click();
    const dialog = page.getByRole('dialog');
    await dialog.getByRole('combobox').click();
    await expect(page.getByRole('option', { name: /^L5A/ })).toBeVisible();
    await expect(page.getByRole('option', { name: /^L4A/ })).toHaveCount(0);
    await page.getByRole('option', { name: /^L5B/ }).click();
    await dialog.getByRole('button', { name: 'Chuyển', exact: true }).click();
    await expect(page.getByRole('combobox', { name: 'Sub-stage' })).toContainText('L5B');
    await page.getByRole('button', { name: /^L7 / }).click();
    await expect(page.getByRole('combobox', { name: 'Sub-stage' })).toHaveCount(0);
  });

  test('L8: hộp hỏi thêm bắt buộc chọn nhóm con và xác nhận thanh toán; không có Hoàn tác; mở Tạo đơn hàng', async ({
    page,
  }) => {
    const create = page.getByRole('button', { name: 'Tạo đơn hàng' });
    await expect(create).toBeDisabled();
    await expect(page.getByRole('button', { name: 'Tạo báo giá' })).toBeEnabled();
    await page.getByRole('button', { name: /^L8 / }).click();
    const dialog = page.getByRole('dialog');
    const move = dialog.getByRole('button', { name: 'Chuyển', exact: true });
    await expect(move).toBeDisabled();
    await dialog.getByRole('combobox').click();
    await expect(page.getByRole('option', { name: /^L8A PH đặt cọc/ })).toBeVisible();
    await expect(page.getByRole('option', { name: /^L8C/ })).toBeVisible();
    await page.getByRole('option', { name: /^L8A/ }).click();
    await expect(move).toBeDisabled(); // còn thiếu xác nhận thanh toán
    await dialog.getByLabel('Phụ huynh đã thanh toán?').check();
    await move.click();
    await expect(page.getByRole('combobox', { name: 'Sub-stage' })).toContainText('L8A');
    await expect(page.getByRole('button', { name: 'Hoàn tác' })).toHaveCount(0);
    await expect(create).toBeEnabled();
  });

  test('thiếu tên/năm sinh học sinh: bấm L5, L7 hay L8 đều hiện hộp chặn (R-CRM-03)', async ({
    page,
  }) => {
    await page.getByRole('button', { name: 'Sửa' }).click();
    await page.getByLabel('Tên học sinh').fill('');
    await page.getByRole('button', { name: 'Lưu' }).click();
    await expect(page.getByRole('button', { name: 'Sửa' })).toBeVisible();
    for (const code of ['L5', 'L7', 'L8']) {
      await page.getByRole('button', { name: new RegExp(`^${code} `) }).click();
      const dialog = page.getByRole('dialog').or(page.getByRole('alertdialog'));
      await expect(dialog.getByText(`Chưa chuyển sang ${code} được`).first()).toBeVisible();
      await expect(dialog.getByText('Thiếu tên học sinh').first()).toBeVisible();
      // Đóng bằng nút (Playwright chờ nút bấm được). Esc có bài riêng ở "Thư viện hộp thoại". Nghi ngờ, CHƯA xác nhận (28/10): bấm Esc trong khoảng
      // 10 ms đầu sau khi hộp gắn vào trang thì hộp không đóng, có thể do Radix chưa ghi nhận lớp hộp; hai lần thử chờ điều kiện (tiêu điểm vào hộp,
      // thân trang chặn chuột) vẫn trượt nên không coi là đã hiểu nguyên nhân.
      await dialog.getByRole('button', { name: 'Đã hiểu' }).click();
      await expect(dialog).toHaveCount(0);
    }
  });

  test('chuyển giai đoạn đổi ngay có Hoàn tác; bước hệ thống tự đổi bị khoá', async ({ page }) => {
    await page.getByRole('button', { name: /L7/ }).click();
    await expect(page.getByRole('button', { name: 'Hoàn tác' })).toBeVisible();
    await page.getByRole('button', { name: 'Hoàn tác' }).click();
    // Bước khoá là aria-disabled nên Playwright không tự bấm; ép bấm như người dùng thật.
    await page.getByRole('button', { name: /L6/ }).click({ force: true });
    await expect(
      page.getByText('Hệ thống tự chuyển khi phiếu kiểm tra Hoàn thành.').first(),
    ).toBeVisible();
  });
});

test.describe('Thư viện hộp thoại', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/dev/hop-thoai');
    await expect(
      page.getByRole('heading', { level: 1, name: 'Trang mẫu hộp thoại' }),
    ).toBeVisible();
  });

  for (const [button, title] of [
    ['① Xác nhận đơn giản', null],
    ['② Bắt buộc lý do', null],
    ['④ Chặn', null],
    ['Chọn từ danh sách có kiểm tra', 'Chọn lớp và ngày vào lớp'],
    ['Cảnh báo trùng SĐT', 'Số điện thoại này đã có hồ sơ'],
  ] as const) {
    test(`mở "${button}": đạt kiểm truy cập, Esc đóng`, async ({ page }) => {
      await page.getByRole('button', { name: button }).click();
      const dialog = page.getByRole('dialog').or(page.getByRole('alertdialog'));
      await expect(dialog).toBeVisible();
      if (title) await expect(dialog.getByText(title).first()).toBeVisible();
      await expectAccessible(page);
      await page.keyboard.press('Escape');
      await expect(dialog).toHaveCount(0);
    });
  }

  test('hộp "Bắt buộc lý do": nút xác nhận mờ cho tới khi chọn lý do', async ({ page }) => {
    await page.getByRole('button', { name: '② Bắt buộc lý do' }).click();
    await expect(page.getByRole('button', { name: /^Xác nhận huỷ/ })).toBeDisabled();
  });

  test('điện thoại: hộp thoại thành tấm trượt sát đáy', async ({ page }) => {
    test.skip(!isPhone(page), 'Chỉ kiểm trên cỡ điện thoại.');
    await page.getByRole('button', { name: '② Bắt buộc lý do' }).click();
    const box = await page.getByRole('alertdialog').or(page.getByRole('dialog')).boundingBox();
    const height = page.viewportSize()?.height ?? 0;
    expect(box).not.toBeNull();
    expect(Math.abs((box?.y ?? 0) + (box?.height ?? 0) - height)).toBeLessThan(2);
  });
});
