import { useQuery } from '@tanstack/react-query';
import type { PasswordPolicy } from '../../../supabase/functions/_shared/login-rules.ts';
import { readBoolSetting, readIntSetting } from './api';
import { useAuth } from './authContext';

export type PasswordPolicyState = {
  policy: PasswordPolicy | null;
  /** Đã thử đọc luật mà lỗi (mạng hoặc máy chủ): giao diện phải báo, không được im lặng (Soát S16). */
  failed: boolean;
  loading: boolean;
  retry: () => void;
};

/** Luật mật khẩu đọc từ Cài đặt (độ dài tối thiểu, bắt có chữ và số), kèm trạng thái tải và lỗi. */
export function usePasswordPolicyState(): PasswordPolicyState {
  const { supabase, claims } = useAuth();
  const query = useQuery({
    queryKey: ['password-policy', claims?.userId],
    enabled: Boolean(supabase && claims),
    queryFn: async (): Promise<PasswordPolicy> => {
      if (!supabase) throw new Error('Chưa cấu hình kết nối.');
      const [minLength, requireLetterDigit] = await Promise.all([
        readIntSetting(supabase, 'password_min_length'),
        readBoolSetting(supabase, 'password_require_letter_digit'),
      ]);
      if (minLength === null || requireLetterDigit === null)
        throw new Error('Không đọc được luật mật khẩu.');
      return { minLength, requireLetterDigit };
    },
  });
  return {
    policy: query.data ?? null,
    failed: query.isError,
    loading: query.isPending,
    retry: () => void query.refetch(),
  };
}

/** Chỉ lấy luật (null khi chưa có hoặc lỗi). Màn cần báo lỗi dùng usePasswordPolicyState. */
export function usePasswordPolicy(): PasswordPolicy | null {
  return usePasswordPolicyState().policy;
}

export function policyHint(policy: PasswordPolicy | null): string {
  if (!policy) return '';
  return `Ít nhất ${policy.minLength} ký tự${policy.requireLetterDigit ? ', có cả chữ và số' : ''}.`;
}
