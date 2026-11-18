// CH-07 Rubric nhận xét: logic thuần. Máy chủ giữ luật (get_rubric, update_review_level_desc, create_rubric_version; R-V2-19, CH-07);
// ở đây chỉ gom nhóm, so sánh bản nháp và đổi chữ.
export type RubricCriterion = {
  id: string;
  code: string;
  group_code: string;
  subject_set: string;
  name: string;
  sort_order: number;
  is_active: boolean;
  levels: Record<string, string>;
};

export type RubricVersion = {
  id: string;
  version_no: number;
  status: string; // DANG_DUNG hoặc NGUNG
  note?: string | null;
  created_at: string;
};

export type Rubric = {
  version: RubricVersion;
  versions: RubricVersion[];
  criteria: RubricCriterion[];
};

export const LEVELS = ['1', '2', '3', '4', '5'] as const;

/** Nhóm theo thứ tự hiện trên canvas (CH07_pc), kèm chữ phụ «Dùng chung mọi môn» / «Riêng môn Toán» / «Bộ môn phụ». */
export const GROUPS: { code: string; label: string }[] = [
  { code: 'THAI_DO', label: 'Thái độ' },
  { code: 'TIEP_THU', label: 'Tiếp thu kiến thức' },
  { code: 'VAN_DUNG', label: 'Năng lực vận dụng' },
];

export function groupNote(group: string, subjectSet: 'TOAN' | 'MON_PHU'): string {
  if (group === 'THAI_DO') return 'Dùng chung mọi môn';
  return subjectSet === 'TOAN' ? 'Riêng môn Toán' : 'Bộ môn phụ';
}

export function versionLabel(v: RubricVersion): string {
  return `Phiên bản ${v.version_no} · ${v.status === 'DANG_DUNG' ? 'đang dùng' : 'đã ngừng'}`;
}

export function criteriaOfGroup(rubric: Rubric, group: string): RubricCriterion[] {
  return rubric.criteria.filter((c) => c.group_code === group);
}

/** Bản nháp: khoá `${criterionId}:${mức}` → chữ đang sửa. */
export type Draft = Record<string, string>;
export const draftKey = (criterionId: string, level: string) => `${criterionId}:${level}`;

export function valueOf(c: RubricCriterion, level: string, draft: Draft): string {
  return draft[draftKey(c.id, level)] ?? c.levels[level] ?? '';
}

/** Các ô đã đổi so với bản đang lưu (chữ đã cắt khoảng trắng). */
export function changedCells(
  rubric: Rubric,
  draft: Draft,
): { criterionId: string; level: number; description: string }[] {
  const out: { criterionId: string; level: number; description: string }[] = [];
  for (const c of rubric.criteria) {
    for (const level of LEVELS) {
      const key = draftKey(c.id, level);
      if (!(key in draft)) continue;
      const next = (draft[key] ?? '').trim();
      if (next !== (c.levels[level] ?? ''))
        out.push({ criterionId: c.id, level: Number(level), description: next });
    }
  }
  return out;
}

/** Ô nào bị xoá trắng (máy chủ không cho mô tả trống). */
export function emptyCells(changes: { description: string }[]): boolean {
  return changes.some((c) => c.description === '');
}

/** Môn thuộc bộ nào: theo bảng review_subject_set; môn không có trong bảng dùng bộ môn phụ (Q-189). */
export function subjectSetOf(subjectCode: string, map: Record<string, string>): 'TOAN' | 'MON_PHU' {
  return map[subjectCode] === 'TOAN' ? 'TOAN' : 'MON_PHU';
}

// ---- Câu mẫu lời nhắn phụ huynh (R-V2-39): 2 loại buổi × mức 1–4 × 3 câu ----
export type Phrase = { kind: string; level: number; seq: number; phrase: string };
export const PHRASE_KINDS: { code: string; label: string }[] = [
  { code: 'THUONG', label: 'Buổi thường' },
  { code: 'KIEM_TRA', label: 'Buổi kiểm tra' },
];
export const PHRASE_LEVELS = [1, 2, 3, 4] as const;
export const phraseKey = (p: { kind: string; level: number; seq: number }) =>
  `${p.kind}:${p.level}:${p.seq}`;

/** Các câu đã đổi so với bản đang lưu (chữ cắt khoảng trắng). */
export function changedPhrases(rows: Phrase[], draft: Record<string, string>): Phrase[] {
  const out: Phrase[] = [];
  for (const r of rows) {
    const k = phraseKey(r);
    if (!(k in draft)) continue;
    const next = (draft[k] ?? '').trim();
    if (next !== r.phrase) out.push({ ...r, phrase: next });
  }
  return out;
}
