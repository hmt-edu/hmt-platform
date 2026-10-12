import { useEffect } from 'react';
import { IDLE_SETTING_KEY, idleGroup } from './claims';
import { readIntSetting } from './api';
import { useAuth } from './authContext';
import { markSessionEnded } from './sessionEnd';

const LAST_ACTIVITY_KEY = 'hmt:last-activity';
const ACTIVITY_EVENTS = ['pointerdown', 'keydown', 'scroll', 'touchstart'] as const;
const MS_PER_MINUTE = 60_000; // allow-number: số mili giây trong một phút
const CHECK_EVERY_MS = 30_000; // allow-number: chu kỳ kiểm (nửa phút), không phải ngưỡng nghiệp vụ

function readLastActivity(): number | null {
  try {
    const raw = localStorage.getItem(LAST_ACTIVITY_KEY);
    return raw ? Number(raw) : null;
  } catch {
    return null;
  }
}

function writeLastActivity(): void {
  try {
    localStorage.setItem(LAST_ACTIVITY_KEY, String(Date.now()));
  } catch {
    // Trình duyệt chặn lưu trữ: chỉ kiểm trong phiên hiện tại.
  }
}

/**
 * Tự đăng xuất khi không dùng quá số phút trong Cài đặt (nhân viên / giáo viên / học sinh).
 * Lưu lần thao tác cuối ở trình duyệt để tính cả khi đóng tab rồi mở lại.
 */
export function useIdleLogout(): void {
  const { supabase, claims, session, signOut } = useAuth();
  const roles = claims?.roles.join(',') ?? '';
  // Lần đăng nhập gần nhất cũng là một lần thao tác: không có mốc này thì người vừa đăng nhập lại sau
  // khi bị tự đăng xuất sẽ bị đăng xuất tiếp vì mốc thao tác cũ.
  const signedInAt = Date.parse(session?.user.last_sign_in_at ?? '') || null;

  useEffect(() => {
    if (!supabase || !roles) return;
    let limitMinutes: number | null = null;
    let cancelled = false;

    const check = () => {
      const stored = readLastActivity();
      const last =
        stored !== null && signedInAt !== null
          ? Math.max(stored, signedInAt)
          : (stored ?? signedInAt);
      if (
        limitMinutes !== null &&
        last !== null &&
        Date.now() - last > limitMinutes * MS_PER_MINUTE
      ) {
        markSessionEnded('idle');
        void signOut();
      }
    };
    void readIntSetting(supabase, IDLE_SETTING_KEY[idleGroup(roles.split(','))]).then((value) => {
      if (cancelled) return;
      limitMinutes = value;
      check();
      writeLastActivity();
    });

    ACTIVITY_EVENTS.forEach((e) =>
      window.addEventListener(e, writeLastActivity, { passive: true }),
    );
    const timer = window.setInterval(check, CHECK_EVERY_MS);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
      ACTIVITY_EVENTS.forEach((e) => window.removeEventListener(e, writeLastActivity));
    };
  }, [supabase, roles, signedInAt, signOut]);
}
