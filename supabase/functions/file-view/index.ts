// Xem tệp: hàm DB kiểm quyền (theo người gọi), Edge Function làm trung gian đọc từ kho tệp, không lộ địa chỉ kho (F-23-55; thiết kế docs/ke-hoach/kho-tep-apps-script.md mục 2).
import { buildFileDeps, storeErrorToFlow } from '../_shared/file-deps.ts';
import { FlowError, viewFile } from '../_shared/file-flow.ts';
import { corsHeaders, fail, HTTP } from '../_shared/http.ts';

/** Thời gian trình duyệt giữ ảnh (giây): tham số của Edge Function FILE_VIEW_CACHE_SECONDS, mặc định 1 giờ. */
function cacheSeconds(): number {
  const n = Number(Deno.env.get('FILE_VIEW_CACHE_SECONDS'));
  return Number.isInteger(n) && n >= 0 ? n : 3600; // allow-number: mặc định 1 giờ khi chưa đặt tham số
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders(req) });
  if (req.method !== 'GET' && req.method !== 'POST') return fail(req, HTTP.METHOD_NOT_ALLOWED, 'HMT_SAI_PHUONG_THUC', 'Chỉ nhận GET hoặc POST.');
  const authorization = req.headers.get('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return fail(req, HTTP.UNAUTHORIZED, 'HMT_CHUA_DANG_NHAP', 'Chưa đăng nhập.');
  // GET (id, thumb trên địa chỉ) để trình duyệt giữ ảnh trong bộ nhớ đệm riêng; POST giữ để tương thích.
  let body: Record<string, unknown>;
  if (req.method === 'GET') {
    const q = new URL(req.url).searchParams;
    body = { id: q.get('id') ?? '', thumb: q.get('thumb') === '1' };
  } else {
    try {
      body = await req.json();
    } catch {
      return fail(req, HTTP.BAD_REQUEST, 'HMT_YEU_CAU_SAI', 'Yêu cầu không hợp lệ.');
    }
  }
  try {
    const { deps } = buildFileDeps(authorization);
    const { bytes, mimeType } = await viewFile(deps, { id: String(body.id ?? ''), thumb: body.thumb === true });
    return new Response(bytes, {
      status: HTTP.OK,
      headers: {
        ...corsHeaders(req),
        'Content-Type': mimeType,
        // Ảnh riêng tư: chỉ bộ nhớ đệm của chính trình duyệt, giữ theo tham số; quyền vẫn kiểm mỗi lần tải mới. Tệp không đổi nội dung theo id.
        'Cache-Control': `private, max-age=${cacheSeconds()}`,
        Vary: 'Authorization, Origin',
        'X-Content-Type-Options': 'nosniff',
        'Content-Disposition': 'inline',
      },
    });
  } catch (e) {
    const err = e instanceof FlowError ? e : storeErrorToFlow(e);
    if (err) return fail(req, err.status, err.code, err.message);
    return fail(req, HTTP.SERVER_ERROR, 'HMT_LOI', 'Chưa xử lý được, thử lại sau.');
  }
});
