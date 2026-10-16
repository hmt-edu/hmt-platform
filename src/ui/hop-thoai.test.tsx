import { fireEvent, render, screen } from '@testing-library/react';
import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { smartTarget } from '../record/smartButton';
import { ChoiceDialog, DuplicateDialog, ReasonDialog } from './Dialogs';

const REASONS = [
  { value: 'a', label: 'Nhập sai' },
  { value: 'khac', label: 'Khác', needsNote: true },
];

function Reason({ onConfirm }: { onConfirm: (r: { option: string; note: string }) => void }) {
  return (
    <ReasonDialog
      open
      onOpenChange={() => undefined}
      title="Huỷ phiếu"
      options={REASONS}
      confirmLabel="Xác nhận huỷ"
      onConfirm={onConfirm}
    />
  );
}

describe('ReasonDialog (hộp thoại ②)', () => {
  it('nút xác nhận mờ cho tới khi chọn lý do', () => {
    render(<Reason onConfirm={() => undefined} />);
    const confirm = screen.getByRole('button', { name: 'Xác nhận huỷ' });
    expect((confirm as HTMLButtonElement).disabled).toBe(true);
  });
});

function Choice({ onConfirm }: { onConfirm: () => void }) {
  const [value, setValue] = useState<string | null>(null);
  return (
    <ChoiceDialog
      open
      onOpenChange={() => undefined}
      title="Chọn lớp"
      columns={['Mã lớp', 'Không chọn được']}
      options={[
        { id: 'ok', cells: ['9A1', ''] },
        { id: 'sai', cells: ['9E1', ''], reasons: ['Đầy chỗ', 'Sai môn', 'Sai cơ sở'] },
      ]}
      value={value}
      onValueChange={setValue}
      canSubmit
      onConfirm={onConfirm}
    />
  );
}

describe('ChoiceDialog (K4d)', () => {
  it('dòng sai điều kiện chỉ hiện hai lý do rồi "+N lý do"', () => {
    render(<Choice onConfirm={() => undefined} />);
    expect(screen.getByText('Đầy chỗ')).toBeTruthy();
    expect(screen.getByText('Sai môn')).toBeTruthy();
    expect(screen.queryByText('Sai cơ sở')).toBeNull();
    expect(screen.getByText('+1 lý do')).toBeTruthy();
  });

  it('chọn dòng hợp lệ thì nút Chọn sáng và gọi onConfirm', () => {
    const onConfirm = vi.fn();
    render(<Choice onConfirm={onConfirm} />);
    const choose = screen.getByRole<HTMLButtonElement>('button', { name: 'Chọn' });
    expect(choose.disabled).toBe(true);
    fireEvent.click(screen.getAllByRole('radio')[0]!);
    expect(choose.disabled).toBe(false);
    fireEvent.click(choose);
    expect(onConfirm).toHaveBeenCalledOnce();
  });
});

describe('DuplicateDialog (K07c, TS-14)', () => {
  it('hai lựa chọn: gắn vào hồ sơ có sẵn hoặc vẫn tạo mới', () => {
    const onAttach = vi.fn();
    const onCreateNew = vi.fn();
    render(
      <DuplicateDialog
        open
        onOpenChange={() => undefined}
        existingCode="HS000123"
        existingName="Lê Gia Huy"
        onAttach={onAttach}
        onCreateNew={onCreateNew}
      />,
    );
    fireEvent.click(screen.getByRole('button', { name: 'Gắn vào hồ sơ có sẵn' }));
    fireEvent.click(screen.getByRole('button', { name: 'Vẫn tạo mới' }));
    expect(onAttach).toHaveBeenCalledOnce();
    expect(onCreateNew).toHaveBeenCalledOnce();
  });
});

describe('smartTarget (quy tắc smart button)', () => {
  it('nhiều bản ghi → danh sách; đúng một → mở thẳng; không có → danh sách rỗng hoặc tắt', () => {
    expect(smartTarget(2)).toBe('list');
    expect(smartTarget(1)).toBe('record');
    expect(smartTarget(0)).toBe('empty-list');
    expect(smartTarget(0, 'disabled')).toBe('none');
  });
});
