import { useEffect } from 'react';
import { IDLE_SETTING_KEY, idleGroup } from './claims';
import { readIntSetting } from './api';
import { useAuth } from './authContext';

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
  const { supabase, claims, signOut } = useAuth();
  const roles = claims?.roles.join(',') ?? '';

  useEffect(() => {
    if (!supabase || !roles) return;
    let limitMinutes: number | null = null;
    let cancelled = false;

    const check = () => {
      const last = readLastActivity();
      if (
        limitMinutes !== null &&
        last !== null &&
        Date.now() - last > limitMinutes * MS_PER_MINUTE
      ) {
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
  }, [supabase, roles, signOut]);
}
