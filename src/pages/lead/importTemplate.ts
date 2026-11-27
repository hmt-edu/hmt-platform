// D1 · File mẫu nhập lead (TS-04 bước 1): dòng đầu là tên cột đúng như bước ghép cột nhận (cột bắt buộc có dấu *), một dòng ví dụ
// và các dòng liệt kê Source, Sub-source đang dùng (lấy từ danh mục lúc tải). Mọi dòng bắt đầu bằng [MẪU] bị bỏ qua khi nhập.
import { toCsv } from './csv';
import type { CsvTable } from './importCsv';
import { IMPORT_FIELDS, type ImportField } from './importMapping';

export const SAMPLE_MARK = '[MẪU]';

/** Nguồn đang dùng và các kênh của từng nguồn (tên hiện trên màn). */
export type TemplateSource = { name: string; channels: string[] };

const EXAMPLE: Partial<Record<ImportField, string>> = {
  parent_name: `${SAMPLE_MARK} Phụ huynh ví dụ`,
  parent_phone: '0900000001',
  student_name: 'Học sinh ví dụ',
  student_birth_year: '2014',
  need: 'Nhu cầu ví dụ',
};

export function leadTemplateCsv(sources: TemplateSource[]): string {
  const columns = IMPORT_FIELDS.map((f) => ({
    key: f.key,
    label: f.required ? `${f.label} *` : f.label,
  }));
  const first = sources[0];
  const example = {
    ...EXAMPLE,
    source: first?.name ?? '',
    channel: first?.channels[0] ?? '',
  };
  const values = sources.flatMap((s) =>
    (s.channels.length > 0 ? s.channels : ['']).map((channel) => ({
      parent_name: `${SAMPLE_MARK} Giá trị hợp lệ`,
      source: s.name,
      channel,
    })),
  );
  return toCsv([example, ...values], columns);
}

/** Bỏ các dòng của file mẫu (có ô bắt đầu bằng [MẪU]), giữ đúng số dòng trong file của dòng còn lại. */
export function dropSampleRows(table: CsvTable): CsvTable {
  const keep = table.rows.map((cells) => !cells.some((c) => c.startsWith(SAMPLE_MARK)));
  return {
    ...table,
    rows: table.rows.filter((_, i) => keep[i]),
    lineNumbers: table.lineNumbers.filter((_, i) => keep[i]),
  };
}
