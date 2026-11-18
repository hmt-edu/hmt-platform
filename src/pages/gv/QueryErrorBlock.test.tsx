import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import { HmtError, FORBIDDEN_CODE } from '../../lib/db';
import { QueryErrorBlock } from './QueryErrorBlock';

const wrap = (node: React.ReactNode) => render(<MemoryRouter>{node}</MemoryRouter>);

describe('Khối lỗi tải của cổng Giáo viên (R-GV-08, R-GV-13)', () => {
  it('không có quyền: hiện trạng thái «không có quyền», có lối về trang Hôm nay, không có nút Thử lại', () => {
    wrap(<QueryErrorBlock error={new HmtError(FORBIDDEN_CODE, 'x')} onRetry={() => undefined} />);
    expect(screen.getByText('Bạn không xem được mục này')).toBeTruthy();
    expect(screen.getByRole('link', { name: 'Về trang Hôm nay' })).toBeTruthy();
    expect(screen.queryByRole('button', { name: 'Thử lại' })).toBeNull();
  });

  it('lỗi mạng hoặc lỗi khác: hiện câu lỗi và nút Thử lại gọi lại', () => {
    const retry = vi.fn();
    wrap(<QueryErrorBlock error={new HmtError('HMT_LOI', 'Có lỗi xảy ra.')} onRetry={retry} />);
    expect(screen.getByText('Có lỗi xảy ra.')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Thử lại' }));
    expect(retry).toHaveBeenCalledTimes(1);
  });

  it('nút phụ (Về lớp) hiện cạnh Thử lại', () => {
    wrap(
      <QueryErrorBlock
        error={new HmtError('HMT_LOI', 'x')}
        onRetry={() => undefined}
        extra={<a href="/gv/lop">Về lớp</a>}
      />,
    );
    expect(screen.getByRole('link', { name: 'Về lớp' })).toBeTruthy();
  });
});
