// Hộp "Chọn gói" của lưới sửa Nháp BH-02 (khung BH02_chon): Hay dùng, Gợi ý theo cơ hội, Tất cả gói (lọc loại gói). Danh sách do
// list_sellable_packages trả (đã gồm nhóm Hay dùng và Gợi ý); giá lấy từ bảng giá đang hiệu lực, giao diện không tính gì.
import { useState } from 'react';
import { errorOf } from '../../lib/db';
import { formatNumber } from '../../lib/format';
import { Button } from '../../ui/Button';
import { Spinner } from '../../ui/Feedback';
import { Dialog } from '../../ui/Overlays';
import { cn } from '../../ui/cn';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { modesOfPrices } from './quoteEdit';
import { useSellablePackages, type SellablePackage } from './useQuoteData';

function PackageItem({
  pkg,
  modeName,
  onPick,
}: {
  pkg: SellablePackage;
  modeName: (code: string) => string;
  onPick: (pkg: SellablePackage) => void;
}) {
  const modes = modesOfPrices(pkg.prices);
  return (
    <li>
      <button
        type="button"
        onClick={() => onPick(pkg)}
        className="focus-ring flex min-h-target w-full flex-col gap-0.5 rounded-control px-3 py-2 text-left hover:bg-hover"
      >
        <span className="flex flex-wrap items-center gap-2">
          <b className="font-semibold">{pkg.code}</b>
          <span>{pkg.name}</span>
          {modes.length === 1 && (
            <span className="rounded-tag bg-surface-subtle px-1.5 text-caption text-fg-muted">
              {`chỉ bán ${modeName(modes[0] ?? '')}`}
            </span>
          )}
        </span>
        <span className="text-caption text-fg-muted tabular">
          {modes.map((m) => `${modeName(m)} ${formatNumber(pkg.prices[m] ?? 0)}`).join(' · ')}
        </span>
      </button>
    </li>
  );
}

function Group({
  title,
  hint,
  children,
}: {
  title: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="flex flex-col gap-1">
      <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">{title}</h3>
      {hint && <p className="text-caption text-fg-muted">{hint}</p>}
      <ul className="flex flex-col">{children}</ul>
    </section>
  );
}

export function QuotePackageDialog({
  open,
  onOpenChange,
  opportunityId,
  onPick,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  opportunityId: string;
  onPick: (pkg: SellablePackage) => void;
}) {
  const catalogs = useLeadCatalogs();
  const [type, setType] = useState<string | null>(null);
  const query = useSellablePackages(opportunityId, type, open);
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const data = query.data;
  const byCode = new Map((data?.packages ?? []).map((p) => [p.code, p]));
  const pick = (codes: string[]) =>
    codes.map((c) => byCode.get(c)).filter((p): p is SellablePackage => p !== undefined);
  // Nhóm Hay dùng và Gợi ý chỉ hiện khi chưa lọc loại gói.
  const popular = type === null ? pick(data?.popular ?? []) : [];
  const suggested = type === null ? pick(data?.suggested ?? []) : [];
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="Chọn gói"
      wide
      footer={<Button onClick={() => onOpenChange(false)}>Đóng</Button>}
    >
      {query.isPending && <Spinner label="Đang tải gói…" />}
      {query.isError && (
        <div role="alert" className="flex flex-col items-start gap-2 text-on-danger-subtle">
          <p>{errorOf(query.error).message}</p>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      )}
      {data && (
        <div className="flex flex-col gap-3">
          {popular.length > 0 && (
            <Group title="Hay dùng" hint="Các gói bạn đưa vào báo giá của mình nhiều nhất gần đây.">
              {popular.map((p) => (
                <PackageItem key={p.id} pkg={p} modeName={modeName} onPick={onPick} />
              ))}
            </Group>
          )}
          {suggested.length > 0 && (
            <Group title="Gợi ý theo cơ hội">
              {suggested.map((p) => (
                <PackageItem key={p.id} pkg={p} modeName={modeName} onPick={onPick} />
              ))}
            </Group>
          )}
          <section className="flex flex-col gap-1">
            <h3 className="text-caption font-semibold tracking-wide text-fg-muted uppercase">
              Tất cả gói
            </h3>
            <div role="group" aria-label="Loại gói" className="flex flex-wrap gap-1.5 pb-1">
              {[{ code: '', name: 'Tất cả' }, ...data.types].map((t) => {
                const active = (type ?? '') === t.code;
                return (
                  <button
                    key={t.code}
                    type="button"
                    aria-pressed={active}
                    onClick={() => setType(t.code === '' ? null : t.code)}
                    className={cn(
                      'focus-ring tap h-control-sm rounded-full border px-3 text-caption font-medium',
                      active
                        ? 'border-brand-300 bg-brand-100 text-brand-800'
                        : 'border-border-strong bg-surface hover:bg-hover',
                    )}
                  >
                    {t.code === '' ? 'Tất cả' : t.code}
                  </button>
                );
              })}
            </div>
            <ul className="flex flex-col">
              {data.packages
                .filter((p) => type === null || p.package_type_code === type)
                .map((p) => (
                  <PackageItem key={p.id} pkg={p} modeName={modeName} onPick={onPick} />
                ))}
            </ul>
          </section>
          <p className="text-caption text-fg-muted">
            Gói chỉ có giá một hình thức thì ghi rõ "chỉ bán" hình thức đó. Giá lấy từ bảng giá đang
            hiệu lực.
          </p>
        </div>
      )}
    </Dialog>
  );
}
