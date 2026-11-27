import type { BulkResult } from './useLeadData';

/** Các dòng «bỏ qua» để đọc: mã lead (nếu được xem) và lý do. */
export function skippedLines(result: BulkResult): string[] {
  return result.skipped.map((s) => `${s.code ?? 'Lead không xem được'}: ${s.reason}`);
}
