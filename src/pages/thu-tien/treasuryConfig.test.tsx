// TC-09: nút «Hoàn tác khoản tiền» ở sổ Khoản tiền vào. Luật R-TIEN-26 (chặn đảo hai lần), R-HT-01 (chỉ Kế toán).
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it, vi } from 'vitest';
import type { AccessView } from '../../nav/access';
import { buildMoneyInConfig } from './treasuryConfig';
import type { MoneyInRow } from './treasuryTypes';

const base: MoneyInRow = {
  id: 'm1',
  code: 'KTV-CS1-2611-0001',
  receipt_id: 'r1',
  receipt_code: 'PT-1',
  order_id: 'o1',
  order_code: 'DH-1',
  parent_id: 'p1',
  parent_name: 'Phụ huynh giả',
  amount: 1000000,
  created_at: '2026-11-16T03:00:00Z',
  branch_code: 'CS1',
  reversal_of_code: null,
  is_reversed: false,
  reason_code: null,
};
const accessOf = (allowed: boolean) =>
  ({ can: () => allowed, teachingBranches: [] }) as unknown as AccessView;

function cell(config: ReturnType<typeof buildMoneyInConfig>, key: string, row: MoneyInRow) {
  const column = config.columns.find((c) => c.key === key);
  const { container } = render(<MemoryRouter>{column?.render(row)}</MemoryRouter>);
  return container;
}

describe('TC-09 nút Hoàn tác khoản tiền', () => {
  it('Kế toán thấy nút ở khoản thu chưa bị hoàn tác, bấm thì gọi onReverse', () => {
    const onReverse = vi.fn();
    const box = cell(buildMoneyInConfig(accessOf(true), onReverse), 'reverse', base);
    const button = box.querySelector('button');
    expect(button?.textContent).toBe('Hoàn tác khoản tiền');
    button?.click();
    expect(onReverse).toHaveBeenCalledWith(base);
  });
  it('R-HT-01: người không có Kế toán · Duyệt (Admin) không thấy nút', () => {
    const box = cell(buildMoneyInConfig(accessOf(false), vi.fn()), 'reverse', base);
    expect(box.querySelector('button')).toBeNull();
  });
  it('R-TIEN-26: khoản đã bị hoàn tác không còn nút, hiện nhãn Đã hoàn tác', () => {
    const config = buildMoneyInConfig(accessOf(true), vi.fn());
    const row = { ...base, is_reversed: true };
    expect(cell(config, 'reverse', row).querySelector('button')).toBeNull();
    expect(cell(config, 'note', row).textContent).toBe('Đã hoàn tác');
  });
  it('TC-02: khoản thu nợ đầu kỳ không có đơn thì cột Đơn hàng hiện nhãn Nợ đầu kỳ, không có link', () => {
    const config = buildMoneyInConfig(accessOf(true), vi.fn());
    const row = { ...base, order_id: null, order_code: null };
    const box = cell(config, 'order', row);
    expect(box.textContent).toBe('Nợ đầu kỳ');
    expect(box.querySelector('a')).toBeNull();
  });
  it('Khoản đảo (âm) không có nút, không có link phiếu thu, ghi mã khoản gốc', () => {
    const config = buildMoneyInConfig(accessOf(true), vi.fn());
    const row = {
      ...base,
      amount: -1000000,
      receipt_id: null,
      receipt_code: null,
      reversal_of_code: 'KTV-GOC',
    };
    expect(cell(config, 'reverse', row).querySelector('button')).toBeNull();
    expect(cell(config, 'receipt', row).textContent).toBe('');
    expect(cell(config, 'note', row).textContent).toBe('Hoàn tác của KTV-GOC');
  });
});
