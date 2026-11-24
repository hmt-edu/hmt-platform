// Tải tệp lên kho (Google Drive qua Apps Script): kiểm quyền bằng hàm DB, lưu ảnh và ảnh thu nhỏ, ghi sổ tệp (F-23-55; thiết kế docs/ke-hoach/kho-tep-apps-script.md mục 2).
import { buildFileDeps, storeErrorToFlow } from '../_shared/file-deps.ts';
import { FlowError, uploadFiles } from '../_shared/file-flow.ts';
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
    const files = Array.isArray(body.files) ? (body.files as Record<string, unknown>[]) : [];
    const result = await uploadFiles(deps, owner, {
      kind: String(body.kind ?? ''),
      assignmentId: String(body.assignmentId ?? ''),
      studentId: typeof body.studentId === 'string' ? body.studentId : null,
      files: files.map((f) => ({
        mimeType: String(f.mimeType ?? ''),
        dataBase64: String(f.dataBase64 ?? ''),
        thumbBase64: typeof f.thumbBase64 === 'string' && f.thumbBase64 ? f.thumbBase64 : null,
      })),
    });
    return json(req, HTTP.OK, result);
  } catch (e) {
    const err = e instanceof FlowError ? e : storeErrorToFlow(e);
    if (err) return fail(req, err.status, err.code, err.message);
    return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI', 'Chưa xử lý được, thử lại sau.');
  }
});
