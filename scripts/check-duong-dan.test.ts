import { describe, expect, it } from 'vitest';
import { scanSource } from './check-duong-dan.mjs';

describe('check:duong-dan', () => {
  it('đếm navigate và Link tới /crm/ không mang state', () => {
    const source = [
      'const a = () => navigate(`/crm/lead/${id}`);',
      'const b = <Link to="/crm/lop">Lớp</Link>;',
    ].join('\n');
    expect(scanSource(source).map((f) => f.kind)).toEqual(['navigate', 'Link']);
  });
  it('bỏ qua chỗ có state, địa chỉ ngoài CRM, và chỗ cố ý có ghi lý do', () => {
    const source = [
      'const a = <Link to="/crm/lop" state={from}>Lớp</Link>;',
      "const b = () => navigate('/gv/lop');",
      '// duong-dan-menu: nút ở màn lỗi',
      "const c = () => navigate('/crm/lop');",
    ].join('\n');
    expect(scanSource(source)).toEqual([]);
  });
});
