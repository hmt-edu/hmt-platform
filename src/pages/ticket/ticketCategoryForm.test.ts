import { describe, expect, it } from 'vitest';
import { NEW_CATEGORY_DRAFT, buildCategoryPayload, categoryErrors } from './ticketCategoryForm';

describe('CSN-08: biểu mẫu nhóm ticket', () => {
  it('tạo mới cần mã đúng dạng và tên', () => {
    expect(Object.keys(categoryErrors(NEW_CATEGORY_DRAFT, true)).sort()).toEqual(['code', 'name']);
    expect(
      categoryErrors({ ...NEW_CATEGORY_DRAFT, code: 'hoc_1', name: 'A' }, true).code,
    ).toBeDefined();
    expect(categoryErrors({ ...NEW_CATEGORY_DRAFT, code: 'HOC_1', name: 'A' }, true)).toEqual({});
  });
  it('sửa nhóm đã có không kiểm mã', () => {
    expect(categoryErrors({ ...NEW_CATEGORY_DRAFT, name: 'A' }, false)).toEqual({});
  });
  it('thứ tự phải là số nguyên', () => {
    expect(
      categoryErrors({ ...NEW_CATEGORY_DRAFT, code: 'HOC', name: 'A', sortOrder: '1.5' }, true)
        .sortOrder,
    ).toBeDefined();
  });
  it('nhóm cha không gửi mức độ, đội, phiếu nghiệp vụ', () => {
    const p = buildCategoryPayload(
      { ...NEW_CATEGORY_DRAFT, code: 'HOC', name: 'Học', priority: 'CAO' },
      { creating: true, kind: 'GROUP', parentCode: null, ticketType: 'DN' },
    );
    expect(p).toMatchObject({ code: 'HOC', kind: 'GROUP', ticket_type: 'DN' });
    expect(p).not.toHaveProperty('default_priority');
  });
  it('nhóm con gửi nhóm cha; tính chất chỉ ở ticket giáo viên', () => {
    const d = { ...NEW_CATEGORY_DRAFT, code: 'HOC_A', name: 'A', nature: 'HO_TRO' };
    const dn = buildCategoryPayload(d, {
      creating: true,
      kind: 'SUBGROUP',
      parentCode: 'HOC',
      ticketType: 'DN',
    });
    expect(dn).toMatchObject({ parent_code: 'HOC' });
    expect(dn).not.toHaveProperty('nature_code');
    const gv = buildCategoryPayload(d, {
      creating: true,
      kind: 'SUBGROUP',
      parentCode: 'HOC',
      ticketType: 'GV',
    });
    expect(gv).toMatchObject({ nature_code: 'HO_TRO' });
  });
  it('sửa không gửi kind, cha, loại (mã không đổi)', () => {
    const p = buildCategoryPayload(
      { ...NEW_CATEGORY_DRAFT, code: 'HOC', name: 'Học' },
      { creating: false, kind: 'GROUP', parentCode: null, ticketType: 'DN' },
    );
    expect(p).not.toHaveProperty('kind');
    expect(p).not.toHaveProperty('ticket_type');
  });
});
