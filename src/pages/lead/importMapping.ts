// Ghép cột của file nhập lead (TS-04 bước 2): đoán cột theo tên, mỗi trường hệ thống chỉ ghép một cột, đổi các dòng file thành hàng
// gửi hàm `import_leads` (khoá như `app.import_one_lead`). Nguồn và kênh trong file là TÊN hoặc mã; đổi sang mã theo danh mục,
// không khớp thì gửi nguyên chữ để hàm trong cơ sở dữ liệu báo lỗi (dòng đó hiện ở bước Xem trước).
import { foldText } from '../../lib/format';
import type { CsvTable } from './importCsv';

export type ImportField =
  | 'parent_name'
  | 'parent_phone'
  | 'student_name'
  | 'student_birth_year'
  | 'source'
  | 'channel'
  | 'need'
  | 'owner_email';

export const IMPORT_FIELDS: {
  key: ImportField;
  label: string;
  required: boolean;
  aliases: string[];
}[] = [
  {
    key: 'parent_name',
    label: 'Tên phụ huynh',
    required: true,
    aliases: [
      'ho ten phu huynh',
      'ten phu huynh',
      'phu huynh',
      'ho ten',
      'ten',
      'parent name',
      'parent',
    ],
  },
  {
    key: 'parent_phone',
    label: 'SĐT',
    required: true,
    aliases: ['so dien thoai', 'sdt', 'dien thoai', 'phone', 'so dt', 'sdt phu huynh'],
  },
  {
    key: 'student_name',
    label: 'Tên học sinh',
    required: false,
    aliases: ['ten hoc sinh', 'hoc sinh', 'ho ten hoc sinh', 'student name', 'student'],
  },
  {
    key: 'student_birth_year',
    label: 'Năm sinh học sinh',
    required: false,
    aliases: ['nam sinh', 'nam sinh hoc sinh', 'birth year'],
  },
  { key: 'source', label: 'Source', required: false, aliases: ['nguon', 'source', 'nguon lead'] },
  {
    key: 'channel',
    label: 'Sub-source',
    required: false,
    aliases: ['kenh', 'sub source', 'subsource', 'sub-source', 'kenh nguon'],
  },
  {
    key: 'need',
    label: 'Nhu cầu',
    required: false,
    aliases: ['ghi chu', 'ghi chu kh', 'nhu cau', 'note', 'notes'],
  },
  {
    key: 'owner_email',
    label: 'Email sale phụ trách',
    required: false,
    aliases: ['email sale', 'email sale phu trach', 'sale', 'nguoi phu trach', 'owner'],
  },
];

/** Cột (theo số thứ tự) ghép với trường nào; null là chưa ghép. */
export type Mapping = (ImportField | null)[];

const fold = (text: string): string =>
  foldText(text)
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

/** Đoán ghép cột theo tên cột; một trường chỉ nhận cột đầu tiên khớp. */
export function autoMap(header: string[]): Mapping {
  const used = new Set<ImportField>();
  return header.map((name) => {
    const f = fold(name);
    const field = IMPORT_FIELDS.find((x) => !used.has(x.key) && x.aliases.some((a) => a === f));
    if (!field) return null;
    used.add(field.key);
    return field.key;
  });
}

/** Chọn trường cho một cột: trường đang ghép ở cột khác thì cột đó thành chưa ghép (mỗi trường một cột). */
export function setColumnField(
  mapping: Mapping,
  column: number,
  field: ImportField | null,
): Mapping {
  return mapping.map((current, i) => {
    if (i === column) return field;
    return field !== null && current === field ? null : current;
  });
}

/** Các trường bắt buộc còn thiếu (theo nhãn), để báo ở bước ghép cột. */
export function missingRequired(mapping: Mapping): string[] {
  return IMPORT_FIELDS.filter((f) => f.required && !mapping.includes(f.key)).map((f) => f.label);
}

/** Tên các cột trong file chưa ghép (dữ liệu cột đó không được nhập). */
export function unmappedColumns(header: string[], mapping: Mapping): string[] {
  return header.filter((_, i) => mapping[i] === null || mapping[i] === undefined);
}

export type CatalogLookup = {
  /** Mục nguồn theo tên hoặc mã (không phân biệt hoa thường, dấu). */
  findSource: (text: string) => { code: string; typeCode: string | undefined } | undefined;
  /** Kênh của một nguồn theo tên hoặc mã. */
  findChannel: (sourceCode: string, text: string) => string | undefined;
};

export type ImportRow = Record<string, string | number>;

/** Dựng các hàng gửi `import_leads`: có `row` là số dòng trong file, bỏ khoá trống. */
export function buildImportRows(
  table: CsvTable,
  mapping: Mapping,
  lookup: CatalogLookup,
): ImportRow[] {
  const col = (field: ImportField): number => mapping.indexOf(field);
  return table.rows.map((cells, i) => {
    const get = (field: ImportField): string => {
      const c = col(field);
      return c >= 0 ? (cells[c] ?? '').trim() : '';
    };
    const row: ImportRow = { row: table.lineNumbers[i] ?? i + 2 };
    const put = (key: string, value: string) => {
      if (value !== '') row[key] = value;
    };
    put('parent_name', get('parent_name'));
    put('parent_phone', get('parent_phone'));
    put('student_name', get('student_name'));
    put('student_birth_year', get('student_birth_year'));
    put('need', get('need'));
    put('owner_email', get('owner_email'));
    const source = get('source');
    if (source !== '') {
      const hit = lookup.findSource(source);
      if (hit) {
        row.source_code = hit.code;
        if (hit.typeCode) row.source_type_code = hit.typeCode;
      } else row.source_code = source;
      const channel = get('channel');
      if (channel !== '')
        row.channel_code = hit ? (lookup.findChannel(hit.code, channel) ?? channel) : channel;
    } else {
      // Có kênh mà không có nguồn: kênh thuộc nguồn mặc định, tra ở bước nhập (hàm kiểm).
      put('channel_code', get('channel'));
    }
    return row;
  });
}

/** Câu báo sau khi nhập: số lead đã nhập, kèm số dòng bị bỏ qua (trùng SĐT, lỗi) nếu có. */
export function importSummary(result: {
  imported: number;
  duplicates: number;
  errors: number;
}): string {
  const head = `Đã nhập ${result.imported} lead.`;
  return result.duplicates + result.errors > 0
    ? `${head} Bỏ qua ${result.duplicates} dòng trùng SĐT, ${result.errors} dòng lỗi.`
    : head;
}
