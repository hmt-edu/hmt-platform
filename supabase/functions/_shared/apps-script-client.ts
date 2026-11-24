// Lớp gọi kho tệp Google Drive qua Google Apps Script web app (F-23-55; thiết kế docs/ke-hoach/kho-tep-apps-script.md, mã script scripts/apps-script-kho-tep/Code.gs).
// Thay lớp OAuth (drive-client). Mọi lời gọi mạng đi qua `fetch` truyền vào để thay bằng giả lập khi kiểm thử.
// Địa chỉ và mật khẩu dùng chung chỉ đến từ secret của Edge Function (APPS_SCRIPT_URL, APPS_SCRIPT_SHARED_SECRET), không bao giờ vào log hay phản hồi cho giao diện.
// Script chỉ có các việc: ping, quota, save, read, remove (xoá vĩnh viễn); chỉ chạm tệp trong thư mục gốc của kho.

export type FetchLike = (input: string, init?: RequestInit) => Promise<Response>;

export interface AppsScriptConfig {
  url: string;
  secret: string;
}

export class StoreError extends Error {
  constructor(
    public code: string,
    message: string,
    public status?: number,
  ) {
    super(message);
  }
}

const RETRY_ATTEMPTS = 3; // allow-number: thử lại tối đa 3 lần với lỗi mạng và 5xx
const RETRY_BASE_MS = 500; // allow-number: chờ tăng dần từ 0,5 giây
const HTTP_SERVER_ERROR = 500; // allow-number: mã HTTP
const HTTP_TOO_MANY = 429; // allow-number: mã HTTP
const CHUNK = 0x8000; // allow-number: cỡ khúc khi đổi byte sang base64 (tránh tràn ngăn xếp)

export function bytesToBase64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += CHUNK) s += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  return btoa(s);
}

export function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

interface ScriptReply {
  ok?: boolean;
  code?: string;
  message?: string;
  [k: string]: unknown;
}

export function createAppsScriptClient(
  config: AppsScriptConfig,
  fetchFn: FetchLike = fetch,
  sleep: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
) {
  /** Gọi script bằng POST JSON; fetch tự theo chuyển hướng 302 của Apps Script. Lỗi mạng/5xx/429 thì thử lại; lỗi nghiệp vụ của script ném StoreError. */
  async function call(body: Record<string, unknown>): Promise<ScriptReply> {
    for (let attempt = 1; ; attempt++) {
      let res: Response | null = null;
      try {
        res = await fetchFn(config.url, {
          method: 'POST',
          redirect: 'follow',
          headers: { 'Content-Type': 'text/plain;charset=utf-8' }, // text/plain: Apps Script không xử lý yêu cầu tiền kiểm CORS
          body: JSON.stringify({ ...body, secret: config.secret }),
        });
      } catch {
        res = null;
      }
      const retryable = res === null || res.status >= HTTP_SERVER_ERROR || res.status === HTTP_TOO_MANY;
      if (retryable) {
        if (attempt >= RETRY_ATTEMPTS) throw new StoreError('HMT_KHO_TEP_LOI', 'Chưa kết nối được kho tệp, thử lại sau.', res?.status);
        await sleep(RETRY_BASE_MS * 2 ** (attempt - 1)); // allow-number: chờ gấp đôi mỗi lần thử
        continue;
      }
      const reply = (await res!.json().catch(() => null)) as ScriptReply | null;
      if (!reply) throw new StoreError('HMT_KHO_TEP_LOI', 'Kho tệp trả lời không đúng, thử lại sau.', res!.status);
      if (reply.ok) return reply;
      // Sai mật khẩu hoặc thiếu cấu hình: lỗi cài đặt, báo quản trị viên (không lộ chi tiết cho người dùng).
      if (reply.code === 'SAI_MAT_KHAU' || reply.code === 'CHUA_CAU_HINH') {
        throw new StoreError('HMT_KHO_TEP_CAU_HINH', 'Kho tệp chưa được cấu hình đúng (báo quản trị viên).');
      }
      throw new StoreError(`HMT_KHO_TEP_${reply.code ?? 'LOI'}`, reply.message ?? 'Kho tệp báo lỗi.');
    }
  }

  return {
    async ping(): Promise<string> {
      return String((await call({ action: 'ping' })).rootName ?? '');
    },
    /** Dung lượng đã dùng và hạn mức của tài khoản (byte), cho chặn mềm theo dung lượng còn trống. */
    async getStorageQuota(): Promise<{ usage: number; limit: number }> {
      const r = await call({ action: 'quota' });
      return { usage: Number(r.usage), limit: Number(r.limit) };
    },
    /** Lưu một tệp vào thư mục con `path` dưới thư mục gốc; trả id tệp trên Drive. Tên và đoạn thư mục chỉ chữ không dấu, số, `_ . -`. */
    async save(p: { path: string[]; name: string; mimeType: string; bytes: Uint8Array }): Promise<string> {
      const r = await call({ action: 'save', path: p.path, name: p.name, mimeType: p.mimeType, dataBase64: bytesToBase64(p.bytes) });
      return String(r.id);
    },
    async read(id: string): Promise<{ mimeType: string; bytes: Uint8Array }> {
      const r = await call({ action: 'read', id });
      return { mimeType: String(r.mimeType), bytes: base64ToBytes(String(r.dataBase64)) };
    },
    /** Xoá VĨNH VIỄN (không qua thùng rác). Tệp đã không còn hoặc ngoài kho thì coi như xong. */
    async remove(id: string): Promise<boolean> {
      return Boolean((await call({ action: 'remove', id })).removed);
    },
  };
}

export type StoreClient = ReturnType<typeof createAppsScriptClient>;
