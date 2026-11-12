// GV-12 Việc cần làm: logic thuần. Hai mục: buổi chưa hoàn tất (kèm hạn còn lại / quá hạn, R-GV-05) và bài BTVN «Nộp sau» chờ cập nhật (R-GV-11).
// Mục «phiếu test chờ chấm» để sau 17/11 (ẩn). Máy chủ quyết buổi nào là của giáo viên và hạn hoàn tất; ở đây chỉ gom nhóm và đổi chữ.
import type { LateItem } from './homework';
import { sessionTitle, type MySession } from './todayLogic';

const MS_PER_HOUR = 3_600_000; // allow-number: mili giây trong một giờ (đổi đơn vị, không phải số nghiệp vụ)
export const LOOKBACK_DAYS = 90; // allow-number: tìm lớp trong 90 ngày qua để dò bài Nộp sau (giới hạn hiển thị, không phải luật)

/** Xếp buổi chưa hoàn tất: quá hạn lâu nhất trước, rồi theo hạn gần nhất. */
export function sortByDeadline(rows: MySession[]): MySession[] {
  return [...rows].sort(
    (a, b) =>
      new Date(a.deadline_at).getTime() - new Date(b.deadline_at).getTime() ||
      a.session_id.localeCompare(b.session_id),
  );
}

export function isOverdue(deadlineIso: string, now: Date): boolean {
  return new Date(deadlineIso).getTime() <= now.getTime();
}

/** «Quá hạn 5 giờ» hoặc «Còn 3 giờ» (làm tròn lên, tối thiểu 1 giờ). */
export function deadlineLeftText(deadlineIso: string, now: Date): string {
  const diff = new Date(deadlineIso).getTime() - now.getTime();
  const hours = Math.max(1, Math.ceil(Math.abs(diff) / MS_PER_HOUR));
  return diff <= 0 ? `Quá hạn ${hours} giờ` : `Còn ${hours} giờ`;
}

/** Tên buổi + lý do chưa Done (nếu có), cho dòng mô tả. */
export function sessionLine(s: MySession): string {
  return sessionTitle(s);
}

/**
 * Mỗi lớp chọn một buổi để hỏi bài Nộp sau: buổi MỚI NHẤT có ngày không sau hôm nay. Máy chủ trả bài Nộp sau của cả lớp
 * (mọi buổi đã giao bài trước buổi đó), nên một lần gọi cho mỗi lớp là đủ.
 */
export function latestSessionPerClass(rows: MySession[], todayKey: string): MySession[] {
  const best = new Map<string, MySession>();
  for (const s of rows) {
    if (s.session_date > todayKey) continue;
    const cur = best.get(s.class_id);
    if (!cur || `${s.session_date}T${s.start_time}` > `${cur.session_date}T${cur.start_time}`) {
      best.set(s.class_id, s);
    }
  }
  return [...best.values()].sort((a, b) => a.class_code.localeCompare(b.class_code));
}

export type LateGroup = {
  /** Buổi mở màn GV-08 (buổi mới nhất của lớp). */
  openSessionId: string;
  title: string;
  /** Mỗi buổi giao bài một dòng: số buổi, ngày, tên em. */
  items: { assignedSessionId: string; sessionNo: number | null; date: string; names: string[] }[];
  total: number;
};

/** Gom bài Nộp sau của một lớp theo buổi giao bài; lớp không có bài thì null. */
export function groupLate(session: MySession, late: LateItem[]): LateGroup | null {
  if (late.length === 0) return null;
  const byAssigned = new Map<string, LateGroup['items'][number]>();
  for (const l of late) {
    const cur = byAssigned.get(l.assigned_session_id) ?? {
      assignedSessionId: l.assigned_session_id,
      sessionNo: l.session_no,
      date: l.session_date,
      names: [],
    };
    cur.names.push(l.full_name);
    byAssigned.set(l.assigned_session_id, cur);
  }
  return {
    openSessionId: session.session_id,
    title: [session.subject_name, session.class_code].filter(Boolean).join(' · '),
    items: [...byAssigned.values()].sort((a, b) => a.date.localeCompare(b.date)),
    total: late.length,
  };
}
