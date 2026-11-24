import { describe, expect, it } from 'vitest';
import { fold, searchGuide, type GuideSection } from './guideIndex';
import { outline, parseInline, parseMarkdown, plainText, safeHref, slugify } from './markdown';

describe('Hướng dẫn: bộ phân tích markdown (A-23-30)', () => {
  it('tách tiêu đề, đoạn, danh sách lồng và bảng', () => {
    const blocks = parseMarkdown(
      [
        '# Tên tài liệu',
        '',
        'Đoạn một',
        'nối dòng.',
        '',
        '## 1. Đăng nhập',
        '- **Các bước:**',
        '  1. Mở trang',
        '  2. Bấm «Đăng nhập»',
        '- Kết quả',
        '',
        '| Thấy gì | Làm gì |',
        '|---|---|',
        '| Lỗi A | Thử lại |',
      ].join('\n'),
    );
    expect(blocks.map((b) => b.kind)).toEqual(['heading', 'paragraph', 'heading', 'list', 'table']);
    const para = blocks[1];
    expect(para?.kind === 'paragraph' && plainText([para])).toBe('Đoạn một nối dòng.');
    const list = blocks[3];
    if (list?.kind !== 'list') throw new Error('phải là danh sách');
    expect(list.items).toHaveLength(2);
    expect(list.items[0]?.children).toHaveLength(2);
    const table = blocks[4];
    if (table?.kind !== 'table') throw new Error('phải là bảng');
    expect(table.rows).toHaveLength(1);
  });

  it('mã neo bỏ dấu, trùng tên thì thêm số, mục lục chỉ lấy cấp 2 và 3', () => {
    expect(slugify('1. Đăng nhập và đổi mật khẩu')).toBe('1-dang-nhap-va-doi-mat-khau');
    const blocks = parseMarkdown('# A\n## Bước\n### Con\n## Bước');
    expect(outline(blocks).map((o) => o.id)).toEqual(['buoc', 'con', 'buoc-2']);
  });

  it('trong dòng: đậm, mã, ảnh, video; liên kết lạ không thành liên kết', () => {
    const parts = parseInline(
      '**Đậm** `mã` [ẢNH: dang-nhap] [VIDEO: cach-dung] [vào](/crm/lead) [bậy](javascript:alert)',
    );
    expect(parts.map((p) => p.kind)).toEqual([
      'bold',
      'text',
      'code',
      'text',
      'image',
      'text',
      'video',
      'text',
      'link',
      'text',
      'text',
    ]);
    expect(safeHref('javascript:alert(1)')).toBeNull();
    expect(safeHref('//evil.example')).toBeNull();
    expect(safeHref('https://example.com')).toBe('https://example.com');
    expect(safeHref('/crm/lead')).toBe('/crm/lead');
  });

  it('khối mã giữ nguyên chữ, không tách tiêu đề trong khối mã', () => {
    const blocks = parseMarkdown('```\n# không phải tiêu đề\n- không phải mục\n```');
    expect(blocks).toEqual([{ kind: 'code', text: '# không phải tiêu đề\n- không phải mục' }]);
  });
});

describe('Hướng dẫn: tìm kiếm (A-23-30)', () => {
  const section: GuideSection = {
    slug: 'x',
    no: '1',
    title: 'Mục X',
    file: 'x.md',
    group: 'bat-dau',
  };
  const docs = [
    {
      section,
      lines: [
        { heading: 'Đăng nhập', headingId: 'dang-nhap', text: 'Nhập tên đăng nhập và mật khẩu.' },
        { heading: 'Xếp lớp', headingId: 'xep-lop', text: 'Bấm «Xếp lớp» rồi chọn lớp.' },
      ],
    },
  ];
  it('không phân biệt hoa thường và dấu', () => {
    expect(fold('Xếp LỚP đ')).toBe('xep lop d');
    expect(searchGuide(docs, 'xep lop').map((h) => h.headingId)).toEqual(['xep-lop']);
    expect(searchGuide(docs, 'MAT KHAU')[0]?.heading).toBe('Đăng nhập');
  });
  it('từ khoá quá ngắn hoặc không có thì trả rỗng; có giới hạn số kết quả', () => {
    expect(searchGuide(docs, 'x')).toEqual([]);
    expect(searchGuide(docs, 'khong-co-gi')).toEqual([]);
    expect(searchGuide(docs, 'lop', 1)).toHaveLength(1);
  });

  it('danh sách đánh số bắt đầu từ số 3 sau một bảng: giữ số đầu, không đếm lại từ 1', () => {
    const blocks = parseMarkdown('1. a\n2. b\n\n| x | y |\n|---|---|\n| 1 | 2 |\n\n3. c\n4. d');
    const lists = blocks.filter((b) => b.kind === 'list');
    expect(lists).toHaveLength(2);
    expect(lists[1]).toMatchObject({ ordered: true, start: 3 });
    expect(lists[0]).not.toHaveProperty('start');
  });
});
