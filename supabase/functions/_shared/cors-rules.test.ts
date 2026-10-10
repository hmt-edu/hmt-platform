import { describe, expect, it } from 'vitest';
import { isOriginAllowed } from './cors-rules.ts';

const preview = 'https://pr-7.hmt-staging.pages.dev';

describe('CORS theo môi trường (L4)', () => {
  it('bản chạy thật (không bật cờ xem trước): KHÔNG nhận trang xem trước của thử nghiệm', () => {
    expect(isOriginAllowed(preview, { allowedOrigins: ['https://app.hoamatoan.edu.vn'], allowStagingPreviews: false })).toBe(false);
  });
  it('bản chạy thật: nhận đúng tên miền khai báo', () => {
    expect(isOriginAllowed('https://app.hoamatoan.edu.vn', { allowedOrigins: ['https://app.hoamatoan.edu.vn'], allowStagingPreviews: false })).toBe(true);
  });
  it('thử nghiệm (bật cờ): nhận trang xem trước của từng PR', () => {
    expect(isOriginAllowed(preview, { allowedOrigins: [], allowStagingPreviews: true })).toBe(true);
  });
  it('không nhận tên miền giả dạng', () => {
    const config = { allowedOrigins: [], allowStagingPreviews: true };
    expect(isOriginAllowed('https://x.hmt-staging.pages.dev.evil.com', config)).toBe(false);
    expect(isOriginAllowed('https://evil.com', config)).toBe(false);
  });
});
