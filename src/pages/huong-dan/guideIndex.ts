// Danh mục tài liệu Hướng dẫn (A-23-30). Nội dung lấy từ docs/huong-dan/*.md, nhúng lúc build (không máy chủ, không dịch vụ ngoài).
// Muốn thêm hay đổi thứ tự mục: sửa mảng GUIDE_SECTIONS (slug là đường dẫn /crm/huong-dan/<slug>).

export type GuideSection = { slug: string; no: number; title: string; file: string };

export const GUIDE_SECTIONS: GuideSection[] = [
  { slug: 'bat-dau', no: 0, title: 'Bắt đầu: đăng nhập, menu, tìm và lọc', file: 'chung.md' },
  { slug: 'sale', no: 1, title: 'Sale và Tuyển sinh', file: 'sale.md' },
  { slug: 'cham-soc-khach-hang', no: 2, title: 'Chăm sóc khách hàng', file: 'cskh.md' },
  { slug: 'ke-toan', no: 3, title: 'Kế toán', file: 'ke-toan.md' },
  { slug: 'truong-co-so', no: 4, title: 'Trưởng cơ sở', file: 'truong-co-so.md' },
  { slug: 'giao-vien', no: 5, title: 'Giáo viên', file: 'giao-vien.md' },
  { slug: 'quan-tri', no: 6, title: 'Quản trị', file: 'quan-tri.md' },
  { slug: 'hoi-dap', no: 7, title: 'Hỏi đáp và lỗi thường gặp', file: '05-hoi-dap.md' },
];

export const DEFAULT_SECTION = GUIDE_SECTIONS[0]!;

export function findSection(slug: string | undefined): GuideSection | undefined {
  return GUIDE_SECTIONS.find((s) => s.slug === slug);
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
