import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { getSupabase } from '../supabase';
import { AuthContext, type AuthState } from './authContext';
import { readClaims } from './claims';

export function AuthProvider({ children }: { children: ReactNode }) {
  const supabase = getSupabase();
  const [session, setSession] = useState<Session | null | undefined>(supabase ? undefined : null);

  useEffect(() => {
    if (!supabase) return;
    void supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data } = supabase.auth.onAuthStateChange((_event, next) => setSession(next));
    return () => data.subscription.unsubscribe();
  }, [supabase]);

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
