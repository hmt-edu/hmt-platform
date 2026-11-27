// Lưới sửa dòng báo giá Nháp (khuôn K06c, dùng đầu tiên cho BH-02). Mỗi dòng hai tầng: tầng 1 Học sinh, Gói, Hình thức, Số lượng (kèm đơn
// vị), Giờ tặng; tầng 2 chính sách chiết khấu bên trái, Đơn giá, Giảm, Thành tiền bên phải trên nền xám (chỉ đọc, do hệ thống trả).
// Giao diện KHÔNG tính tiền, giờ hay chiết khấu: số trên màn là số máy chủ đã trả.
import { useState } from 'react';
import { Link } from 'react-router';
import { formatMoney, formatNumber } from '../../lib/format';
import { Button, IconButton } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { Select } from '../../ui/Overlays';
import { INPUT_CLASS } from '../../ui/Field';
import { cn } from '../../ui/cn';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  blankRow,
  giftRow,
  addFamilyRows,
  insertPackageRow,
  modesOfPrices,
  type EditRow,
  type RowIssue,
} from './quoteEdit';
import { QuotePackageDialog } from './QuotePackageDialog';
import { QuoteGiftDialog } from './QuoteGiftDialog';
import { studentLabel } from '../../features/prospect/prospectLogic';
import { QuotePolicyDialog } from './QuotePolicyDialog';
import { percentText, quoteCapText, type RowCalc } from './quotePreview';
import { UNIT_LABEL } from './quoteRecord';
import type { DiscountPolicy, GiftPolicy, OppStudent, SellablePackage } from './useQuoteData';

/** Học sinh chưa có tên thì gọi theo thứ tự trong cơ hội để phân biệt được. */
function studentOption(s: OppStudent) {
  const full_name = s.full_name ?? `Học sinh thứ ${String(s.position)}`;
  return { value: s.id, ...studentLabel({ full_name, birth_year: s.birth_year }) };
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
  limitIssues,
  disabled,
  policies,
  giftPolicies,
  calcs,
  cap,
  layout,
}: {
  rows: EditRow[];
  onChange: (rows: EditRow[]) => void;
  students: OppStudent[];
  opportunityId: string;
  opportunityHref: string;
  issues: RowIssue[];
  /** Vượt hạn mức Ưu đãi linh hoạt: chữ đỏ dưới chip của dòng, nút Lưu mờ (Q-151). */
  limitIssues: RowIssue[];
  disabled: boolean;
  policies: DiscountPolicy[];
  giftPolicies: GiftPolicy[];
  calcs: Record<string, RowCalc>;
  /** Trần chiết khấu (R-TIEN-29), đọc từ tham số cài đặt. */
  cap: number | null;
  /** Q-74: 'tao' = Tạo báo giá 11 cột (BH02_tao); 'sua' = Sửa báo giá 13 cột (BH02_sua). */
  layout: 'tao' | 'sua';
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

  /** Tổng % chiết khấu máy chủ vừa trả (gồm giờ tặng quy ra %); chưa có hoặc 0 thì null. */
  const totalPercentText = (row: EditRow): string | null => {
    // Vượt hạn mức Ưu đãi linh hoạt: chưa có số hợp lệ, hiện "—" như khung BH02_chip_vuot_han_muc.
    if (limitIssues.some((i) => i.rowKey === row.key)) return null;
    const c = calcs[row.key];
    return c?.status === 'ok' && c.totalPercent > 0 ? `${percentText(c.totalPercent)}%` : null;
  };
  /** Chip chính sách chiết khấu (hoặc chính sách quà) của dòng và nút "Chính sách"; một hàng, không xuống dòng. */
  const discountChips = (row: EditRow, index: number) => (
    <>
      {row.kind === 'GIFT' && (
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
                {policy.is_flexible !== true && <span aria-hidden="true">·</span>}
                <input
                  type="text"
                  inputMode="decimal"
                  aria-label={`Mức ${d.name} dòng ${String(index + 1)} (%)`}
                  value={d.value}
                  disabled={disabled}
                  onChange={(e) =>
                    update(row.key, {
                      discounts: row.discounts.map((x) =>
                        x.policyId === d.policyId ? { ...x, value: e.target.value } : x,
                      ),
                    })
                  }
                  className="h-7 w-14 rounded-control border border-border-strong bg-surface px-1.5 text-right tabular"
                />
                {/* Ưu đãi linh hoạt: chip chỉ ghi "tên + số %" (Design); hạn mức hiện ở câu lỗi khi vượt. */}
                <span>
                  {policy.is_flexible === true
                    ? '%'
                    : `% · tối đa ${percentText(policy.max_value)}%`}
                </span>
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
            <button
              type="button"
              aria-label={`Bỏ ${d.name} khỏi dòng ${String(index + 1)}`}
              disabled={disabled}
              onClick={() =>
                update(row.key, {
                  discounts: row.discounts.filter((x) => x.policyId !== d.policyId),
                })
              }
              className="focus-ring rounded-tag px-1 text-fg-muted hover:bg-hover disabled:opacity-60"
            >
              ✕
            </button>
          </span>
        );
      })}
      {row.kind !== 'GIFT' && (
        <Button
          size="sm"
          icon="plus"
          disabled={disabled}
          aria-label={layout === 'tao' ? `Thêm ưu đãi dòng ${String(index + 1)}` : undefined}
          onClick={() => setPolicyFor(row.key)}
        >
          {layout === 'tao' ? 'Thêm' : 'Chính sách'}
        </Button>
      )}
    </>
  );
  /** Ô Chiết khấu: chip một hàng; vượt hạn mức Ưu đãi linh hoạt thì câu đỏ ngay dưới chip (khung BH02_chip_vuot_han_muc). */
  const discountCell = (row: EditRow, index: number) => {
    const limit = limitIssues.find((i) => i.rowKey === row.key);
    return (
      <span className="flex flex-col gap-1">
        <span className="flex items-center gap-1.5">{discountChips(row, index)}</span>
        {limit && (
          <span role="alert" className="text-caption whitespace-nowrap text-on-danger-subtle">
            {limit.message}
          </span>
        )}
      </span>
    );
  };
  const cap_ = cap;
  const columns: LineColumn<EditRow>[] = [
    {
      key: 'no',
      header: '#',
      align: 'center',
      width: 'w-8',
      cell: (_row, index) => <span className="text-fg-muted">{index + 1}</span>,
    },
    {
      key: 'student',
      header: 'Học sinh',
      width: 'w-[150px]',
      cell: (row, index) => (
        <div className="w-full">
          <Select
            label={`Học sinh dòng ${String(index + 1)}`}
            value={row.studentId}
            onChange={(v) => update(row.key, { studentId: v })}
            placeholder="Chọn học sinh…"
            options={students.map(studentOption)}
            disabled={disabled}
            requiredEmpty={row.studentId === ''}
            className="w-full"
          />
        </div>
      ),
    },
    {
      key: 'package',
      header: 'Gói',
      width: 'w-[190px]',
      cell: (row, index) =>
        row.kind === 'GIFT' ? (
          <span className="flex w-full items-baseline gap-2">
            <span className="text-caption text-fg-muted">Quà tặng</span>
            <span className="font-medium">{row.packageCode}</span>
            <span className="min-w-0 truncate">{row.packageName}</span>
          </span>
        ) : (
          <button
            type="button"
            disabled={disabled}
            onClick={() => setPickFor(row.key)}
            aria-label={`${row.packageId === '' ? 'Chọn gói…' : `${row.packageCode} · ${row.packageName}`} (Gói dòng ${String(index + 1)})`}
            title={row.packageId === '' ? undefined : `${row.packageCode} · ${row.packageName}`}
            className="focus-ring flex h-control w-full items-center rounded-control border border-border-strong bg-surface px-2.5 text-left hover:bg-hover disabled:opacity-60"
          >
            {/* Một dòng như các ô bên cạnh, tên gói dài thì cắt bớt; đầy đủ ở chú thích khi rê chuột. */}
            {row.packageId === '' ? (
              <span className="text-fg-muted">Chọn gói…</span>
            ) : (
              <span className="min-w-0 truncate">
                <span className="font-medium">{row.packageCode}</span>
                <span className="text-caption text-fg-muted">{` · ${row.packageName}`}</span>
              </span>
            )}
          </button>
        ),
    },
    {
      key: 'mode',
      header: 'Hình thức',
      width: 'w-24',
      cell: (row, index) =>
        row.kind === 'GIFT' ? (
          <span>—</span>
        ) : (
          <span className="flex items-center gap-2">
            <div className="w-full">
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
            </div>
            {row.modes.length === 1 && (
              <span className="text-caption text-fg-muted">{`chỉ ${modeName(row.modes[0] ?? '')}`}</span>
            )}
          </span>
        ),
    },
    {
      key: 'quantity',
      header: 'Số lượng',
      align: 'right',
      width: 'w-[84px]',
      cell: (row, index) => (
        <input
          type="text"
          inputMode="decimal"
          aria-label={`Số lượng dòng ${String(index + 1)}`}
          aria-invalid={issueOf(row.key) ? true : undefined}
          value={row.quantity}
          disabled={disabled}
          onChange={(e) => update(row.key, { quantity: e.target.value, calc: null })}
          className={cn(INPUT_CLASS, 'tabular w-full text-right')}
        />
      ),
    },
    {
      key: 'unit',
      header: 'Đơn vị',
      width: 'w-14',
      cell: (row) => (
        <span className="text-fg-muted">{row.unitCode === '' ? '' : UNIT_LABEL[row.unitCode]}</span>
      ),
    },
    {
      key: 'gift-hours',
      header: 'Giờ tặng',
      align: 'right',
      width: 'w-[74px]',
      cell: (row, index) => {
        if (row.kind === 'GIFT') return null;
        const giftDiscount = row.discounts.find(
          (d) => policyById.get(d.policyId)?.kind === 'GIFT_HOURS',
        );
        const giftPolicy = giftDiscount ? policyById.get(giftDiscount.policyId) : undefined;
        if (giftDiscount === undefined) return <span className="tabular text-fg-muted">0</span>;
        if (giftPolicy?.fixed_value)
          return <span className="tabular">{percentText(giftPolicy.max_value)}</span>;
        return (
          <input
            type="text"
            inputMode="decimal"
            aria-label={`Giờ tặng dòng ${String(index + 1)}`}
            value={giftDiscount.value}
            disabled={disabled}
            onChange={(e) =>
              update(row.key, {
                discounts: row.discounts.map((d) =>
                  d.policyId === giftDiscount.policyId ? { ...d, value: e.target.value } : d,
                ),
              })
            }
            className={cn(INPUT_CLASS, 'tabular w-full text-right')}
          />
        );
      },
    },
    {
      key: 'unit-price',
      header: 'Đơn giá',
      align: 'right',
      width: 'w-[84px]',
      cell: (row) => {
        const calc: RowCalc | undefined = calcs[row.key];
        if (calc?.status === 'pending') return <span className="text-fg">Đang tính…</span>;
        return (
          <span className="tabular">{priceText(calc, row, 'unitPrice', row.kind === 'GIFT')}</span>
        );
      },
    },
    // Q-74: Tạo báo giá 11 cột (BH02_tao: Chiết khấu gộp một cột, có Tổng %); Sửa báo giá 13 cột (BH02_sua: Loại chiết khấu, %, Giảm).
    layout === 'tao'
      ? {
          key: 'discount',
          header: 'Ưu đãi',
          cell: (row, index) => discountCell(row, index),
        }
      : {
          key: 'discount',
          header: 'Loại ưu đãi',
          cell: (row, index) => discountCell(row, index),
        },
    ...(layout === 'tao'
      ? ([
          {
            key: 'percent',
            header: 'Tổng %',
            align: 'right',
            width: 'w-[76px]',
            cell: (row: EditRow) => <span className="tabular">{totalPercentText(row) ?? '—'}</span>,
          },
        ] satisfies LineColumn<EditRow>[])
      : []),
    ...(layout === 'sua'
      ? ([
          {
            key: 'percent',
            header: '%',
            align: 'right',
            width: 'w-[76px]',
            cell: (row: EditRow) => <span className="tabular">{totalPercentText(row) ?? '—'}</span>,
          },
          {
            key: 'reduction',
            header: 'Giảm',
            align: 'right',
            width: 'w-[92px]',
            cell: (row: EditRow) => (
              <span className="tabular">
                {calcs[row.key]?.status === 'pending'
                  ? '…'
                  : priceText(calcs[row.key], row, 'discountAmount', row.kind === 'GIFT')}
              </span>
            ),
          },
        ] satisfies LineColumn<EditRow>[])
      : []),
    {
      key: 'total',
      header: 'Thành tiền',
      align: 'right',
      width: 'w-[104px]',
      cell: (row) => (
        <span className="tabular font-semibold">
          {calcs[row.key]?.status === 'pending'
            ? '…'
            : limitIssues.some((i) => i.rowKey === row.key)
              ? '—'
              : priceText(calcs[row.key], row, 'lineTotal', row.kind === 'GIFT')}
        </span>
      ),
    },
    {
      key: 'remove',
      header: null,
      width: 'w-[70px]',
      headerSrOnly: 'Xoá dòng',
      cell: (row, index) => (
        <IconButton
          icon="close"
          label={`Xoá dòng ${String(index + 1)}`}
          disabled={disabled}
          onClick={() => onChange(rows.filter((r) => r.key !== row.key))}
        />
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-2">
      <p className="text-caption text-fg-muted">
        Chưa thấy học sinh?{' '}
        <Link to={opportunityHref} className="font-medium text-link hover:underline">
          Thêm học sinh ở cơ hội.
        </Link>
      </p>
      <LineTable<EditRow>
        caption="Gói học (đang sửa)"
        // Vùng cuộn nhận bàn phím: lúc danh sách em còn tải, mọi ô trong bảng bị khoá nên không có phần tử nào focus được (axe scrollable-region-focusable).
        scrollFocusable
        columns={columns}
        rows={rows}
        rowKey={(row) => row.key}
        rowLabel={(_row, index) => `Dòng ${String(index + 1)}`}
        rowBusy={(row) => calcs[row.key]?.status === 'pending'}
        rowAccent={(row) => {
          const calc: RowCalc | undefined = calcs[row.key];
          if (issueOf(row.key) || calc?.status === 'error') return 'danger';
          if (calc?.status === 'ok' && calc.overCap) return 'warning';
          return undefined;
        }}
        rowClassName={(row) => {
          const calc: RowCalc | undefined = calcs[row.key];
          if (issueOf(row.key) || calc?.status === 'error') return 'bg-danger-subtle';
          if (calc?.status === 'ok' && calc.overCap) return 'bg-warning-subtle';
          return undefined;
        }}
        below={(row) => {
          const calc: RowCalc | undefined = calcs[row.key];
          const issue = issueOf(row.key);
          const gift = row.kind === 'GIFT';
          const calcError = calc?.status === 'error' ? calc.message : null;
          const needsStudent = calc?.status === 'needs-student';
          if (!calcError && !gift && !issue && !needsStudent) return null;
          return (
            <div className="flex flex-col gap-0.5">
              {needsStudent && (
                <p className="text-fg-muted">
                  {gift ? 'Chọn học sinh để thêm quà' : 'Chọn học sinh để xem giá'}
                </p>
              )}
              {calcError && (
                <p role="alert" className="text-on-danger-subtle">
                  {calcError}
                </p>
              )}
              {gift && (
                <p className="text-fg-muted">
                  {`Quà tặng: không tính vào trần ưu đãi${cap_ === null ? '' : ` ${String(cap_)}%`}, không giảm thêm.`}
                </p>
              )}
              {issue && (
                <p role="alert" className="text-on-danger-subtle">
                  {issue.message}
                </p>
              )}
            </div>
          );
        }}
      />
      <p className="text-caption text-fg-muted">Kéo thanh ngang để xem các cột bên phải.</p>
      {/* Khung BH02_sua: trần đọc từ tham số cài đặt (discount_total_cap_percent), không viết cứng. */}
      {/* Khung BH02_chip_vuot_tran: có dòng vượt trần thì câu hiện trong hộp cảnh báo vàng; vẫn Lưu và Gửi được (R-V2-11). */}
      {cap !== null &&
        (rows.some((r) => {
          const c: RowCalc | undefined = calcs[r.key];
          return c?.status === 'ok' && c.overCap;
        }) ? (
          <Alert tone="warning">{quoteCapText(cap)}</Alert>
        ) : (
          <p className="text-caption text-fg-muted">{quoteCapText(cap)}</p>
        ))}
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
        <Button
          icon="plus"
          disabled={disabled || students.length < 2}
          onClick={() =>
            onChange(
              addFamilyRows(
                rows,
                students.map((st) => st.id),
              ),
            )
          }
        >
          Thêm cả nhà
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
