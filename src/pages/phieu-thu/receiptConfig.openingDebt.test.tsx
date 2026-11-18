// TC-02 Thu nợ đầu kỳ (R-V2-15): phiếu không có đơn hiện «Thu nợ đầu kỳ» ở cột Đơn hàng, không dựng liên kết hỏng; phiếu có đơn vẫn liên kết tới đơn.
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';
import type { AccessView } from '../../nav/access';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { buildReceiptConfig } from './receiptConfig';
import type { ReceiptRow } from './receiptTypes';

const row = (over: Partial<ReceiptRow>): ReceiptRow => ({
  id: 'r1',
  code: 'PT-CS1-2611-0001',
  status_code: 'NHAP',
  status: 'Nháp',
  order_id: 'o1',
  order_code: 'DH-CS1-2611-0001',
  parent_id: 'p1',
  parent_code: 'PH000001',
  parent_name: 'Phụ huynh giả',
  amount: 1000000,
  payment_method_code: 'TIEN_MAT',
  payment_method: 'Tiền mặt',
  paid_on: '2026-11-18',
  branch_code: 'CS1',
  collect_branch_code: 'CS1',
  created_at: '2026-11-18T03:00:00Z',
  created_by_name: null,
  approver_name: null,
  submitted_at: null,
  ...over,
});

function orderCell(r: ReceiptRow) {
  const catalogs = { filterOptions: () => [], name: () => undefined } as unknown as LeadCatalogs;
  const access = {
    can: () => true,
    teachingBranches: [],
    seesAllBranches: true,
  } as unknown as AccessView;
  const column = buildReceiptConfig(catalogs, access).columns.find((c) => c.key === 'order');
  const { container } = render(<MemoryRouter>{column?.render(r)}</MemoryRouter>);
  return container;
}

describe('Phiếu thu: cột Đơn hàng với phiếu nợ đầu kỳ', () => {
  it('phiếu không đơn hiện Thu nợ đầu kỳ và không có liên kết', () => {
    const c = orderCell(row({ order_id: null, order_code: null, is_opening_debt: true }));
    expect(c.textContent).toBe('Thu nợ đầu kỳ');
    expect(c.querySelector('a')).toBeNull();
  });
  it('phiếu có đơn vẫn liên kết tới đơn', () => {
    const c = orderCell(row({}));
    expect(c.querySelector('a')?.getAttribute('href')).toBe('/crm/don-hang/o1');
    expect(c.textContent).toBe('DH-CS1-2611-0001');
  });
});
