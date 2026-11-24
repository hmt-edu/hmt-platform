import { describe, expect, it } from 'vitest';
import { createDriveClient, DriveError, isRetryable, type FetchLike } from './drive-client.ts';

const CONFIG = { clientId: 'cid', clientSecret: 'secret', refreshToken: 'rt' };
const json = (body: unknown, status = 200, headers: Record<string, string> = {}) => new Response(JSON.stringify(body), { status, headers });

interface Call {
  url: string;
  init?: RequestInit;
}
/** Giả lập Drive: trả lần lượt các phản hồi cho lời gọi API; lời gọi lấy token luôn thành công. */
function fake(responses: Array<() => Response>) {
  const calls: Call[] = [];
  let i = 0;
  const f: FetchLike = (url, init) => {
    calls.push({ url, init });
    if (url.includes('oauth2.googleapis.com')) return Promise.resolve(json({ access_token: 'AT', expires_in: 3600 }));
    const next = responses[Math.min(i++, responses.length - 1)];
    return Promise.resolve(next!());
  };
  return { f, calls, api: () => calls.filter((c) => !c.url.includes('oauth2')) };
}
const noSleep = () => Promise.resolve();

describe('isRetryable', () => {
  it('thử lại với 429, 5xx và 403 quá tốc độ; không thử lại 403 khác, 404', () => {
    expect(isRetryable(429, undefined)).toBe(true);
    expect(isRetryable(503, undefined)).toBe(true);
    expect(isRetryable(403, 'userRateLimitExceeded')).toBe(true);
    expect(isRetryable(403, 'forbidden')).toBe(false);
    expect(isRetryable(404, undefined)).toBe(false);
  });
});

describe('createDriveClient', () => {
  it('tạo phiên tải tiếp được: gửi đúng tiêu đề, trả địa chỉ phiên, không để lộ khoá trong địa chỉ', async () => {
    const { f, api } = fake([() => new Response(null, { status: 200, headers: { Location: 'https://upload.example/session1' } })]);
    const c = createDriveClient(CONFIG, f, noSleep);
    const url = await c.startResumableUpload({ name: 'abc', mimeType: 'image/webp', size: 1234, parentId: 'F1', origin: 'https://app.test' });
    expect(url).toBe('https://upload.example/session1');
    const h = api()[0]!.init!.headers as Record<string, string>;
    expect(h['X-Upload-Content-Length']).toBe('1234');
    expect(h['Origin']).toBe('https://app.test');
    expect(h['Authorization']).toBe('Bearer AT');
    expect(JSON.parse(String(api()[0]!.init!.body))).toEqual({ name: 'abc', parents: ['F1'] });
  });

  it('dùng lại token đến gần hết hạn, đổi token mới khi sắp hết hạn', async () => {
    let t = 0;
    const { f, calls } = fake([() => json({ id: 'x', size: '5', mimeType: 'image/webp' })]);
    const c = createDriveClient(CONFIG, f, noSleep, () => t);
    await c.getFileInfo('x');
    await c.getFileInfo('x');
    expect(calls.filter((x) => x.url.includes('oauth2')).length).toBe(1);
    t = 3_600_000;
    await c.getFileInfo('x');
    expect(calls.filter((x) => x.url.includes('oauth2')).length).toBe(2);
  });

  it('refresh token bị thu hồi (invalid_grant): báo cần cấp quyền lại', async () => {
    const f: FetchLike = () => Promise.resolve(json({ error: 'invalid_grant' }, 400));
    const c = createDriveClient(CONFIG, f, noSleep);
    await expect(c.getFileInfo('x')).rejects.toMatchObject({ code: 'HMT_DRIVE_HET_QUYEN' });
  });

  it('thử lại 429 rồi thành công; hết 3 lần thì báo lỗi tiếng Việt', async () => {
    const ok = fake([() => json({}, 429), () => json({}, 503), () => json({ id: 'x', size: '9', mimeType: 'm' })]);
    expect((await createDriveClient(CONFIG, ok.f, noSleep).getFileInfo('x')).size).toBe(9);
    expect(ok.api().length).toBe(3);
    const bad = fake([() => json({}, 500)]);
    await expect(createDriveClient(CONFIG, bad.f, noSleep).getFileInfo('x')).rejects.toMatchObject({ code: 'HMT_DRIVE_LOI', message: 'Tải lên chưa được, thử lại sau.' });
    expect(bad.api().length).toBe(3);
  });

  it('hết dung lượng Drive: báo ngay, không thử lại', async () => {
    const r = fake([() => json({ error: { errors: [{ reason: 'storageQuotaExceeded' }] } }, 403)]);
    await expect(createDriveClient(CONFIG, r.f, noSleep).startResumableUpload({ name: 'a', mimeType: 'image/webp', size: 1, parentId: 'F' })).rejects.toMatchObject({ code: 'HMT_DRIVE_DAY' });
    expect(r.api().length).toBe(1);
  });

  it('xoá vĩnh viễn gọi DELETE; tệp đã mất (404) coi như xong', async () => {
    const r = fake([() => new Response(null, { status: 204 })]);
    await createDriveClient(CONFIG, r.f, noSleep).deletePermanently('abc');
    expect(r.api()[0]!.init!.method).toBe('DELETE');
    const gone = fake([() => json({}, 404)]);
    await expect(createDriveClient(CONFIG, gone.f, noSleep).deletePermanently('abc')).resolves.toBeUndefined();
  });

  it('đọc dung lượng còn lại và tạo thư mục', async () => {
    const r = fake([() => json({ storageQuota: { usage: '100', limit: '1000' } }), () => json({ id: 'NEW' })]);
    const c = createDriveClient(CONFIG, r.f, noSleep);
    expect(await c.getStorageQuota()).toEqual({ usage: 100, limit: 1000 });
    expect(await c.createFolder('CS1', 'ROOT')).toBe('NEW');
  });

  it('DriveError mang mã để Edge Function trả cho giao diện', () => {
    expect(new DriveError('HMT_DRIVE_LOI', 'x', 500).code).toBe('HMT_DRIVE_LOI');
  });
});
