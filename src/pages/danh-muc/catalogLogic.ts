// Logic thuần của QT-06, QT-07 Danh mục: dựng cây phẳng cho bảng, nhãn danh mục, kiểm mã phía giao diện (cùng luật với hàm DB catalog_add_item).
// Luật và quyền do hàm DB kiểm (R-V2-42, Q-110, Q-122); giao diện chỉ ẩn nút cho đúng kiểu danh mục.

export type CatalogKind = 'HE_THONG' | 'MO';

export type CatalogLevel = { code: string; name: string; total: number; active: number };

export type CatalogSummary = {
  code: string;
  name: string;
  kind: CatalogKind;
  is_read_only: boolean;
  description: string | null;
  levels: CatalogLevel[];
};

export type CatalogNode = {
  id: string;
  catalog_code: string;
  code: string;
  name: string;
  sort_order: number;
  is_active: boolean;
  is_locked: boolean;
  parent_id: string | null;
};

export type CatalogTree = {
  root: {
    code: string;
    name: string;
    kind: CatalogKind;
    is_read_only: boolean;
    description: string | null;
  };
  levels: { code: string; name: string }[];
  items: CatalogNode[];
};

/** Kiểu danh mục để hiện nhãn và chọn nút: chỉ xem (Q-110), khoá chỉ đổi tên (Q-122), mở. */
export type CatalogMode = 'view' | 'locked' | 'open';

export function catalogMode(c: { kind: CatalogKind; is_read_only: boolean }): CatalogMode {
  if (c.is_read_only) return 'view';
  return c.kind === 'HE_THONG' ? 'locked' : 'open';
}

export const MODE_LABEL: Record<CatalogMode, string> = {
  view: 'Chỉ xem',
  locked: 'Khoá',
  open: 'Mở',
};

/**
 * Tên danh mục gốc hiện trên màn (Q-128, spec 06 tên danh mục #9 và #29): hai danh mục gốc mà tên trong DB là tên của tầng đầu, không phải
 * tên cả danh mục ("Loại nguồn" là tầng đầu của "Nguồn lead"; "Tỉnh/Thành phố" là tầng đầu của "Tỉnh, phường"). Danh mục khác dùng tên trong DB.
 */
const ROOT_LABEL: Record<string, string> = {
  SOURCE_TYPE: 'Nguồn lead',
  PROVINCE: 'Tỉnh, phường',
};
export function rootLabel(code: string, name: string): string {
  return ROOT_LABEL[code] ?? name;
}

/** Đơn vị đếm của từng tầng ở dòng tóm tắt ("4 loại · 12 nguồn · 14 kênh", "8 giai đoạn · 62 nhóm con"); tầng khác đếm là "mục". */
const LEVEL_UNIT: Record<string, string> = {
  SOURCE_TYPE: 'loại',
  SOURCE: 'nguồn',
  SOURCE_CHANNEL: 'kênh',
  LEAD_STAGE: 'giai đoạn',
  LEAD_SUBSTAGE: 'nhóm con',
  OPP_STAGE: 'giai đoạn',
  OPP_SUBSTAGE: 'nhóm con',
  PROVINCE: 'tỉnh',
  WARD: 'phường, xã',
};

/** Dòng tóm tắt dưới tên danh mục ở cột trái: "4 loại · 12 nguồn · 14 kênh", thêm "chỉ đổi tên" cho danh mục khoá. */
export function summaryLine(c: CatalogSummary): string {
  if (c.levels.every((l) => l.total === 0)) return 'Chưa có mục';
  const parts = c.levels.map((l) => `${l.total} ${LEVEL_UNIT[l.code] ?? 'mục'}`);
  if (catalogMode(c) === 'locked') parts.push('chỉ đổi tên');
  return parts.join(' · ');
}

export type TreeRow = {
  node: CatalogNode;
  depth: number;
  first: boolean;
  last: boolean;
  /** Số thứ tự hiển thị: đếm lại từ 1 trong từng nhóm cùng cha (Q-132), không phải số lưu trong DB. */
  rank: number;
};

/**
 * Cây mục thành danh sách phẳng theo thứ tự hiển thị: mỗi mục cha rồi các mục con của nó (sắp theo thứ tự, rồi id).
 * `first`, `last`: mục đầu, cuối trong nhóm cùng cha (▲ mờ ở mục đầu, ▼ mờ ở mục cuối).
 */
export function flattenTree(items: CatalogNode[]): TreeRow[] {
  const byParent = new Map<string | null, CatalogNode[]>();
  for (const it of items) {
    const key = it.parent_id;
    byParent.set(key, [...(byParent.get(key) ?? []), it]);
  }
  for (const list of byParent.values()) {
    list.sort((a, b) => a.sort_order - b.sort_order || a.id.localeCompare(b.id));
  }
  const out: TreeRow[] = [];
  const walk = (parent: string | null, depth: number) => {
    const list = byParent.get(parent) ?? [];
    list.forEach((node, i) => {
      out.push({ node, depth, first: i === 0, last: i === list.length - 1, rank: i + 1 });
      walk(node.id, depth + 1);
    });
  };
  walk(null, 0);
  return out;
}

/** Tên tầng con của một mục ở tầng `depth` (để ghi nút "Thêm kênh"), hoặc null nếu là tầng cuối. */
export function childLevelName(
  levels: { code: string; name: string }[],
  depth: number,
): string | null {
  return levels[depth + 1]?.name ?? null;
}

/** Mã mục: chữ viết hoa không dấu, số, gạch dưới, không bắt đầu bằng gạch dưới (cùng luật catalog_add_item). */
export const CODE_PATTERN = /^[A-Z0-9][A-Z0-9_]*$/;

export type AddInputErrors = { code?: string };

/** Kiểm nhanh ở ô nhập trước khi gọi máy chủ (máy chủ vẫn kiểm lại và trả câu lỗi thật). */
export function addInputErrors(code: string): AddInputErrors {
  const errors: AddInputErrors = {};
  const c = code.trim().toUpperCase();
  if (c !== '' && !CODE_PATTERN.test(c)) {
    errors.code =
      'Mã chỉ gồm chữ viết hoa không dấu, số và gạch dưới, không bắt đầu bằng gạch dưới.';
  }
  return errors;
}

/** Danh mục «Loại buổi» (E23): có thêm cột Form nhận xét chỉ đọc. */
export const SESSION_TYPE_CATALOG = 'SESSION_TYPE';

/**
 * Form nhận xét của một loại buổi (chỉ đọc, E23 phương án b, Chat chốt 19/11): buổi Kiểm tra chấm bằng Form điểm (R-V2-20), mọi loại còn lại chấm
 * 9 tiêu chí (R-V2-19). Phản ánh đúng luật đang chạy trong hàm DB; đổi form theo loại chưa có (cần bảng cấu hình, anh Trường chưa chốt).
 */
export function sessionTypeFormLabel(typeCode: string): string {
  return typeCode === 'KIEM_TRA' ? 'Form điểm' : '9 tiêu chí';
}
