import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { useDb } from '../../lib/db';

type CatalogItem = { catalog_code: string; code: string; name: string; is_active: boolean };
type Campaign = { id: string; name: string; is_active: boolean };

const CATALOGS = ['LEAD_STAGE', 'LEAD_SUBSTAGE', 'SOURCE_TYPE', 'SOURCE', 'SOURCE_CHANNEL'];
const FOREVER = Infinity;

export type LeadCatalogs = {
  /** Tên theo mã, kể cả mục đã Ngừng (dòng cũ vẫn hiện tên). */
  name: (catalog: string, code: string | null | undefined) => string | undefined;
  /** Các mục đang dùng của danh mục, đúng thứ tự sắp xếp. */
  options: (catalog: string) => { value: string; label: string }[];
  campaigns: { value: string; label: string }[];
  campaignName: (id: string | null | undefined) => string | undefined;
  ready: boolean;
};

/** Danh mục và chiến dịch cho màn Lead (tên hiển thị, lựa chọn của bộ lọc). Đổi hiếm nên giữ suốt phiên. */
export function useLeadCatalogs(): LeadCatalogs {
  const supabase = useDb();
  const items = useQuery({
    queryKey: ['lead-catalogs'],
    staleTime: FOREVER,
    queryFn: async (): Promise<CatalogItem[]> => {
      const { data, error } = await supabase
        .schema('app')
        .from('catalog_item')
        .select('catalog_code, code, name, is_active')
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
    const byKey = new Map((items.data ?? []).map((i) => [`${i.catalog_code}|${i.code}`, i]));
    const campaignById = new Map((campaigns.data ?? []).map((c) => [c.id, c.name]));
    return {
      name: (catalog, code) => (code ? byKey.get(`${catalog}|${code}`)?.name : undefined),
      options: (catalog) =>
        (items.data ?? [])
          .filter((i) => i.catalog_code === catalog && i.is_active)
          .map((i) => ({ value: i.code, label: i.name })),
      campaigns: (campaigns.data ?? [])
        .filter((c) => c.is_active)
        .map((c) => ({ value: c.id, label: c.name })),
      campaignName: (id) => (id ? campaignById.get(id) : undefined),
      ready: items.isSuccess,
    };
  }, [items.data, items.isSuccess, campaigns.data]);
}
