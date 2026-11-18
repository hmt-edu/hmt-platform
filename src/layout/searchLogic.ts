// Hàm thuần của ô tìm kiếm toàn hệ thống (CHUNG-11): nhóm kết quả theo loại, đường dẫn mở bản ghi.
export type SearchHit = {
  entity_type: string;
  entity_id: string;
  title: string;
  subtitle: string | null;
  code: string | null;
};

type Kind = { label: string; path: (id: string) => string };

/** Thứ tự nhóm theo canvas K1 (Học sinh, Khách hàng, ... ) và nơi mở bản ghi. */
export const SEARCH_KINDS: Record<string, Kind> = {
  STUDENT: { label: 'Học sinh', path: (id) => `/crm/hoc-sinh/${id}` },
  PARENT: { label: 'Khách hàng', path: (id) => `/crm/phu-huynh/${id}` },
  LEAD: { label: 'Lead', path: (id) => `/crm/lead/${id}` },
  OPPORTUNITY: { label: 'Cơ hội', path: (id) => `/crm/co-hoi/${id}` },
  ORDER: { label: 'Đơn hàng', path: (id) => `/crm/don-hang/${id}` },
  RECEIPT: { label: 'Phiếu thu', path: (id) => `/crm/phieu-thu/${id}` },
  CLASS: { label: 'Lớp', path: (id) => `/crm/lop/${id}` },
  USER_ACCOUNT: { label: 'Nhân viên', path: (id) => `/crm/quan-tri/nguoi-dung/${id}` },
};

export type SearchGroup = { type: string; label: string; hits: SearchHit[] };

/** Gom kết quả theo loại, theo thứ tự cố định; loại lạ bị bỏ (máy chủ thêm loại mới thì giao diện chưa biết mở đâu). */
export function groupHits(hits: SearchHit[]): SearchGroup[] {
  return Object.entries(SEARCH_KINDS)
    .map(([type, kind]) => ({
      type,
      label: kind.label,
      hits: hits.filter((h) => h.entity_type === type),
    }))
    .filter((g) => g.hits.length > 0);
}

export function hitPath(hit: SearchHit): string | null {
  return SEARCH_KINDS[hit.entity_type]?.path(hit.entity_id) ?? null;
}
