import { describe, expect, it } from 'vitest';
import { testGroupFilter } from '../phieu/testFilters';
import { buildLeadGroupTree } from './leadGroups';
import type { GroupCounts } from './leadTypes';

const counts: GroupCounts = {
  total: 5,
  groups: [
    { k1: 'DRAFT', l1: 'Nháp', k2: 'TOAN', l2: 'Toán', count: 3 },
    { k1: 'DRAFT', l1: 'Nháp', k2: 'ANH', l2: 'Tiếng Anh', count: 2 },
  ],
};

describe('buildLeadGroupTree: bộ lọc của nhóm theo từng màn', () => {
  it('mặc định dùng trường của lead (stage, source, owner)', () => {
    const { specs } = buildLeadGroupTree<{ id: string }>(
      { total: 1, groups: [{ k1: 'C1', l1: 'Data mới', k2: null, l2: null, count: 1 }] },
      ['stage'],
      {},
      () => undefined,
    );
    expect(specs.get('g:stage=C1')?.filters).toEqual({ stage: ['C1'] });
  });

  it('màn Phiếu truyền bộ lọc riêng: nhóm trạng thái, môn mở đúng dòng của nhóm', () => {
    const { specs } = buildLeadGroupTree<{ id: string }>(
      counts,
      ['status', 'subject'],
      {},
      () => undefined,
      testGroupFilter,
    );
    expect(specs.get('g:status=DRAFT/subject=TOAN')?.filters).toEqual({
      status: ['DRAFT'],
      subject: ['TOAN'],
    });
    expect(specs.get('g:status=DRAFT/subject=ANH')?.filters).toEqual({
      status: ['DRAFT'],
      subject: ['ANH'],
    });
  });

  it('không truyền bộ lọc riêng thì trường lạ không lọc gì (lỗi cũ của màn Phiếu: mở nhóm ra toàn bộ dòng)', () => {
    const { specs } = buildLeadGroupTree<{ id: string }>(
      counts,
      ['status', 'subject'],
      {},
      () => undefined,
    );
    expect(specs.get('g:status=DRAFT/subject=TOAN')?.filters).toEqual({});
  });
});
