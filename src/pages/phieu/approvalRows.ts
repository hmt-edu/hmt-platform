// Bảng «Duyệt» của chi tiết phiếu nghiệp vụ (canvas CSN-06: Cấp, Người duyệt, Kết quả, Lúc): dựng từ các cấp duyệt và nhật ký, không gộp thành một dòng chữ.
import type { TaskEvent } from './phieuTypes';

export type ApprovalRow = {
  level: number;
  role: string;
  approver: string | null;
  /** «Đã duyệt», «Đang chờ», «Chưa tới», «Từ chối» hoặc «Không áp dụng» (phiếu đã huỷ). */
  result: string;
  at: string | null;
};

/** Chỉ tính nhật ký từ lần trình gần nhất (phiếu bị từ chối rồi trình lại thì duyệt đếm lại từ cấp 1). */
export function approvalRows(
  levels: string[],
  status: string,
  events: TaskEvent[],
  roleLabel: (level: string) => string,
  nextApprover: string | null = null,
): ApprovalRow[] {
  const lastSubmit = events.map((e) => e.event_type).lastIndexOf('TRINH');
  const cycle = lastSubmit >= 0 ? events.slice(lastSubmit) : [];
  const approved = cycle.filter((e) => e.event_type === 'DUYET');
  const rejected = cycle.find((e) => e.event_type === 'TU_CHOI') ?? null;
  return levels.map((level, i) => {
    const done = approved[i];
    const base = { level: i + 1, role: roleLabel(level) };
    if (done)
      return { ...base, approver: done.created_by_name, result: 'Đã duyệt', at: done.created_at };
    if (status === 'HUY') return { ...base, approver: null, result: 'Không áp dụng', at: null };
    if (i === approved.length && rejected && status === 'TU_CHOI')
      return {
        ...base,
        approver: rejected.created_by_name,
        result: 'Từ chối',
        at: rejected.created_at,
      };
    if (i === approved.length && status === 'CHO_DUYET')
      return { ...base, approver: nextApprover, result: 'Đang chờ', at: null };
    return { ...base, approver: null, result: 'Chưa tới', at: null };
  });
}
