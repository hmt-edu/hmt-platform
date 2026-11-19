// Bài tái hiện lỗi «e2e đỏ quanh nửa đêm giờ Việt Nam» (17:00–24:00 UTC): CI chạy giờ UTC, mà ứng dụng tính «hôm nay» theo giờ Việt Nam.
// Dữ liệu giả của bài e2e dựng bằng `current_date` (UTC) lệch một ngày với màn hình trong khung 00:00–07:00 giờ Việt Nam. Quy ước: mọi ngày trong e2e dùng
// `(now() at time zone 'Asia/Ho_Chi_Minh')::date`, không dùng `current_date`.
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const DIR = join(__dirname, '..', 'e2e');

describe('e2e: ngày giả theo giờ Việt Nam', () => {
  it('không bài e2e nào dùng current_date (UTC) trong câu SQL', () => {
    const bad: string[] = [];
    for (const name of readdirSync(DIR).filter((f) => f.endsWith('.ts'))) {
      const lines = readFileSync(join(DIR, name), 'utf8').split('\n');
      lines.forEach((line, i) => {
        const code = line.replace(/\/\/.*$/, '');
        if (/\bcurrent_date\b/i.test(code)) bad.push(`${name}:${i + 1}`);
      });
    }
    expect(bad).toEqual([]);
  });
});
