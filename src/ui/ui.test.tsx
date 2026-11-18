import { fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { Button } from './Button';
import { Avatar, CountBadge, StateView } from './Feedback';
import { OtpInput, PasswordInput, TextField } from './Field';

describe('Field', () => {
  it('nhãn nối với ô nhập; dấu bắt buộc không lẫn vào tên nhãn', () => {
    render(<TextField label="Email" required />);
    const input = screen.getByLabelText('Email');
    expect(input.getAttribute('aria-required')).toBe('true');
    expect(input.getAttribute('aria-invalid')).toBeNull();
  });

  it('lỗi hiện tại chỗ và nối với ô nhập bằng aria-describedby', () => {
    render(<TextField label="Email" error="Email chưa đúng." help="Email công việc." />);
    const input = screen.getByLabelText('Email');
    expect(input.getAttribute('aria-invalid')).toBe('true');
    const described = (input.getAttribute('aria-describedby') ?? '').split(' ');
    const texts = described.map((id) => document.getElementById(id)?.textContent);
    expect(texts).toEqual(['Email chưa đúng.', 'Email công việc.']);
  });
});

describe('PasswordInput', () => {
  it('mặc định ẩn; bấm Hiện thì thấy mật khẩu, bấm Ẩn thì ẩn lại', () => {
    render(<PasswordInput label="Mật khẩu" defaultValue="abc12345" />);
    const input = screen.getByLabelText('Mật khẩu');
    expect(input.getAttribute('type')).toBe('password');
    fireEvent.click(screen.getByRole('button', { name: 'Hiện mật khẩu' }));
    expect(input.getAttribute('type')).toBe('text');
    fireEvent.click(screen.getByRole('button', { name: 'Ẩn mật khẩu' }));
    expect(input.getAttribute('type')).toBe('password');
  });
});

describe('OtpInput', () => {
  function Harness() {
    const [value, setValue] = useState('');
    return <OtpInput label="Mã xác thực" value={value} onChange={setValue} />;
  }

  it('chỉ nhận chữ số, tối đa 6 số (kể cả khi dán mã có dấu cách)', () => {
    render(<Harness />);
    const input = screen.getByLabelText<HTMLInputElement>('Mã xác thực');
    fireEvent.change(input, { target: { value: '12a 34-5678' } });
    expect(input.value).toBe('123456');
    expect(input.getAttribute('autocomplete')).toBe('one-time-code');
  });
});

describe('Button', () => {
  it('đang xử lý thì không bấm được lần nữa', () => {
    const onClick = vi.fn();
    render(
      <Button loading onClick={onClick}>
        Lưu
      </Button>,
    );
    const button = screen.getByRole('button', { name: /Lưu/ });
    fireEvent.click(button);
    expect(onClick).not.toHaveBeenCalled();
    expect(button.hasAttribute('disabled')).toBe(true);
  });
});

describe('Feedback', () => {
  it('trạng thái không có quyền được đọc ngay cho trình đọc màn hình', () => {
    render(<StateView kind="forbidden" title="Bạn không có quyền xem trang này" />);
    expect(screen.getByRole('alert')).toBeTruthy();
    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe(
      'Bạn không có quyền xem trang này',
    );
  });

  it('ảnh đại diện lấy chữ đầu của hai từ cuối, bỏ phần trong ngoặc', () => {
    const { container } = render(<Avatar name="Phạm Ngọc Ánh (giả)" />);
    // Chữ viết tắt nằm ở thuộc tính (vẽ bằng CSS), không là chữ trong DOM (luật axe label-content-name-mismatch).
    expect(container.firstElementChild?.getAttribute('data-initials')).toBe('NÁ');
    expect(container.textContent).toBe('');
  });

  it('số đếm bằng 0 thì không hiện', () => {
    const { container } = render(<CountBadge count={0} label="việc chờ duyệt" />);
    expect(container.textContent).toBe('');
  });
});
