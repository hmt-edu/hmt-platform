import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { ChoiceCards, FileRow, ProgressBar, SubmissionViewer, Switch } from './Lms';
import { LMS_MAX_FILE_BYTES, fileProblem, formatFileSize } from './lmsFiles';

describe('Switch (công tắc)', () => {
  it('role=switch, aria-checked đổi khi bấm, nhãn nối với công tắc', () => {
    const onChange = vi.fn();
    render(<Switch label="Cho nộp lại" checked={false} onChange={onChange} />);
    const sw = screen.getByRole('switch', { name: 'Cho nộp lại' });
    expect(sw.getAttribute('aria-checked')).toBe('false');
    fireEvent.click(sw);
    expect(onChange).toHaveBeenCalledWith(true);
  });

  it('khoá thì không đổi được', () => {
    const onChange = vi.fn();
    render(<Switch label="Nhận bài muộn" checked disabled onChange={onChange} />);
    const sw = screen.getByRole('switch', { name: 'Nhận bài muộn' });
    expect(sw.getAttribute('aria-checked')).toBe('true');
    fireEvent.click(sw);
    expect(onChange).not.toHaveBeenCalled();
  });
});

describe('ProgressBar', () => {
  it('giá trị bị chặn trong 0–100 và có nhãn chữ', () => {
    const { rerender } = render(<ProgressBar value={140} label="Đã chấm" />);
    expect(screen.getByRole('progressbar', { name: 'Đã chấm' }).getAttribute('aria-valuenow')).toBe(
      '100',
    );
    rerender(<ProgressBar value={-5} label="Đã chấm" />);
    expect(screen.getByRole('progressbar', { name: 'Đã chấm' }).getAttribute('aria-valuenow')).toBe(
      '0',
    );
  });
});

describe('tệp (R-LMS-04)', () => {
  it('chỉ nhận ảnh hoặc PDF, tối đa 10 MB', () => {
    expect(fileProblem({ type: 'image/png', size: 1000 })).toBeNull();
    expect(fileProblem({ type: 'application/pdf', size: LMS_MAX_FILE_BYTES })).toBeNull();
    expect(fileProblem({ type: 'application/pdf', size: LMS_MAX_FILE_BYTES + 1 })).toBe(
      'Tệp quá 10 MB.',
    );
    expect(fileProblem({ type: 'application/zip', size: 10 })).toBe('Chỉ nhận ảnh hoặc PDF.');
  });

  it('dung lượng đọc được', () => {
    expect(formatFileSize(500)).toBe('1 KB');
    expect(formatFileSize(820 * 1024)).toBe('820 KB');
    expect(formatFileSize(1.5 * 1024 * 1024)).toBe('1,5 MB');
  });

  it('hàng tệp: đang tải có thanh tiến độ; lỗi hiện chữ; khoá thì không có nút Xoá', () => {
    const onRemove = vi.fn();
    const { rerender } = render(
      <ul>
        <FileRow name="bai.pdf" size={2048} progress={40} onRemove={onRemove} />
      </ul>,
    );
    expect(screen.getByRole('progressbar', { name: 'Đang tải bai.pdf' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Xoá tệp bai.pdf' }));
    expect(onRemove).toHaveBeenCalledTimes(1);
    rerender(
      <ul>
        <FileRow name="to.png" size={LMS_MAX_FILE_BYTES + 1} error="Tệp quá 10 MB." />
      </ul>,
    );
    expect(screen.getByRole('alert').textContent).toBe('Tệp quá 10 MB.');
    rerender(
      <ul>
        <FileRow name="cu.pdf" size={1024} locked onRemove={onRemove} />
      </ul>,
    );
    expect(screen.queryByRole('button', { name: /Xoá tệp/ })).toBeNull();
    expect(screen.getByText(/đã khoá vì có em nộp bài/)).toBeTruthy();
  });
});

describe('ChoiceCards (thẻ chọn trạng thái)', () => {
  const options = [
    { value: 'DA_CHAM', label: 'Đã chấm', description: 'Có điểm 1–5' },
    { value: 'NOP_SAU', label: 'Nộp sau' },
    { value: 'DA_CHAM_X', label: 'Khoá', disabled: true, disabledReason: 'Em chưa nộp bài.' },
  ];

  it('chọn một thẻ gọi onChange; thẻ bị khoá không chọn được và nói lý do', () => {
    const onChange = vi.fn();
    render(
      <ChoiceCards
        legend="Trạng thái BTVN"
        options={options}
        value="DA_CHAM"
        onChange={onChange}
      />,
    );
    expect(screen.getByRole<HTMLInputElement>('radio', { name: /Đã chấm/ }).checked).toBe(true);
    fireEvent.click(screen.getByRole('radio', { name: /Nộp sau/ }));
    expect(onChange).toHaveBeenCalledWith('NOP_SAU');
    expect(screen.getByRole<HTMLInputElement>('radio', { name: /Khoá/ }).disabled).toBe(true);
    expect(screen.getByText('Em chưa nộp bài.')).toBeTruthy();
  });
});

describe('SubmissionViewer (khung xem bài nộp)', () => {
  const pages = [
    { id: 'a', src: 'a.png', alt: 'Trang 1 của bài nộp' },
    { id: 'b', src: 'b.png', alt: 'Trang 2 của bài nộp' },
  ];

  it('nhiều trang: đổi trang bằng dải ảnh nhỏ, phóng to có giới hạn', () => {
    render(<SubmissionViewer pages={pages} />);
    expect(screen.getByText('Trang 1/2')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Trang 2' }));
    expect(screen.getByText('Trang 2/2')).toBeTruthy();
    expect(screen.getByRole('img', { name: 'Trang 2 của bài nộp' })).toBeTruthy();
    expect(screen.getByRole<HTMLButtonElement>('button', { name: /Thu nhỏ/ }).disabled).toBe(true);
    fireEvent.click(screen.getByRole('button', { name: /Phóng to/ }));
    expect(screen.getByRole<HTMLButtonElement>('button', { name: /Thu nhỏ/ }).disabled).toBe(false);
  });

  it('PDF hiện khung nhúng; đang tải và lỗi có chữ; lỗi có nút Thử lại', () => {
    const onRetry = vi.fn();
    const { rerender } = render(<SubmissionViewer pdfSrc="x.pdf" />);
    expect(screen.getByTitle('Bài nộp (PDF)')).toBeTruthy();
    rerender(<SubmissionViewer loading />);
    expect(screen.getByRole('status').textContent).toContain('Đang tải bài nộp');
    rerender(<SubmissionViewer error="Không tải được ảnh." onRetry={onRetry} />);
    fireEvent.click(screen.getByRole('button', { name: /Thử lại/ }));
    expect(onRetry).toHaveBeenCalledTimes(1);
  });
});
