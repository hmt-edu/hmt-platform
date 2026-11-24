// Kiểm mã Apps Script kho tệp (F-23-53) bằng Drive giả: mật khẩu, ràng buộc thư mục gốc, tên, xoá vĩnh viễn.
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { describe, expect, it, vi } from 'vitest';

interface Reply {
  ok?: boolean;
  code?: string;
  dataBase64?: string;
  [k: string]: unknown;
}
type Node = { id: string; parents: Node[]; name: string };
function setup(secret = 'S3CRET-OK', quota = { used: 5, limit: 10 * 1024 ** 3 }) {
  const root: Node = { id: 'ROOT', parents: [], name: 'HMT' };
  const other: Node = { id: 'OTHER', parents: [], name: 'SAOLUU' };
  const inside: Node = { id: 'IN1', parents: [root], name: 'a' };
  const outside: Node = { id: 'OUT1', parents: [other], name: 'b' };
  const all = new Map([root, other, inside, outside].map((n) => [n.id, n]));
  const removed: string[] = [];
  const wrap = (n: Node): Record<string, unknown> => ({
    getId: () => n.id,
    getParents: () => {
      let i = 0;
      return { hasNext: () => i < n.parents.length, next: () => wrap(n.parents[i++] as Node) };
    },
    getBlob: () => ({ getContentType: () => 'image/webp', getBytes: () => [1, 2] }),
    getSize: () => 2,
    getName: () => n.name,
    getFoldersByName: () => ({ hasNext: () => false }),
    createFolder: (name: string) => {
      const c: Node = { id: `F-${name}`, parents: [n], name };
      all.set(c.id, c);
      return wrap(c);
    },
    createFile: () => {
      const c: Node = { id: 'NEWFILE', parents: [n], name: 'x' };
      all.set(c.id, c);
      return wrap(c);
    },
  });
  const ctx = {
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (k: string) => ({ SECRET: secret, ROOT_FOLDER_ID: 'ROOT' })[k],
      }),
    },
    DriveApp: {
      getFolderById: (id: string) => wrap(all.get(id)!),
      getFileById: (id: string) => {
        const n = all.get(id);
        if (!n) throw new Error('khong co');
        return wrap(n);
      },
      getStorageUsed: () => quota.used,
      getStorageLimit: () => quota.limit,
    },
    Drive: { Files: { remove: vi.fn((id: string) => removed.push(id)) } },
    Utilities: { newBlob: () => ({}), base64Decode: () => [], base64Encode: () => 'AQI=' },
    ContentService: {
      MimeType: { JSON: 'json' },
      createTextOutput: (t: string) => ({
        t,
        setMimeType() {
          return this;
        },
      }),
    },
    JSON,
  };
  runInNewContext(readFileSync('scripts/apps-script-kho-tep/Code.gs', 'utf8'), ctx);
  const call = (body: object): Reply => {
    const doPost = (ctx as unknown as { doPost: (e: unknown) => { t: string } }).doPost;
    return JSON.parse(doPost({ postData: { contents: JSON.stringify(body) } }).t) as Reply;
  };
  return { call, removed };
}

describe('Apps Script kho tệp', () => {
  it('luật mật khẩu: sai hoặc thiếu mật khẩu thì từ chối mọi việc', () => {
    const { call } = setup();
    expect(call({ action: 'ping', secret: 'sai' }).code).toBe('SAI_MAT_KHAU');
    expect(call({ action: 'ping' }).code).toBe('SAI_MAT_KHAU');
    expect(call({ action: 'ping', secret: 'S3CRET-OK' }).ok).toBe(true);
  });
  it('luật thư mục gốc: đọc và xoá tệp ngoài thư mục gốc đều không chạm gì', () => {
    const { call, removed } = setup();
    const s = 'S3CRET-OK';
    expect(call({ action: 'read', secret: s, id: 'OUT1' }).code).toBe('KHONG_THAY');
    expect(call({ action: 'remove', secret: s, id: 'OUT1' })).toEqual({ ok: true, removed: false });
    expect(removed).toEqual([]);
    expect(call({ action: 'read', secret: s, id: 'IN1' }).dataBase64).toBe('AQI=');
  });
  it('luật xoá vĩnh viễn: tệp trong kho bị xoá bằng Drive.Files.remove', () => {
    const { call, removed } = setup();
    expect(call({ action: 'remove', secret: 'S3CRET-OK', id: 'IN1' })).toEqual({
      ok: true,
      removed: true,
    });
    expect(removed).toEqual(['IN1']);
  });
  it('luật tên: tên tệp hoặc thư mục con lạ (dấu cách, ../, tên có dấu) bị chặn; tên hợp lệ lưu được', () => {
    const { call } = setup();
    const base = {
      action: 'save',
      secret: 'S3CRET-OK',
      mimeType: 'image/webp',
      dataBase64: 'AQI=',
    };
    expect(call({ ...base, name: '../x', path: [] }).code).toBe('TEN_SAI');
    expect(call({ ...base, name: 'a.webp', path: ['Nguyễn Văn A'] }).code).toBe('TEN_SAI');
    expect(call({ ...base, name: 'a.webp', path: ['..'] }).ok).toBe(false);
    expect(call({ ...base, name: 'u1.webp', path: ['LOP-01', '2026-11'] })).toMatchObject({
      ok: true,
      id: 'NEWFILE',
    });
  });
  it('dung lượng: trả đã dùng và hạn mức của tài khoản', () => {
    expect(setup().call({ action: 'quota', secret: 'S3CRET-OK' })).toEqual({
      ok: true,
      usage: 5,
      limit: 10 * 1024 ** 3,
    });
  });
  it('luật trần cỡ: tệp lớn hơn trần bị từ chối trước khi giải mã', () => {
    const { call } = setup();
    const r = call({
      action: 'save',
      secret: 'S3CRET-OK',
      name: 'a.pdf',
      path: [],
      mimeType: 'application/pdf',
      dataBase64: 'A'.repeat(30 * 1024 * 1024),
    });
    expect(r.code).toBe('QUA_LON');
  });
  it('luật chừa dung lượng: còn dưới 1 GB trống thì từ chối lưu, đủ thì lưu', () => {
    const base = {
      action: 'save',
      secret: 'S3CRET-OK',
      name: 'a.webp',
      path: [],
      mimeType: 'image/webp',
      dataBase64: 'AQI=',
    };
    const gb = 1024 ** 3;
    expect(setup('S3CRET-OK', { used: 15 * gb - gb / 2, limit: 15 * gb }).call(base).code).toBe(
      'HET_CHO',
    );
    expect(setup('S3CRET-OK', { used: 5 * gb, limit: 15 * gb }).call(base).ok).toBe(true);
  });
});
