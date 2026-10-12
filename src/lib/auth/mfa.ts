// Xác thực hai bước (TOTP) qua Supabase Auth. Chốt 12/10: không có mã dự phòng, mỗi người tối đa 2 thiết bị.
import type { SupabaseClient } from '@supabase/supabase-js';

/** Số thiết bị TOTP tối đa mỗi người (khớp `max_enrolled_factors` trong cấu hình Supabase Auth). */
export const MAX_TOTP_DEVICES = 2;

export type TotpDevice = { id: string; name: string; createdAt: string };
export type TotpEnrollment = { factorId: string; qrCode: string; secret: string };

export async function listTotpDevices(supabase: SupabaseClient): Promise<TotpDevice[]> {
  const { data, error } = await supabase.auth.mfa.listFactors();
  if (error) throw new Error(error.message);
  return data.totp
    .filter((f) => f.status === 'verified')
    .map((f) => ({ id: f.id, name: f.friendly_name ?? 'Thiết bị', createdAt: f.created_at }));
}

/** Bắt đầu đăng ký một thiết bị: dọn các lần đăng ký dở, rồi tạo mã QR mới. */
export async function startTotpEnrollment(
  supabase: SupabaseClient,
  name: string,
): Promise<TotpEnrollment> {
  const { data: factors } = await supabase.auth.mfa.listFactors();
  for (const factor of factors?.all ?? []) {
    if (factor.status === 'unverified') await supabase.auth.mfa.unenroll({ factorId: factor.id });
  }
  const { data, error } = await supabase.auth.mfa.enroll({
    factorType: 'totp',
    friendlyName: name,
  });
  if (error || !data) throw new Error(error?.message ?? 'Không tạo được mã cài đặt.');
  return { factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret };
}

/** Kiểm mã 6 số với một thiết bị; đúng thì phiên lên mức hai bước (aal2). */
export async function verifyTotp(
  supabase: SupabaseClient,
  factorId: string,
  code: string,
): Promise<boolean> {
  const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
  return !error;
}

/** Người có hai thiết bị nhập mã của máy nào cũng được: thử lần lượt từng thiết bị. */
export async function verifyTotpAnyDevice(
  supabase: SupabaseClient,
  devices: TotpDevice[],
  code: string,
): Promise<boolean> {
  for (const device of devices) {
    if (await verifyTotp(supabase, device.id, code)) return true;
  }
  return false;
}

export async function removeTotpDevice(supabase: SupabaseClient, factorId: string): Promise<void> {
  const { error } = await supabase.auth.mfa.unenroll({ factorId });
  if (error) throw new Error(error.message);
}
