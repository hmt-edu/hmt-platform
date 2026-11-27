// Hộp "Chọn chính sách chiết khấu" của lưới sửa Nháp BH-02 (khung BH02_ck): chọn nhiều chính sách (cộng dồn), tối đa một chính sách tặng
// giờ (Đ174). Danh sách do list_applicable_discount_policies trả; "Áp dụng" mới ghi vào dòng.
import { useState } from 'react';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Overlays';
import { Checkbox } from '../../ui/Field';
import { percentText } from './quotePreview';
import type { DiscountPolicy } from './useQuoteData';

function amountText(p: DiscountPolicy): string {
  const max = percentText(p.max_value);
  if (p.kind === 'PERCENT') return p.fixed_value ? `Giảm ${max}%` : `Giảm tối đa ${max}%`;
  return p.fixed_value ? `Tặng ${max} giờ` : `Tặng tối đa ${max} giờ`;
}

function kindText(p: DiscountPolicy): string {
  const approval = p.requires_approval ? 'cần duyệt' : 'không cần duyệt';
  return p.kind === 'PERCENT'
    ? `Loại: giảm theo % · ${approval}`
    : `Loại: giờ tặng (tối đa một chính sách) · ${approval}`;
}

export function QuotePolicyDialog({
  open,
  onOpenChange,
  policies,
  selected,
  totalText,
  onApply,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  policies: DiscountPolicy[];
  selected: string[];
  /** "Tổng chiết khấu" hiện tại của dòng (số do máy chủ trả ở lần xem thử gần nhất); "—" khi chưa có. */
  totalText: string;
  onApply: (policyIds: string[]) => void;
}) {
  if (!open) return null;
  return (
    <PolicyBody
      onOpenChange={onOpenChange}
      policies={policies}
      selected={selected}
      totalText={totalText}
      onApply={onApply}
    />
  );
}

function PolicyBody({
  onOpenChange,
  policies,
  selected,
  totalText,
  onApply,
}: {
  onOpenChange: (open: boolean) => void;
  policies: DiscountPolicy[];
  selected: string[];
  totalText: string;
  onApply: (policyIds: string[]) => void;
}) {
  const [chosen, setChosen] = useState<string[]>(selected);
  const giftChosen = policies.find((p) => p.kind === 'GIFT_HOURS' && chosen.includes(p.id));
  function toggle(id: string) {
    setChosen((cur) => (cur.includes(id) ? cur.filter((x) => x !== id) : [...cur, id]));
  }
  return (
    <Dialog
      open
      onOpenChange={onOpenChange}
      title="Chọn chính sách ưu đãi"
      description="Chọn nhiều chính sách thì cộng dồn, nhưng tối đa một chính sách tặng giờ (Đ174)."
      wide
      footer={
        <>
          <span className="mr-auto self-center text-body text-fg-muted">
            Tổng ưu đãi: <b className="text-fg tabular">{totalText}</b>
          </span>
          <Button onClick={() => onOpenChange(false)}>Huỷ</Button>
          <Button
            variant="primary"
            onClick={() => {
              onApply(chosen);
              onOpenChange(false);
            }}
          >
            Áp dụng
          </Button>
        </>
      }
    >
      {policies.length === 0 ? (
        <p className="text-fg-muted">Chưa có chính sách ưu đãi nào áp dụng được.</p>
      ) : (
        <ul className="flex flex-col">
          {policies.map((p) => {
            const checked = chosen.includes(p.id);
            const blocked =
              p.kind === 'GIFT_HOURS' && giftChosen !== undefined && giftChosen.id !== p.id;
            return (
              <li key={p.id} className="rounded-control px-2 py-1.5 hover:bg-hover">
                <Checkbox
                  label={
                    <span className="flex flex-col">
                      <span className="flex flex-wrap items-center gap-2">
                        <b className="font-semibold">{p.name}</b>
                        <span>{amountText(p)}</span>
                        {p.fixed_value && (
                          <span className="rounded-tag bg-surface-subtle px-1.5 text-caption">
                            Áp đúng mức
                          </span>
                        )}
                        {p.requires_approval && (
                          <span className="rounded-tag bg-warning-subtle px-1.5 text-caption text-on-warning-subtle">
                            Cần duyệt
                          </span>
                        )}
                      </span>
                      <span className="text-caption text-fg-muted">{kindText(p)}</span>
                    </span>
                  }
                  checked={checked}
                  disabled={blocked}
                  onChange={() => toggle(p.id)}
                />
              </li>
            );
          })}
        </ul>
      )}
    </Dialog>
  );
}
