import { describe, expect, it, vi } from 'vitest';
import { base64ToBytes, bytesToBase64, createAppsScriptClient, StoreError, type FetchLike } from './apps-script-client';

const CFG = { url: 'https://script.example/exec', secret: 'MAT-KHAU' };
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });
const noSleep = async () => undefined;
const sent = (f: ReturnType<typeof vi.fn>, i = 0) => JSON.parse((f.mock.calls[i] as [string, RequestInit])[1].body as string) as Record<string, unknown>;

describe('lớp gọi Apps Script', () => {
  it('mọi lời gọi gửi POST kèm mật khẩu dùng chung, theo chuyển hướng', async () => {
    const f = vi.fn(async () => reply({ ok: true, usage: 5, limit: 10 }));
    const c = createAppsScriptClient(CFG, f as FetchLike, noSleep);
    expect(await c.getStorageQuota()).toEqual({ usage: 5, limit: 10 });
    const init = (f.mock.calls[0] as [string, RequestInit])[1];
    expect(init.method).toBe('POST');
    expect(init.redirect).toBe('follow');
    expect(sent(f)).toMatchObject({ action: 'quota', secret: 'MAT-KHAU' });
  });
  it('luật mật khẩu: script từ chối sai mật khẩu thì ném lỗi cấu hình, không lộ chi tiết', async () => {
    const f = vi.fn(async () => reply({ ok: false, code: 'SAI_MAT_KHAU', message: 'Sai mật khẩu.' }));
    const c = createAppsScriptClient({ ...CFG, secret: 'sai' }, f as FetchLike, noSleep);
    const e = await c.ping().catch((x: StoreError) => x);
    expect((e as StoreError).code).toBe('HMT_KHO_TEP_CAU_HINH');
    expect((e as StoreError).message).not.toContain('sai');
  });
  it('save gửi base64 và trả id; read giải base64; remove báo đã xoá', async () => {
    const f = vi.fn(async (_u: string, init?: RequestInit) => {
      const a = (JSON.parse(init!.body as string) as { action: string }).action;
      if (a === 'save') return reply({ ok: true, id: 'D1' });
      if (a === 'read') return reply({ ok: true, mimeType: 'image/webp', dataBase64: bytesToBase64(new Uint8Array([1, 2, 3])) });
      return reply({ ok: true, removed: true });
    });
    const c = createAppsScriptClient(CFG, f as FetchLike, noSleep);
    expect(await c.save({ path: ['c', '2026-11'], name: 'a.webp', mimeType: 'image/webp', bytes: new Uint8Array([9]) })).toBe('D1');
    expect(sent(f as never)).toMatchObject({ action: 'save', path: ['c', '2026-11'], name: 'a.webp', dataBase64: 'CQ==' });
    expect(Array.from((await c.read('D1')).bytes)).toEqual([1, 2, 3]);
    expect(await c.remove('D1')).toBe(true);
  });
  it('lỗi mạng và 5xx thì thử lại tối đa 3 lần; hết lần thì báo lỗi kho tệp', async () => {
    const f = vi.fn(async () => { throw new Error('mạng'); });
    const c = createAppsScriptClient(CFG, f as FetchLike, noSleep);
    expect(await c.ping().catch((x: StoreError) => x.code)).toBe('HMT_KHO_TEP_LOI');
    expect(f).toHaveBeenCalledTimes(3);
    let n = 0;
    const g = vi.fn(async () => (++n < 3 ? reply({}, 503) : reply({ ok: true, rootName: 'HMT' })));
    expect(await createAppsScriptClient(CFG, g as FetchLike, noSleep).ping()).toBe('HMT');
  });
  it('phản hồi không phải JSON (trang lỗi của Google) thì báo lỗi, không đổ nội dung ra', async () => {
    const f = vi.fn(async () => new Response('<html>lỗi</html>', { status: 200 }));
    expect(await createAppsScriptClient(CFG, f as FetchLike, noSleep).ping().catch((x: StoreError) => x.code)).toBe('HMT_KHO_TEP_LOI');
  });
  it('base64 hai chiều giữ nguyên byte', () => {
    const b = new Uint8Array(70000).map((_, i) => i % 251);
    expect(base64ToBytes(bytesToBase64(b))).toEqual(b);
  });
});
