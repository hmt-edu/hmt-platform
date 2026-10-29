// Lưới sửa dòng báo giá Nháp (khuôn K06c, dùng đầu tiên cho BH-02). Mỗi dòng hai tầng: tầng 1 Học sinh, Gói, Hình thức, Số lượng (kèm đơn
// vị), Giờ tặng; tầng 2 chính sách chiết khấu bên trái, Đơn giá, Giảm, Thành tiền bên phải trên nền xám (chỉ đọc, do hệ thống trả).
// Giao diện KHÔNG tính tiền, giờ hay chiết khấu: số trên màn là số máy chủ đã trả.
import { useState } from 'react';
import { Link } from 'react-router';
import { formatMoney, formatNumber } from '../../lib/format';
import { Button, IconButton } from '../../ui/Button';
import { Select } from '../../ui/Overlays';
import { INPUT_CLASS } from '../../ui/Field';
import { cn } from '../../ui/cn';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  blankRow,
  giftRow,
  insertPackageRow,
  modesOfPrices,
  type EditRow,
  type RowIssue,
} from './quoteEdit';
import { QuotePackageDialog } from './QuotePackageDialog';
import { QuoteGiftDialog } from './QuoteGiftDialog';
import { QuotePolicyDialog } from './QuotePolicyDialog';
import { percentText, type RowCalc } from './quotePreview';
import { UNIT_LABEL } from './quoteRecord';
import type { DiscountPolicy, GiftPolicy, OppStudent, SellablePackage } from './useQuoteData';

const GRID =
  'grid grid-cols-[minmax(130px,1.1fr)_minmax(150px,1.3fr)_minmax(96px,0.8fr)_minmax(120px,0.9fr)_88px_36px] items-center gap-2';

function studentLabel(s: OppStudent): string {
  const name = s.full_name ?? `Em thứ ${String(s.position)}`;
  return s.birth_year ? `${name} · ${String(s.birth_year)}` : name;
}

/** Số hiện ở ô Đơn giá, Giảm, Thành tiền: số máy chủ vừa trả; chưa có lần tính nào thì số đã lưu của dòng chưa đổi; còn lại "—". */
function priceText(
  calc: RowCalc | undefined,
  row: EditRow,
  key: 'unitPrice' | 'discountAmount' | 'lineTotal',
  money = false,
): string {
  const text = (n: number) => (money ? formatMoney(n) : formatNumber(n));
  if (calc?.status === 'ok') return text(calc[key]);
  if (calc === undefined && row.calc) return text(row.calc[key]);
  return '—';
}

export function QuoteLineGrid({
  rows,
  onChange,
  students,
  opportunityId,
  opportunityHref,
  issues,
  disabled,
  policies,
  giftPolicies,
  calcs,
  cap,
}: {
  rows: EditRow[];
  onChange: (rows: EditRow[]) => void;
  students: OppStudent[];
  opportunityId: string;
  opportunityHref: string;
  issues: RowIssue[];
  disabled: boolean;
  policies: DiscountPolicy[];
  giftPolicies: GiftPolicy[];
  calcs: Record<string, RowCalc>;
  /** Trần chiết khấu (R-TIEN-29), đọc từ tham số cài đặt. */
  cap: number | null;
}) {
  const catalogs = useLeadCatalogs();
  const [pickFor, setPickFor] = useState<string | null>(null);
  const [policyFor, setPolicyFor] = useState<string | null>(null);
  const [giftOpen, setGiftOpen] = useState(false);
  const giftById = new Map(giftPolicies.map((g) => [g.id, g]));
  // R-TIEN-35: dòng mới mặc định em đầu của cơ hội (đổi được); cơ hội chưa có em thì để trống.
  const firstStudentId = students[0]?.id ?? '';
  const policyById = new Map(policies.map((p) => [p.id, p]));
  const modeName = (code: string) => catalogs.name('STUDY_MODE', code) ?? code;
  const update = (key: string, patch: Partial<EditRow>) =>
    onChange(rows.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  const issueOf = (key: string) => issues.find((i) => i.rowKey === key);
  // Chính sách hiện cho dòng: đúng loại gói đang chọn (rỗng là mọi loại); chưa chọn gói thì hiện hết, máy chủ kiểm lúc tính.
  const policiesFor = (row: EditRow | undefined) =>
    policies.filter(
      (p) =>
        row === undefined ||
        row.packageType === '' ||
        p.package_type_codes.length === 0 ||
        p.package_type_codes.includes(row.packageType),
    );
  const totalTextOf = (row: EditRow | undefined) => {
    const c = row ? calcs[row.key] : undefined;
    return c?.status === 'ok' ? `${percentText(c.totalPercent)}%` : '—';
  };

  function pickPackage(row: EditRow, pkg: SellablePackage) {
    const modes = modesOfPrices(pkg.prices);
    // Gói bán một hình thức thì khoá hình thức đó; nhiều hình thức thì giữ hình thức đang chọn nếu còn bán, không thì lấy hình thức đầu.
    const mode = modes.includes(row.mode) ? row.mode : (modes[0] ?? '');
    update(row.key, {
      packageId: pkg.id,
      packageCode: pkg.code,
      packageName: pkg.name,
      packageType: pkg.package_type_code,
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
          const calc: RowCalc | undefined = calcs[row.key];
          const giftDiscount = row.discounts.find(
            (d) => policyById.get(d.policyId)?.kind === 'GIFT_HOURS',
          );
          const giftPolicy = giftDiscount ? policyById.get(giftDiscount.policyId) : undefined;
          const calcError = calc?.status === 'error' ? calc.message : null;
          const overCap = calc?.status === 'ok' && calc.overCap;
          return (
            <li
              key={row.key}
              aria-label={`Dòng ${String(index + 1)}`}
              className={cn(
                'flex flex-col gap-2 rounded-control border bg-surface p-2',
                issue || calcError ? 'border-danger' : overCap ? 'border-warning' : 'border-border',
              )}
              aria-busy={calc?.status === 'pending' ? true : undefined}
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
                      title={
                        row.packageId === '' ? undefined : `${row.packageCode} · ${row.packageName}`
                      }
                      className="focus-ring flex h-control w-full items-center rounded-control border border-border-strong bg-surface px-2.5 text-left hover:bg-hover disabled:opacity-60"
                    >
                      {/* Một dòng như các ô bên cạnh (cùng chiều cao), tên gói dài thì cắt bớt; đầy đủ ở chú thích khi rê chuột. */}
                      {row.packageId === '' ? (
                        <span className="text-fg-muted">Chọn gói…</span>
                      ) : (
                        <span className="min-w-0 truncate">
                          <span className="font-medium">{row.packageCode}</span>
                          <span className="text-caption text-fg-muted">{` · ${row.packageName}`}</span>
                        </span>
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
                <div className="flex min-h-control items-center gap-1.5">
                  <div className="w-16 shrink-0">
                    <input
                      type="text"
                      inputMode="decimal"
                      aria-label={`Số lượng dòng ${String(index + 1)}`}
                      aria-invalid={issue ? true : undefined}
                      value={row.quantity}
                      disabled={disabled}
                      onChange={(e) => update(row.key, { quantity: e.target.value, calc: null })}
                      className={cn(INPUT_CLASS, 'tabular')}
                    />
                  </div>
                  <span className="text-caption text-fg-muted">
                    {row.unitCode === '' ? '' : UNIT_LABEL[row.unitCode]}
                  </span>
                </div>
                <div className="flex min-h-control items-center gap-1 tabular">
                  {gift ? null : giftDiscount === undefined ? (
                    <span className="text-fg-muted">0</span>
                  ) : giftPolicy?.fixed_value ? (
                    <span>{percentText(giftPolicy.max_value)}</span>
                  ) : (
                    <div className="w-16 shrink-0">
                      <input
                        type="text"
                        inputMode="decimal"
                        aria-label={`Giờ tặng dòng ${String(index + 1)}`}
                        value={giftDiscount.value}
                        disabled={disabled}
                        onChange={(e) =>
                          update(row.key, {
                            discounts: row.discounts.map((d) =>
                              d.policyId === giftDiscount.policyId
                                ? { ...d, value: e.target.value }
                                : d,
                            ),
                          })
                        }
                        className={cn(INPUT_CLASS, 'tabular')}
                      />
                    </div>
                  )}
                </div>
                <div>
                  <IconButton
                    icon="close"
                    label={`Xoá dòng ${String(index + 1)}`}
                    disabled={disabled}
                    onClick={() => onChange(rows.filter((r) => r.key !== row.key))}
                  />
                </div>
              </div>
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex min-w-0 flex-1 flex-wrap items-center gap-x-3 gap-y-1">
                  <span className="text-caption font-semibold whitespace-nowrap text-fg-muted">
                    {gift ? 'Chính sách quà tặng' : 'Chiết khấu · chính sách'}
                  </span>
                  <div className="flex flex-wrap items-center gap-1.5">
                    {gift && (
                      <span className="rounded-tag bg-surface-subtle px-2 py-0.5 text-caption">
                        {row.giftPolicyName}
                        {giftById.get(row.giftPolicyId) &&
                          ` · tối đa ${percentText(giftById.get(row.giftPolicyId)?.max_quantity ?? 0)} ${row.unitCode === '' ? '' : UNIT_LABEL[row.unitCode]}`}
                        {giftById.get(row.giftPolicyId)?.requires_approval && ' · cần duyệt'}
                      </span>
                    )}
                    {row.discounts.map((d) => {
                      const policy = policyById.get(d.policyId);
                      return (
                        <span
                          key={d.policyId}
                          className="flex items-center gap-1.5 rounded-tag bg-surface-subtle px-2 py-0.5 text-caption"
                        >
                          {d.name}
                          {policy?.kind === 'PERCENT' && !policy.fixed_value && (
                            <>
                              <span aria-hidden="true">·</span>
                              <input
                                type="text"
                                inputMode="decimal"
                                aria-label={`Mức ${d.name} dòng ${String(index + 1)} (%)`}
                                value={d.value}
                                disabled={disabled}
                                onChange={(e) =>
                                  update(row.key, {
                                    discounts: row.discounts.map((x) =>
                                      x.policyId === d.policyId
                                        ? { ...x, value: e.target.value }
                                        : x,
                                    ),
                                  })
                                }
                                className="h-7 w-14 rounded-control border border-border-strong bg-surface px-1.5 text-right tabular"
                              />
                              <span>{`% · tối đa ${percentText(policy.max_value)}%`}</span>
                            </>
                          )}
                          {policy?.kind === 'PERCENT' && policy.fixed_value && (
                            <span>{`· ${percentText(policy.max_value)}% (áp đúng mức)`}</span>
                          )}
                          {policy?.kind === 'GIFT_HOURS' && (
                            <span>
                              {policy.fixed_value
                                ? `· tặng ${percentText(policy.max_value)} giờ (áp đúng mức)`
                                : `· tặng tối đa ${percentText(policy.max_value)} giờ`}
                            </span>
                          )}
                          {policy?.requires_approval && <span>· cần duyệt</span>}
                        </span>
                      );
                    })}
                    {!gift && (
                      <Button
                        size="sm"
                        icon="plus"
                        disabled={disabled}
                        onClick={() => setPolicyFor(row.key)}
                      >
                        Chính sách
                      </Button>
                    )}
                  </div>
                </div>
                <dl className="relative grid w-full shrink-0 grid-cols-3 gap-3 rounded-control bg-canvas px-3 py-1.5 text-body tabular sm:w-[22rem]">
                  {calc?.status === 'pending' && (
                    <span
                      aria-hidden="true"
                      className="absolute inset-0 animate-pulse rounded-control bg-neutral-300/40"
                    />
                  )}
                  {calc?.status === 'needs-student' ? (
                    <div className="relative col-span-3 self-center text-fg">
                      <dt className="sr-only">Giá</dt>
                      <dd>{gift ? 'Chọn em để thêm quà' : 'Chọn em để xem giá'}</dd>
                    </div>
                  ) : calc?.status === 'pending' ? (
                    <div className="relative col-span-3 self-center text-fg">
                      <dt className="sr-only">Giá</dt>
                      <dd>Đang tính giá…</dd>
                    </div>
                  ) : (
                    <>
                      <div className="text-right">
                        <dt className="text-caption text-fg-muted">Đơn giá</dt>
                        <dd>{priceText(calc, row, 'unitPrice', gift)}</dd>
                      </div>
                      <div className="text-right">
                        <dt className="text-caption text-fg-muted">Giảm</dt>
                        <dd>{priceText(calc, row, 'discountAmount', gift)}</dd>
                      </div>
                      <div className="text-right">
                        <dt className="text-caption text-fg-muted">Thành tiền</dt>
                        <dd className="font-semibold">{priceText(calc, row, 'lineTotal', gift)}</dd>
                      </div>
                    </>
                  )}
                </dl>
              </div>
              {calc?.status === 'ok' && calc.totalPercent > 0 && (
                <p className="text-caption text-fg-muted">
                  Tổng chiết khấu <b className="text-fg">{percentText(calc.totalPercent)}%</b>
                  {cap !== null ? ` / trần ${String(cap)}%` : ''}
                </p>
              )}
              {overCap && (
                <p className="text-caption text-on-warning-subtle">
                  Vượt trần: cần Trưởng cơ sở duyệt. Vẫn lưu được.
                </p>
              )}
              {calcError && (
                <p role="alert" className="text-caption text-on-danger-subtle">
                  {calcError}
                </p>
              )}
              {gift && (
                <p className="text-caption text-fg-muted">
                  {`Quà tặng: không tính vào trần chiết khấu${cap === null ? '' : ` ${String(cap)}%`}, không có chiết khấu (R-TIEN-30).`}
                </p>
              )}
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
        <Button
          icon="plus"
          disabled={disabled}
          onClick={() =>
            onChange(insertPackageRow(rows, { ...blankRow(), studentId: firstStudentId }))
          }
        >
          Thêm dòng
        </Button>
        <Button icon="plus" disabled={disabled} onClick={() => setGiftOpen(true)}>
          Thêm quà tặng
        </Button>
      </div>
      <p className="text-caption text-fg-muted">
        Số lượng do nhân viên điền; đơn giá, giảm, thành tiền do hệ thống tính. Giờ tặng chỉ có qua
        chính sách tặng giờ. Quà tặng chỉ thêm qua chính sách quà tặng.
      </p>
      <QuoteGiftDialog
        open={giftOpen}
        onOpenChange={setGiftOpen}
        policies={giftPolicies}
        cap={cap}
        onPick={(policy) => {
          onChange([...rows, { ...giftRow(policy), studentId: firstStudentId }]);
          setGiftOpen(false);
        }}
      />
      <QuotePolicyDialog
        open={policyFor !== null}
        onOpenChange={(open) => !open && setPolicyFor(null)}
        policies={policyFor === null ? [] : policiesFor(rows.find((r) => r.key === policyFor))}
        selected={rows.find((r) => r.key === policyFor)?.discounts.map((d) => d.policyId) ?? []}
        totalText={totalTextOf(rows.find((r) => r.key === policyFor))}
        onApply={(ids) => {
          const row = rows.find((r) => r.key === policyFor);
          if (!row) return;
          update(row.key, {
            discounts: ids.map(
              (id) =>
                row.discounts.find((d) => d.policyId === id) ?? {
                  policyId: id,
                  name: policyById.get(id)?.name ?? '',
                  value: '',
                },
            ),
          });
        }}
      />
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
