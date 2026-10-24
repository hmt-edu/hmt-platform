// Dựng cây nhóm (Group By ở máy chủ) từ số đếm của lead_group_counts và dòng đã tải của từng nhóm lá.
// Hàm thuần, có kiểm thử. Nhóm lá tải dòng khi người dùng mở; "Xem thêm" tải trang kế tiếp.
import type { TableGroup } from '../../ui/Data';
import { GROUP_FIELD_OF, groupFilter, type LeadFilters } from './leadFilters';
import type { GroupCounts } from './leadTypes';
import type { Leaf } from './useLeadData';

/** Nhãn nhóm: giai đoạn kèm mã như ở cột và Kanban ("C1 Data mới"); khác thì tên máy chủ trả. */
function labelOf(field: string | undefined, key: string | null, label: string | null): string {
  if (!label) return 'Chưa có';
  return field === 'stage' && key ? `${key} ${label}` : label;
}

export type LeafSpec = { filters: LeadFilters };

export type GroupTreeResult<Row> = {
  tree: TableGroup<Row>[];
  /** Khoá nhóm lá → bộ lọc của nhóm đó (để tải dòng khi mở). */
  specs: Map<string, LeafSpec>;
};

export function buildLeadGroupTree<Row>(
  counts: GroupCounts,
  fields: string[],
  leaves: Record<string, Leaf<Row>>,
  onMore: (key: string, spec: LeafSpec) => void,
  /** Bộ lọc của một nhóm theo trường và khoá; mỗi màn có trường nhóm riêng (mặc định: trường của lead, cơ hội). */
  filterOf: (field: string, key: string) => LeadFilters = groupFilter,
): GroupTreeResult<Row> {
  const specs = new Map<string, LeafSpec>();
  const [f1, f2] = fields.map((f) => GROUP_FIELD_OF[f] ?? f);

  const leaf = (
    key: string,
    label: string,
    count: number,
    filters: LeadFilters,
  ): TableGroup<Row> => {
    const spec = { filters };
    specs.set(key, spec);
    const data = leaves[key];
    const remaining = data ? data.total - data.rows.length : 0;
    return {
      key,
      label,
      count,
      children: [],
      rows: data?.rows ?? [],
      loading: data?.loading ?? false,
      more:
        data && data.rows.length > 0 && remaining > 0
          ? { remaining, loading: data.loading, onMore: () => onMore(key, spec) }
          : undefined,
    };
  };

  if (!f2) {
    const tree = counts.groups.map((g) =>
      leaf(`g:${f1}=${g.k1}`, labelOf(f1, g.k1, g.l1), g.count, filterOf(f1 ?? '', g.k1)),
    );
    return { tree, specs };
  }

  const parents = new Map<string, TableGroup<Row>>();
  for (const g of counts.groups) {
    const parentKey = `g:${f1}=${g.k1}`;
    let parent = parents.get(g.k1);
    if (!parent) {
      parent = { key: parentKey, label: labelOf(f1, g.k1, g.l1), count: 0, children: [], rows: [] };
      parents.set(g.k1, parent);
    }
    parent.count += g.count;
    parent.children.push(
      leaf(`${parentKey}/${f2}=${g.k2 ?? ''}`, labelOf(f2, g.k2, g.l2), g.count, {
        ...filterOf(f1 ?? '', g.k1),
        ...filterOf(f2, g.k2 ?? ''),
      }),
    );
  }
  return { tree: [...parents.values()], specs };
}
