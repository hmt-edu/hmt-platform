// Phần đầu (frontmatter) của mỗi bài hướng dẫn (A-23-42). Mục lục tự sinh từ đây, nên nhiều người viết song song không sửa chung một file.
// Dạng: dòng «khoá: giá trị» nằm giữa hai dòng «---» ở đầu tệp; mảng viết «[a, b]». Không dùng thư viện ngoài.
//   title (bắt buộc) · group: bat-dau | vai | tra-cuu (bắt buộc) · slug (mặc định: đường dẫn bỏ .md, «/» thành «-»)
//   no (số hiện trước tên, nhóm «Bắt đầu») · order (số, nhỏ lên trước) · role (nhãn nút «Bạn là ai?») · portals: [crm, gv] (mặc định crm)
//   parent (khoá phân hệ làm «cha» trên menu, mặc định lấy từ phan_he) · priority: P1|P2|P3 · flow (mã luồng trong KE-NGHIEP-VU) · screens: [mã màn] · checked (ngày đi thử lần cuối, yyyy-mm-dd)

export type GuideGroup = 'bat-dau' | 'vai' | 'tra-cuu';
export const GUIDE_GROUP_KEYS: GuideGroup[] = ['bat-dau', 'vai', 'tra-cuu'];
export type GuidePortal = 'crm' | 'gv';
export const GUIDE_PORTAL_KEYS: GuidePortal[] = ['crm', 'gv'];

export type GuideMeta = {
  slug: string;
  title: string;
  group: GuideGroup;
  no?: string;
  order: number;
  role?: string;
  portals: GuidePortal[];
  priority?: string;
  flow?: string;
  /** Khoá phân hệ làm «cha» trên menu (chỉ bài nhóm «vai»); không có thì bài đứng riêng. */
  parent?: string;
  screens: string[];
  checked?: string;
  /** Đường dẫn tệp tính từ docs/huong-dan, ví dụ «03-cskh.md» hoặc «tu-van/nhap-lead.md». */
  file: string;
};

/** Khoá cha từ chữ viết tự do: bỏ dấu, chữ thường, khoảng trắng thành gạch nối («Chăm sóc khách hàng» → cham-soc-khach-hang). */
export function parentKey(text: string): string {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/gi, 'd')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

const FENCE = /^---[ \t]*$/;
const DEFAULT_ORDER = 1000; // allow-number: thứ tự mặc định cho bài chưa đặt order (sắp xếp mục lục), không phải số nghiệp vụ

/** Tách phần đầu và thân bài. Không có phần đầu thì trả `raw: null` và thân là nguyên văn. */
export function splitFrontmatter(text: string): { raw: string | null; body: string } {
  const clean = text.startsWith('\uFEFF') ? text.slice(1) : text;
  const lines = clean.split('\n');
  const first = lines[0];
  if (first === undefined || !FENCE.test(first.replace(/\r$/, '')))
    return { raw: null, body: text };
  const end = lines.findIndex((l, i) => i > 0 && FENCE.test(l.replace(/\r$/, '')));
  if (end < 0) return { raw: null, body: text };
  return { raw: lines.slice(1, end).join('\n'), body: lines.slice(end + 1).join('\n') };
}

/** Bỏ phần đầu để dựng và tìm kiếm chỉ trên nội dung bài. */
export const stripFrontmatter = (text: string): string => splitFrontmatter(text).body;

function unquote(v: string): string {
  const t = v.trim();
  return t.length >= 2 && /^(["']).*\1$/.test(t) ? t.slice(1, -1) : t;
}

function parseValue(v: string): string | string[] {
  const t = v.trim();
  if (t.startsWith('[') && t.endsWith(']'))
    return t
      .slice(1, -1)
      .split(',')
      .map(unquote)
      .filter((x) => x !== '');
  return unquote(t);
}

/** Đọc các cặp khoá-giá trị; dòng trống và dòng bắt đầu bằng # bị bỏ qua. */
export function parseFrontmatterFields(raw: string): Record<string, string | string[]> {
  const out: Record<string, string | string[]> = {};
  for (const line of raw.split('\n')) {
    const t = line.replace(/\r$/, '');
    if (t.trim() === '' || t.trim().startsWith('#')) continue;
    const at = t.indexOf(':');
    if (at <= 0) throw new Error(`Dòng không đúng dạng «khoá: giá trị»: ${t}`);
    out[t.slice(0, at).trim()] = parseValue(t.slice(at + 1));
  }
  return out;
}

const str = (v: string | string[] | undefined): string | undefined =>
  typeof v === 'string' && v !== '' ? v : undefined;
const list = (v: string | string[] | undefined): string[] =>
  Array.isArray(v) ? v : typeof v === 'string' && v !== '' ? [v] : [];

/** Dựng mục lục một bài từ tệp. Trả null nếu tệp không có phần đầu (không phải bài hướng dẫn). Sai khuôn thì ném lỗi nêu rõ tệp. */
export function metaFromSource(file: string, text: string): GuideMeta | null {
  const { raw } = splitFrontmatter(text);
  if (raw === null) return null;
  const fail = (msg: string): never => {
    throw new Error(`docs/huong-dan/${file}: ${msg}`);
  };
  let f: Record<string, string | string[]>;
  try {
    f = parseFrontmatterFields(raw);
  } catch (e) {
    return fail(e instanceof Error ? e.message : String(e));
  }
  // Chấp nhận cả kiểu viết theo quy cách đợt 1 (HUONG-DAN-DOT1-QUY-CACH): id, ten, vai, phan_he, ma_man, uu_tien, cap_nhat.
  const title = str(f.title) ?? str(f.ten) ?? fail('thiếu «title» (hoặc «ten»)');
  const group =
    str(f.group) ??
    (f.ten !== undefined ? 'vai' : fail('thiếu «group» (bat-dau, vai hoặc tra-cuu)'));
  if (!GUIDE_GROUP_KEYS.includes(group as GuideGroup)) fail(`«group» không hợp lệ: ${group}`);
  const portals = list(f.portals).length
    ? list(f.portals)
    : list(f.vai).includes('giao-vien')
      ? ['crm', 'gv']
      : [];
  for (const p of portals)
    if (!GUIDE_PORTAL_KEYS.includes(p as GuidePortal)) fail(`«portals» không hợp lệ: ${p}`);
  const orderText = str(f.order);
  const order = orderText === undefined ? DEFAULT_ORDER : Number(orderText);
  if (!Number.isFinite(order)) fail(`«order» phải là số: ${orderText}`);
  const slug =
    str(f.slug) ??
    (str(f.id) ? (str(f.id) ?? '').toLowerCase() : file.replace(/\.md$/, '').replace(/\//g, '-'));
  if (!/^[a-z0-9-]+$/.test(slug))
    fail(`«slug» chỉ gồm chữ thường không dấu, số, gạch nối: ${slug}`);
  const parentText = str(f.parent) ?? str(f.phan_he);
  const parent = parentText !== undefined ? parentKey(parentText) : undefined;
  const no = str(f.no);
  const role = str(f.role);
  const priority = str(f.priority) ?? str(f.uu_tien);
  const flow = str(f.flow) ?? str(f.id);
  const checked = str(f.checked) ?? str(f.cap_nhat);
  return {
    slug,
    title,
    group: group as GuideGroup,
    ...(no !== undefined ? { no } : {}),
    order,
    ...(role !== undefined ? { role } : {}),
    ...(parent ? { parent } : {}),
    portals: portals.length > 0 ? (portals as GuidePortal[]) : ['crm'],
    ...(priority !== undefined ? { priority } : {}),
    ...(flow !== undefined ? { flow } : {}),
    screens: list(f.screens).length ? list(f.screens) : list(f.ma_man),
    ...(checked !== undefined ? { checked } : {}),
    file,
  };
}

/** Sắp theo nhóm (đúng thứ tự khai báo), rồi order, rồi đường dẫn tệp. */
export function sortGuideMetas(metas: GuideMeta[]): GuideMeta[] {
  return [...metas].sort(
    (a, b) =>
      GUIDE_GROUP_KEYS.indexOf(a.group) - GUIDE_GROUP_KEYS.indexOf(b.group) ||
      a.order - b.order ||
      a.file.localeCompare(b.file),
  );
}
