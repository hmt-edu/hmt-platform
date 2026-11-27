import { readFileSync, readdirSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { scanSource } from './check-duong-dan.mjs';

const FOLDERS = [
  'khach-hang',
  'lop',
  'buoi',
  'diem-danh-ngay',
  'ghi-danh',
  'yeu-cau-buoi',
  'ticket',
  'phieu-den',
  'khung-chuong-trinh',
  'goi-ban',
  'nguoi-dung',
  'vai-tro',
];
// Thư mục `phieu` còn có Phiếu Test (thuộc Tuyển sinh, H1 PR2) nên ở đây chỉ kê các tệp phiếu nghiệp vụ.
const TASK_FILES = ['TaskListPage.tsx', 'TaskRecordPage.tsx', 'phieuConfig.tsx'];

describe('check:duong-dan, khách hàng, đào tạo, chăm sóc, quản trị (H1 PR4)', () => {
  it('mọi chỗ mở trang đều nối tiếp đường dẫn trang gốc', { timeout: 60_000 }, () => {
    const files = [
      ...FOLDERS.flatMap((folder) =>
        readdirSync(`src/pages/${folder}`)
          .filter((name) => /\.tsx?$/.test(name) && !/\.test\./.test(name))
          .map((name) => `src/pages/${folder}/${name}`),
      ),
      ...TASK_FILES.map((name) => `src/pages/phieu/${name}`),
    ];
    const found = files.flatMap((file) =>
      scanSource(readFileSync(file, 'utf8'), file).map((f) => `${file}:${f.line}`),
    );
    expect(found).toEqual([]);
  });
});
