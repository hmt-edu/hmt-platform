import { describe, expect, it } from 'vitest';
import { groupHits, hitPath, type SearchHit } from './searchLogic';

const hit = (entity_type: string, id: string): SearchHit => ({
  entity_type,
  entity_id: id,
  title: 't',
  subtitle: null,
  code: null,
});

describe('CHUNG-11 tìm kiếm', () => {
  it('gom theo loại đúng thứ tự, bỏ loại lạ', () => {
    const groups = groupHits([
      hit('ORDER', '1'),
      hit('STUDENT', '2'),
      hit('LAZ', '3'),
      hit('STUDENT', '4'),
    ]);
    expect(groups.map((g) => g.type)).toEqual(['STUDENT', 'ORDER']);
    expect(groups[0]?.hits).toHaveLength(2);
  });
  it('đường dẫn mở bản ghi', () => {
    expect(hitPath(hit('OPPORTUNITY', 'x'))).toBe('/crm/co-hoi/x');
    expect(hitPath(hit('LAZ', 'x'))).toBeNull();
  });
});
