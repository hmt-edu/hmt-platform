import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { SessionStepBar } from './SessionStepBar';

describe('Thanh bốn bước của buổi (GV05, GV06)', () => {
  it('hiện đủ bốn bước, đánh dấu bước hiện tại', () => {
    render(<SessionStepBar current={2} />);
    const items = screen.getAllByRole('listitem');
    expect(items).toHaveLength(4);
    expect(items[1]?.getAttribute('aria-current')).toBe('step');
    expect(items[0]?.getAttribute('aria-current')).toBeNull();
    expect(screen.getByText('BTVN')).toBeTruthy();
  });

  it('bước đã xong có chữ «xong» cho người đọc màn hình', () => {
    render(<SessionStepBar current={2} done={[1]} />);
    expect(screen.getByText('(xong)')).toBeTruthy();
  });
});
