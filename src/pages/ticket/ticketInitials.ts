// Chữ cái đầu của người xử lý cho thẻ Kanban CSN-02.
/** Chữ cái đầu của họ và tên (Nguyễn Thị Lan → NL); chưa giao thì «?». */
export function assigneeInitials(name: string | null): string {
  const words = (name ?? '').trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return '?';
  const first = words[0]?.[0] ?? '';
  const last = words.length > 1 ? (words[words.length - 1]?.[0] ?? '') : '';
  return `${first}${last}`.toUpperCase();
}
