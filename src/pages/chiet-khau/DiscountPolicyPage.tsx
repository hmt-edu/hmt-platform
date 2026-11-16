// CH-04 Chính sách chiết khấu và quà tặng (canvas 9933: CH04_chinh, CH04_loi): hai tab Chiết khấu, Quà tặng; bảng, hộp Thêm/Sửa, Ngừng/Dùng lại.
// Luật R-TIEN-29, R-TIEN-30, R-TIEN-14 (Ngừng thì không hiện ở chỗ chọn mới; đơn cũ giữ giá trị đã chụp; không xoá). Quyền Cấu hình bán hàng, DB kiểm.
// VÊNH CANVAS (làm theo luật và DB, ghi ở PR): DB chỉ có kiểu % và Giờ tặng (không «Số tiền cố định»), «Giá trị» và «Mức tối đa» là một (max_value, kèm cờ «áp đúng mức»),
// không có cột «Áp dụng cho» (Báo giá, Đơn, Phiếu thu). Chính sách «Ưu đãi linh hoạt» (hệ thống, hạn mức ở Tham số nghiệp vụ) không sửa, không ngừng ở màn này.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { formatDate } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag, type TagTone } from '../../ui/Data';
import { Alert, Spinner, StateView } from '../../ui/Feedback';
import { FormDialog } from '../../ui/Dialogs';
import { Checkbox, Field, TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { LineTable, type LineColumn } from '../../ui/LineTable';
import { Select, Tabs } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import {
  branchesLabel,
  dateToIso,
  discountValueLabel,
  errorSummary,
  formErrors,
  isoToDate,
  policyCode,
  STATUS_LABEL,
  statusOf,
  todayVn,
  type DiscountPolicy,
  type FormValues,
  type GiftPolicy,
  type PolicyStatus,
} from './policyLogic';
import {
  saveDiscountPolicy,
  saveGiftPolicy,
  setPolicyActive,
  useDiscountPolicies,
  useGiftPackages,
  useGiftPolicies,
  usePackageTypes,
  useRefreshPolicies,
  type NamedCode,
} from './usePolicyData';

const STATUS_TONE: Record<PolicyStatus, TagTone> = {
  ACTIVE: 'success',
  UPCOMING: 'info',
  EXPIRED: 'neutral',
  STOPPED: 'neutral',
};

type Editing =
  { kind: 'discount'; policy: DiscountPolicy | null } | { kind: 'gift'; policy: GiftPolicy | null };

export function DiscountPolicyPage() {
  const access = useAccess();
  const supabase = useDb();
  const toast = useToast();
  const refresh = useRefreshPolicies();
  const discounts = useDiscountPolicies();
  const gifts = useGiftPolicies();
  const packageTypes = usePackageTypes();
  const [tab, setTab] = useState('discount');
  const [editing, setEditing] = useState<Editing | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const canCreate = access.can('CONFIG_SALES', 'TAO');
  const canEdit = access.can('CONFIG_SALES', 'SUA');
  const branches = access.teachingBranches;
  const branchCode = (id: string) => branches.find((b) => b.id === id)?.code ?? id;
  const typeName = (code: string) => packageTypes.data?.find((t) => t.code === code)?.name ?? code;
  const today = todayVn();

  const toggle = async (entity: 'DISCOUNT_POLICY' | 'GIFT_POLICY', id: string, active: boolean) => {
    setBusyId(id);
    try {
      await setPolicyActive(supabase, entity, id, active);
      await refresh();
      toast({ title: active ? 'Đã dùng lại chính sách.' : 'Đã ngừng chính sách.' });
    } catch (e) {
      toast({ title: errorOf(e).message, tone: 'danger' });
    } finally {
      setBusyId(null);
    }
  };

  const common = <P extends DiscountPolicy | GiftPolicy>(
    entity: 'DISCOUNT_POLICY' | 'GIFT_POLICY',
    open: (p: P) => void,
    locked: (p: P) => boolean,
  ): LineColumn<P>[] => [
    {
      key: 'valid',
      header: 'Hiệu lực từ – đến',
      width: 'w-44',
      cell: (p) => `${formatDate(p.valid_from)} – ${p.valid_to ? formatDate(p.valid_to) : '…'}`,
    },
    {
      key: 'types',
      header: 'Nhóm gói',
      cell: (p) =>
        p.package_type_codes.length === 0
          ? 'Mọi nhóm'
          : p.package_type_codes.map(typeName).join(', '),
    },
    { key: 'branch', header: 'Cơ sở', cell: (p) => branchesLabel(p.branch_ids, branchCode) },
    {
      key: 'approval',
      header: 'Cần duyệt',
      width: 'w-24',
      cell: (p) => (p.requires_approval ? 'Có' : 'Không'),
    },
    {
      key: 'status',
      header: 'Trạng thái',
      width: 'w-36',
      cell: (p) => {
        const s = statusOf(p, today);
        return <Tag tone={STATUS_TONE[s]}>{STATUS_LABEL[s]}</Tag>;
      },
    },
    {
      key: 'actions',
      header: 'Thao tác',
      headerSrOnly: 'Thao tác',
      width: 'w-40',
      cell: (p) =>
        canEdit && !locked(p) ? (
          <div className="flex gap-1">
            <Button variant="text" onClick={() => open(p)}>
              Sửa
            </Button>
            <Button
              variant="text"
              loading={busyId === p.id}
              onClick={() => void toggle(entity, p.id, !p.is_active)}
            >
              {p.is_active ? 'Ngừng' : 'Dùng lại'}
            </Button>
          </div>
        ) : (
          '—'
        ),
    },
  ];

  const discountColumns: LineColumn<DiscountPolicy>[] = [
    {
      key: 'name',
      header: 'Tên chính sách',
      cell: (p) => (
        <span className="flex items-center gap-2">
          <b>{p.name}</b>
          {p.is_flexible && <Tag tone="info">Hệ thống</Tag>}
        </span>
      ),
    },
    {
      key: 'kind',
      header: 'Kiểu',
      width: 'w-28',
      cell: (p) => (p.kind === 'PERCENT' ? '%' : 'Giờ tặng'),
    },
    {
      key: 'max',
      header: 'Mức tối đa',
      width: 'w-40',
      cell: (p) => `${discountValueLabel(p)}${p.fixed_value ? ' (áp đúng mức)' : ''}`,
    },
    ...common<DiscountPolicy>(
      'DISCOUNT_POLICY',
      (p) => setEditing({ kind: 'discount', policy: p }),
      (p) => p.is_flexible,
    ),
  ];
  const giftColumns: LineColumn<GiftPolicy>[] = [
    { key: 'name', header: 'Tên chính sách', cell: (p) => <b>{p.name}</b> },
    {
      key: 'gift',
      header: 'Loại quà',
      cell: (p) =>
        p.gift_package ? `${p.gift_package.name} (${p.gift_package.package_type_code})` : '—',
    },
    {
      key: 'max',
      header: 'Mức tối đa',
      width: 'w-40',
      cell: (p) => `${p.max_quantity.toLocaleString('vi-VN')} / đơn`,
    },
    ...common<GiftPolicy>(
      'GIFT_POLICY',
      (p) => setEditing({ kind: 'gift', policy: p }),
      () => false,
    ),
  ];

  const failed = discounts.isError || gifts.isError;
  const loading = !discounts.data || !gifts.data;
  const table = <P,>(
    columns: LineColumn<P>[],
    rows: P[],
    caption: string,
    key: (p: P) => string,
  ) => (
    <LineTable
      caption={caption}
      columns={columns}
      rows={rows}
      rowKey={key}
      rowLabel={(p) => key(p)}
    />
  );

  return (
    <div className="mx-auto flex max-w-[1280px] flex-col gap-4 p-4 md:p-6">
      <h1 className="text-h1">Chính sách chiết khấu</h1>
      {failed ? (
        <StateView
          kind="error"
          title="Không tải được chính sách"
          actions={
            <Button
              onClick={() => {
                void discounts.refetch();
                void gifts.refetch();
              }}
            >
              Thử lại
            </Button>
          }
        >
          {errorOf(discounts.error ?? gifts.error).message}
        </StateView>
      ) : loading ? (
        <Spinner label="Đang tải chính sách…" />
      ) : (
        <Tabs
          label="Loại chính sách"
          value={tab}
          onChange={setTab}
          items={[
            {
              value: 'discount',
              label: 'Chiết khấu',
              count: discounts.data.length,
              content: (
                <div className="flex flex-col gap-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-body text-fg-muted">
                      Nhiều chiết khấu trên một dòng thì cộng dồn; tổng không quá trần chiết khấu
                      (tham số, đổi ở Tham số nghiệp vụ). Giờ tặng tính vào trần: giờ tặng ÷ giờ
                      mua. Vượt trần phải quản lý cơ sở duyệt (R-TIEN-29).
                    </p>
                    {canCreate && (
                      <Button
                        variant="primary"
                        icon="plus"
                        onClick={() => setEditing({ kind: 'discount', policy: null })}
                      >
                        Thêm chiết khấu
                      </Button>
                    )}
                  </div>
                  {table(discountColumns, discounts.data, 'Chính sách chiết khấu', (p) => p.id)}
                  <p className="text-caption text-fg-muted">
                    Ngừng một chính sách thì không hiện ở chỗ chọn mới; đơn cũ giữ nguyên chiết khấu
                    đã chụp lúc tạo (R-TIEN-14). Không xoá.
                  </p>
                </div>
              ),
            },
            {
              value: 'gift',
              label: 'Quà tặng',
              count: gifts.data.length,
              content: (
                <div className="flex flex-col gap-3">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-body text-fg-muted">
                      Quà tặng là tài liệu, dịch vụ (dòng giá 0 đ). Không tính vào trần chiết khấu
                      (R-TIEN-30).
                    </p>
                    {canCreate && (
                      <Button
                        variant="primary"
                        icon="plus"
                        onClick={() => setEditing({ kind: 'gift', policy: null })}
                      >
                        Thêm quà tặng
                      </Button>
                    )}
                  </div>
                  {table(giftColumns, gifts.data, 'Chính sách quà tặng', (p) => p.id)}
                </div>
              ),
            },
          ]}
        />
      )}
      {editing && (
        <PolicyForm
          key={`${editing.kind}:${editing.policy?.id ?? 'new'}`}
          editing={editing}
          packageTypes={packageTypes.data ?? []}
          branches={branches}
          onClose={() => setEditing(null)}
          onSaved={async () => {
            setEditing(null);
            await refresh();
            toast({ title: 'Đã lưu chính sách.' });
          }}
        />
      )}
    </div>
  );
}

function PolicyForm({
  editing,
  packageTypes,
  branches,
  onClose,
  onSaved,
}: {
  editing: Editing;
  packageTypes: NamedCode[];
  branches: { id: string; code: string; name: string }[];
  onClose: () => void;
  onSaved: () => Promise<void>;
}) {
  const supabase = useDb();
  const giftPackages = useGiftPackages();
  const isGift = editing.kind === 'gift';
  const p = editing.policy;
  const [v, setV] = useState<FormValues>({
    name: p?.name ?? '',
    kind: editing.kind === 'discount' ? (editing.policy?.kind ?? 'PERCENT') : 'PERCENT',
    maxValue: String(
      editing.kind === 'discount'
        ? (editing.policy?.max_value ?? '')
        : (editing.policy?.max_quantity ?? ''),
    ),
    fixedValue: editing.kind === 'discount' ? (editing.policy?.fixed_value ?? false) : false,
    requiresApproval: p?.requires_approval ?? false,
    validFrom: p ? isoToDate(p.valid_from) : null,
    validTo: p?.valid_to ? isoToDate(p.valid_to) : null,
    packageTypes: p?.package_type_codes ?? [],
    branchIds: p?.branch_ids ?? [],
  });
  const [giftPackageId, setGiftPackageId] = useState(
    editing.kind === 'gift' ? (editing.policy?.gift_package_id ?? '') : '',
  );
  const [tried, setTried] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const errors = formErrors(v, isGift);
  const summary = errorSummary(errors);
  const set = (patch: Partial<FormValues>) => setV((cur) => ({ ...cur, ...patch }));
  const toggleIn = (list: string[], item: string) =>
    list.includes(item) ? list.filter((x) => x !== item) : [...list, item];
  const show = <K extends keyof typeof errors>(k: K) => (tried ? errors[k] : undefined);

  const submit = () => {
    setTried(true);
    if (summary !== null || v.validFrom === null) return;
    if (isGift && giftPackageId === '') {
      setError('Chọn loại quà.');
      return;
    }
    setBusy(true);
    setError(null);
    const base = {
      name: v.name.trim(),
      requires_approval: v.requiresApproval,
      valid_from: dateToIso(v.validFrom),
      valid_to: v.validTo ? dateToIso(v.validTo) : null,
      package_type_codes: v.packageTypes,
      branch_ids: v.branchIds,
    };
    const request = isGift
      ? saveGiftPolicy(supabase, p?.id ?? null, {
          ...base,
          ...(p ? {} : { code: policyCode(v.name) }),
          gift_package_id: giftPackageId,
          max_quantity: Number(v.maxValue.replace(',', '.')),
        })
      : saveDiscountPolicy(supabase, p?.id ?? null, {
          ...base,
          ...(p ? {} : { code: policyCode(v.name) }),
          kind: v.kind,
          max_value: Number(v.maxValue.replace(',', '.')),
          fixed_value: v.kind === 'PERCENT' && v.fixedValue,
        });
    void request
      .then(onSaved)
      .catch((e: unknown) => setError(errorOf(e).message))
      .finally(() => setBusy(false));
  };

  const title = isGift
    ? p
      ? 'Sửa chính sách quà tặng'
      : 'Thêm chính sách quà tặng'
    : p
      ? 'Sửa chính sách chiết khấu'
      : 'Thêm chính sách chiết khấu';
  return (
    <FormDialog
      open
      wide
      onOpenChange={(open) => !open && onClose()}
      title={title}
      confirmLabel="Lưu"
      canSubmit
      busy={busy}
      error={error}
      onSubmit={submit}
    >
      <div className="flex flex-col gap-3">
        {tried && summary && <Alert tone="danger">{summary}</Alert>}
        <TextField
          label="Tên chính sách"
          required
          value={v.name}
          onChange={(e) => set({ name: e.target.value })}
          invalid={!!show('name')}
          error={show('name')}
          help={p ? `Mã ${p.code}, không đổi.` : undefined}
        />
        {isGift ? (
          <Field label="Loại quà" required>
            {(field) => (
              <Select
                id={field.id}
                label="Loại quà"
                value={giftPackageId}
                onChange={setGiftPackageId}
                placeholder="Chọn gói quà"
                options={(giftPackages.data ?? []).map((g) => ({
                  value: g.id,
                  label: `${g.name} (${g.package_type_code})`,
                }))}
              />
            )}
          </Field>
        ) : (
          <Field label="Kiểu" required>
            {(field) => (
              <Select
                id={field.id}
                label="Kiểu"
                value={v.kind}
                disabled={p !== null}
                onChange={(x) =>
                  set({ kind: x === 'GIFT_HOURS' ? 'GIFT_HOURS' : 'PERCENT', fixedValue: false })
                }
                options={[
                  { value: 'PERCENT', label: '%' },
                  { value: 'GIFT_HOURS', label: 'Giờ tặng' },
                ]}
              />
            )}
          </Field>
        )}
        <div className="grid gap-3 sm:grid-cols-2">
          <TextField
            label={
              isGift
                ? 'Mức tối đa (số lượng mỗi đơn)'
                : v.kind === 'PERCENT'
                  ? 'Mức tối đa (%)'
                  : 'Mức tối đa (giờ)'
            }
            required
            inputMode="decimal"
            value={v.maxValue}
            onChange={(e) => set({ maxValue: e.target.value })}
            invalid={!!show('maxValue')}
            error={show('maxValue')}
          />
          {!isGift && v.kind === 'PERCENT' && (
            <Checkbox
              label="Áp đúng mức này (nhân viên không nhập)"
              checked={v.fixedValue}
              onChange={(e) => set({ fixedValue: e.target.checked })}
            />
          )}
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <DateInput
            label="Hiệu lực từ"
            required
            value={v.validFrom}
            onChange={(d) => set({ validFrom: d })}
            error={show('validFrom')}
          />
          <DateInput
            label="Hiệu lực đến"
            value={v.validTo}
            onChange={(d) => set({ validTo: d })}
            error={show('validTo')}
          />
        </div>
        <fieldset className="flex flex-col gap-1">
          <legend className="text-body font-semibold">Cơ sở</legend>
          <p className="text-caption text-fg-muted">Không chọn cơ sở nào là Tất cả cơ sở.</p>
          <div className="flex flex-wrap gap-x-4">
            {branches.map((b) => (
              <Checkbox
                key={b.id}
                label={`${b.code} ${b.name}`}
                checked={v.branchIds.includes(b.id)}
                onChange={() => set({ branchIds: toggleIn(v.branchIds, b.id) })}
              />
            ))}
          </div>
        </fieldset>
        <Checkbox
          label="Cần duyệt (quản lý cơ sở duyệt)"
          checked={v.requiresApproval}
          onChange={(e) => set({ requiresApproval: e.target.checked })}
        />
        <fieldset className="flex flex-col gap-1">
          <legend className="text-body font-semibold">Nhóm gói *</legend>
          <div className="flex flex-wrap gap-x-4">
            {packageTypes.map((t) => (
              <Checkbox
                key={t.code}
                label={t.name}
                checked={v.packageTypes.includes(t.code)}
                onChange={() => set({ packageTypes: toggleIn(v.packageTypes, t.code) })}
              />
            ))}
          </div>
          {show('packageTypes') && (
            <p className="text-caption text-danger-action">{show('packageTypes')}</p>
          )}
        </fieldset>
      </div>
    </FormDialog>
  );
}
