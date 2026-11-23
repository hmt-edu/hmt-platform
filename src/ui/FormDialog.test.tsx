// Mẫu B11 (khuôn K08): hộp FormDialog đã có dữ liệu nhập thì bấm nền hoặc Esc không đóng mà hỏi trước; chưa nhập gì thì đóng bình thường; nút Huỷ đóng thẳng.
import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { FormDialog } from './Dialogs';
import { TextField } from './Field';

function setup() {
  const onOpenChange = vi.fn();
  render(
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title="Giao sale"
      confirmLabel="Giao"
      canSubmit={false}
      onSubmit={() => undefined}
    >
      <TextField label="Ghi chú" />
    </FormDialog>,
  );
  return onOpenChange;
}

describe('FormDialog: không đóng khi hộp đã có dữ liệu', () => {
  it('chưa nhập gì: Esc đóng hộp', () => {
    const onOpenChange = setup();
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' });
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });

  it('đã nhập: Esc không đóng, hiện hỏi «Bỏ nội dung đang nhập?»; Tiếp tục nhập giữ hộp', () => {
    const onOpenChange = setup();
    fireEvent.input(screen.getByLabelText('Ghi chú'), { target: { value: 'abc' } });
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' });
    expect(onOpenChange).not.toHaveBeenCalled();
    expect(screen.getByText('Bỏ nội dung đang nhập?')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Tiếp tục nhập' }));
    expect(onOpenChange).not.toHaveBeenCalled();
  });

  it('đã nhập rồi chọn Bỏ nội dung: hộp đóng', () => {
    const onOpenChange = setup();
    fireEvent.input(screen.getByLabelText('Ghi chú'), { target: { value: 'abc' } });
    fireEvent.keyDown(screen.getByRole('dialog'), { key: 'Escape' });
    fireEvent.click(screen.getByRole('button', { name: 'Bỏ nội dung' }));
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });

  it('nút Huỷ luôn đóng thẳng dù đã nhập', () => {
    const onOpenChange = setup();
    fireEvent.input(screen.getByLabelText('Ghi chú'), { target: { value: 'abc' } });
    fireEvent.click(screen.getByRole('button', { name: 'Huỷ' }));
    expect(onOpenChange).toHaveBeenCalledWith(false);
  });
});
