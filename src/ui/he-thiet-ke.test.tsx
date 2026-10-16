import { fireEvent, render, screen, within } from '@testing-library/react';
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { Button } from './Button';
import { Code, Tag } from './Data';
import { Checkbox, TextAreaField, TextField } from './Field';
import { Combobox, DateInput } from './Inputs';
import { Dialog } from './Overlays';
import { StageBar, type StageStep } from './Stage';

const STEPS: StageStep[] = [
  { code: 'L1', label: 'Mới' },
  { code: 'L2', label: 'Đã liên hệ' },
  { code: 'L3', label: 'Quan tâm' },
];

describe('StageBar', () => {
  it('bước đang ở có aria-current; bước đã qua không bấm được khi chỉ đi tới', () => {
    const onSelect = vi.fn();
    render(<StageBar steps={STEPS} current="L2" onSelect={onSelect} />);
    expect(screen.getByRole('button', { name: /^L2/ }).getAttribute('aria-current')).toBe('step');
    fireEvent.click(screen.getByRole('button', { name: /^L1/ }));
    expect(onSelect).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: /^L3/ }));
    expect(onSelect).toHaveBeenCalledWith(STEPS[2]);
  });

  it('cho đi lùi khi luật của màn không chặn (forwardOnly=false)', () => {
    const onSelect = vi.fn();
    render(<StageBar steps={STEPS} current="L3" forwardOnly={false} onSelect={onSelect} />);
    fireEvent.click(screen.getByRole('button', { name: /^L1/ }));
    expect(onSelect).toHaveBeenCalledWith(STEPS[0]);
  });
});

describe('thành phần cơ bản', () => {
  it('nút đang xử lý bị khoá và báo bận', () => {
    const onClick = vi.fn();
    render(
      <Button loading onClick={onClick}>
        Lưu
      </Button>,
    );
    const button = screen.getByRole('button', { name: /Lưu/ });
    fireEvent.click(button);
    expect(onClick).not.toHaveBeenCalled();
    expect(button.getAttribute('aria-busy')).toBe('true');
  });

  it('ô nhập: nhãn nối với ô, lỗi nối bằng aria, đánh dấu bắt buộc', () => {
    render(<TextField label="Số điện thoại" required error="Số điện thoại chưa đúng." />);
    const input = screen.getByLabelText('Số điện thoại');
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-required')).toBe('true');
    const errorId = input.getAttribute('aria-describedby') ?? '';
    expect(document.getElementById(errorId)?.textContent).toBe('Số điện thoại chưa đúng.');
  });

  it('ô nhiều dòng và ô tick có nhãn bấm được', () => {
    render(
      <>
        <TextAreaField label="Ghi chú" />
        <Checkbox label="Dùng cho mọi người" />
      </>,
    );
    expect(screen.getByLabelText('Ghi chú').tagName).toBe('TEXTAREA');
    const check = screen.getByLabelText<HTMLInputElement>('Dùng cho mọi người');
    fireEvent.click(check);
    expect(check.checked).toBe(true);
  });

  it('thẻ trạng thái có chữ; mã dùng chữ số đều chiều rộng', () => {
    render(
      <>
        <Tag tone="danger" icon="forbidden">
          Khoá
        </Tag>
        <Code>CO000121</Code>
      </>,
    );
    expect(screen.getByText('Khoá')).toBeTruthy();
    expect(screen.getByText('CO000121').className).toContain('tabular');
  });
});

describe('Dialog', () => {
  it('có tiêu đề, nút đóng; hộp bắt buộc (dismissible=false) không có nút đóng', () => {
    const { rerender } = render(
      <Dialog open onOpenChange={() => undefined} title="Từ chối đơn hàng">
        <p>Nội dung</p>
      </Dialog>,
    );
    const dialog = screen.getByRole('dialog', { name: 'Từ chối đơn hàng' });
    expect(within(dialog).getByRole('button', { name: 'Đóng' })).toBeTruthy();
    rerender(
      <Dialog open onOpenChange={() => undefined} title="Từ chối đơn hàng" dismissible={false}>
        <p>Nội dung</p>
      </Dialog>,
    );
    expect(screen.queryByRole('button', { name: 'Đóng' })).toBeNull();
  });
});

describe('Combobox, DateInput (PR 4a)', () => {
  it('tìm không cần dấu; lựa chọn có lý do thì không chọn được', async () => {
    const onChange = vi.fn();
    render(
      <Combobox
        label="Lớp"
        value={[]}
        onChange={onChange}
        options={[
          { value: 'a', label: '6B1 Số học' },
          { value: 'b', label: '7A1 Hình', disabledReason: 'Hết chỗ' },
        ]}
      />,
    );
    fireEvent.click(screen.getByRole('combobox', { name: /Lớp/ }));
    const input = await screen.findByPlaceholderText('Gõ để tìm (không cần dấu)');
    fireEvent.change(input, { target: { value: 'so hoc' } });
    expect(screen.queryByText('7A1 Hình')).toBeNull();
    fireEvent.click(await screen.findByText('6B1 Số học'));
    expect(onChange).toHaveBeenCalledWith(['a']);
  });

  it('ô ngày gõ tay luôn là dd/mm/yyyy và tự chèn dấu "/"', () => {
    const onChange = vi.fn();
    function Holder() {
      const [value, setValue] = useState<Date | null>(null);
      return (
        <DateInput
          label="Ngày vào lớp"
          value={value}
          onChange={(d) => {
            onChange(d);
            setValue(d);
          }}
        />
      );
    }
    render(<Holder />);
    const input = screen.getByLabelText<HTMLInputElement>('Ngày vào lớp');
    fireEvent.change(input, { target: { value: '05102026' } });
    expect(input.value).toBe('05/10/2026');
    const picked = onChange.mock.calls.at(-1)?.[0] as Date;
    expect([picked.getDate(), picked.getMonth(), picked.getFullYear()]).toEqual([5, 9, 2026]);
    fireEvent.change(input, { target: { value: '31022026' } });
    expect(screen.getByText(/Ngày không đúng/)).toBeTruthy();
  });
});
