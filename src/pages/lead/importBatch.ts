import { formatDateTime } from '../../lib/format';
import type { ImportBatch } from './useLeadData';

/** Một dòng của ô lọc «Lần nhập»: lúc nhập, tên tệp, người nhập, số lead còn đang dùng. */
export function importBatchOption(b: ImportBatch): { value: string; label: string } {
  const parts = [
    formatDateTime(b.created_at),
    b.file_name,
    b.importer_name,
    `còn ${b.active_count}/${b.imported_count} lead`,
  ];
  return { value: b.id, label: parts.filter(Boolean).join(' · ') };
}
