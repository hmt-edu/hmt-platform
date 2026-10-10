// Send Email hook (chốt 10/10/2026): mọi thư Supabase Auth định gửi đều đi qua đây.
// Luật: KHÔNG BAO GIỜ gửi thư tới địa chỉ nội bộ của học sinh (@hocsinh.hoamatoan.edu.vn).
// Thư còn lại gửi qua Resend (gói miễn phí) khi đã cấu hình RESEND_API_KEY và EMAIL_FROM.
import { Webhook } from 'npm:standardwebhooks@1.1.1';
import { HTTP } from '../_shared/http.ts';
import { isInternalStudentEmail } from '../_shared/login-rules.ts';

const SUBJECTS: Record<string, string> = {
  recovery: 'HMT: đặt lại mật khẩu',
  magiclink: 'HMT: đăng nhập',
  email_change: 'HMT: xác nhận đổi email',
  signup: 'HMT: xác nhận tài khoản',
  invite: 'HMT: lời mời',
  reauthentication: 'HMT: mã xác minh',
};

function hookError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  const secret = (Deno.env.get('SEND_EMAIL_HOOK_SECRET') ?? '').replace('v1,whsec_', '');
  const payload = await req.text();
  let data: { user: { email: string }; email_data: Record<string, string> };
  try {
    data = new Webhook(secret).verify(payload, Object.fromEntries(req.headers)) as typeof data;
  } catch {
    return hookError(HTTP.UNAUTHORIZED, 'Chữ ký hook không hợp lệ.');
  }

  const to = data.user.email;
  // Luật: địa chỉ học sinh thì bỏ thư, trả thành công để Supabase Auth không báo lỗi.
  if (isInternalStudentEmail(to)) {
    return new Response(JSON.stringify({}), { status: HTTP.OK, headers: { 'Content-Type': 'application/json' } });
  }

  const apiKey = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('EMAIL_FROM');
  if (!apiKey || !from) {
    return hookError(HTTP.UNAVAILABLE, 'Chưa cấu hình gửi email. Liên hệ quản trị viên để đặt lại mật khẩu.');
  }

  const type = data.email_data.email_action_type ?? '';
  const verifyUrl =
    `${data.email_data.site_url}/auth/v1/verify?token=${encodeURIComponent(data.email_data.token_hash ?? '')}` +
    `&type=${encodeURIComponent(type)}&redirect_to=${encodeURIComponent(data.email_data.redirect_to ?? '')}`;
  const html =
    `<p>Xin chào,</p><p>Bấm vào liên kết dưới đây để tiếp tục:</p><p><a href="${verifyUrl}">${verifyUrl}</a></p>` +
    `<p>Mã: <b>${data.email_data.token ?? ''}</b></p><p>Nếu không phải bạn yêu cầu, hãy bỏ qua thư này.</p>`;

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ from, to: [to], subject: SUBJECTS[type] ?? 'HMT', html }),
  });
  if (!response.ok) return hookError(HTTP.BAD_GATEWAY, 'Gửi email thất bại.');
  return new Response(JSON.stringify({}), { status: HTTP.OK, headers: { 'Content-Type': 'application/json' } });
});
