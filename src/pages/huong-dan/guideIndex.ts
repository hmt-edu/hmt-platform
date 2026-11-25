// Danh mục tài liệu Hướng dẫn (A-23-30). Nội dung lấy từ docs/huong-dan/*.md, nhúng lúc build (không máy chủ, không dịch vụ ngoài).
// Muốn thêm hay đổi thứ tự mục: sửa mảng GUIDE_SECTIONS (slug là đường dẫn /crm/huong-dan/<slug>).

import index from 'virtual:huong-dan-muc-luc';
import { stripFrontmatter, type GuideGroup, type GuideMeta, type GuidePortal } from './frontmatter';

export type { GuideGroup, GuidePortal };

export type GuideSection = {
  slug: string;
  /** Số thứ tự hiện trước tên (chỉ nhóm «Bắt đầu»); các nhóm khác không đánh số. */
  no?: string;
  title: string;
  /** Đường dẫn tệp tính từ docs/huong-dan (có thể nằm trong thư mục con). */
  file: string;
  group: GuideGroup;
  /** Mục dành cho một vai: dùng cho khối «Bạn là ai?» ở đầu hướng dẫn. */
  roleLabel?: string;
  /** Khoá phân hệ «cha» (xem GUIDE_PARENTS); chỉ bài nhóm «vai» có. */
  parent?: string;
  /** Cổng nào hiện mục này (mặc định chỉ CRM). */
  portals: GuidePortal[];
  /** Phần đầu bài (priority, flow, screens, checked) giữ nguyên cho công cụ kiểm. */
  meta: GuideMeta;
};

/** Tiêu đề nhóm trên menu (chữ nhỏ, không bấm được). */
export const GUIDE_GROUPS: { key: GuideGroup; title: string }[] = [
  { key: 'bat-dau', title: 'Bắt đầu' },
  { key: 'vai', title: 'Hướng dẫn theo vai trò' },
  { key: 'tra-cuu', title: 'Tra cứu' },
];

/** Các «cha» (phân hệ) trên menu, đúng thứ tự hiện. Bài có `parent` (hoặc `phan_he`) trùng khoá thì là «con». Khoá lạ vẫn hiện, xếp cuối. */
export const GUIDE_PARENTS: { key: string; title: string }[] = [
  { key: 'tu-van', title: 'Tư vấn tuyển sinh' },
  { key: 'ban-hang', title: 'Bán hàng' },
  { key: 'thu-chi', title: 'Thu chi' },
  { key: 'dao-tao', title: 'Đào tạo' },
  { key: 'cham-soc-khach-hang', title: 'Chăm sóc khách hàng' },
  { key: 'cskh', title: 'Chăm sóc khách hàng' },
  { key: 'giao-vien', title: 'Giáo viên' },
  { key: 'chung', title: 'Chung' },
  { key: 'quan-tri', title: 'Quản trị' },
  { key: 'cau-hinh', title: 'Cấu hình' },
];

export type GuideParentNode = { key: string; title: string; children: GuideSection[] };

const collator = new Intl.Collator('vi', { numeric: true });

/** Chữ hiện của «con»: mã luồng (nếu có, ví dụ «QT10A») và tên. */
export const childLabel = (s: GuideSection): string =>
  s.meta.flow && /^[a-z]{1,4}\d+[a-z]?$/i.test(s.meta.flow)
    ? `${s.meta.flow.toUpperCase()} · ${s.title}`
    : s.title;

/**
 * Cây menu hai cấp từ các mục nhóm «vai» có cha: cha theo thứ tự GUIDE_PARENTS (khoá lạ xếp cuối), con theo `order`,
 * rồi theo mã luồng (số tự nhiên: qt2 trước qt10), rồi theo tên. Cha trùng tên (cskh và cham-soc-khach-hang) gộp một.
 */
export function buildParentTree(sections: GuideSection[]): GuideParentNode[] {
  const nodes = new Map<string, GuideParentNode>();
  const titleOf = new Map(GUIDE_PARENTS.map((p) => [p.key, p.title]));
  const merged = (key: string) => titleOf.get(key) ?? key;
  for (const s of sections) {
    if (s.group !== 'vai' || s.parent === undefined) continue;
    const title = merged(s.parent);
    const node = nodes.get(title) ?? { key: s.parent, title, children: [] };
    node.children.push(s);
    nodes.set(title, node);
  }
  const rank = (title: string) => {
    const i = GUIDE_PARENTS.findIndex((p) => p.title === title);
    return i < 0 ? GUIDE_PARENTS.length : i;
  };
  return [...nodes.values()]
    .sort((a, b) => rank(a.title) - rank(b.title) || collator.compare(a.title, b.title))
    .map((n) => ({
      ...n,
      children: [...n.children].sort(
        (a, b) =>
          a.meta.order - b.meta.order ||
          collator.compare(a.meta.flow ?? '', b.meta.flow ?? '') ||
          collator.compare(a.title, b.title),
      ),
    }));
}

/** Mục con thuộc một cha (để biết cha nào mở sẵn). */
export const parentTitleOf = (s: GuideSection): string | undefined =>
  s.group === 'vai' && s.parent !== undefined
    ? (GUIDE_PARENTS.find((p) => p.key === s.parent)?.title ?? s.parent)
    : undefined;

// Mục lục TỰ SINH từ phần đầu (frontmatter) của mọi bài trong docs/huong-dan/**/*.md (xem frontmatter.ts):
// thêm bài = thêm tệp có phần đầu, không sửa tệp này. Thứ tự: nhóm, rồi «order», rồi đường dẫn. Slug «bat-dau» là đường mặc định.
export const GUIDE_SECTIONS: GuideSection[] = index.map((m) => ({
  slug: m.slug,
  ...(m.no !== undefined ? { no: m.no } : {}),
  title: m.title,
  file: m.file,
  group: m.group,
  ...(m.role !== undefined ? { roleLabel: m.role } : {}),
  ...(m.parent !== undefined ? { parent: m.parent } : {}),
  portals: m.portals,
  meta: m,
}));

/** Các mục hiện ở một cổng, giữ đúng thứ tự menu chung (theo «portals» ở phần đầu bài). */
export const sectionsFor = (portal: GuidePortal): GuideSection[] =>
  GUIDE_SECTIONS.filter((s) => s.portals.includes(portal));

export const DEFAULT_SECTION = GUIDE_SECTIONS[0]!;

/** Mục mở đầu tiên của cổng: cổng CRM mở mục đầu; cổng khác mở bài vai của chính nó nếu có, không thì mục đầu của cổng. */
export const defaultSectionFor = (portal: GuidePortal): GuideSection => {
  const list = sectionsFor(portal);
  return portal === 'crm'
    ? DEFAULT_SECTION
    : (list.find((s) => s.group === 'vai') ?? list[0] ?? DEFAULT_SECTION);
};

/** Địa chỉ cũ (trước khi gộp menu) đổi sang mục mới, để liên kết đã gửi cho người dùng không chết. */
export const GUIDE_SLUG_ALIASES: Record<string, string> = {
  chung: 'chung-dang-nhap',
  'bat-dau-nhanh': 'chung-dang-nhap',
  'thao-tac-co-ban': 'chung-danh-sach',
  sale: 'theo-vai-tu-van',
  'cham-soc-khach-hang': 'theo-vai-cskh',
  'ke-toan': 'theo-vai-ke-toan',
  'truong-co-so': 'theo-vai-truong-co-so',
};

/** Thứ tự nút ở khối «Bạn là ai?» (nhãn lạ xếp cuối, theo thứ tự xuất hiện). */
const ROLE_ORDER = [
  'Mọi người',
  'Người mới',
  'Tư vấn tuyển sinh',
  'CSKH và vận hành lớp',
  'Kế toán',
  'Trưởng cơ sở',
  'Giáo viên',
  'Học sinh',
  'Phụ huynh',
  'Quản trị',
  'Người có quyền duyệt',
];

/** Mỗi nhãn vai MỘT nút, trỏ tới bài đầu tiên mang nhãn đó; xếp theo ROLE_ORDER. */
export function roleButtons(sections: GuideSection[]): { label: string; section: GuideSection }[] {
  const first = new Map<string, GuideSection>();
  for (const s of sections) {
    if (s.roleLabel !== undefined && !first.has(s.roleLabel)) first.set(s.roleLabel, s);
  }
  const rank = (label: string) => {
    const i = ROLE_ORDER.indexOf(label);
    return i < 0 ? ROLE_ORDER.length : i;
  };
  return [...first.entries()]
    .map(([label, section]) => ({ label, section }))
    .sort((a, b) => rank(a.label) - rank(b.label));
}

/** Tên mục để hiện: «0. Giới thiệu hệ thống» (có số) hoặc «Vai: Kế toán» (không số). */
export const sectionLabel = (s: GuideSection) =>
  s.no !== undefined ? `${s.no}. ${s.title}` : s.title;

/** Thứ tự đọc đúng như menu: Bắt đầu, vai (không cha), rồi từng cha với các con, rồi Tra cứu. */
export function menuOrder(portal: GuidePortal = 'crm'): GuideSection[] {
  const list = sectionsFor(portal);
  const flat = (g: GuideGroup) =>
    list.filter((s) => s.group === g && !(g === 'vai' && s.parent !== undefined));
  return [
    ...flat('bat-dau'),
    ...flat('vai'),
    ...buildParentTree(list).flatMap((n) => n.children),
    ...flat('tra-cuu'),
  ];
}

/** Mục liền trước và liền sau theo đúng thứ tự menu. */
export function neighbours(
  slug: string,
  portal: GuidePortal = 'crm',
): { prev?: GuideSection; next?: GuideSection } {
  const list = menuOrder(portal);
  const i = list.findIndex((s) => s.slug === slug);
  if (i < 0) return {};
  const prev = list[i - 1];
  const next = list[i + 1];
  return { ...(prev ? { prev } : {}), ...(next ? { next } : {}) };
}

export function findSection(slug: string | undefined): GuideSection | undefined {
  const target = slug !== undefined ? (GUIDE_SLUG_ALIASES[slug] ?? slug) : slug;
  return GUIDE_SECTIONS.find((s) => s.slug === target);
}

const loaders = import.meta.glob('../../../docs/huong-dan/**/*.md', {
  query: '?raw',
  import: 'default',
}) as Record<string, () => Promise<string>>;

/** Đọc nguồn markdown của một mục (tải theo nhu cầu, mỗi file một gói riêng). */
export function loadSource(section: GuideSection): Promise<string> {
  const load = loaders[`../../../docs/huong-dan/${section.file}`];
  if (!load) return Promise.reject(new Error(`Thiếu tài liệu ${section.file}.`));
  return load()
    .then(stripFrontmatter)
    .then((text) => (section.slug === ERROR_CODE_SLUG ? withErrorCodes(text) : text));
}

const ERROR_CODE_SLUG = 'tra-ma-loi';

/** Trang «Tra mã lỗi»: nối bảng mã sinh từ migration (tải riêng, chỉ khi mở trang này). */
async function withErrorCodes(text: string): Promise<string> {
  const { default: codes } = await import('virtual:huong-dan-ma-loi');
  const lines = codes.map((e) => {
    const said = e.messages.length ? e.messages.join(' / ') : '(không có câu báo cố định)';
    const links = e.guides.map((g) => `[${g.title}](/crm/huong-dan/${g.slug})`).join(', ');
    return `- **${e.code}**: ${said}${links ? ` Xem: ${links}.` : ''}`;
  });
  return `${text}\n\n## Danh sách mã (${codes.length})\n\n${lines.join('\n')}\n`;
}

const SNIPPET_MAX = 160; // allow-number: độ dài đoạn trích ở kết quả tìm (trình bày), không phải số nghiệp vụ
const SNIPPET_BEFORE = 40; // allow-number: số chữ lấy trước chỗ khớp (trình bày)
const SNIPPET_AFTER = 120; // allow-number: số chữ lấy sau chỗ khớp (trình bày)

export type SearchSection = Pick<GuideSection, 'slug' | 'title'>;

export type SearchHit = {
  section: SearchSection;
  heading: string;
  headingId: string;
  snippet: string;
};

/** Tìm trong các tài liệu đã đọc (không phân biệt hoa thường, bỏ dấu): trả về tối đa `limit` kết quả, mỗi kết quả một đoạn dưới một tiêu đề. */
export function searchGuide(
  docs: { section: SearchSection; lines: { heading: string; headingId: string; text: string }[] }[],
  query: string,
  limit = 30,
): SearchHit[] {
  const q = fold(query.trim());
  if (q.length < 2) return [];
  const hits: SearchHit[] = [];
  for (const doc of docs) {
    for (const line of doc.lines) {
      const at = fold(line.text).indexOf(q);
      if (at < 0) continue;
      hits.push({
        section: doc.section,
        heading: line.heading,
        headingId: line.headingId,
        snippet:
          line.text.length > SNIPPET_MAX
            ? `${line.text.slice(Math.max(0, at - SNIPPET_BEFORE), at + SNIPPET_AFTER)}…`
            : line.text,
      });
      if (hits.length >= limit) return hits;
    }
  }
  return hits;
}

/** Bỏ dấu tiếng Việt và hạ chữ thường để so khớp. */
export function fold(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'd')
    .toLowerCase();
}
