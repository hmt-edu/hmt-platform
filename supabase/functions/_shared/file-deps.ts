// Nối lõi luồng tệp (file-flow.ts) với Supabase và Google Drive thật. Dùng chung cho file-upload-start, file-upload-done, file-view.
// Quyền: hàm DB gọi bằng token của người gọi; ghi stored_file bằng khoá dịch vụ (bảng không cấp ghi cho đăng nhập thường).
// Khoá Drive chỉ đọc từ secret của Edge Function: DRIVE_CLIENT_ID, DRIVE_CLIENT_SECRET, DRIVE_REFRESH_TOKEN, DRIVE_ROOT_FOLDER_ID.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { createDriveClient, DriveError } from './drive-client.ts';
import { FlowError, type FileDeps, type PendingRow, type UploadAuth, type ViewAuth } from './file-flow.ts';
import { publishableKey, secretKey } from './http.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const PG_UNIQUE_VIOLATION = '23505'; // allow-number: mã lỗi Postgres trùng khoá duy nhất

function need(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Thiếu secret ${name} cho Edge Function.`);
  return v;
}

/** Lỗi hàm DB (hint là mã HMT_*) đổi sang FlowError để trả câu tiếng Việt cho giao diện. */
function rpcError(e: { message: string; hint?: string }): FlowError {
  const code = e.hint?.startsWith('HMT_') ? e.hint : 'HMT_LOI';
  return new FlowError(code, e.message, code === 'HMT_KHONG_CO_QUYEN' ? 403 : 400); // allow-number: mã HTTP
}

export function driveErrorToFlow(e: unknown): FlowError | null {
  return e instanceof DriveError ? new FlowError(e.code, e.message, 502) : null; // allow-number: mã HTTP cổng lỗi
}

export function buildFileDeps(authorization: string): { deps: FileDeps; callerId: () => Promise<string> } {
  const asCaller = createClient(SUPABASE_URL, publishableKey(), {
    db: { schema: 'app' },
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const admin = createClient(SUPABASE_URL, secretKey(), { db: { schema: 'app' }, auth: { persistSession: false } });
  const drive = createDriveClient({ clientId: need('DRIVE_CLIENT_ID'), clientSecret: need('DRIVE_CLIENT_SECRET'), refreshToken: need('DRIVE_REFRESH_TOKEN') });

  const deps: FileDeps = {
    drive,
    rootFolderId: need('DRIVE_ROOT_FOLDER_ID'),
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
    async getPending(id, ownerUserId) {
      const { data } = await admin.from('stored_file').select('*').eq('id', id).eq('owner_user_id', ownerUserId).maybeSingle();
      return (data as (PendingRow & { status: string }) | null) ?? null;
    },
    async markReady(id, storageKey, thumbKey) {
      const { error } = await admin.from('stored_file').update({ status: 'DANG_DUNG', storage_key: storageKey, thumb_storage_key: thumbKey }).eq('id', id).eq('status', 'CHO_TAI');
      if (error) throw new FlowError('HMT_LOI', 'Chưa ghi được sổ tệp, thử lại.', 500); // allow-number: mã HTTP
    },
    async minFreeGb() {
      const { data } = await admin.from('setting_def').select('value').eq('key', 'file_storage_min_free_gb').maybeSingle();
      return Number((data as { value: string } | null)?.value);
    },
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

