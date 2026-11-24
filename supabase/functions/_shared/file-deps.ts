// Nối lõi luồng tệp (file-flow.ts) với Supabase và kho tệp thật (Google Drive qua Apps Script). Dùng chung cho file-upload, file-view.
// Quyền: hàm DB gọi bằng token của người gọi; ghi stored_file bằng khoá dịch vụ (bảng không cấp ghi cho đăng nhập thường).
// Địa chỉ và mật khẩu của kho tệp (Apps Script) chỉ đọc từ secret của Edge Function: APPS_SCRIPT_URL, APPS_SCRIPT_SHARED_SECRET.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { base64ToBytes, createAppsScriptClient, StoreError } from './apps-script-client.ts';
import { FlowError, type FileDeps, type StoreLike, type PendingRow, type UploadAuth, type ViewAuth } from './file-flow.ts';
import { publishableKey, secretKey } from './http.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const VN_OFFSET_MS = 7 * 3_600_000; // allow-number: Asia/Ho_Chi_Minh là UTC+7
const PG_UNIQUE_VIOLATION = '23505'; // allow-number: mã lỗi Postgres trùng khoá duy nhất

/** Lỗi hàm DB (hint là mã HMT_*) đổi sang FlowError để trả câu tiếng Việt cho giao diện. */
function rpcError(e: { message: string; hint?: string }): FlowError {
  const code = e.hint?.startsWith('HMT_') ? e.hint : 'HMT_LOI';
  return new FlowError(code, e.message, code === 'HMT_KHONG_CO_QUYEN' ? 403 : 400); // allow-number: mã HTTP
}

export function storeErrorToFlow(e: unknown): FlowError | null {
  return e instanceof StoreError ? new FlowError(e.code, e.message, 502) : null; // allow-number: mã HTTP cổng lỗi
}

export function buildFileDeps(authorization: string): { deps: FileDeps; callerId: () => Promise<string> } {
  const asCaller = createClient(SUPABASE_URL, publishableKey(), {
    db: { schema: 'app' },
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const admin = createClient(SUPABASE_URL, secretKey(), { db: { schema: 'app' }, auth: { persistSession: false } });
  // Kho tệp tạo muộn, sau bước kiểm quyền: chưa cài kho thì người đã qua kiểm quyền nhận 503 «chưa cài đặt» (không phải 500 chung).
  let storeClient: StoreLike | null = null;
  const getStore = (): StoreLike => {
    if (storeClient) return storeClient;
    const url = Deno.env.get('APPS_SCRIPT_URL');
    const secret = Deno.env.get('APPS_SCRIPT_SHARED_SECRET');
    if (!url || !secret) throw new FlowError('HMT_KHO_TEP_CHUA_CAI', 'Kho tệp chưa được cài đặt, báo quản trị viên.', 503); // allow-number: mã HTTP
    storeClient = createAppsScriptClient({ url, secret });
    return storeClient;
  };
  const store: StoreLike = {
    save: (p) => getStore().save(p),
    read: (id) => getStore().read(id),
    getStorageQuota: () => getStore().getStorageQuota(),
  };

  const deps: FileDeps = {
    store,
    async authorizeUpload(kind, assignmentId, studentId) {
      const { data, error } = await asCaller.rpc('file_authorize_upload', { p_kind: kind, p_assignment_id: assignmentId, p_student_id: studentId });
      if (error) throw rpcError(error);
      return data as UploadAuth;
    },
    async authorizeView(fileId) {
      const { data, error } = await asCaller.rpc('file_authorize_view', { p_file_id: fileId });
      if (error) throw rpcError(error);
      return data as ViewAuth;
    },
    async insertPending(row: PendingRow) {
      const { error } = await admin.from('stored_file').insert({ ...row, status: 'CHO_TAI', created_by: row.owner_user_id, updated_by: row.owner_user_id });
      if (error?.code === PG_UNIQUE_VIOLATION) return 'TRUNG';
      if (error) throw new FlowError('HMT_LOI', 'Chưa ghi được sổ tệp, thử lại.', 500); // allow-number: mã HTTP
      return 'OK';
    },
    async supersedePending(assignmentId, studentId, sha256) {
      let q = admin.from('stored_file').update({ status: 'DA_XOA', cleaned_at: new Date().toISOString() }).eq('assignment_id', assignmentId).eq('sha256', sha256).eq('status', 'CHO_TAI');
      q = studentId ? q.eq('student_id', studentId) : q.is('student_id', null);
      const { data, error } = await q.select('id');
      if (error) throw new FlowError('HMT_LOI', 'Chưa ghi được sổ tệp, thử lại.', 500); // allow-number: mã HTTP
      return data?.length ?? 0;
    },
    async abandon(id) {
      await admin.from('stored_file').update({ status: 'DA_XOA', cleaned_at: new Date().toISOString() }).eq('id', id).eq('status', 'CHO_TAI');
    },
    async markReady(id, storageKey, thumbKey) {
      const { error } = await admin.from('stored_file').update({ status: 'DANG_DUNG', storage_key: storageKey, thumb_storage_key: thumbKey }).eq('id', id).eq('status', 'CHO_TAI');
      if (error) throw new FlowError('HMT_LOI', 'Chưa ghi được sổ tệp, thử lại.', 500); // allow-number: mã HTTP
    },
    async minFreeGb() {
      const { data, error } = await admin.from('setting_def').select('value').eq('key', 'file_storage_min_free_gb').maybeSingle();
      // Không đọc được tham số thì KHÔNG lặng lẽ bỏ chặn mềm theo dung lượng: báo lỗi để biết (soát 00:08).
      if (error || !data) throw new FlowError('HMT_LOI', 'Chưa đọc được tham số dung lượng kho tệp, thử lại.', 500); // allow-number: mã HTTP
      return Number((data as { value: string }).value);
    },
    async sha256(bytes) {
      const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
      return Array.from(digest, (b) => b.toString(16).padStart(2, '0')).join(''); // allow-number: hệ thập lục phân hai chữ số
    },
    decodeBase64: base64ToBytes,
    monthFolder: () => new Date(Date.now() + VN_OFFSET_MS).toISOString().slice(0, 7), // allow-number: YYYY-MM
    newId: () => crypto.randomUUID(),
  };
  return {
    deps,
    async callerId() {
      const { data, error } = await asCaller.auth.getUser(authorization.replace(/^Bearer /, ''));
      if (error || !data.user) throw new FlowError('HMT_CHUA_DANG_NHAP', 'Chưa đăng nhập.', 401); // allow-number: mã HTTP
      return data.user.id;
    },
  };
}

