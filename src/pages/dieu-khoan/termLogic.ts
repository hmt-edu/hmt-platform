// CH-09 Điều khoản thanh toán: logic thuần (mã từ tên, kiểm các đợt trước khi gửi, nhãn). Luật R-TIEN-07; hàm DB create_payment_term kiểm lần nữa (câu lỗi của DB là câu thật).
// Điều khoản đã tạo KHÔNG sửa: đổi là tạo bản mới cùng mã (version + 1); đơn cũ giữ lịch đã sinh.
import { foldText, formatMoney, formatNumber } from '../../lib/format';

export type TermInstallment = {
  seq: number;
  share_percent: number | null;
  fixed_amount: number | null;
  due_days: number;
};

export type PaymentTerm = {
  id: string;
  code: string;
  version: number;
  name: string;
  valid_from: string;
  is_active: boolean;
  installments: TermInstallment[];
};

/** Mã điều khoản từ tên: chữ hoa không dấu, ký tự khác thành gạch dưới ("Chia 3 đợt" → "CHIA_3_DOT"). */
export function codeFromName(name: string): string {
  return foldText(name)
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
}

/** Ngày (giờ địa phương) → yyyy-mm-dd để gửi hàm DB. */
export const dateToIso = (d: Date): string =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; // allow-number: định dạng yyyy-mm-dd

export type Draft = { mode: 'PERCENT' | 'FIXED'; value: string; dueDays: string };

const FULL_PERCENT = 100; // allow-number: tổng phần trăm các đợt phải đủ 100 (cùng luật DB create_payment_term)
const EPSILON = 1e-9; // allow-number: sai số so sánh số thực
const roundShown = (n: number): number => Math.round(n * 100) / 100; // allow-number: làm tròn hiển thị 2 chữ số
const toNumber = (text: string): number => Number(text.replace(',', '.'));

/** Mô tả cách chia: "Chia 3 đợt: 30% / 30% / 40%" hoặc "Cọc 5.000.000 đ rồi 2 đợt". */
export function describeInstallments(list: TermInstallment[]): string {
  const sorted = [...list].sort((a, b) => a.seq - b.seq);
  if (sorted.length === 1) return 'Đóng một lần';
  const first = sorted[0];
  if (first?.fixed_amount !== null && first?.fixed_amount !== undefined) {
    return `Cọc ${first.fixed_amount.toLocaleString('vi-VN')} đ rồi ${sorted.length - 1} đợt`;
  }
  return `Chia ${sorted.length} đợt`;
}

/** Lỗi toàn bảng đợt (null khi hợp lệ): cùng luật với create_payment_term để báo ngay, DB vẫn kiểm. */
export function installmentsError(drafts: Draft[]): string | null {
  if (drafts.length === 0) return 'Cần ít nhất một đợt.';
  for (const [i, d] of drafts.entries()) {
    const n = toNumber(d.value);
    if (d.value.trim() === '' || !Number.isFinite(n) || n <= 0)
      return `Đợt ${i + 1}: nhập giá trị lớn hơn 0.`;
    if (d.mode === 'FIXED' && i > 0) return 'Chỉ đợt 1 được là số tiền cố định.';
    if (d.mode === 'FIXED' && !Number.isInteger(n))
      return 'Số tiền cố định phải là số nguyên (đồng).';
    const due = toNumber(d.dueDays);
    if (d.dueDays.trim() === '' || !Number.isInteger(due) || due < 0) {
      return `Đợt ${i + 1}: số ngày đến hạn là số nguyên không âm.`;
    }
  }
  if (drafts[0]?.mode === 'FIXED' && drafts.length < 2) {
    return 'Đợt 1 là số tiền cố định thì cần ít nhất một đợt sau.';
  }
  const pct = drafts.filter((d) => d.mode === 'PERCENT').reduce((s, d) => s + toNumber(d.value), 0);
  if (Math.abs(pct - FULL_PERCENT) > EPSILON) {
    return `Tổng phần trăm các đợt chia theo % phải đúng ${FULL_PERCENT} (đang ${roundShown(pct)}).`;
  }
  return null;
}

/** Đổi bảng nháp thành mảng gửi cho create_payment_term. */
export function toPayload(drafts: Draft[]) {
  return drafts.map((d, i) => ({
    seq: i + 1,
    share_percent: d.mode === 'PERCENT' ? toNumber(d.value) : null,
    fixed_amount: d.mode === 'FIXED' ? toNumber(d.value) : null,
    due_days: toNumber(d.dueDays),
  }));
}

/** Nhãn cách chia của một đợt đã lưu (khung CH09): "% của tổng đơn", "% của phần còn lại sau đợt 1", "Số tiền cố định". */
export function shareLabel(i: TermInstallment, hasFixedFirst: boolean): string {
  if (i.fixed_amount !== null) return 'Số tiền cố định';
  return i.seq === 1 || !hasFixedFirst ? '% của tổng đơn' : '% của phần còn lại sau đợt 1';
}

/** Chữ trong ô chọn điều khoản: tên ghép lịch đợt từ dữ liệu, "Đặt cọc thường · 30% + 70% sau 14 ngày". */
export function termLabel(t: {
  name: string;
  installments?: TermInstallment[] | undefined;
}): string {
  const sorted = [...(t.installments ?? [])].sort((a, b) => a.seq - b.seq);
  // Một đợt đóng ngay thì tên là đủ.
  if (sorted.length === 0 || (sorted.length === 1 && sorted[0]?.due_days === 0)) return t.name;
  const hasFixedFirst = sorted[0]?.fixed_amount !== null;
  const parts = sorted.map((i) => {
    const amount =
      i.fixed_amount !== null
        ? formatMoney(i.fixed_amount)
        : `${formatNumber(i.share_percent ?? 0)}%${hasFixedFirst ? ' phần còn lại' : ''}`;
    return i.due_days > 0 ? `${amount} sau ${formatNumber(i.due_days)} ngày` : amount;
  });
  return `${t.name} · ${parts.join(' + ')}`;
}
