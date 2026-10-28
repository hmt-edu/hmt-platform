// Lưới sửa dòng báo giá Nháp (khuôn K06c, dùng đầu tiên cho BH-02). Mỗi dòng hai tầng: tầng 1 Học sinh, Gói, Hình thức, Số lượng (kèm đơn
// vị), Giờ tặng; tầng 2 chính sách chiết khấu bên trái, Đơn giá, Giảm, Thành tiền bên phải trên nền xám (chỉ đọc, do hệ thống trả).
// Giao diện KHÔNG tính tiền, giờ hay chiết khấu: số trên màn là số máy chủ đã trả.
import { useState } from 'react';
import { Link } from 'react-router';
import { formatNumber } from '../../lib/format';
import { Button, IconButton } from '../../ui/Button';
import { Select } from '../../ui/Overlays';
import { INPUT_CLASS } from '../../ui/Field';
import { cn } from '../../ui/cn';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { blankRow, modesOfPrices, type EditRow, type RowIssue } from './quoteEdit';
import { QuotePackageDialog } from './QuotePackageDialog';
import { UNIT_LABEL } from './quoteRecord';
import type { OppStudent, SellablePackage } from './useQuoteData';

const GRID =
  'grid grid-cols-[minmax(130px,1.1fr)_minmax(150px,1.3fr)_minmax(96px,0.8fr)_minmax(96px,0.8fr)_64px_36px] items-start gap-2';

function studentLabel(s: OppStudent): string {
  const name = s.full_name ?? `Em thứ ${String(s.position)}`;
  return s.birth_year ? `${name} · ${String(s.birth_year)}` : name;
}

export function QuoteLineGrid({
  rows,
  onChange,
  students,
  opportunityId,
  opportunityHref,
  issues,
  disabled,
}: {
  rows: EditRow[];
  onChange: (rows: EditRow[]) => void;
  students: OppStudent[];
  opportunityId: string;
  opportunityHref: string;
  issues: RowIssue[];
  disabled: boolean;
}) {
  const catalogs = useLeadCatalogs();
  const [pickFor, setPickFor] = useState<string | null>(null);
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const update = (key: string, patch: Partial<EditRow>) =>
    onChange(rows.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  const issueOf = (key: string) => issues.find((i) => i.rowKey === key);

  function pickPackage(row: EditRow, pkg: SellablePackage) {
    const modes = modesOfPrices(pkg.prices);
    // Gói bán một hình thức thì khoá hình thức đó; nhiều hình thức thì giữ hình thức đang chọn nếu còn bán, không thì lấy hình thức đầu.
    const mode = modes.includes(row.mode) ? row.mode : (modes[0] ?? '');
    update(row.key, {
      packageId: pkg.id,
      packageCode: pkg.code,
      packageName: pkg.name,
      unitCode: pkg.unit_code,
      modes,
      mode,
      calc: null,
    });
    setPickFor(null);
  }

  return (
    <div className="flex flex-col gap-2">
      <p className="text-caption text-fg-muted">
        Chưa thấy em?{' '}
        <Link to={opportunityHref} className="font-medium text-link hover:underline">
          Thêm em ở cơ hội.
        </Link>
      </p>
      <div aria-hidden="true" className={cn(GRID, 'px-2 text-caption font-semibold text-fg-muted')}>
        <span>Học sinh</span>
        <span>Gói</span>
        <span>Hình thức</span>
        <span>Số lượng</span>
        <span>Giờ tặng</span>
        <span />
      </div>
      <ul aria-label="Gói học (đang sửa)" className="flex flex-col gap-2">
        {rows.map((row, index) => {
          const issue = issueOf(row.key);
          const gift = row.kind === 'GIFT';
          const giftHours = row.discounts.length === 0 ? '—' : '';
          return (
            <li
              key={row.key}
              aria-label={`Dòng ${String(index + 1)}`}
              className={cn(
                'flex flex-col gap-2 rounded-control border bg-surface p-2',
                issue ? 'border-danger' : 'border-border',
              )}
            >
              <div className={GRID}>
                <div>
                  <Select
                    label={`Học sinh dòng ${String(index + 1)}`}
                    value={row.studentId}
                    onChange={(v) => update(row.key, { studentId: v })}
                    placeholder="Chọn em…"
                    options={students.map((s) => ({ value: s.id, label: studentLabel(s) }))}
                    disabled={disabled}
                    requiredEmpty={row.studentId === ''}
                    className="w-full"
                  />
                </div>
                <div>
                  {gift ? (
                    <span className="flex flex-col">
                      <span className="text-caption text-fg-muted">Quà tặng</span>
                      <span className="font-medium">{row.packageCode}</span>
                      <span>{row.packageName}</span>
                    </span>
                  ) : (
                    <button
                      type="button"
                      disabled={disabled}
                      onClick={() => setPickFor(row.key)}
                      aria-label={`Gói dòng ${String(index + 1)}`}
                      className="focus-ring flex min-h-control w-full flex-col items-start justify-center rounded-control border border-border-strong bg-surface px-2.5 py-1 text-left hover:bg-hover disabled:opacity-60"
                    >
                      {row.packageId === '' ? (
                        <span className="text-fg-muted">Chọn gói…</span>
                      ) : (
                        <>
                          <span className="font-medium">{row.packageCode}</span>
                          <span className="text-caption text-fg-muted">{row.packageName}</span>
                        </>
                      )}
                    </button>
                  )}
                </div>
                <div>
                  {gift ? (
                    <span>—</span>
                  ) : (
                    <>
                      <Select
                        label={`Hình thức dòng ${String(index + 1)}`}
                        value={row.mode}
                        onChange={(v) => update(row.key, { mode: v, calc: null })}
                        placeholder="—"
                        options={(row.modes.length > 0 ? row.modes : ['OFF', 'ONL']).map((m) => ({
                          value: m,
                          label: modeName(m),
                        }))}
                        disabled={disabled || row.packageId === '' || row.modes.length === 1}
                        className="w-full"
                      />
                      {row.modes.length === 1 && (
                        <span className="text-caption text-fg-muted">{`chỉ ${modeName(row.modes[0] ?? '')}`}</span>
                      )}
                    </>
                  )}
                </div>
                <div className="flex items-center gap-1.5">
                  <input
                    type="text"
                    inputMode="decimal"
                    aria-label={`Số lượng dòng ${String(index + 1)}`}
                    aria-invalid={issue ? true : undefined}
                    value={row.quantity}
                    disabled={disabled}
                    onChange={(e) => update(row.key, { quantity: e.target.value, calc: null })}
                    className={cn(INPUT_CLASS, 'w-16 shrink-0 tabular')}
                  />
                  <span className="text-caption text-fg-muted">
                    {row.unitCode === '' ? '' : UNIT_LABEL[row.unitCode]}
                  </span>
                </div>
                <div className="pt-2 text-fg-muted tabular">{giftHours}</div>
                <div>
                  <IconButton
                    icon="close"
                    label={`Xoá dòng ${String(index + 1)}`}
                    disabled={disabled}
                    onClick={() => onChange(rows.filter((r) => r.key !== row.key))}
                  />
                </div>
              </div>
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="flex min-w-0 flex-1 flex-col gap-1">
                  <span className="text-caption font-semibold text-fg-muted">
                    Chiết khấu · chính sách
                  </span>
                  <div className="flex flex-wrap gap-1.5">
                    {row.discounts.length === 0 ? (
                      <span className="text-caption text-fg-muted">—</span>
                    ) : (
                      row.discounts.map((d) => (
                        <span
                          key={d.policyId}
                          className="rounded-tag bg-surface-subtle px-2 py-0.5 text-caption"
                        >
                          {d.name}
                        </span>
                      ))
                    )}
                  </div>
                </div>
                <dl className="grid grid-cols-3 gap-3 rounded-control bg-canvas px-3 py-1.5 text-body tabular">
                  <div>
                    <dt className="text-caption text-fg-muted">Đơn giá</dt>
                    <dd>{row.calc ? formatNumber(row.calc.unitPrice) : '—'}</dd>
                  </div>
                  <div>
                    <dt className="text-caption text-fg-muted">Giảm</dt>
                    <dd>{row.calc ? formatNumber(row.calc.discountAmount) : '—'}</dd>
                  </div>
                  <div>
                    <dt className="text-caption text-fg-muted">Thành tiền</dt>
                    <dd className="font-semibold">
                      {row.calc ? formatNumber(row.calc.lineTotal) : '—'}
                    </dd>
                  </div>
                </dl>
              </div>
              {issue && (
                <p role="alert" className="text-caption text-on-danger-subtle">
                  {issue.message}
                </p>
              )}
            </li>
          );
        })}
      </ul>
      <div className="flex flex-wrap gap-2">
        <Button icon="plus" disabled={disabled} onClick={() => onChange([...rows, blankRow()])}>
          Thêm dòng
        </Button>
      </div>
      <p className="text-caption text-fg-muted">
        Số lượng do nhân viên điền; đơn giá, giảm, thành tiền do hệ thống tính. Giờ tặng chỉ có qua
        chính sách tặng giờ. Quà tặng chỉ thêm qua chính sách quà tặng.
      </p>
      <QuotePackageDialog
        open={pickFor !== null}
        onOpenChange={(open) => !open && setPickFor(null)}
        opportunityId={opportunityId}
        onPick={(pkg) => {
          const row = rows.find((r) => r.key === pickFor);
          if (row) pickPackage(row, pkg);
        }}
      />
    </div>
  );
}
