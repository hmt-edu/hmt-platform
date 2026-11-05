// Gọi máy chủ cho màn Nhập: xem trước và nạp thật dùng cùng một đường (p_commit / commit), nên kết quả luôn khớp nhau.
import type { SupabaseClient } from '@supabase/supabase-js';
import { callFunction, rpc } from '../../lib/db';
import type { ImportResult } from './importFile';
import type { ImportKindConfig } from './importKinds';

export function runImport(
  supabase: SupabaseClient,
  config: ImportKindConfig,
  rows: Record<string, string | number>[],
  commit: boolean,
  fileName: string,
): Promise<ImportResult> {
  if (config.viaFunction) {
    return callFunction<ImportResult>(supabase, 'import-users', { rows, commit, fileName });
  }
  return rpc<ImportResult>(supabase, 'import_records', {
    p_kind: config.kind,
    p_rows: rows,
    p_commit: commit,
    p_file_name: fileName,
  });
}
