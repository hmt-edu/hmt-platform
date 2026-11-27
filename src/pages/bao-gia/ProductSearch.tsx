// Ô tìm sản phẩm dùng chung cho lưới sửa Nháp Báo giá, tạo và sửa Đơn hàng (canvas «HMT Ô tìm sản phẩm»). Thay hộp «Chọn gói»:
// bấm là hiện ngay «Hay dùng», «Gợi ý theo cơ hội»; gõ không dấu; chip lọc; mũi tên, Enter, Esc. Danh sách do list_sellable_packages trả.
import { useId, useState, type KeyboardEvent, type ReactNode } from 'react';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Spinner } from '../../ui/Feedback';
import { Popover, Select } from '../../ui/Overlays';
import { cn } from '../../ui/cn';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  NO_FILTERS,
  filterValues,
  productGroups,
  productRows,
  type ProductFilters,
} from './productSearchLogic';
import { useSellablePackages, type SellablePackage } from './useQuoteData';

// Máy tính xếp cột như canvas; màn hẹp xếp dọc từng dòng.
const COLUMNS =
  'gap-0.5 px-3 sm:grid-cols-[110px_90px_70px_minmax(0,1fr)_minmax(0,230px)] sm:gap-2';
const ALL = 'all'; // Select không nhận giá trị rỗng.
const FILTER_CHIPS: { key: keyof ProductFilters; label: string }[] = [
  { key: 'type', label: 'Loại lớp' },
  { key: 'subject', label: 'Môn' },
  { key: 'grade', label: 'Khối' },
];

function Panel({
  opportunityId,
  onPick,
}: {
  opportunityId: string;
  onPick: (pkg: SellablePackage) => void;
}) {
  const catalogs = useLeadCatalogs();
  const query = useSellablePackages(opportunityId, null, true);
  const [text, setText] = useState('');
  const [filters, setFilters] = useState<ProductFilters>(NO_FILTERS);
  const [active, setActive] = useState(0);
  const listId = useId();

  const data = query.data;
  const rows = data ? productRows(data, (c, code) => catalogs.name(c, code)) : [];
  const groups = data ? productGroups(rows, data, text, filters) : [];
  const flat = groups.flatMap((g) => g.rows);
  const current = Math.min(active, Math.max(flat.length - 1, 0));
  const optionId = (i: number) => `${listId}-${String(i)}`;

  function move(next: number) {
    setActive(next);
    document.getElementById(optionId(next))?.scrollIntoView({ block: 'nearest' });
  }

  function onKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      move(Math.min(current + 1, flat.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      move(Math.max(current - 1, 0));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      const row = flat[current];
      if (row) onPick(row.pkg);
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <input
        autoFocus
        role="combobox"
        aria-label="Tìm sản phẩm"
        aria-expanded="true"
        aria-controls={listId}
        aria-activedescendant={flat.length > 0 ? optionId(current) : undefined}
        placeholder="Tìm sản phẩm: tên, mã, môn, khối"
        autoComplete="off"
        value={text}
        onChange={(e) => {
          setText(e.target.value);
          setActive(0);
        }}
        onKeyDown={onKeyDown}
        className="focus-ring h-control w-full rounded-control border border-border-strong bg-surface px-2.5"
      />
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-caption text-fg-muted">Lọc nhanh</span>
        {FILTER_CHIPS.map(({ key, label }) => (
          <Select
            key={key}
            label={label}
            value={filters[key] === '' ? ALL : filters[key]}
            onChange={(v) => {
              setFilters((f) => ({ ...f, [key]: v === ALL ? '' : v }));
              setActive(0);
            }}
            options={[
              { value: ALL, label: `${label}: Tất cả` },
              ...filterValues(rows, key).map((v) => ({ value: v, label: v })),
            ]}
            className="w-auto"
          />
        ))}
      </div>
      {query.isPending && <Spinner label="Đang tải sản phẩm…" />}
      {query.isError && (
        <div role="alert" className="flex flex-col items-start gap-2 text-on-danger-subtle">
          <p>{errorOf(query.error).message}</p>
          <Button onClick={() => void query.refetch()}>Thử lại</Button>
        </div>
      )}
      {data && (
        <>
          <div
            aria-hidden="true"
            className={cn(COLUMNS, 'hidden text-caption text-fg-muted sm:grid')}
          >
            <span>Loại lớp</span>
            <span>Môn</span>
            <span>Khối</span>
            <span>Sản phẩm</span>
            <span className="text-right">Đơn giá · đơn vị</span>
          </div>
          <div
            id={listId}
            role="listbox"
            aria-label="Sản phẩm"
            className="flex max-h-80 flex-col overflow-y-auto"
          >
            {groups.map((g) => (
              <div key={g.title ?? 'found'} role="group" aria-label={g.title ?? 'Kết quả'}>
                {g.title && (
                  <p className="px-3 pt-2 pb-1 text-caption font-semibold text-fg-muted">
                    {g.title}
                  </p>
                )}
                {g.rows.map((r) => {
                  // Số thứ tự trong cả danh sách (qua các nhóm) để mũi tên đi liền mạch.
                  const i = flat.indexOf(r);
                  return (
                    <div
                      key={r.pkg.id}
                      id={optionId(i)}
                      role="option"
                      aria-selected={i === current}
                      tabIndex={-1}
                      onMouseMove={() => setActive(i)}
                      onClick={() => onPick(r.pkg)}
                      className={cn(
                        COLUMNS,
                        'flex min-h-target cursor-pointer flex-col rounded-control py-1.5 sm:grid sm:items-center',
                        i === current && 'bg-hover',
                      )}
                    >
                      <span className="text-caption text-fg-muted">{r.type}</span>
                      <span>{r.subject}</span>
                      <span>{r.grade}</span>
                      <span className="min-w-0">
                        <b className="font-semibold">{r.pkg.code}</b> {r.pkg.name}
                      </span>
                      <span className="tabular sm:text-right">{r.price}</span>
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
          {groups.length === 0 && (
            <div className="flex flex-col items-center gap-1 py-3 text-center">
              <b>Không thấy sản phẩm</b>
              <span className="text-caption text-fg-muted">
                Thử bỏ bớt bộ lọc hoặc gõ ít chữ hơn.
              </span>
              <Button
                size="sm"
                onClick={() => {
                  setText('');
                  setFilters(NO_FILTERS);
                }}
              >
                Xoá bộ lọc
              </Button>
            </div>
          )}
          <p className="text-caption text-fg-muted">
            Mũi tên lên xuống để chọn · Enter để xác nhận · Esc để đóng · gõ không dấu vẫn tìm được
          </p>
        </>
      )}
    </div>
  );
}

export function ProductSearch({
  opportunityId,
  trigger,
  onPick,
}: {
  opportunityId: string;
  /** Nút mở ô tìm. */
  trigger: ReactNode;
  onPick: (pkg: SellablePackage) => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <Popover
      label="Tìm sản phẩm"
      trigger={trigger}
      open={open}
      onOpenChange={setOpen}
      className="max-h-[var(--radix-popover-content-available-height)] w-[760px] overflow-y-auto"
    >
      <Panel
        opportunityId={opportunityId}
        onPick={(pkg) => {
          setOpen(false);
          onPick(pkg);
        }}
      />
    </Popover>
  );
}
