// Giữ cột người dùng chọn ở nút «Cột» sau khi tải lại trang (K03, Tester T-STG2). Chỉ là tiện lợi của từng người trên trình duyệt này:
// lưu theo (người đăng nhập, mã màn) trong localStorage, không đi lên máy chủ. Mọi thao tác đọc ghi đều bọc try/catch vì
// localStorage có thể bị chặn (cửa sổ riêng tư) hoặc đầy; lỗi thì bỏ qua, danh sách vẫn chạy với cột mặc định.
import { useContext, useEffect, useRef } from 'react';
import { AuthContext } from '../lib/auth/authContext';
import type { ListState } from './types';

export const columnsStorageKey = (userId: string, screenCode: string) =>
  `hmt.cols.${userId}.${screenCode}`;

export function readSavedColumns(userId: string, screenCode: string): string[] | null {
  try {
    const raw = window.localStorage.getItem(columnsStorageKey(userId, screenCode));
    if (raw === null) return null;
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed) || !parsed.every((k) => typeof k === 'string')) return null;
    return parsed.length > 0 ? parsed : null;
  } catch {
    return null;
  }
}

export function writeSavedColumns(userId: string, screenCode: string, columns: string[]): void {
  try {
    const key = columnsStorageKey(userId, screenCode);
    if (columns.length === 0) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, JSON.stringify(columns));
  } catch {
    // Bỏ qua: không lưu được thì lần sau về cột mặc định.
  }
}

/**
 * Gắn vào khung danh sách: lần đầu vào màn nếu người này đã chọn cột trước đó thì áp lại; sau đó mỗi lần cột đổi thì lưu.
 * `columns` rỗng nghĩa là «mặc định» (nút Đặt lại): xoá bản đã lưu.
 */
export function usePersistedColumns(
  screenCode: string,
  state: ListState,
  onStateChange: (next: ListState) => void,
): void {
  const userId = useContext(AuthContext)?.session?.user.id ?? null;
  const restored = useRef(false);
  // Cột vừa áp lại từ bản đã lưu, đang chờ trạng thái màn cập nhật; chưa tới lượt đó thì không ghi (kẻo xoá bản đã lưu).
  const pending = useRef<string[] | null>(null);
  const latest = useRef({ state, onStateChange });
  useEffect(() => {
    latest.current = { state, onStateChange };
  });

  useEffect(() => {
    if (userId === null || restored.current) return;
    restored.current = true;
    const saved = readSavedColumns(userId, screenCode);
    const now = latest.current;
    if (saved && now.state.columns.length === 0) {
      pending.current = saved;
      now.onStateChange({ ...now.state, columns: saved });
    }
  }, [userId, screenCode]);

  useEffect(() => {
    // Chưa áp bản đã lưu thì chưa ghi (tránh ghi đè bản đã lưu bằng «mặc định» ở lần vẽ đầu).
    if (userId === null || !restored.current) return;
    if (pending.current !== null) {
      if (JSON.stringify(pending.current) === JSON.stringify(state.columns)) pending.current = null;
      return;
    }
    const saved = readSavedColumns(userId, screenCode) ?? [];
    if (JSON.stringify(saved) !== JSON.stringify(state.columns)) {
      writeSavedColumns(userId, screenCode, state.columns);
    }
  }, [userId, screenCode, state.columns]);
}
