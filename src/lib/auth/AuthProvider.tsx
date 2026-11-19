import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { queryClient } from '../query';
import { getSupabase } from '../supabase';
import { AuthContext, type AuthState } from './authContext';
import { readClaims } from './claims';

export function AuthProvider({ children }: { children: ReactNode }) {
  const supabase = getSupabase();
  const [session, setSession] = useState<Session | null | undefined>(supabase ? undefined : null);

  // Người đang đăng nhập trong thẻ này. Đổi người (đăng xuất, đăng nhập tài khoản khác) thì xoá bộ nhớ đệm dữ liệu: nếu không, màn còn
  // giữ kết quả của người trước (ví dụ nút Duyệt, Từ chối trống khi đổi sang Trưởng cơ sở, báo cáo Tester 2 T2-08/T2-12) và dữ liệu
  // của người trước có thể lộ cho người sau trên máy dùng chung.
  const userRef = useRef<string | null | undefined>(undefined);
  const track = useCallback((next: Session | null) => {
    const id = next?.user.id ?? null;
    if (userRef.current !== undefined && userRef.current !== id) queryClient.clear();
    userRef.current = id;
    setSession(next);
  }, []);

  useEffect(() => {
    if (!supabase) return;
    void supabase.auth.getSession().then(({ data }) => track(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, next) => track(next));
    return () => data.subscription.unsubscribe();
  }, [supabase, track]);

  const signOut = useCallback(async () => {
    await supabase?.auth.signOut();
  }, [supabase]);

  const refresh = useCallback(async () => {
    await supabase?.auth.refreshSession();
  }, [supabase]);

  const value = useMemo<AuthState>(
    () => ({
      supabase,
      session,
      claims: session ? readClaims(session.access_token) : null,
      signOut,
      refresh,
    }),
    [supabase, session, signOut, refresh],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
