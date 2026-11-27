// Bảng dòng đơn ở chế độ SỬA (UI-O3, canvas BH05_nhap): mỗi dòng sửa số giờ, hình thức, chính sách chiết khấu (chip, ✕ để bỏ, "+ Thêm"), bỏ dòng.
// Học sinh, gói giữ nguyên; thêm dòng, thêm em để bước tạo đơn từ cơ hội (dùng chung ô chọn gói, học sinh). Giao diện KHÔNG tính tiền: Thành tiền
// hiện số máy chủ đã tính lần lưu trước, tính lại khi bấm Lưu (R-TIEN-13).
import { formatDate, formatNumber } from '../../lib/format';
import { discountText } from '../bao-gia/quoteRecord';
import { Button } from '../../ui/Button';
import { INPUT_CLASS } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import {
  addedError,
  flexibleLimitError,
  lineError,
  type AddedLine,
  type DraftDiscount,
  type LineDraft,
  type OrderDraft,
} from './orderEdit';
import type { OppStudent } from '../bao-gia/useQuoteData';
import type { OrderLineClass } from '../ghi-danh/enrollTypes';
import type { OrderLine, OrderLineDiscount } from './orderTypes';
import type { PolicyOption } from './useOrderData';

type Props = {
  lines: OrderLine[];
  draft: OrderDraft;
  onChange: (lineNo: number, patch: Partial<LineDraft>) => void;
  policies: PolicyOption[];
  modes: { value: string; label: string }[];
  branchId: string;
  today: string;
  /** Đã đổi gì đó mà chưa Lưu: các số tiền là của lần lưu trước, hiện mờ kèm dòng "Chưa tính lại" (Q-50). */
  stale: boolean;
  /** Học sinh (em) của cơ hội để chọn cho dòng mới; thêm em làm ở cơ hội. */
  students: OppStudent[];
  /** Mở hộp chọn gói để thêm một dòng (Q-67, canvas BH05_nhap_sua). */
  onAdd: () => void;
  onChangeAdded: (key: string, patch: Partial<AddedLine>) => void;
  onRemoveAdded: (key: string) => void;
  /** Mã lớp, ngày vào lớp đang chọn của từng dòng (BH-08), theo số dòng. */
  lineClasses: Record<number, OrderLineClass>;
  /** Mở hộp Chọn lớp và ngày vào lớp (BH-08) cho một dòng. */
  onPickClass: (line: OrderLine) => void;
};

/** Chính sách áp được cho loại gói, cơ sở ở thời điểm hiện tại (máy chủ kiểm lại khi lưu). */
function applicableTo(
  p: PolicyOption,
  packageTypeCode: string,
  branchId: string,
  today: string,
): boolean {
  return (
    p.valid_from <= today &&
    (p.valid_to === null || p.valid_to >= today) &&
    (p.package_type_codes.length === 0 || p.package_type_codes.includes(packageTypeCode)) &&
    (p.branch_ids.length === 0 || p.branch_ids.includes(branchId))
  );
}

/** Chính sách áp được cho gói và cơ sở của dòng. */
function applicable(p: PolicyOption, line: OrderLine, branchId: string, today: string): boolean {
  return applicableTo(p, line.package_type_code, branchId, today);
}

/**
 * Ô chiết khấu của một dòng (chip chọn nhiều, ✕ để bỏ, "+ Thêm"): dùng cho dòng cũ và dòng mới thêm (Q-69). Giao diện chỉ chọn chính sách và
 * nhập giá trị; % cộng dồn, trần 20% (chỉ cảnh báo), thành tiền do máy chủ tính khi Lưu. `label` đặt tên cho trình đọc màn hình ("dòng 1", "dòng mới 1").
 */
function DiscountEditor({
  label,
  discounts,
  onChange,
  policies,
  addable,
  oldOf,
}: {
  label: string;
  discounts: DraftDiscount[];
  onChange: (next: DraftDiscount[]) => void;
  policies: PolicyOption[];
  addable: PolicyOption[];
  oldOf?: ((policyId: string) => OrderLineDiscount | undefined) | undefined;
}) {
  // Vượt hạn mức Ưu đãi linh hoạt: chữ đỏ dưới chip, nút Lưu mờ (Q-151); máy chủ kiểm lại khi Lưu.
  const limitError = flexibleLimitError(discounts, policies);
  return (
    <span className="flex flex-col gap-1.5">
      <span className="flex flex-nowrap items-center gap-1.5 whitespace-nowrap">
        {discounts.map((x) => {
          const p = policies.find((q) => q.id === x.policy_id);
          const old = oldOf?.(x.policy_id);
          const name = p?.name ?? old?.policy_name ?? 'Chính sách';
          const unit = (p?.kind ?? old?.kind) === 'GIFT_HOURS' ? 'giờ' : '%';
          return (
            <span
              key={x.policy_id}
              className="inline-flex items-center gap-1 rounded-tag bg-surface-subtle px-2 py-0.5 text-caption"
            >
              {name}
              {p && !p.fixed_value && (
                <input
                  aria-label={`Giá trị ${name} ${label}`}
                  inputMode="decimal"
                  autoComplete="off"
                  className="tabular w-12 rounded-control border border-border px-1 text-right"
                  value={x.value === null ? '' : String(x.value)}
                  onChange={(e) => {
                    const text = e.target.value.replace(',', '.').trim();
                    const value = text === '' || Number.isNaN(Number(text)) ? null : Number(text);
                    onChange(
                      discounts.map((y) => (y.policy_id === x.policy_id ? { ...y, value } : y)),
                    );
                  }}
                />
              )}
              {p && !p.fixed_value ? unit : ''}
              <button
                type="button"
                aria-label={`Bỏ ${name} khỏi ${label}`}
                className="focus-ring rounded-tag px-1 text-fg-muted hover:bg-hover"
                onClick={() => onChange(discounts.filter((y) => y.policy_id !== x.policy_id))}
              >
                ✕
              </button>
            </span>
          );
        })}
        {addable.length > 0 && (
          <Select
            label={`Thêm chính sách ưu đãi ${label}`}
            value=""
            placeholder="+ Thêm"
            onChange={(id) => {
              const p = addable.find((q) => q.id === id);
              if (!p) return;
              onChange([
                ...discounts,
                // Ưu đãi linh hoạt: nhân viên tự gõ %, không đặt sẵn hạn mức (R-V2-45).
                {
                  policy_id: p.id,
                  value: p.fixed_value || p.is_flexible === true ? null : p.max_value,
                },
              ]);
            }}
            options={addable.map((p) => ({ value: p.id, label: p.name }))}
          />
        )}
      </span>
      {limitError !== null && (
        <span role="alert" className="text-caption text-on-danger-subtle">
          {limitError}
        </span>
      )}
    </span>
  );
}

export function OrderEditLines({
  lines,
  draft,
  onChange,
  policies,
  modes,
  branchId,
  today,
  stale,
  students,
  onAdd,
  onChangeAdded,
  onRemoveAdded,
  lineClasses,
  onPickClass,
}: Props) {
  const live = lines.filter((l) => !draft.lines[l.line_no]?.removed);
  const dim = stale ? 'opacity-50' : '';
  return (
    <div className="flex flex-col gap-2">
      {/* Q-50, Q-56: ngay TRÊN bảng, luôn thấy (không nằm trong vùng cuộn ngang). Giao diện không tính tiền, kể cả xem trước. */}
      {stale && (
        <p role="status" className="text-caption text-fg-label">
          Chưa tính lại, bấm Lưu để cập nhật.
        </p>
      )}
      {/* relative: chữ sr-only (cột Bỏ dòng) không thoát khỏi vùng cuộn làm cả trang tràn ngang ở 1280 (Q-72). */}
      <div className="relative overflow-x-auto rounded-control border border-border">
        <table
          aria-label="Dòng đơn đang sửa"
          className="w-full min-w-[1180px] text-body whitespace-nowrap"
        >
          <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
            <tr>
              <th className="px-3 py-2">Học sinh</th>
              <th className="px-2 py-2">Sản phẩm</th>
              <th className="px-2 py-2">Hình thức</th>
              <th className="px-2 py-2">Mã lớp</th>
              <th className="px-2 py-2">Ngày vào lớp</th>
              <th className="px-2 py-2 text-right">Số lượng</th>
              <th className="px-2 py-2 text-right">Đơn giá</th>
              <th className="px-2 py-2">Ưu đãi</th>
              <th className="px-2 py-2 text-right">Tổng %</th>
              <th className="px-2 py-2 text-right">Giảm</th>
              <th className="px-2 py-2 text-right">Thành tiền</th>
              <th className="px-2 py-2">
                <span className="sr-only">Bỏ dòng</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {lines.map((l) => {
              const d = draft.lines[l.line_no];
              if (!d) return null;
              const gift = l.line_kind === 'GIFT';
              const error = lineError(d);
              const chosen = new Set(d.discounts.map((x) => x.policy_id));
              const addable = policies.filter(
                (p) => !chosen.has(p.id) && applicable(p, l, branchId, today),
              );
              return (
                <tr
                  key={l.id}
                  className={
                    d.removed
                      ? 'border-t border-border opacity-50'
                      : 'border-t border-border align-top'
                  }
                >
                  <td className="px-3 py-2">
                    {l.student_name ?? 'Chưa có học sinh'}
                    {/* BH05_chan_em_sua: em thiếu họ tên hoặc năm sinh vẫn báo ngay khi sửa (R-TIEN-35). */}
                    {l.student_name && !l.student_complete && (
                      <span className="block text-caption text-on-warning-subtle">
                        {l.student_birth_year ? 'thiếu họ tên' : 'thiếu năm sinh'}
                      </span>
                    )}
                  </td>
                  <td className="px-2 py-2">
                    <span className="font-medium">{l.package_name}</span>
                    {gift && (
                      <span className="block text-caption text-fg-muted">
                        Quà tặng: chỉ bỏ dòng được
                      </span>
                    )}
                    {d.removed && (
                      <span className="block text-caption text-fg-muted">Sẽ bỏ khi bấm Lưu</span>
                    )}
                  </td>
                  <td className="px-2 py-2">
                    {gift || d.removed ? (
                      '—'
                    ) : (
                      <Select
                        label={`Hình thức dòng ${l.line_no}`}
                        value={d.mode}
                        onChange={(v) => onChange(l.line_no, { mode: v })}
                        options={modes}
                      />
                    )}
                  </td>
                  <td className="px-2 py-2">
                    {lineClasses[l.line_no]?.class_code ?? <span className="text-fg-muted">—</span>}
                    {!gift && !d.removed && (
                      <button
                        type="button"
                        className="focus-ring block text-caption text-link hover:underline"
                        onClick={() => onPickClass(l)}
                      >
                        {lineClasses[l.line_no] ? 'Đổi lớp' : 'Chọn lớp'}
                      </button>
                    )}
                  </td>
                  <td className="px-2 py-2">
                    {lineClasses[l.line_no] ? (
                      formatDate(lineClasses[l.line_no]?.enrol_start_date)
                    ) : (
                      <span className="text-fg-muted">—</span>
                    )}
                  </td>
                  <td className="px-2 py-2">
                    {gift || d.removed ? (
                      <span className="tabular">{formatNumber(l.quantity)}</span>
                    ) : (
                      <span className="flex flex-col gap-1">
                        <input
                          aria-label={`Số giờ dòng ${l.line_no}`}
                          inputMode="decimal"
                          autoComplete="off"
                          className={`${INPUT_CLASS} tabular w-24 text-right`}
                          value={d.quantity === null ? '' : String(d.quantity)}
                          onChange={(e) => {
                            const text = e.target.value.replace(',', '.').trim();
                            onChange(l.line_no, {
                              quantity:
                                text === '' || Number.isNaN(Number(text)) ? null : Number(text),
                            });
                          }}
                        />
                        {error && (
                          <span className="text-caption text-on-danger-subtle">{error}</span>
                        )}
                      </span>
                    )}
                  </td>
                  <td className={`tabular px-2 py-2 text-right ${dim}`}>
                    {formatNumber(l.unit_price)}
                  </td>
                  <td className="px-2 py-2">
                    {gift || d.removed ? (
                      '—'
                    ) : (
                      <DiscountEditor
                        label={`dòng ${l.line_no}`}
                        discounts={d.discounts}
                        onChange={(next) => onChange(l.line_no, { discounts: next })}
                        policies={policies}
                        addable={addable}
                        oldOf={(id) => l.discounts.find((q) => q.policy_id === id)}
                      />
                    )}
                  </td>
                  <td className={`tabular px-2 py-2 text-right ${dim}`}>
                    {discountText(l) || '—'}
                  </td>
                  <td className={`tabular px-2 py-2 text-right ${dim}`}>
                    {formatNumber(l.discount_amount)}
                  </td>
                  <td className={`tabular px-2 py-2 text-right ${dim}`}>
                    {formatNumber(l.line_total)}
                  </td>
                  <td className="px-2 py-2">
                    {d.removed ? (
                      <Button onClick={() => onChange(l.line_no, { removed: false })}>
                        Giữ lại
                      </Button>
                    ) : (
                      <Button
                        disabled={live.length <= 1}
                        title={live.length <= 1 ? 'Đơn cần ít nhất một dòng' : undefined}
                        onClick={() => onChange(l.line_no, { removed: true })}
                      >
                        Bỏ dòng
                      </Button>
                    )}
                  </td>
                </tr>
              );
            })}
            {draft.added.map((a, i) => {
              const error = addedError(a);
              return (
                <tr key={a.key} className="border-t border-border align-top">
                  <td className="px-3 py-2">
                    <Select
                      label={`Học sinh dòng mới ${i + 1}`}
                      value={a.studentId}
                      placeholder="Chọn học sinh"
                      onChange={(v) => onChangeAdded(a.key, { studentId: v })}
                      options={students.map((st) => ({
                        value: st.id,
                        label: `${st.full_name ?? 'Học sinh chưa có tên'}${st.birth_year ? ` · ${st.birth_year}` : ''}`,
                      }))}
                    />
                  </td>
                  <td className="px-2 py-2">
                    <span className="font-medium">{a.packageName}</span>
                    <span className="block text-caption text-fg-muted">
                      {`${a.packageCode} · dòng mới, tính giá khi Lưu`}
                    </span>
                  </td>
                  <td className="px-2 py-2">
                    <Select
                      label={`Hình thức dòng mới ${i + 1}`}
                      value={a.mode}
                      onChange={(v) => onChangeAdded(a.key, { mode: v })}
                      options={modes.filter((m) => a.modes.includes(m.value))}
                    />
                  </td>
                  <td className="px-2 py-2 text-fg-muted">—</td>
                  <td className="px-2 py-2 text-fg-muted">—</td>
                  <td className="px-2 py-2">
                    <span className="flex flex-col gap-1">
                      <input
                        aria-label={`Số lượng dòng mới ${i + 1}`}
                        inputMode="decimal"
                        autoComplete="off"
                        className={`${INPUT_CLASS} tabular w-24 text-right`}
                        value={a.quantity === null ? '' : String(a.quantity)}
                        onChange={(e) => {
                          const text = e.target.value.replace(',', '.').trim();
                          onChangeAdded(a.key, {
                            quantity:
                              text === '' || Number.isNaN(Number(text)) ? null : Number(text),
                          });
                        }}
                      />
                      {error && <span className="text-caption text-on-danger-subtle">{error}</span>}
                    </span>
                  </td>
                  <td className="px-2 py-2 text-right text-fg-muted opacity-50">—</td>
                  <td className="px-2 py-2">
                    <DiscountEditor
                      label={`dòng mới ${i + 1}`}
                      discounts={a.discounts}
                      onChange={(next) => onChangeAdded(a.key, { discounts: next })}
                      policies={policies}
                      addable={policies.filter(
                        (p) =>
                          !a.discounts.some((x) => x.policy_id === p.id) &&
                          applicableTo(p, a.packageTypeCode, branchId, today),
                      )}
                    />
                  </td>
                  <td className="px-2 py-2 text-right text-fg-muted opacity-50">—</td>
                  <td className="px-2 py-2 text-right text-fg-muted opacity-50">—</td>
                  <td className="px-2 py-2 text-right text-fg-muted opacity-50">—</td>
                  <td className="px-2 py-2">
                    <Button onClick={() => onRemoveAdded(a.key)}>Bỏ dòng</Button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button icon="plus" onClick={onAdd}>
          Thêm dòng
        </Button>
        <span className="text-caption text-fg-muted">
          Chưa thấy học sinh? Thêm học sinh ở cơ hội.
        </span>
      </div>
    </div>
  );
}
