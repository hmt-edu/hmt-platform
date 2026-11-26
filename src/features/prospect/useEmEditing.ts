// Bản nháp của khối «Thông tin học sinh» (A-26-01). Em đầu nằm trong bản nháp của trang (lưu cùng lead, cơ hội);
// em từ số 2 giữ bản nháp ở đây, lưu bằng update_prospect_student khi đang chọn em đó và bấm Lưu.
import { useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';
import {
  dirtyEmIds,
  draftOfStudent,
  emLabel,
  emPayload,
  validateEmDraft,
  type EmDraft,
  type ProspectStudent,
} from './prospectLogic';
import { updateProspectStudent } from './useProspect';

export type PendingEm = { id: string; name: string; draft: EmDraft; error: string | null };

export function saveEm(supabase: SupabaseClient, em: PendingEm) {
  return updateProspectStudent(supabase, em.id, emPayload(em.draft));
}

export function useEmEditing(students: ProspectStudent[]) {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<Record<string, EmDraft>>({});
  const found = students.findIndex((s) => s.id === selectedId);
  const index = found < 0 ? 0 : found;
  const selected = students[index] ?? null;
  const dirtyIds = dirtyEmIds(students, drafts);
  return {
    selected,
    /** Đang chọn em đầu, hoặc chưa có em nào: ô nhập là của trang. */
    isFirst: index === 0,
    select: setSelectedId,
    draftOf: (s: ProspectStudent): EmDraft => drafts[s.id] ?? draftOfStudent(s),
    change: (s: ProspectStudent, patch: Partial<EmDraft>) =>
      setDrafts((all) => ({ ...all, [s.id]: { ...(all[s.id] ?? draftOfStudent(s)), ...patch } })),
    dirtyIds,
    /** Em đang chọn (từ số 2) có thay đổi cần lưu cùng lần bấm Lưu này; `error` khác null thì chưa lưu được. */
    pending: (requireYear: boolean): PendingEm | null => {
      if (!selected || !dirtyIds.includes(selected.id)) return null;
      const draft = drafts[selected.id]!;
      const errors = validateEmDraft(draft, requireYear, new Date().getFullYear());
      const error = errors.fullName ?? errors.birthYear ?? null;
      return { id: selected.id, name: emLabel(selected), draft, error };
    },
    /** Tên các em KHÔNG đang chọn mà còn thay đổi chưa lưu. */
    othersAfterSave: (): string[] =>
      students.filter((s) => s.id !== selected?.id && dirtyIds.includes(s.id)).map(emLabel),
    discard: (id: string) =>
      setDrafts((all) => Object.fromEntries(Object.entries(all).filter(([k]) => k !== id))),
    reset: () => setDrafts({}),
  };
}

export type EmEditing = ReturnType<typeof useEmEditing>;
