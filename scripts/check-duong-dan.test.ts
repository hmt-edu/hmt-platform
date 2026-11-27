import { readFileSync } from 'node:fs';
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
  it('phân hệ Tuyển sinh: mọi chỗ mở trang đều nối tiếp đường dẫn trang gốc (H1 PR2)', () => {
    const files = [
      'src/pages/lead/LeadListPage.tsx',
      'src/pages/lead/LeadRecordPage.tsx',
      'src/pages/lead/leadConfig.tsx',
      'src/pages/co-hoi/OpportunityListPage.tsx',
      'src/pages/co-hoi/OpportunityRecordPage.tsx',
      'src/pages/co-hoi/oppConfig.tsx',
      'src/pages/phieu/TestListPage.tsx',
      'src/pages/phieu/TestRecordPage.tsx',
      'src/pages/phieu/testConfig.tsx',
      'src/pages/lich-hen/AppointmentParts.tsx',
      'src/features/prospect/ProspectStudents.tsx',
    ];
    const found = files.flatMap((file) =>
      scanSource(readFileSync(file, 'utf8'), file).map((f) => `${file}:${f.line}`),
    );
    expect(found).toEqual([]);
  });
});
