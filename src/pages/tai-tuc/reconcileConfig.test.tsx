// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import type { AccessView } from '../../nav/access';
import { buildReconcileConfig } from './reconcileConfig';
import type { ReconcileRow } from './reconcileTypes';

afterEach(cleanup);

const access = {
  can: () => false,
  featureOn: () => false,
  seesAllBranches: false,
  teachingBranches: [],
} as unknown as AccessView;

const config = buildReconcileConfig(access, () => undefined, null);

describe('TT-04 Đối chiếu tái tục', () => {
  it('Ghi danh (n) hiện số đếm, bấm mới mở danh sách mã', () => {
    const column = config.columns.find((c) => c.key === 'enroll');
    render(<>{column?.render({ enrollment_codes: 'GD-01, GD-02' } as ReconcileRow)}</>);
    expect(screen.queryByText('GD-01')).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: '2 ghi danh' }));
    expect(screen.getByText('GD-01')).toBeTruthy();
    expect(screen.getByText('GD-02')).toBeTruthy();
  });

  it('cột, bộ lọc và Group By ghi «Tháng hết giờ», không ghi Campaign', () => {
    expect(JSON.stringify([config.filterFields, config.groupFields])).not.toContain('Campaign');
    expect(config.columns.map((c) => c.label)).toContain('Tháng hết giờ');
  });
});
