import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { useDb } from '../../lib/db';

type CatalogItem = {
  id: string;
  catalog_code: string;
  code: string;
  name: string;
  is_active: boolean;
  parent_id: string | null;
  requires_note: boolean;
};
type Campaign = { id: string; name: string; is_active: boolean };

const CATALOGS = [
  'LEAD_STAGE',
  'LEAD_SUBSTAGE',
  'SOURCE_TYPE',
  'SOURCE',
  'SOURCE_CHANNEL',
  'PROVINCE',
  'WARD',
  'ACTIVITY_TYPE',
  'APPOINTMENT_CANCEL_REASON',
];
const FOREVER = Infinity;

export type LeadCatalogs = {
  /** Tên theo mã, kể cả mục đã Ngừng (dòng cũ vẫn hiện tên). */
  name: (catalog: string, code: string | null | undefined) => string | undefined;
  /** Các mục đang dùng của danh mục, đúng thứ tự sắp xếp. */
  options: (catalog: string) => { value: string; label: string }[];
  /** Các mục đang dùng của danh mục con thuộc một mục cha (nguồn của loại nguồn, kênh của nguồn, phường của tỉnh). */
  childrenOf: (
    catalog: string,
    parentCatalog: string,
    parentCode: string | null | undefined,
  ) => { value: string; label: string }[];
  /** Mã của mục cha (loại nguồn của một nguồn). */
  parentCode: (
    catalog: string,
    code: string | null | undefined,
    parentCatalog: string,
  ) => string | undefined;
  /** Mục này bắt buộc ghi chú khi chọn ("Khác" của lý do huỷ). */
  requiresNote: (catalog: string, code: string | null | undefined) => boolean;
  campaigns: { value: string; label: string }[];
  campaignName: (id: string | null | undefined) => string | undefined;
  ready: boolean;
};

/** Danh mục và chiến dịch cho màn Lead (tên hiển thị, lựa chọn của bộ lọc và biểu mẫu). Đổi hiếm nên giữ suốt phiên. */
export function useLeadCatalogs(): LeadCatalogs {
  const supabase = useDb();
  const items = useQuery({
    queryKey: ['lead-catalogs'],
    staleTime: FOREVER,
    queryFn: async (): Promise<CatalogItem[]> => {
      const { data, error } = await supabase
        .schema('app')
        .from('catalog_item')
        .select('id, catalog_code, code, name, is_active, parent_id, requires_note')
        .in('catalog_code', CATALOGS)
        .order('sort_order');
      if (error) throw new Error(error.message);
      return data ?? [];
    },
  });
  const campaigns = useQuery({
    queryKey: ['lead-campaigns'],
    staleTime: FOREVER,
    queryFn: async (): Promise<Campaign[]> => {
      const { data, error } = await supabase
        .schema('app')
        .from('campaign')
        .select('id, name, is_active')
        .order('name');
      if (error) throw new Error(error.message);
      return data ?? [];
    },
  });

  return useMemo<LeadCatalogs>(() => {
    const all = items.data ?? [];
    const byKey = new Map(all.map((i) => [`${i.catalog_code}|${i.code}`, i]));
    const byId = new Map(all.map((i) => [i.id, i]));
    const campaignById = new Map((campaigns.data ?? []).map((c) => [c.id, c.name]));
    const toOption = (i: CatalogItem) => ({ value: i.code, label: i.name });
    return {
      name: (catalog, code) => (code ? byKey.get(`${catalog}|${code}`)?.name : undefined),
      options: (catalog) =>
        all.filter((i) => i.catalog_code === catalog && i.is_active).map(toOption),
      childrenOf: (catalog, parentCatalog, parentCode) => {
        const parent = parentCode ? byKey.get(`${parentCatalog}|${parentCode}`) : undefined;
        if (!parent) return [];
        return all
          .filter((i) => i.catalog_code === catalog && i.is_active && i.parent_id === parent.id)
          .map(toOption);
      },
      parentCode: (catalog, code, parentCatalog) => {
        const item = code ? byKey.get(`${catalog}|${code}`) : undefined;
        const parent = item?.parent_id ? byId.get(item.parent_id) : undefined;
        return parent && parent.catalog_code === parentCatalog ? parent.code : undefined;
      },
      requiresNote: (catalog, code) =>
        code ? byKey.get(`${catalog}|${code}`)?.requires_note === true : false,
      campaigns: (campaigns.data ?? [])
        .filter((c) => c.is_active)
        .map((c) => ({ value: c.id, label: c.name })),
      campaignName: (id) => (id ? campaignById.get(id) : undefined),
      ready: items.isSuccess,
    };
  }, [items.data, items.isSuccess, campaigns.data]);
}
