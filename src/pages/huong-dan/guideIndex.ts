// Danh mục tài liệu Hướng dẫn (A-23-30). Nội dung lấy từ docs/huong-dan/*.md, nhúng lúc build (không máy chủ, không dịch vụ ngoài).
// Muốn thêm hay đổi thứ tự mục: sửa mảng GUIDE_SECTIONS (slug là đường dẫn /crm/huong-dan/<slug>).

export type GuideGroup = 'bat-dau' | 'vai' | 'tra-cuu';
export type GuideSection = {
  slug: string;
  /** Số thứ tự hiện trước tên (chỉ nhóm «Bắt đầu»); các nhóm khác không đánh số. */
  no?: string;
  title: string;
  file: string;
  group: GuideGroup;
  /** Mục dành cho một vai: dùng cho khối «Bạn là ai?» ở đầu hướng dẫn. */
  roleLabel?: string;
};

/** Tiêu đề nhóm trên menu (chữ nhỏ, không bấm được). */
export const GUIDE_GROUPS: { key: GuideGroup; title: string }[] = [
  { key: 'bat-dau', title: 'Bắt đầu' },
  { key: 'vai', title: 'Hướng dẫn theo vai trò' },
  { key: 'tra-cuu', title: 'Tra cứu' },
];

// MỘT danh sách, không trùng. Thứ tự ở đây là thứ tự menu và thứ tự «Bài trước / Bài sau». Slug bat-dau là đường mặc định.
// Mọi file .md trong docs/huong-dan (trừ README, CHUP-ANH) phải có ở đây: guideIndex.test.ts giữ.
export const GUIDE_SECTIONS: GuideSection[] = [
  {
    slug: 'bat-dau',
    no: '0',
    title: 'Giới thiệu hệ thống',
    file: '00-gioi-thieu.md',
    group: 'bat-dau',
  },
  {
    slug: 'bat-dau-nhanh',
    no: '1',
    title: 'Bắt đầu nhanh',
    file: '01-bat-dau-nhanh.md',
    group: 'bat-dau',
  },
  {
    slug: 'thao-tac-co-ban',
    no: '2',
    title: 'Thao tác cơ bản dùng chung',
    file: '02-thao-tac-co-ban.md',
    group: 'bat-dau',
  },
  {
    slug: 'theo-vai-tu-van',
    title: 'Vai: Tư vấn tuyển sinh',
    file: '03-tu-van-tuyen-sinh.md',
    group: 'vai',
    roleLabel: 'Tư vấn tuyển sinh',
  },
  {
    slug: 'theo-vai-cskh',
    title: 'Vai: CSKH và vận hành lớp',
    file: '03-cskh.md',
    group: 'vai',
    roleLabel: 'CSKH và vận hành lớp',
  },
  {
    slug: 'theo-vai-ke-toan',
    title: 'Vai: Kế toán',
    file: '03-ke-toan.md',
    group: 'vai',
    roleLabel: 'Kế toán',
  },
  {
    slug: 'theo-vai-truong-co-so',
    title: 'Vai: Trưởng cơ sở',
    file: '03-truong-co-so.md',
    group: 'vai',
    roleLabel: 'Trưởng cơ sở',
  },
  {
    slug: 'theo-vai-hoc-sinh',
    title: 'Vai: Học sinh',
    file: '03-hoc-sinh.md',
    group: 'vai',
    roleLabel: 'Học sinh',
  },
  {
    slug: 'theo-vai-phu-huynh',
    title: 'Vai: Phụ huynh',
    file: '03-phu-huynh.md',
    group: 'vai',
    roleLabel: 'Phụ huynh',
  },
  {
    slug: 'giao-vien',
    title: 'Vai: Giáo viên',
    file: 'giao-vien.md',
    group: 'vai',
    roleLabel: 'Giáo viên',
  },
  {
    slug: 'quan-tri',
    title: 'Vai: Quản trị',
    file: 'quan-tri.md',
    group: 'vai',
    roleLabel: 'Quản trị',
  },
  { slug: 'tu-dien', title: 'Từ điển thuật ngữ', file: '04-tu-dien.md', group: 'tra-cuu' },
  { slug: 'hoi-dap', title: 'Hỏi đáp và lỗi thường gặp', file: '05-hoi-dap.md', group: 'tra-cuu' },
];

export type GuidePortal = 'crm' | 'gv';

/** Cổng giáo viên (A-23-38) chỉ hiện ba bài: thao tác cơ bản, bài vai Giáo viên, hỏi đáp. */
const GV_SLUGS = ['thao-tac-co-ban', 'giao-vien', 'hoi-dap'];

/** Các mục hiện ở một cổng, giữ đúng thứ tự menu chung. */
export const sectionsFor = (portal: GuidePortal): GuideSection[] =>
  portal === 'gv' ? GUIDE_SECTIONS.filter((s) => GV_SLUGS.includes(s.slug)) : GUIDE_SECTIONS;

/** Mục mở đầu tiên của cổng (cổng CRM: giới thiệu; cổng Giáo viên: bài vai Giáo viên). */
export const defaultSectionFor = (portal: GuidePortal): GuideSection =>
  portal === 'gv' ? GUIDE_SECTIONS.find((s) => s.slug === 'giao-vien')! : DEFAULT_SECTION;

/** Địa chỉ cũ (trước khi gộp menu) đổi sang mục mới, để liên kết đã gửi cho người dùng không chết. */
export const GUIDE_SLUG_ALIASES: Record<string, string> = {
  chung: 'bat-dau-nhanh',
  sale: 'theo-vai-tu-van',
  'cham-soc-khach-hang': 'theo-vai-cskh',
  'ke-toan': 'theo-vai-ke-toan',
  'truong-co-so': 'theo-vai-truong-co-so',
};

/** Tên mục để hiện: «0. Giới thiệu hệ thống» (có số) hoặc «Vai: Kế toán» (không số). */
export const sectionLabel = (s: GuideSection) =>
  s.no !== undefined ? `${s.no}. ${s.title}` : s.title;

/** Mục liền trước và liền sau theo đúng thứ tự menu. */
export function neighbours(
  slug: string,
  portal: GuidePortal = 'crm',
): { prev?: GuideSection; next?: GuideSection } {
  const list = sectionsFor(portal);
  const i = list.findIndex((s) => s.slug === slug);
  if (i < 0) return {};
  const prev = list[i - 1];
  const next = list[i + 1];
  return { ...(prev ? { prev } : {}), ...(next ? { next } : {}) };
}

export const DEFAULT_SECTION = GUIDE_SECTIONS[0]!;

export function findSection(slug: string | undefined): GuideSection | undefined {
  const target = slug !== undefined ? (GUIDE_SLUG_ALIASES[slug] ?? slug) : slug;
  return GUIDE_SECTIONS.find((s) => s.slug === target);
}

const loaders = import.meta.glob('../../../docs/huong-dan/*.md', {
  query: '?raw',
  import: 'default',
}) as Record<string, () => Promise<string>>;

/** Đọc nguồn markdown của một mục (tải theo nhu cầu, mỗi file một gói riêng). */
export function loadSource(section: GuideSection): Promise<string> {
  const load = loaders[`../../../docs/huong-dan/${section.file}`];
  if (!load) return Promise.reject(new Error(`Thiếu tài liệu ${section.file}.`));
  return load();
}

const SNIPPET_MAX = 160; // allow-number: độ dài đoạn trích ở kết quả tìm (trình bày), không phải số nghiệp vụ
const SNIPPET_BEFORE = 40; // allow-number: số chữ lấy trước chỗ khớp (trình bày)
const SNIPPET_AFTER = 120; // allow-number: số chữ lấy sau chỗ khớp (trình bày)

export type SearchHit = {
  section: GuideSection;
  heading: string;
  headingId: string;
  snippet: string;
};

/** Tìm trong các tài liệu đã đọc (không phân biệt hoa thường, bỏ dấu): trả về tối đa `limit` kết quả, mỗi kết quả một đoạn dưới một tiêu đề. */
export function searchGuide(
  docs: { section: GuideSection; lines: { heading: string; headingId: string; text: string }[] }[],
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
