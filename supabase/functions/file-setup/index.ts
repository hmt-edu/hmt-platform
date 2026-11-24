// Dựng thư mục gốc của kho tệp trên Drive (chỉ ADMIN, chạy một lần khi cài; F-23-52). Với phạm vi drive.file, ứng dụng chỉ thấy thư mục do chính nó tạo,
// nên thư mục gốc phải do Edge Function tạo. Trả id thư mục (không phải bí mật) để Admin dán vào secret DRIVE_ROOT_FOLDER_ID.
import { createClient } from 'npm:@supabase/supabase-js@2.117.3';
import { createDriveClient, DriveError } from '../_shared/drive-client.ts';
import { corsHeaders, fail, HTTP, json, publishableKey } from '../_shared/http.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'POST') return fail(req, HTTP.METHOD_NOT_ALLOWED, 'HMT_SAI_PHUONG_THUC', 'Chỉ nhận POST.');
  const authorization = req.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return fail(req, HTTP.UNAUTHORIZED, 'HMT_CHUA_DANG_NHAP', 'Chưa đăng nhập.');
  const asCaller = createClient(Deno.env.get('SUPABASE_URL') ?? '', publishableKey(), {
    db: { schema: 'app' },
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });
  const { error: notAdmin } = await asCaller.rpc('assert_account_admin');
  if (notAdmin) return fail(req, HTTP.FORBIDDEN, 'HMT_KHONG_CO_QUYEN', notAdmin.message);
  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch {
    /* thân rỗng cũng được */
  }
  const name = typeof body.name === 'string' && body.name.trim() ? body.name.trim().slice(0, 60) : 'HMT'; // allow-number: độ dài tên thư mục tối đa
  try {
    const drive = createDriveClient({
      clientId: Deno.env.get('DRIVE_CLIENT_ID') ?? '',
      clientSecret: Deno.env.get('DRIVE_CLIENT_SECRET') ?? '',
      refreshToken: Deno.env.get('DRIVE_REFRESH_TOKEN') ?? '',
    });
    const folderId = await drive.createFolder(name, 'root');
    return json(req, HTTP.OK, { folderId });
  } catch (e) {
    if (e instanceof DriveError) return fail(req, HTTP.BAD_GATEWAY, e.code, e.message);
    return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI', 'Chưa xử lý được, thử lại sau.');
  }
});
