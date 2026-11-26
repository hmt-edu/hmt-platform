import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { DetailField } from './Detail';

describe('DetailField: trường trống vẫn hiện nhãn (quyết định 26/11, thay Mẫu B6)', () => {
  it.each([[''], [null], [undefined], [false]])(
    'giá trị %j: có nhãn, giá trị để trống',
    (value) => {
      render(
        <dl>
          <DetailField label="Ghi chú" mode="view" value={value} />
        </dl>,
      );
      expect(screen.getByRole('term').textContent).toBe('Ghi chú');
      expect(screen.getByRole('definition').textContent).toBe('');
    },
  );
});
