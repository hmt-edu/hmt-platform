// Xem thử giá khi sửa Nháp: gửi các dòng đủ điều kiện cho app.preview_quotation_lines (cùng hàm tính giá với lúc Lưu) và đổi kết quả về từng dòng.
// Máy chủ dừng ở lỗi đầu tiên và nêu đúng dòng; hook bỏ dòng đó ra rồi tính lại các dòng còn lại để mọi dòng lỗi đều hiện câu lỗi. Một lần đổi
// dòng gọi một lần (thêm một lần nữa cho mỗi dòng lỗi). Lỗi mạng không mất dữ liệu đã nhập: hiện băng lỗi và nút Thử lại.
import { useCallback, useEffect, useRef, useState } from 'react';
import { HmtError, errorOf, rpc, useDb } from '../../lib/db';
import type { EditRow } from './quoteEdit';
import {
  errorLineNo,
  previewCandidates,
  remapLineNo,
  waitingStatus,
  type RowCalc,
} from './quotePreview';

type PreviewLine = {
  line_no: number;
  unit_price: number;
  discount_amount: number;
  line_total: number;
  total_discount_percent: number;
  over_cap: boolean;
};
type PreviewResult = { lines: PreviewLine[]; total_amount: number };

const DEBOUNCE_MS = 400; // allow-number: chờ người dùng ngừng gõ rồi mới gọi máy chủ

export type QuotePreview = {
  calcs: Record<string, RowCalc>;
  /** Tổng cộng báo giá do máy chủ trả (các dòng đã tính được); null khi chưa có. */
  total: number | null;
  computing: boolean;
  /** Lỗi không thuộc dòng nào (mạng, quyền): băng lỗi trên lưới. */
  networkError: string | null;
  retry: () => void;
};

export function useQuotePreview(
  opportunityId: string,
  rows: EditRow[],
  enabled: boolean,
): QuotePreview {
  const supabase = useDb();
  const [calcs, setCalcs] = useState<Record<string, RowCalc>>({});
  const [total, setTotal] = useState<number | null>(null);
  const [computing, setComputing] = useState(false);
  const [networkError, setNetworkError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const run = useRef(0);

  // Chữ ký của việc cần tính: đổi dòng mới tính lại; số tính sẵn và khoá nội bộ không tính.
  const candidates = previewCandidates(rows);
  const signature = JSON.stringify(candidates.map((c) => [c.rowKey, c.line]));
  const rowsRef = useRef(rows);
  useEffect(() => {
    rowsRef.current = rows;
  }, [rows]);

  useEffect(() => {
    if (!enabled) return;
    const mine = ++run.current;
    const current = rowsRef.current;
    // Trạng thái chờ ngay: dòng sẽ gửi đi đang tính, dòng chưa đủ điều kiện hiện đúng lý do.
    const sending = new Set(previewCandidates(current).map((c) => c.rowKey));
    setCalcs((prev) => {
      const next: Record<string, RowCalc> = {};
      for (const row of current) {
        next[row.key] = sending.has(row.key) ? { status: 'pending' } : waitingStatus(row);
        const old = prev[row.key];
        if (sending.has(row.key) && old?.status === 'ok') next[row.key] = old; // giữ số cũ cho tới khi có số mới
      }
      return next;
    });
    if (sending.size === 0) {
      setTotal(0);
      setComputing(false);
      setNetworkError(null);
      return;
    }
    setComputing(true);
    const timer = window.setTimeout(() => {
      void (async () => {
        let active = previewCandidates(rowsRef.current);
        const errors: Record<string, string> = {};
        const indexOf = new Map(rowsRef.current.map((r, i) => [r.key, i]));
        try {
          for (let attempt = 0; attempt <= active.length + 1; attempt += 1) {
            if (active.length === 0) {
              if (run.current === mine) finish(errors, [], 0, active);
              return;
            }
            try {
              const res = await rpc<PreviewResult>(supabase, 'preview_quotation_lines', {
                p_opportunity_id: opportunityId,
                p_lines: active.map((c) => c.line),
              });
              if (run.current === mine) finish(errors, res.lines, res.total_amount, active);
              return;
            } catch (e) {
              const lineNo = e instanceof HmtError ? errorLineNo(e.message) : null;
              const bad = lineNo === null ? undefined : active[lineNo - 1];
              if (!(e instanceof HmtError) || bad === undefined) throw e;
              errors[bad.rowKey] = remapLineNo(e.message, (indexOf.get(bad.rowKey) ?? 0) + 1);
              active = active.filter((c) => c.rowKey !== bad.rowKey);
            }
          }
        } catch (e) {
          if (run.current === mine) {
            setComputing(false);
            setNetworkError(errorOf(e).message);
            // Giữ dữ liệu nhập; dòng đang tính trở về chưa có số.
            setCalcs((prev) => {
              const next = { ...prev };
              for (const [k, v] of Object.entries(next))
                if (v.status === 'pending') next[k] = { status: 'incomplete' };
              return next;
            });
          }
        }
      })();
    }, DEBOUNCE_MS);

    function finish(
      errors: Record<string, string>,
      lines: PreviewLine[],
      totalAmount: number,
      active: { rowKey: string }[],
    ) {
      setNetworkError(null);
      setComputing(false);
      setTotal(totalAmount);
      setCalcs(() => {
        const next: Record<string, RowCalc> = {};
        for (const row of rowsRef.current) next[row.key] = waitingStatus(row);
        active.forEach((c, i) => {
          const l = lines[i];
          if (l)
            next[c.rowKey] = {
              status: 'ok',
              unitPrice: l.unit_price,
              discountAmount: l.discount_amount,
              lineTotal: l.line_total,
              totalPercent: l.total_discount_percent,
              overCap: l.over_cap,
            };
        });
        for (const [key, message] of Object.entries(errors))
          next[key] = { status: 'error', message };
        return next;
      });
    }

    return () => {
      window.clearTimeout(timer);
    };
  }, [signature, enabled, nonce, opportunityId, supabase]);

  const retry = useCallback(() => setNonce((n) => n + 1), []);
  return { calcs, total, computing, networkError, retry };
}
