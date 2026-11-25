import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { LineTable } from './LineTable';
import { PageFrame, PageHeader } from './PageHeader';

describe('PageHeader (F-24-16)', () => {
  it('tiêu đề 20 px (text-h2), nút cùng dải với tiêu đề, mô tả dưới tiêu đề', () => {
    render(
      <PageFrame>
        <PageHeader title="Bảng giá" description="Mô tả" actions={<button>Thêm</button>} />
      </PageFrame>,
    );
    const h1 = screen.getByRole('heading', { level: 1, name: 'Bảng giá' });
    expect(h1.className).toContain('text-h2');
    const header = h1.closest('header');
    expect(header?.contains(screen.getByRole('button', { name: 'Thêm' }))).toBe(true);
    expect(header?.contains(screen.getByText('Mô tả'))).toBe(true);
  });

  it('không có nút thì không vẽ khối nút trống', () => {
    const { container } = render(<PageHeader title="Vai trò" actions={false} />);
    expect(container.querySelectorAll('header > div')).toHaveLength(1);
  });
});

describe('LineTable wrap (F-24-16, G2)', () => {
  const columns = [{ key: 'a', header: 'Cột', cell: (r: { a: string }) => r.a }];
  it('wrap: bảng theo bề rộng khung, ô được xuống dòng', () => {
    render(
      <LineTable wrap caption="t" columns={columns} rows={[{ a: 'x' }]} rowKey={(r) => r.a} />,
    );
    const table = screen.getByRole('table');
    expect(table.className).toContain('w-full');
    expect(table.className).not.toContain('w-max');
    expect(screen.getByRole('cell').className).not.toContain('whitespace-nowrap');
  });
  it('mặc định giữ một hàng một dòng (Báo giá, Đơn hàng)', () => {
    render(<LineTable caption="t" columns={columns} rows={[{ a: 'x' }]} rowKey={(r) => r.a} />);
    expect(screen.getByRole('table').className).toContain('w-max');
    expect(screen.getByRole('cell').className).toContain('whitespace-nowrap');
  });
});
