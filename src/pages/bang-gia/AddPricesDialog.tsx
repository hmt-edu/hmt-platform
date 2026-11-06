// Hộp "Thêm bảng giá mới" (CH-03, theo gói): chọn ngày hiệu lực, lọc gói theo Loại, Môn, Khối, chọn nhiều gói (chọn tất cả theo bộ lọc),
// nhập MỘT giá offline và/hoặc MỘT giá online áp cho mọi gói đã chọn; sửa riêng từng gói được. Một lần gọi (một giao dịch).
// Ô giá để trống = không thêm giá; "Không bán" = thêm dòng giá để trống (ngừng bán hình thức đó từ ngày hiệu lực).
import { useMemo, useState } from 'react';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { formatNumber, parseMoney } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { Button } from '../../ui/Button';
import { Dialog, Select } from '../../ui/Overlays';
import { Alert } from '../../ui/Feedback';
import { Checkbox, Field, INPUT_CLASS, TextField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Pagination } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { PriceCellView } from './PriceListPage';
import { buildPriceItems, hasNoOnline, toDateKey, type PriceInput } from './priceLogic';
import {
  addPackagePrices,
  packagesForFilter,
  usePricePage,
  type PriceFilters,
} from './usePriceData';

type Picked = Record<string, string>; // id gói đã chọn → loại gói
type Override = { off?: PriceInput; onl?: PriceInput };

const BOX = 'size-4 accent-[var(--action-primary-bg)]';
const NONE_TEXT = 'Không bán';
const textOf = (v: PriceInput | undefined) =>
  v === undefined || v === null ? '' : v === 'none' ? NONE_TEXT : formatNumber(v);
const inputOf = (text: string): PriceInput => {
  if (text.trim() === '') return null;
  return parseMoney(text);
};

function PriceInputBox({
  label,
  value,
  onChange,
  disabled,
}: {
  label: string;
  value: PriceInput | undefined;
  onChange: (v: PriceInput) => void;
  disabled?: boolean;
}) {
  return (
    <input
      aria-label={label}
      disabled={disabled}
      inputMode="numeric"
      autoComplete="off"
      placeholder={disabled ? 'Không bán' : 'Theo giá chung'}
      value={textOf(value)}
      onChange={(e) => onChange(inputOf(e.target.value))}
      className={`${INPUT_CLASS} tabular text-right`}
    />
  );
}

export function AddPricesDialog({
  open,
  onOpenChange,
  onDone,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  return open ? <AddPricesForm open onOpenChange={onOpenChange} onDone={onDone} /> : null;
}

function AddPricesForm({
  open,
  onOpenChange,
  onDone,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  const supabase = useDb();
  const catalogs = useLeadCatalogs();
  const pageSize = useIntSetting('list_page_size_default');
  const [effective, setEffective] = useState<Date | null>(() => new Date());
  const [search, setSearch] = useState('');
  const [type, setType] = useState('');
  const [subject, setSubject] = useState('');
  const [grade, setGrade] = useState('');
  const [page, setPage] = useState({ key: '', n: 0 });
  const [picked, setPicked] = useState<Picked>({});
  const [common, setCommon] = useState<{ off: PriceInput; onl: PriceInput }>({
    off: null,
    onl: null,
  });
  const [overrides, setOverrides] = useState<Record<string, Override>>({});
  const [busy, setBusy] = useState(false);
  const [selecting, setSelecting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [truncated, setTruncated] = useState<string | null>(null);
  const q = useDebounced(search);
  const filters: PriceFilters = { q, type, subject, grade, status: 'active' };
  const key = JSON.stringify(filters);
  const n = page.key === key ? page.n : 0;
  const todayKey = toDateKey(new Date());
  const list = usePricePage(todayKey, filters, n * (pageSize ?? 0), pageSize);
  const rows = useMemo(() => list.data?.rows ?? [], [list.data]);
  const total = list.data?.total ?? 0;
  const ids = Object.keys(picked);
  const items = buildPriceItems(
    ids.map((id) => ({ id, type: picked[id] ?? '' })),
    common,
    overrides,
  );
  const allOnPage = rows.length > 0 && rows.every((r) => picked[r.id] !== undefined);

  const setOverride = (id: string, patch: Override) =>
    setOverrides((prev) => ({ ...prev, [id]: { ...prev[id], ...patch } }));

  async function selectAllByFilter() {
    setSelecting(true);
    setError(null);
    try {
      const result = await packagesForFilter(supabase, filters);
      setPicked((prev) => ({
        ...prev,
        ...Object.fromEntries(result.items.map((i) => [i.id, i.package_type_code])),
      }));
      setTruncated(
        result.total > result.items.length
          ? `Mới chọn ${result.items.length} trên ${result.total} gói (quá giới hạn mỗi lần). Thu hẹp bộ lọc để chọn phần còn lại.`
          : null,
      );
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setSelecting(false);
    }
  }

  async function submit() {
    if (effective === null) return;
    setBusy(true);
    setError(null);
    try {
      const count = await addPackagePrices(supabase, toDateKey(effective), items);
      onOpenChange(false);
      onDone(`Đã thêm ${count} dòng giá, hiệu lực từ ${effective.toLocaleDateString('vi-VN')}.`);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => !busy && onOpenChange(next)}
      title="Thêm bảng giá mới"
      description="Chọn ngày hiệu lực, chọn các gói, nhập giá chung rồi chỉnh riêng từng gói nếu cần."
      wide
      dismissible={!busy}
      footer={
        <>
          <Button onClick={() => onOpenChange(false)} disabled={busy}>
            Huỷ
          </Button>
          <Button
            variant="primary"
            loading={busy}
            disabled={effective === null || items.length === 0}
            onClick={() => void submit()}
          >
            Lưu bảng giá mới
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {error && (
          <Alert tone="danger" title="Chưa lưu được.">
            {error}
          </Alert>
        )}
        <DateInput
          label="Hiệu lực từ"
          required
          value={effective}
          onChange={setEffective}
          help="Được chọn ngày trong quá khứ. Đơn đã tạo giữ giá cũ (R-TIEN-14)."
        />
        <div className="grid gap-3 md:grid-cols-2">
          <PriceCommon
            label="Giá offline chung"
            value={common.off}
            onChange={(v) => setCommon((c) => ({ ...c, off: v }))}
          />
          <PriceCommon
            label="Giá online chung"
            value={common.onl}
            onChange={(v) => setCommon((c) => ({ ...c, onl: v }))}
          />
        </div>
        <p className="text-caption text-fg-muted">
          Ô để trống = không thêm giá. Gói dịch vụ, tài liệu không có giá online. Bảng này có{' '}
          {items.length} dòng giá cho {ids.length} gói đã chọn.
        </p>
        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-[180px] flex-1">
            <TextField
              label="Tìm gói"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Tìm mã, tên…"
            />
          </div>
          <Select
            label="Loại gói"
            value={type}
            onChange={setType}
            options={[{ value: '', label: 'Mọi loại gói' }, ...catalogs.options('PACKAGE_TYPE')]}
          />
          <Select
            label="Môn"
            value={subject}
            onChange={setSubject}
            options={[{ value: '', label: 'Mọi môn' }, ...catalogs.options('SUBJECT')]}
          />
          <Select
            label="Khối"
            value={grade}
            onChange={setGrade}
            options={[{ value: '', label: 'Mọi khối' }, ...catalogs.options('GRADE')]}
          />
          <Button loading={selecting} onClick={() => void selectAllByFilter()}>
            Chọn tất cả theo bộ lọc
          </Button>
          {ids.length > 0 && (
            <Button
              variant="ghost"
              onClick={() => {
                setPicked({});
                setTruncated(null);
              }}
            >
              Bỏ chọn ({ids.length})
            </Button>
          )}
        </div>
        {truncated && <Alert tone="warning">{truncated}</Alert>}
        <div className="overflow-x-auto rounded-control border border-border">
          <table className="w-full text-body" aria-label="Chọn gói để thêm giá">
            <thead className="bg-surface-subtle text-left text-caption text-fg-muted">
              <tr>
                <th className="w-10 px-3 py-2">
                  <input
                    type="checkbox"
                    aria-label="Chọn cả trang"
                    className={BOX}
                    checked={allOnPage}
                    onChange={(e) =>
                      setPicked((prev) => {
                        const next = { ...prev };
                        for (const r of rows) {
                          if (e.target.checked) next[r.id] = r.package_type_code;
                          else delete next[r.id];
                        }
                        return next;
                      })
                    }
                  />
                </th>
                <th className="px-2 py-2">Mã gói</th>
                <th className="px-2 py-2">Giá hiện tại (offline / online)</th>
                <th className="px-2 py-2">Giá offline mới</th>
                <th className="px-2 py-2">Giá online mới</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const on = picked[r.id] !== undefined;
                return (
                  <tr key={r.id} className="border-t border-border align-top">
                    <td className="px-3 py-2">
                      <input
                        type="checkbox"
                        aria-label={`Chọn ${r.code}`}
                        className={BOX}
                        checked={on}
                        onChange={(e) =>
                          setPicked((prev) => {
                            const next = { ...prev };
                            if (e.target.checked) next[r.id] = r.package_type_code;
                            else delete next[r.id];
                            return next;
                          })
                        }
                      />
                    </td>
                    <td className="px-2 py-2">
                      <span className="font-medium">{r.code}</span>
                      <span className="block text-caption text-fg-muted">{r.name}</span>
                    </td>
                    <td className="px-2 py-2">
                      <div className="flex flex-col gap-1">
                        <PriceCellView cell={r.offline} type={r.package_type_code} />
                        <PriceCellView cell={r.online} type={r.package_type_code} />
                      </div>
                    </td>
                    <td className="px-2 py-2">
                      <PriceInputBox
                        label={`Giá offline mới của ${r.code}`}
                        disabled={!on}
                        value={overrides[r.id]?.off}
                        onChange={(v) => setOverride(r.id, { off: v })}
                      />
                    </td>
                    <td className="px-2 py-2">
                      <PriceInputBox
                        label={`Giá online mới của ${r.code}`}
                        disabled={!on || hasNoOnline(r.package_type_code)}
                        value={overrides[r.id]?.onl}
                        onChange={(v) => setOverride(r.id, { onl: v })}
                      />
                    </td>
                  </tr>
                );
              })}
              {rows.length === 0 && !list.isPending && (
                <tr>
                  <td colSpan={5} className="px-3 py-6 text-center text-fg-muted">
                    Không có gói nào khớp bộ lọc.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        {pageSize !== null && total > pageSize && (
          <Pagination
            page={n + 1}
            pageSize={pageSize}
            total={total}
            onPageChange={(next) => setPage({ key, n: next - 1 })}
          />
        )}
      </div>
    </Dialog>
  );
}

/** Giá chung: ô nhập tiền, kèm ô "Không bán hình thức này" (dòng giá để trống). */
function PriceCommon({
  label,
  value,
  onChange,
}: {
  label: string;
  value: PriceInput;
  onChange: (v: PriceInput) => void;
}) {
  const none = value === 'none';
  return (
    <Field label={label}>
      {(f) => (
        <div className="flex flex-col gap-1">
          <input
            {...f}
            inputMode="numeric"
            autoComplete="off"
            disabled={none}
            value={none ? '' : textOf(value)}
            onChange={(e) => onChange(inputOf(e.target.value))}
            className={`${INPUT_CLASS} tabular text-right`}
          />
          <Checkbox
            label="Không bán hình thức này"
            checked={none}
            onChange={(e) => onChange(e.target.checked ? 'none' : null)}
          />
        </div>
      )}
    </Field>
  );
}
