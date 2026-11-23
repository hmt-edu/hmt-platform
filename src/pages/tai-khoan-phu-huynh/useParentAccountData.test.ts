import { describe, expect, it, vi } from 'vitest';
import type { SupabaseClient } from '@supabase/supabase-js';

const { callFunction } = vi.hoisted(() => ({ callFunction: vi.fn().mockResolvedValue({}) }));
vi.mock('../../lib/db', () => ({ callFunction, rpc: vi.fn(), useDb: vi.fn() }));

import { PARENT_LOCK_REASON, lockParentAccount } from './useParentAccountData';

describe('Khoá tài khoản phụ huynh (QT-17) không bắt nhập lý do', () => {
  it('gửi lý do cố định để hàm khoá không báo thiếu lý do (HMT_THIEU_LY_DO)', async () => {
    await lockParentAccount({} as SupabaseClient, 'u-1');
    expect(callFunction).toHaveBeenCalledWith(expect.anything(), 'admin-users', {
      action: 'lock',
      userId: 'u-1',
      reason: PARENT_LOCK_REASON,
    });
    expect(PARENT_LOCK_REASON.trim()).not.toBe('');
  });
});
