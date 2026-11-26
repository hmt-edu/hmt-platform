import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Chatter } from './Chatter';

describe('Chatter: dòng thời gian mặc định tab «Ghi chú» (F-26-02)', () => {
  it('mở bản ghi thì «Ghi chú» đang chọn, «Tất cả» chưa chọn', () => {
    render(
      <Chatter
        status="ready"
        entries={[]}
        onSend={vi.fn()}
        searchPeople={vi.fn().mockResolvedValue([])}
      />,
    );
    expect(screen.getByRole('button', { name: 'Ghi chú' }).getAttribute('aria-pressed')).toBe(
      'true',
    );
    expect(screen.getByRole('button', { name: 'Tất cả' }).getAttribute('aria-pressed')).toBe(
      'false',
    );
  });
});
