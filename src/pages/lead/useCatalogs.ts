import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { useDb } from '../../lib/db';

export type CatalogItem = {
  id: string;
  catalog_code: string;
  code: string;
  name: string;
  is_active: boolean;
  parent_id: string | null;
  requires_note: boolean;
  applies_to: string[] | null;
};
type Campaign = { id: string; name: string; is_active: boolean };

const CATALOGS = [
  'LEAD_STAGE',
  'LEAD_SUBSTAGE',
  'OPP_STAGE',
  'OPP_SUBSTAGE',
  'TEST_SKIP_REASON',
  'TEST_STATUS',
  'TEST_CANCEL_REASON',
  'TEST_MODE',
  'TEST_LEVEL',
  'SUBJECT',
  'GRADE',
  'LEVEL',
  'FRAMEWORK_LEVEL',
  'SOURCE_TYPE',
  'SOURCE',
  'SOURCE_CHANNEL',
  'PROVINCE',
  'WARD',
  'ACTIVITY_TYPE',
  'APPOINTMENT_RESULT',
  'APPOINTMENT_CANCEL_REASON',
  'ACCOUNT_LOCK_REASON',
  'QUOTATION_STATUS',
  'STUDY_MODE',
  'REJECT_REASON',
  'ORDER_STATUS',
  'TICKET_STATUS',
  'UPSALE_STAGE',
  'UPSALE_SUBSTAGE',
  'TICKET_PRIORITY',
  'TICKET_TEAM',
  'TICKET_CHANNEL',
  'SESSION_STATUS',
  'SESSION_CANCEL_REASON',
  'ATTENDANCE_STATUS',
  'HOURS_ADJUST_REASON',
  'ORDER_CANCEL_REASON',
  'REASSIGN_REASON',
  'PACKAGE_TYPE',
  'PAYMENT_METHOD',
  'RECEIPT_STATUS',
  'RECEIPT_CANCEL_REASON',
  'REVERSAL_REASON',
  'ENROLLMENT_STATUS',
];
const FOREVER = Infinity;

const toOption = (i: CatalogItem) => ({ value: i.code, label: i.name });

/**
 * Các mục dùng được của một danh mục, đúng thứ tự. `keep`: mã đang lưu trên bản ghi cũ; mục này vẫn hiện (kể cả đã Ngừng) để bản ghi cũ
 * không mất giá trị khi mở sửa (R-V2-43), mục Ngừng khác thì không hiện ở ô chọn mới.
 */
export function activeOptions(all: CatalogItem[], catalog: string, keep?: string | null) {
  return all
    .filter((i) => i.catalog_code === catalog && (i.is_active || i.code === keep))
    .map(toOption);
}

/** Mục đang dùng của một danh mục, chỉ những mục áp dụng cho `appliesTo` (cột applies_to; để trống là áp dụng mọi nơi). */
export function optionsAppliesTo(all: CatalogItem[], catalog: string, appliesTo: string) {
  return all
    .filter(
      (i) =>
        i.catalog_code === catalog &&
        i.is_active &&
        (!i.applies_to || i.applies_to.length === 0 || i.applies_to.includes(appliesTo)),
    )
    .map(toOption);
}

/**
 * Danh sách cho BỘ LỌC (Q-127, R-V2-43): liệt kê cả mục đã Ngừng, kèm nhãn "(ngừng)", để lọc được dữ liệu cũ. Ô chọn khi tạo hoặc sửa
 * dùng `activeOptions`, không có mục Ngừng.
 */
export function filterOptions(all: CatalogItem[], catalog: string) {
  return all
    .filter((i) => i.catalog_code === catalog)
    .map((i) => ({ value: i.code, label: i.is_active ? i.name : `${i.name} (ngừng)` }));
}

/**
 * Các mục con dùng được của một mục cha. R-V2-43 (Q-116): mục cha đã Ngừng thì mục con tự ẩn khỏi ô chọn (trạng thái từng mục con giữ nguyên,
 * Dùng lại mục cha thì mục con đang dùng hiện lại). `keep`: mã con đang lưu trên bản ghi cũ vẫn hiện để không mất giá trị.
 */
export function childOptions(
  all: CatalogItem[],
  catalog: string,
  parentCatalog: string,
  parentCode: string | null | undefined,
  keep?: string | null,
) {
  const parent = parentCode
    ? all.find((i) => i.catalog_code === parentCatalog && i.code === parentCode)
    : undefined;
  if (!parent) return [];
  const parentUsable = parent.is_active;
  return all
    .filter(
      (i) =>
        i.catalog_code === catalog &&
        i.parent_id === parent.id &&
        ((i.is_active && parentUsable) || i.code === keep),
    )
    .map(toOption);
}

export type LeadCatalogs = {
  /** Tên theo mã, kể cả mục đã Ngừng (dòng cũ vẫn hiện tên). */
  name: (catalog: string, code: string | null | undefined) => string | undefined;
  /** Các mục đang dùng của danh mục, đúng thứ tự sắp xếp. */
  options: (catalog: string, keep?: string | null) => { value: string; label: string }[];
  /** Như `options` nhưng liệt kê cả mục đã Ngừng kèm nhãn "(ngừng)": chỉ cho bộ lọc danh sách (Q-127). */
  filterOptions: (catalog: string) => { value: string; label: string }[];
  /** Như `options`, nhưng chỉ mục áp dụng cho một đối tượng (cột applies_to; để trống là áp dụng mọi nơi), ví dụ lý do từ chối của báo giá. */
  optionsFor: (catalog: string, appliesTo: string) => { value: string; label: string }[];
  /** Các mục đang dùng của danh mục con thuộc một mục cha (nguồn của loại nguồn, kênh của nguồn, phường của tỉnh). */
  childrenOf: (
    catalog: string,
    parentCatalog: string,
    parentCode: string | null | undefined,
    /** Mã đang lưu trên bản ghi cũ: vẫn hiện dù đã Ngừng hoặc mục cha đã Ngừng (R-V2-43). */
    keep?: string | null,
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
        .select('id, catalog_code, code, name, is_active, parent_id, requires_note, applies_to')
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
    return {
      name: (catalog, code) => (code ? byKey.get(`${catalog}|${code}`)?.name : undefined),
      options: (catalog, keep) => activeOptions(all, catalog, keep),
      filterOptions: (catalog) => filterOptions(all, catalog),
      optionsFor: (catalog, appliesTo) => optionsAppliesTo(all, catalog, appliesTo),
      childrenOf: (catalog, parentCatalog, parentCode, keep) =>
        childOptions(all, catalog, parentCatalog, parentCode, keep),
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
