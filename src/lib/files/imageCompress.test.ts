import { describe, expect, it } from 'vitest';
import { mimeOfBlob } from './imageCompress';

describe('mimeOfBlob', () => {
  it('luật Safari: canvas trả PNG thì ghi đúng image/png, không gắn nhãn WebP', () => {
    expect(mimeOfBlob(new Blob(['x'], { type: 'image/png' }))).toBe('image/png');
  });
  it('trình duyệt có WebP thì giữ image/webp; loại lạ hoặc rỗng quy về image/webp', () => {
    expect(mimeOfBlob(new Blob(['x'], { type: 'image/webp' }))).toBe('image/webp');
    expect(mimeOfBlob(new Blob(['x']))).toBe('image/webp');
  });
  it('JPEG giữ nguyên loại', () => {
    expect(mimeOfBlob(new Blob(['x'], { type: 'image/jpeg' }))).toBe('image/jpeg');
  });
});
