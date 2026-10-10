// T5 (soát bảo mật 10/10/2026): xem hạ tầng Supabase gửi kèm header IP nào, để chọn header người gọi
// không giả được. Chỉ chạy trên thử nghiệm; nơi khác trả 404. Chỉ trả lại IP của chính người gọi.
import { HTTP } from '../_shared/http.ts';

const IP_HEADERS = ['cf-connecting-ip', 'true-client-ip', 'x-real-ip', 'x-forwarded-for', 'x-envoy-external-address', 'forwarded'];

Deno.serve((req) => {
  if (Deno.env.get('HMT_ALLOW_STAGING_PREVIEWS') !== 'true') {
    return new Response('Not found', { status: HTTP.NOT_FOUND });
  }
  const headers = Object.fromEntries(IP_HEADERS.map((name) => [name, req.headers.get(name)]));
  return new Response(JSON.stringify({ headers }), { headers: { 'Content-Type': 'application/json' } });
});
