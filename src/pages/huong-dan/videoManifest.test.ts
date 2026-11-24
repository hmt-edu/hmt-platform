import { describe, expect, it } from 'vitest';
import { parseVideoManifest, safeVideoUrl } from './videoManifest';

describe('Manifest video hướng dẫn (A-23-41b)', () => {
  it('đổi ID Drive thành địa chỉ xem trước; url thành tệp trực tiếp', () => {
    const m = parseVideoManifest({
      videos: {
        a: { drive: '1AbCdEfGhIjKlMn' },
        b: { url: 'https://cdn.example.com/b.mp4' },
        c: { url: '/huong-dan/video/c.mp4' },
      },
    });
    expect(m.a).toEqual({
      kind: 'drive',
      src: 'https://drive.google.com/file/d/1AbCdEfGhIjKlMn/preview',
    });
    expect(m.b).toEqual({ kind: 'file', src: 'https://cdn.example.com/b.mp4' });
    expect(m.c).toEqual({ kind: 'file', src: '/huong-dan/video/c.mp4' });
  });
  it('bỏ dòng hỏng, ID lạ và địa chỉ nguy hiểm; JSON sai dạng thì rỗng', () => {
    const m = parseVideoManifest({
      videos: {
        x: { drive: 'ngan' },
        y: { drive: '../../evil" onload="x' },
        z: { url: 'javascript:alert(1)' },
        w: { url: '//evil.example.com/a.mp4' },
        v: 'chuoi',
        u: null,
      },
    });
    expect(m).toEqual({});
    expect(parseVideoManifest(null)).toEqual({});
    expect(parseVideoManifest({ videos: 5 })).toEqual({});
    expect(parseVideoManifest('x')).toEqual({});
  });
  it('safeVideoUrl chỉ nhận «/…» và https', () => {
    expect(safeVideoUrl('http://a.com/x.mp4')).toBeNull();
    expect(safeVideoUrl('data:video/mp4;base64,AAA')).toBeNull();
    expect(safeVideoUrl(5)).toBeNull();
    expect(safeVideoUrl('/a.mp4')).toBe('/a.mp4');
  });
});
