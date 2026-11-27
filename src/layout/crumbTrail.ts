// Đường dẫn trên thanh trên theo trang gốc: mở một trang từ smart button, bảng hay liên kết của trang khác thì đường dẫn nối tiếp
// trang gốc ("Tuyển sinh / Cơ hội / <tên cơ hội> / Phiếu kiểm tra / PKT000001") thay vì nhảy về nhóm menu của trang đích.
// Trang gốc gửi đường dẫn của mình trong `location.state.from` (sống qua tải lại trang vì nằm trong lịch sử trình duyệt);
// vào bằng thanh bên thì không có `from` và đường dẫn dựng từ menu như cũ.
import { createContext, useCallback, useContext } from 'react';
import { useNavigate, type NavigateOptions } from 'react-router';

export type Crumb = { label: string; to?: string };

/** Đường dẫn đang hiện của trang hiện tại và địa chỉ của nó (đường dẫn + chuỗi lọc), để trang con nối tiếp. */
/** `dropLast`: đang ở danh sách lọc theo bản ghi cha, trang mở từ đây không giữ tầng danh sách. */
export type CrumbsValue = { crumbs: Crumb[]; here: string; dropLast?: boolean };
export const CrumbsContext = createContext<CrumbsValue>({ crumbs: [], here: '' });

const pathOf = (to: string | undefined) => (to ?? '').split('?')[0];

/**
 * Đường dẫn của trang gốc, dùng làm `from` khi mở trang con: mọi mục giữ liên kết, mục cuối (tên bản ghi, không có liên kết)
 * trỏ về chính trang gốc để bấm quay lại được.
 */
export function trailOf(value: CrumbsValue): Crumb[] {
  if (value.dropLast) return value.crumbs.slice(0, -1);
  return value.crumbs.map((c, i) =>
    i === value.crumbs.length - 1 && !c.to && value.here ? { ...c, to: value.here } : c,
  );
}

/**
 * Nối đường dẫn của trang gốc với đường dẫn dựng từ menu của trang đích (`own`: nhóm, mục, và tên bản ghi nếu có).
 * Chỉ nối MỤC CUỐI của trang đích (tên bản ghi hoặc tên trang), bỏ nhóm và tầng danh sách ở giữa (H1). Nếu trang đích đã có trong đường dẫn gốc (quay lại một trang đã đi qua)
 * thì cắt đường dẫn gốc tới đó, không nối dài thêm.
 */
export function mergeTrail(from: Crumb[] | null, own: Crumb[], destPath: string): Crumb[] {
  if (!from || from.length === 0 || own.length < 2) return own;
  const seen = from.findIndex((c) => pathOf(c.to) === destPath);
  if (seen >= 0) {
    const cut = from.slice(0, seen + 1);
    const lastIndex = cut.length - 1;
    return cut.map((c, i) => (i === lastIndex ? { label: c.label } : c));
  }
  return [...from, ...own.slice(-1)];
}

/** Mở một trang từ trang hiện tại và nối tiếp đường dẫn (smart button, dòng bảng, liên kết). */
export function useNavigateFrom() {
  const navigate = useNavigate();
  const value = useContext(CrumbsContext);
  return useCallback(
    (to: string, options?: NavigateOptions) =>
      void navigate(to, { ...options, state: { from: trailOf(value) } }),
    [navigate, value],
  );
}

/** `state` cho một `<Link>` mở trang con từ trang hiện tại. */
export function useFromState(): { from: Crumb[] } {
  const value = useContext(CrumbsContext);
  return { from: trailOf(value) };
}

/** Đường dẫn gốc nằm trong `location.state`, nếu có. */
export function fromOf(state: unknown): Crumb[] | null {
  if (typeof state !== 'object' || state === null || !('from' in state)) return null;
  const from: unknown = state.from;
  if (!Array.isArray(from)) return null;
  const items: unknown[] = from;
  const crumbs = items.filter(
    (c): c is Crumb =>
      typeof c === 'object' && c !== null && 'label' in c && typeof c.label === 'string',
  );
  return crumbs.length > 0 ? crumbs : null;
}
