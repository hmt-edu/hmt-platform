import { describe, expect, it } from 'vitest';
import { encodePath, presignUrl, uriEncode } from './r2-presign.ts';

// Ví dụ chuẩn trong tài liệu AWS «Authenticating Requests: Using Query Parameters (AWS Signature Version 4)» (khoá ví dụ công khai, không phải khoá thật).
const AWS_EXAMPLE = {
  method: 'GET' as const,
  host: 'examplebucket.s3.amazonaws.com',
  path: '/test.txt',
  accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
  secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  region: 'us-east-1',
  expiresSeconds: 86400,
  now: new Date('2013-05-24T00:00:00Z'),
};

describe('presignUrl', () => {
  it('khớp chữ ký mẫu của AWS (SigV4 đúng)', async () => {
    const url = await presignUrl(AWS_EXAMPLE);
    expect(url).toContain('X-Amz-Signature=aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404');
  });
  it('địa chỉ có hạn, ký đúng tiêu đề host và thuật toán', async () => {
    const url = new URL(await presignUrl(AWS_EXAMPLE));
    expect(url.searchParams.get('X-Amz-Expires')).toBe('86400');
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toBe('host');
    expect(url.searchParams.get('X-Amz-Algorithm')).toBe('AWS4-HMAC-SHA256');
    expect(url.searchParams.get('X-Amz-Credential')).toBe('AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request');
  });
  it('đổi phương thức, đường dẫn hoặc thời điểm thì chữ ký đổi', async () => {
    const base = await presignUrl(AWS_EXAMPLE);
    expect(await presignUrl({ ...AWS_EXAMPLE, method: 'PUT' })).not.toBe(base);
    expect(await presignUrl({ ...AWS_EXAMPLE, path: '/khac.txt' })).not.toBe(base);
    expect(await presignUrl({ ...AWS_EXAMPLE, now: new Date('2013-05-24T00:00:01Z') })).not.toBe(base);
  });
  it('không để lộ khoá bí mật trong địa chỉ', async () => {
    expect(await presignUrl(AWS_EXAMPLE)).not.toContain('wJalrXUtnFEMI');
  });
});

describe('mã hoá đường dẫn', () => {
  it('giữ dấu / giữa các đoạn, mã hoá ký tự đặc biệt', () => {
    expect(encodePath('/a b/c+d/é')).toBe('/a%20b/c%2Bd/%C3%A9');
    expect(uriEncode("!'()*")).toBe('%21%27%28%29%2A');
  });
});
