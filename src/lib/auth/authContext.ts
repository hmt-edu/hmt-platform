import { createContext, useContext } from 'react';
import type { Session, SupabaseClient } from '@supabase/supabase-js';
import type { HmtClaims } from './claims';

export type AuthState = {
  supabase: SupabaseClient | null;
  /** undefined = đang tải phiên. */
  session: Session | null | undefined;
  claims: HmtClaims | null;
  signOut: () => Promise<void>;
  /** Lấy token mới (sau khi đổi mật khẩu, xác thực hai bước) để cập nhật vai trò, aal. */
  refresh: () => Promise<void>;
};

export const AuthContext = createContext<AuthState | null>(null);

export function useAuth(): AuthState {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth phải nằm trong AuthProvider');
  return value;
}
