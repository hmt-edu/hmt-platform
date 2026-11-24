// Luồng nộp bài (HT-04): tải các trang CHƯA có mã tệp theo từng đợt (≤ số tệp mỗi lần), giữ mã đã có, rồi chốt MỘT lần với mọi mã.
// «Thử lại» sau khi tải xong mà bước chốt hỏng chỉ gọi lại bước chốt, không tải lại ảnh (soát 02:35; máy chủ báo trùng 409 nếu tải lại).
import type { SupabaseClient } from '@supabase/supabase-js';
import { submitAssignment, uploadFiles, type FileToUpload, type SubmitResult } from './fileApi';

export interface SubmitPage {
  /** Mã tệp trên kho sau khi tải xong; null là chưa tải. Do luồng này ghi vào, giao diện giữ lại giữa các lần thử. */
  fileId: string | null;
  prepare: () => Promise<FileToUpload>;
}

export type SubmitStage =
  | { phase: 'prepare'; done: number; total: number }
  | { phase: 'upload'; done: number; total: number }
  | { phase: 'retry'; attempt: number }
  | { phase: 'commit' };

/** Chia danh sách thành các đợt tối đa `size` phần tử, giữ thứ tự. */
export function inBatches<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += Math.max(1, size)) out.push(items.slice(i, i + size));
  return out;
}

/** Nộp bài: tải các trang chưa có mã (theo đợt, ghi mã vào `pages[i].fileId` ngay khi đợt xong) rồi chốt. Lỗi ném ra cho giao diện hiện; mã đã có được giữ. */
export async function submitPages(
  supabase: SupabaseClient,
  args: {
    assignmentId: string;
    studentId: string;
    pages: SubmitPage[];
    maxPerBatch: number;
    onStage?: (stage: SubmitStage) => void;
  },
): Promise<SubmitResult> {
  const { pages, onStage } = args;
  const todo = pages.filter((p) => p.fileId === null);
  let done = pages.length - todo.length;
  for (const batch of inBatches(todo, args.maxPerBatch)) {
    onStage?.({ phase: 'prepare', done, total: pages.length });
    const files = await Promise.all(batch.map((p) => p.prepare()));
    const ids = await uploadFiles(
      supabase,
      { kind: 'BAI_NOP', assignmentId: args.assignmentId, studentId: args.studentId, files },
      (s) =>
        onStage?.(
          s.phase === 'retry'
            ? { phase: 'retry', attempt: s.attempt ?? 1 }
            : { phase: s.phase === 'prepare' ? 'prepare' : 'upload', done, total: pages.length },
        ),
    );
    batch.forEach((p, i) => {
      p.fileId = ids[i] ?? null;
    });
    done += batch.length;
  }
  onStage?.({ phase: 'commit' });
  return submitAssignment(
    supabase,
    args.assignmentId,
    pages.map((p) => p.fileId as string),
  );
}
