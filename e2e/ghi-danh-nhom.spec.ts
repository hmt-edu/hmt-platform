// GD-03 xếp lớp THEO NHÓM LỚP (nợ của cụm Ghi danh, Chat 10/11): một học sinh có hai ghi danh Chờ xếp lớp (Đại, Hình); nhóm lớp có một lớp Đại và một lớp Hình.
// Chọn nhóm thì ghi danh Đại vào lớp Đại, ghi danh Hình vào lớp Hình, cả hai trong một lần. Máy tính (màn Đào tạo ưu tiên máy tính).
import { expect, test } from '@playwright/test';
import { PASSWORD, enterAs, showAllColumns } from './helpers';
import { DB_URL } from './bao-gia-seed';
import { seedGroup, type GroupSeed } from './ghi-danh-nhom-seed';

test.skip(!PASSWORD || !DB_URL, 'Cần SEED_PASSWORD và DB_URL (dựng ghi danh giả).');
// eslint-disable-next-line no-empty-pattern
test.beforeEach(({}, testInfo) => {
  test.skip(testInfo.project.name === 'dien-thoai', 'Màn Đào tạo chỉ có bản máy tính.');
});

let seed: GroupSeed;
// eslint-disable-next-line no-empty-pattern
test.beforeAll(async ({}, testInfo) => {
  seed = await seedGroup(testInfo.project.name);
});

test('GD-03: theo nhóm lớp xếp cả hai ghi danh vào đúng lớp của từng môn trong một lần', async ({
  page,
}) => {
  await enterAs(page, 'cskh.cs5');
  await page.goto('/crm/cho-xep-lop');
  await page.getByRole('searchbox').fill(seed.tag);
  const queue = page.getByRole('table', { name: 'Ghi danh' });
  await expect(queue.getByRole('link', { name: seed.daiEnrollment })).toBeVisible();
  await expect(queue.getByRole('link', { name: seed.hinhEnrollment })).toBeVisible();
  await queue
    .getByRole('row', { name: new RegExp(seed.daiEnrollment) })
    .getByRole('button', { name: 'Xếp lớp' })
    .click();
  const dialog = page.getByRole('dialog', { name: 'Xếp lớp cho ghi danh' });
  // Có nhóm lớp phù hợp thì mở sẵn chế độ "Theo nhóm lớp" và chọn sẵn nhóm.
  await expect(dialog.getByRole('radio', { name: 'Theo nhóm lớp' })).toBeChecked();
  await expect(dialog.getByRole('radio', { name: new RegExp(seed.groupName) })).toBeChecked();
  // Bảng "Xếp vào": mỗi ghi danh một lớp đúng môn.
  const pairs = dialog.getByRole('table', { name: 'Xếp vào' });
  await expect(pairs.getByRole('row', { name: new RegExp(seed.daiEnrollment) })).toContainText(
    seed.daiClass,
  );
  await expect(pairs.getByRole('row', { name: new RegExp(seed.hinhEnrollment) })).toContainText(
    seed.hinhClass,
  );
  await dialog.getByRole('button', { name: 'Xếp lớp', exact: true }).click();
  await expect(page.getByText('Đã xếp lớp cho 2 ghi danh.', { exact: true })).toBeVisible();
  // Cả hai rời bộ lọc Chờ xếp lớp.
  await expect(queue.getByRole('link', { name: seed.daiEnrollment })).toHaveCount(0);
  await expect(queue.getByRole('link', { name: seed.hinhEnrollment })).toHaveCount(0);
  // Danh sách ghi danh: cả hai Đã xếp lớp, mỗi ghi danh đúng lớp của mình.
  await page.goto('/crm/ghi-danh');
  await page.getByRole('searchbox').fill(seed.student);
  await showAllColumns(page);
  const list = page.getByRole('table', { name: 'Ghi danh' });
  const dai = list.getByRole('row', { name: new RegExp(seed.daiEnrollment) });
  const hinh = list.getByRole('row', { name: new RegExp(seed.hinhEnrollment) });
  await expect(dai).toContainText('Đã xếp lớp');
  await expect(dai).toContainText(seed.daiClass);
  await expect(hinh).toContainText('Đã xếp lớp');
  await expect(hinh).toContainText(seed.hinhClass);
});
