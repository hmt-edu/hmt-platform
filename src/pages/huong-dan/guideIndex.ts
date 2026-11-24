// Danh mục tài liệu Hướng dẫn (A-23-30). Nội dung lấy từ docs/huong-dan/*.md, nhúng lúc build (không máy chủ, không dịch vụ ngoài).
// Muốn thêm hay đổi thứ tự mục: sửa mảng GUIDE_SECTIONS (slug là đường dẫn /crm/huong-dan/<slug>).

export type GuideSection = { slug: string; no: string; title: string; file: string };

// Thứ tự: 0 giới thiệu (mục mở đầu, slug bat-dau là đường mặc định), 1 bắt đầu nhanh, 2 thao tác cơ bản, 3 theo vai, 4 từ điển, 5 hỏi đáp,
// rồi các hướng dẫn chi tiết theo vai (bản đầu, còn dùng). Mọi file .md trong docs/huong-dan (trừ README, CHUP-ANH) phải có ở đây: guideIndex.test.ts giữ.
export const GUIDE_SECTIONS: GuideSection[] = [
  { slug: 'bat-dau', no: '0', title: 'Giới thiệu hệ thống', file: '00-gioi-thieu.md' },
  { slug: 'bat-dau-nhanh', no: '1', title: 'Bắt đầu nhanh', file: '01-bat-dau-nhanh.md' },
  {
    slug: 'thao-tac-co-ban',
    no: '2',
    title: 'Thao tác cơ bản dùng chung',
    file: '02-thao-tac-co-ban.md',
  },
  {
    slug: 'theo-vai-tu-van',
    no: '3a',
    title: 'Theo vai: Tư vấn tuyển sinh',
    file: '03-tu-van-tuyen-sinh.md',
  },
  { slug: 'theo-vai-cskh', no: '3b', title: 'Theo vai: CSKH và vận hành lớp', file: '03-cskh.md' },
  { slug: 'theo-vai-ke-toan', no: '3c', title: 'Theo vai: Kế toán', file: '03-ke-toan.md' },
  {
    slug: 'theo-vai-truong-co-so',
    no: '3d',
    title: 'Theo vai: Trưởng cơ sở',
    file: '03-truong-co-so.md',
  },
  { slug: 'tu-dien', no: '4', title: 'Từ điển thuật ngữ', file: '04-tu-dien.md' },
  { slug: 'hoi-dap', no: '5', title: 'Hỏi đáp và lỗi thường gặp', file: '05-hoi-dap.md' },
  {
    slug: 'chung',
    no: '6',
    title: 'Hướng dẫn chung (đăng nhập, menu, tìm và lọc)',
    file: 'chung.md',
  },
  { slug: 'sale', no: '7', title: 'Sale và Tuyển sinh', file: 'sale.md' },
  { slug: 'cham-soc-khach-hang', no: '8', title: 'Chăm sóc khách hàng', file: 'cskh.md' },
  { slug: 'ke-toan', no: '9', title: 'Kế toán', file: 'ke-toan.md' },
  { slug: 'truong-co-so', no: '10', title: 'Trưởng cơ sở', file: 'truong-co-so.md' },
  { slug: 'giao-vien', no: '11', title: 'Giáo viên', file: 'giao-vien.md' },
  { slug: 'quan-tri', no: '12', title: 'Quản trị', file: 'quan-tri.md' },
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
