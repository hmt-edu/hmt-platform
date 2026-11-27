// Hộp "Chọn chính sách quà tặng" của lưới sửa Nháp BH-02 (khung BH02_ck). Mỗi chính sách chọn được thêm một dòng quà tặng; đây là cách duy nhất
// thêm quà (R-TIEN-30). Danh sách do list_applicable_gift_policies trả.
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Overlays';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { percentText } from './quotePreview';
import { UNIT_LABEL } from './quoteRecord';
import type { GiftPolicy } from './useQuoteData';

export function QuoteGiftDialog({
  open,
  onOpenChange,
  policies,
  cap,
  onPick,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  policies: GiftPolicy[];
  /** Trần chiết khấu (R-TIEN-29) để ghi trong câu hướng dẫn. */
  cap: number | null;
  onPick: (policy: GiftPolicy) => void;
}) {
  const catalogs = useLeadCatalogs();
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Chọn chính sách quà tặng"
      description={`Mỗi chính sách chọn được sẽ thêm một dòng quà tặng. Quà tặng không tính vào trần ưu đãi${cap === null ? '' : ` ${String(cap)}%`}.`}
      footer={<Button onClick={() => onOpenChange(false)}>Đóng</Button>}
    >
      {policies.length === 0 ? (
        <p className="text-fg-muted">Chưa có chính sách quà tặng nào áp dụng được.</p>
      ) : (
        <ul className="flex flex-col">
          {policies.map((p) => (
            <li key={p.id}>
              <button
                type="button"
                onClick={() => onPick(p)}
                className="focus-ring flex min-h-target w-full flex-col gap-0.5 rounded-control px-3 py-2 text-left hover:bg-hover"
              >
                <span className="flex flex-wrap items-center gap-2">
                  <b className="font-semibold">{p.name}</b>
                  <span className="rounded-tag bg-surface-subtle px-1.5 text-caption">
                    {catalogs.name('PACKAGE_TYPE', p.gift_package.package_type_code) ??
                      p.gift_package.package_type_code}
                  </span>
                  {p.requires_approval && (
                    <span className="rounded-tag bg-warning-subtle px-1.5 text-caption text-on-warning-subtle">
                      Cần duyệt
                    </span>
                  )}
                </span>
                <span className="text-caption text-fg-muted">
                  {`${p.gift_package.name} · tối đa ${percentText(p.max_quantity)} ${UNIT_LABEL[p.gift_package.unit_code]}`}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </Dialog>
  );
}
