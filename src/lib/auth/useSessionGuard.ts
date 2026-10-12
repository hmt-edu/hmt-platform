import { useEffect } from 'react';
import { useAuth } from './authContext';
import { markSessionEnded } from './sessionEnd';

const CHECK_EVERY_MS = 60_000; // allow-number: chu kỳ kiểm phiên (một phút), không phải ngưỡng nghiệp vụ

/**
 * Phiên bị thu hồi (khoá tài khoản, bỏ vai trò, đổi cơ sở) thì cơ sở dữ liệu chặn ngay; hook này
 * hỏi lại định kỳ và khi quay lại tab, để giao diện tự về trang đăng nhập thay vì hiện màn trống.
 */
export function useSessionGuard(): void {
  const { supabase, claims, signOut } = useAuth();
  const userId = claims?.userId;

  useEffect(() => {
    if (!supabase || !userId) return;
    let stopped = false;
    const check = async () => {
      const { data, error } = (await supabase.schema('app').rpc('current_user_active')) as {
        data: unknown;
        error: unknown;
      };
      // Lỗi mạng thì bỏ qua lượt này; chỉ đăng xuất khi cơ sở dữ liệu trả lời rõ là phiên hết hiệu lực.
      if (stopped || error || data !== false) return;
      markSessionEnded('ended');
      await signOut();
    };
    const onVisible = () => {
      if (document.visibilityState === 'visible') void check();
    };
    void check();
    const timer = window.setInterval(() => void check(), CHECK_EVERY_MS);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      stopped = true;
      window.clearInterval(timer);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [supabase, userId, signOut]);
}
