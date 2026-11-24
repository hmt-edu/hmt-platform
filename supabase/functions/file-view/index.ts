// Xem tệp: hàm DB kiểm quyền (theo người gọi), Edge Function làm trung gian đọc từ kho tệp, không lộ địa chỉ kho (F-23-55; thiết kế docs/ke-hoach/kho-tep-apps-script.md mục 2).
import { buildFileDeps, storeErrorToFlow } from '../_shared/file-deps.ts';
import { FlowError, viewFile } from '../_shared/file-flow.ts';
import { corsHeaders, fail, HTTP } from '../_shared/http.ts';

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
    const { deps } = buildFileDeps(authorization);
    const { bytes, mimeType } = await viewFile(deps, { id: String(body.id ?? ''), thumb: body.thumb === true });
    return new Response(bytes, {
      status: HTTP.OK,
      headers: { ...corsHeaders(req), 'Content-Type': mimeType, 'Cache-Control': 'private, no-store' },
    });
  } catch (e) {
    const err = e instanceof FlowError ? e : storeErrorToFlow(e);
    if (err) return fail(req, err.status, err.code, err.message);
    return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI', 'Chưa xử lý được, thử lại sau.');
  }
});
