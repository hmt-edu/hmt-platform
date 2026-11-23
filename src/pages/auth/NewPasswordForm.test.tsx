import { fireEvent, render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const state = vi.hoisted(() => ({
  value: {
    policy: null as null | { minLength: number; requireLetterDigit: boolean },
    failed: false,
    loading: true,
    retry: () => undefined,
  },
}));

vi.mock('../../lib/auth/usePasswordPolicy', () => ({
  usePasswordPolicyState: () => state.value,
  policyHint: () => '',
}));
vi.mock('../../lib/auth/authContext', () => ({
  useAuth: () => ({ supabase: {}, session: null, refresh: () => Promise.resolve() }),
}));

import { NewPasswordForm } from './NewPasswordForm';

const renderForm = () => render(<NewPasswordForm submitLabel="Lưu" onDone={() => undefined} />);

describe('Đặt mật khẩu mới: luật mật khẩu không tải được thì báo bằng chữ (Soát S16, CHUNG-07)', () => {
  beforeEach(() => {
    state.value = { policy: null, failed: false, loading: true, retry: () => undefined };
  });

  it('đang tải: báo «Đang tải luật mật khẩu», nút Lưu mờ', () => {
    renderForm();
    expect(screen.getByRole('status').textContent).toContain('Đang tải luật mật khẩu');
    expect(screen.getByRole<HTMLButtonElement>('button', { name: 'Lưu' }).disabled).toBe(true);
  });

  it('lỗi tải: hiện câu lỗi tiếng Việt và nút Tải lại gọi retry', () => {
    const retry = vi.fn();
    state.value = { policy: null, failed: true, loading: false, retry };
    renderForm();
    expect(screen.getByText(/Không tải được luật mật khẩu/)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Tải lại luật mật khẩu' }));
    expect(retry).toHaveBeenCalledTimes(1);
  });

  it('có luật: hiện điều kiện, không có thông báo lỗi tải', () => {
    state.value = {
      policy: { minLength: 8, requireLetterDigit: true },
      failed: false,
      loading: false,
      retry: () => undefined,
    };
    renderForm();
    expect(screen.getByText('Tối thiểu 8 ký tự')).toBeTruthy();
    expect(screen.queryByText(/Không tải được luật mật khẩu/)).toBeNull();
  });
});

describe('Đổi mật khẩu trong hồ sơ hỏi mật khẩu hiện tại (S8, CHUNG-13)', () => {
  beforeEach(() => {
    state.value = {
      policy: { minLength: 8, requireLetterDigit: true },
      failed: false,
      loading: false,
      retry: () => undefined,
    };
  });

  it('askCurrent: có ô «Mật khẩu hiện tại»; để trống thì báo và không đổi', () => {
    render(<NewPasswordForm submitLabel="Lưu" askCurrent onDone={() => undefined} />);
    expect(screen.getByLabelText(/Mật khẩu hiện tại/)).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Lưu' }));
    expect(screen.getByText('Nhập mật khẩu hiện tại.')).toBeTruthy();
  });

  it('đổi lần đầu và đặt lại từ email (không askCurrent): không có ô mật khẩu hiện tại', () => {
    renderForm();
    expect(screen.queryByLabelText(/Mật khẩu hiện tại/)).toBeNull();
  });
});
