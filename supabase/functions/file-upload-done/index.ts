// Hoàn tất tải tệp: kiểm tệp Drive đúng tên và cỡ rồi đổi dòng sổ sang DANG_DUNG (F-23-49; thiết kế docs/ke-hoach/luu-tru-tep-drive.md mục 2).
import { buildFileDeps, driveErrorToFlow } from '../_shared/file-deps.ts';
import { FlowError, finishUpload } from '../_shared/file-flow.ts';
import { corsHeaders, fail, HTTP, json } from '../_shared/http.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'POST') return fail(req, HTTP.METHOD_NOT_ALLOWED, 'HMT_SAI_PHUONG_THUC', 'Chỉ nhận POST.');
  const authorization = req.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return fail(req, HTTP.UNAUTHORIZED, 'HMT_CHUA_DANG_NHAP', 'Chưa đăng nhập.');
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail(req, HTTP.BAD_REQUEST, 'HMT_YEU_CAU_SAI', 'Yêu cầu không hợp lệ.');
  }
  try {
    const { deps, callerId } = buildFileDeps(authorization);
    const owner = await callerId();
    const result = await finishUpload(deps, owner, {
      id: String(body.id ?? ''),
      driveId: String(body.driveId ?? ''),
      thumbDriveId: typeof body.thumbDriveId === 'string' ? body.thumbDriveId : null,
    });
    return json(req, HTTP.OK, result);
  } catch (e) {
    const err = e instanceof FlowError ? e : driveErrorToFlow(e);
    if (err) return fail(req, err.status, err.code, err.message);
    return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI', 'Chưa xử lý được, thử lại sau.');
  }
});
