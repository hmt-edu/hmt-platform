// A-27-17: nút «Xếp lớp» trên danh sách Ghi danh phải nằm ở cột hiện sẵn (cột thứ chín từng bị ẩn mặc định nên không bấm được).
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { defaultColumnKeys } from '../../list/state';
import type { AccessView } from '../../nav/access';
import type { LeadCatalogs } from '../lead/useCatalogs';
import { buildEnrollConfig } from './enrollConfig';
import type { EnrollmentRow } from './enrollTypes';

const catalogs = { filterOptions: () => [] } as unknown as LeadCatalogs;
const access = { seesAllBranches: false, teachingBranches: [] } as unknown as AccessView;
const waiting = { class_code: null, status_code: 'CHO_XEP_LOP' } as unknown as EnrollmentRow;

describe('buildEnrollConfig: nút Xếp lớp', () => {
  it('dòng Chờ xếp lớp có nút ở một cột hiện mặc định, bấm thì mở đúng dòng', () => {
    const onAssign = vi.fn();
    const config = buildEnrollConfig(catalogs, access, onAssign);
    const shown = defaultColumnKeys(config);
    render(
      <>
        {config.columns
          .filter((c) => shown.includes(c.key) && c.key === 'class')
          .map((c) => (
            <div key={c.key}>{c.render(waiting)}</div>
          ))}
      </>,
    );
    screen.getByRole('button', { name: 'Xếp lớp' }).click();
    expect(onAssign).toHaveBeenCalledWith(waiting);
  });

  it('không có quyền sửa thì không có nút', () => {
    const column = buildEnrollConfig(catalogs, access).columns.find((c) => c.key === 'class');
    render(<>{column?.render(waiting)}</>);
    expect(screen.queryByRole('button', { name: 'Xếp lớp' })).toBeNull();
  });
});
