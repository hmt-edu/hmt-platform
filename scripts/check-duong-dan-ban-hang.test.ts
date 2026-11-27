import { readFileSync, readdirSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { scanSource } from './check-duong-dan.mjs';

const FOLDERS = [
  'bao-gia',
  'don-hang',
  'phieu-thu',
  'phieu-chi',
  'tai-tuc',
  'thu-tien',
  'doi-soat',
  'so-du',
  'sap-het-gio',
];

describe('check:duong-dan, bán hàng, thu chi, tái tục (H1 PR3)', () => {
  it('mọi chỗ mở trang đều nối tiếp đường dẫn trang gốc', { timeout: 60_000 }, () => {
    const found = FOLDERS.flatMap((folder) =>
      readdirSync(`src/pages/${folder}`)
        .filter((name) => /\.tsx?$/.test(name) && !/\.test\./.test(name))
        .map((name) => `src/pages/${folder}/${name}`),
    ).flatMap((file) =>
      scanSource(readFileSync(file, 'utf8'), file).map((f) => `${file}:${f.line}`),
    );
    expect(found).toEqual([]);
  });
});
