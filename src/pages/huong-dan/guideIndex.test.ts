import { describe, expect, it } from 'vitest';
import {
  GUIDE_GROUPS,
  defaultSectionFor,
  sectionsFor,
  GUIDE_SECTIONS,
  GUIDE_SLUG_ALIASES,
  findSection,
  buildRoleTree,
  GUIDE_ROLES,
  isRoleOverview,
  childLabel,
  menuOrder,
  roleButtons,
  neighbours,
} from './guideIndex';
import { stripFrontmatter } from './frontmatter';

// Tệp trong docs/huong-dan KHÔNG có phần đầu (frontmatter) thì không phải bài người dùng: chỉ các tệp này được phép.
const NOT_GUIDE = new Set(['README.md', 'CHUP-ANH.md', 'KE-NGHIEP-VU.md', 'video-huong-dan.md']);

// Liệt kê tệp thật bằng chính cơ chế guideIndex dùng (Vite glob), gồm cả thư mục con.
const raw = import.meta.glob<string>('../../../docs/huong-dan/**/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
});
const PREFIX = '../../../docs/huong-dan/';
const found = Object.keys(raw).map((path) => path.slice(PREFIX.length));

describe('Danh mục Hướng dẫn (guideIndex)', () => {
  it('mọi tệp .md trong docs/huong-dan có phần đầu thì vào danh mục; không có thì phải nằm trong danh sách ngoại lệ', () => {
    const registered = new Set(GUIDE_SECTIONS.map((s) => s.file));
    const lech = found.filter((f) => {
      const hasHead = (raw[`${PREFIX}${f}`] ?? '').startsWith('---');
      return hasHead ? !registered.has(f) : !NOT_GUIDE.has(f.slice(f.lastIndexOf('/') + 1));
    });
    expect(
      lech,
      `Thêm phần đầu (title, group…) vào bài, hoặc đưa vào NOT_GUIDE: ${lech.join(', ')}`,
    ).toEqual([]);
  });

  it('mọi mục trỏ tới tệp có thật', () => {
    const ghost = GUIDE_SECTIONS.filter((s) => !found.includes(s.file)).map((s) => s.file);
    expect(ghost).toEqual([]);
  });

  it('slug và số thứ tự không trùng; mục đầu giữ slug mặc định bat-dau', () => {
    const slugs = GUIDE_SECTIONS.map((s) => s.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
    const nos = GUIDE_SECTIONS.map((s) => s.no).filter((n) => n !== undefined);
    expect(new Set(nos).size).toBe(nos.length);
    expect(GUIDE_SECTIONS[0]?.slug).toBe('bat-dau');
  });
});

describe('Menu gọn (A-23-37)', () => {
  it('mọi mục thuộc đúng một nhóm có tiêu đề; không còn bài trùng nội dung cũ', () => {
    const keys = new Set(GUIDE_GROUPS.map((g) => g.key));
    expect(GUIDE_SECTIONS.every((s) => keys.has(s.group))).toBe(true);
    const files = GUIDE_SECTIONS.map((s) => s.file);
    for (const old of ['chung.md', 'sale.md', 'cskh.md', 'ke-toan.md', 'truong-co-so.md'])
      expect(files).not.toContain(old);
  });
  it('địa chỉ cũ đổi sang mục mới có thật', () => {
    for (const to of Object.values(GUIDE_SLUG_ALIASES)) expect(findSection(to)).toBeDefined();
    expect(findSection('sale')?.slug).toBe('theo-vai-tu-van');
  });
  it('bài trước / bài sau theo đúng thứ tự menu; đầu không có bài trước, cuối không có bài sau', () => {
    expect(neighbours(GUIDE_SECTIONS[0]!.slug).prev).toBeUndefined();
    expect(neighbours(GUIDE_SECTIONS[0]!.slug).next?.slug).toBe(GUIDE_SECTIONS[1]!.slug);
    expect(neighbours(GUIDE_SECTIONS[GUIDE_SECTIONS.length - 1]!.slug).next).toBeUndefined();
  });
});

// Số trên menu phải khớp số ở dòng tiêu đề của bài (B-23-38): mục có số ở tiêu đề thì menu hiện đúng số đó.
const sources = raw;

describe('Số mục trên menu khớp tiêu đề bài', () => {
  it('tiêu đề bài bắt đầu bằng «<số>. » thì số đó bằng số mục trên menu', () => {
    const lech: string[] = [];
    for (const s of GUIDE_SECTIONS) {
      const text = stripFrontmatter(sources[`${PREFIX}${s.file}`] ?? '');
      const m = /^# (\d+[a-z]?)\.\s/.exec(text);
      if (m && m[1] !== s.no) lech.push(`${s.file}: tiêu đề ${m[1]}, menu ${s.no}`);
    }
    expect(lech).toEqual([]);
  });
});

describe('Hướng dẫn cổng Giáo viên (A-23-38)', () => {
  it('chỉ hiện bài gắn cổng Giáo viên (phần chung, bài Giáo viên, hỏi đáp); không có bài vai CRM; mở đầu bằng bài Giáo viên', () => {
    const slugs = sectionsFor('gv').map((s) => s.slug);
    expect(slugs).toEqual(expect.arrayContaining(['chung-dang-nhap', 'giao-vien', 'hoi-dap']));
    expect(slugs).not.toContain('theo-vai-ke-toan');
    expect(slugs).not.toContain('bat-dau');
    expect(defaultSectionFor('gv').slug).toBe('giao-vien');
    expect(defaultSectionFor('crm').slug).toBe('bat-dau');
  });
  it('bài trước/sau của cổng Giáo viên không nhảy sang bài CRM', () => {
    const n = neighbours('giao-vien', 'gv');
    expect(sectionsFor('gv').map((x) => x.slug)).toContain(n.prev?.slug);
    expect(n.next).toMatchObject({ slug: 'giao-vien-gv1-hom-nay' });
    expect(neighbours('giao-vien-gv13-cham-kiem-tra', 'gv').next).toMatchObject({
      slug: 'hoi-dap',
    });
    expect(neighbours('hoi-dap', 'gv').next).toBeUndefined();
  });
});

describe('Menu theo vai (A-24-07)', () => {
  const sec = (
    slug: string,
    roles: string[],
    order: number,
    opts: { flow?: string; parent?: string; title?: string; roleLabel?: string } = {},
  ) =>
    ({
      slug,
      title: opts.title ?? `Bài ${slug}`,
      file: `${slug}.md`,
      group: 'vai',
      ...(opts.parent ? { parent: opts.parent } : {}),
      ...(opts.roleLabel ? { roleLabel: opts.roleLabel } : {}),
      portals: ['crm'],
      meta: { order, roles, ...(opts.flow ? { flow: opts.flow } : {}) },
    }) as unknown as (typeof GUIDE_SECTIONS)[number];

  it('vai theo thứ tự khai báo; trong vai: Tổng quan trước, rồi order, phân hệ, mã luồng tự nhiên (ts2 trước ts10)', () => {
    const tree = buildRoleTree([
      sec('a', ['quan-tri'], 1000, { flow: 'qt10' }),
      sec('b', ['quan-tri'], 1000, { flow: 'qt2' }),
      sec('c', ['tu-van'], 1000, { flow: 'ts1' }),
      sec('d', ['quan-tri'], 5, { flow: 'qt99' }),
      sec('e', ['quan-tri'], 9999, { title: 'Vai: Quản trị' }),
    ]);
    expect(tree.map((n) => n.title)).toEqual(['Tư vấn tuyển sinh', 'Quản trị']);
    expect(tree[1]?.children.map((c) => c.slug)).toEqual(['e', 'd', 'b', 'a']);
  });

  it('bài dùng chung nhiều vai chỉ xếp một chỗ (vai đầu trong «vai»); bài không thuộc vai nào thì không vào cây', () => {
    const tree = buildRoleTree([
      sec('x', ['ke-toan', 'cskh'], 1000),
      sec('y', ['chung'], 1000),
      sec('z', [], 1000),
    ]);
    expect(tree.map((n) => n.title)).toEqual(['Kế toán']);
    expect(tree[0]?.children.map((c) => c.slug)).toEqual(['x']);
  });

  it('chữ «con»: «Tổng quan» cho bài «Vai: …», có mã luồng khi hợp lệ, không thì chỉ tên', () => {
    expect(childLabel(sec('o', ['cskh'], 1, { title: 'Vai: CSKH' }))).toBe('Tổng quan');
    expect(childLabel(sec('a', ['cskh'], 1, { flow: 'qt10a' }))).toBe('QT10A · Bài a');
    expect(childLabel(sec('a', ['cskh'], 1, { flow: 'mot-id-dai-dong' }))).toBe('Bài a');
  });

  it('dữ liệu thật: mỗi bài nhóm «vai» đúng MỘT chỗ trên menu, không vai nào trống', () => {
    const vai = GUIDE_SECTIONS.filter((s) => s.group === 'vai');
    const tree = buildRoleTree(GUIDE_SECTIONS);
    const slugs = tree.flatMap((n) => n.children.map((c) => c.slug));
    expect(new Set(slugs).size).toBe(slugs.length);
    expect(slugs.sort()).toEqual(vai.map((s) => s.slug).sort());
    expect(tree.map((n) => n.key)).toEqual(GUIDE_ROLES.map((r) => r.key));
    for (const n of tree) expect(n.children.length, `vai ${n.title} trống`).toBeGreaterThan(0);
  });

  it('mỗi vai có đúng một bài «Tổng quan» đứng đầu', () => {
    for (const n of buildRoleTree(GUIDE_SECTIONS)) {
      expect(n.children.filter(isRoleOverview).length, n.title).toBe(1);
      expect(isRoleOverview(n.children[0]!), n.title).toBe(true);
    }
  });
});

describe('Thứ tự đọc theo menu (A-23-49)', () => {
  it('menuOrder có đủ mọi mục một lần và Bài trước/Bài sau đi theo nó', () => {
    const order = menuOrder('crm').map((s) => s.slug);
    expect(order.sort()).toEqual(
      sectionsFor('crm')
        .map((s) => s.slug)
        .sort(),
    );
    const list = menuOrder('crm');
    const mid = list[Math.floor(list.length / 2)]!;
    const { prev, next } = neighbours(mid.slug);
    expect(prev?.slug).toBe(list[list.indexOf(mid) - 1]?.slug);
    expect(next?.slug).toBe(list[list.indexOf(mid) + 1]?.slug);
  });
});

describe('Khối «Bạn là ai?» mỗi vai một nút (A-24-05)', () => {
  it('không nhãn nào xuất hiện hai lần, mỗi nút trỏ tới bài có đúng nhãn đó', () => {
    for (const portal of ['crm', 'gv'] as const) {
      const buttons = roleButtons(sectionsFor(portal));
      const labels = buttons.map((b) => b.label);
      expect(new Set(labels).size).toBe(labels.length);
      for (const b of buttons) expect(b.section.roleLabel).toBe(b.label);
    }
  });

  it('nhãn gần trùng «Quản trị viên» đã gộp vào «Quản trị»', () => {
    const labels = GUIDE_SECTIONS.map((s) => s.roleLabel);
    expect(labels).not.toContain('Quản trị viên');
  });

  it('giữ thứ tự hợp lý và bài đầu của vai; nhãn lạ xếp cuối', () => {
    const mk = (slug: string, role: string) =>
      ({
        slug,
        title: slug,
        roleLabel: role,
        group: 'vai',
        portals: ['crm'],
        meta: {},
      }) as unknown as (typeof GUIDE_SECTIONS)[number];
    const out = roleButtons([
      mk('a1', 'Quản trị'),
      mk('b1', 'Lạ'),
      mk('c1', 'Tư vấn tuyển sinh'),
      mk('c2', 'Tư vấn tuyển sinh'),
      mk('d1', 'Mọi người'),
    ]);
    expect(out.map((b) => b.label)).toEqual(['Mọi người', 'Tư vấn tuyển sinh', 'Quản trị', 'Lạ']);
    expect(out.find((b) => b.label === 'Tư vấn tuyển sinh')?.section.slug).toBe('c1');
  });

  it('bài nhóm «vai» thắng bài nhóm «bắt đầu» đứng trước (Quản trị → bài vai Quản trị)', () => {
    const mk = (slug: string, role: string, group: 'bat-dau' | 'vai') =>
      ({
        slug,
        title: slug,
        roleLabel: role,
        group,
        portals: ['crm'],
        meta: {},
      }) as unknown as (typeof GUIDE_SECTIONS)[number];
    const out = roleButtons([
      mk('xac-thuc', 'Quản trị', 'bat-dau'),
      mk('quan-tri', 'Quản trị', 'vai'),
    ]);
    expect(out.find((b) => b.label === 'Quản trị')?.section.slug).toBe('quan-tri');
  });

  it('dữ liệu thật: nút của mỗi vai có bài nhóm «vai» thì trỏ vào bài nhóm «vai»', () => {
    const list = sectionsFor('crm');
    for (const b of roleButtons(list)) {
      if (list.some((s) => s.roleLabel === b.label && s.group === 'vai')) {
        expect(b.section.group).toBe('vai');
      }
    }
  });
});
