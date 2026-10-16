// Bốn khung mở ra của K1 (Filters, Group By, Cột, Favorites) và hộp Lọc nâng cao, theo gói thiết kế v2.
// Máy tính: khung nổi, áp dụng ngay. Điện thoại: tấm trượt từ dưới lên, có nút Áp dụng.
import { useState, type DragEvent, type ReactNode } from 'react';
import { Button, IconButton } from '../ui/Button';
import { cn } from '../ui/cn';
import { Checkbox, TextField } from '../ui/Field';
import { Icon } from '../ui/icons';
import { Dialog, Drawer, Popover, Select } from '../ui/Overlays';
import { MAX_GROUP_LEVELS, blankCondition, defaultColumnKeys, visibleColumnKeys } from './state';
import {
  OPERATORS_BY_TYPE,
  type Condition,
  type ListConfig,
  type ListState,
  type Operator,
} from './types';

/**
 * Khung neo dưới nút (máy tính) hoặc tấm trượt dưới màn hình (điện thoại). `footer` chỉ hiện ở tấm trượt
 * (nút Xoá lọc, Áp dụng); trên máy tính các thay đổi có hiệu lực ngay nên không cần.
 */
export function PanelHost({
  sheet,
  open,
  onOpenChange,
  trigger,
  title,
  footer,
  width = 'w-80',
  align = 'end',
  children,
}: {
  sheet: boolean;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  trigger: ReactNode;
  title: string;
  footer?: ReactNode;
  width?: string;
  align?: 'start' | 'end';
  children: ReactNode;
}) {
  if (sheet) {
    return (
      <>
        <span onClick={() => onOpenChange(true)} className="contents">
          {trigger}
        </span>
        <Drawer open={open} onOpenChange={onOpenChange} title={title} side="bottom" footer={footer}>
          <div className="p-4">{children}</div>
        </Drawer>
      </>
    );
  }
  return (
    <Popover
      open={open}
      onOpenChange={onOpenChange}
      align={align}
      className={cn(width, 'p-0')}
      trigger={trigger}
    >
      <div className="flex max-h-[70dvh] flex-col overflow-y-auto">{children}</div>
    </Popover>
  );
}

const SECTION_TITLE = 'text-caption font-semibold text-fg-muted';

/** Filters: lọc nhanh theo nhóm (cùng nhóm HOẶC, khác nhóm VÀ) + lối vào Lọc nâng cao. */
export function QuickFilterPanel<Row>({
  config,
  state,
  onChange,
  onAdvanced,
}: {
  config: ListConfig<Row>;
  state: ListState;
  onChange: (next: ListState) => void;
  onAdvanced: () => void;
}) {
  const toggle = (group: string, value: string) => {
    const current = state.quick[group] ?? [];
    const next = current.includes(value) ? current.filter((v) => v !== value) : [...current, value];
    const quick = { ...state.quick };
    if (next.length === 0) delete quick[group];
    else quick[group] = next;
    onChange({ ...state, quick });
  };
  return (
    <div className="flex flex-col">
      <p className="px-4 pt-3 pb-1 font-display text-h4">Lọc nhanh</p>
      {config.quickGroups.map((group, index) => (
        <div
          role="group"
          aria-label={group.label}
          key={group.key}
          className={cn('flex flex-col px-4 py-2', index > 0 && 'border-t border-border')}
        >
          <p aria-hidden="true" className={cn(SECTION_TITLE, 'mb-1')}>
            {group.label}
          </p>
          {group.options.map((option) => (
            <div key={option.value}>
              <Checkbox
                label={option.label}
                checked={(state.quick[group.key] ?? []).includes(option.value)}
                onChange={() => toggle(group.key, option.value)}
              />
              {option.hint && (
                <p className="-mt-1 pl-6 text-caption text-fg-muted">{option.hint}</p>
              )}
            </div>
          ))}
        </div>
      ))}
      <p className="px-4 pt-1 pb-2 text-caption text-fg-muted">
        Cùng nhóm là HOẶC, khác nhóm là VÀ.
      </p>
      <button
        type="button"
        onClick={onAdvanced}
        className="focus-ring tap flex min-h-11 items-center gap-2 border-t border-border px-4 text-left text-body hover:bg-hover"
      >
        <Icon name="config" size={16} />
        <span className="flex-1">Lọc nâng cao…</span>
        <Icon name="chevronRight" size={16} className="text-fg-muted" />
      </button>
    </div>
  );
}

/** Group By: chọn tối đa hai cấp theo thứ tự bấm; bấm lại để bỏ; đủ hai cấp thì các trường còn lại mờ. */
export function GroupPanel<Row>({
  config,
  state,
  onChange,
}: {
  config: ListConfig<Row>;
  state: ListState;
  onChange: (next: ListState) => void;
}) {
  const full = state.group.length >= MAX_GROUP_LEVELS;
  const toggle = (key: string) => {
    if (state.group.includes(key))
      onChange({ ...state, group: state.group.filter((k) => k !== key) });
    else if (!full) onChange({ ...state, group: [...state.group, key] });
  };
  return (
    <div className="flex flex-col">
      <p className="px-4 pt-3 pb-1 font-display text-h4">Nhóm theo</p>
      <ul className="flex flex-col px-2 pb-1">
        {config.groupFields.map((field) => {
          const level = state.group.indexOf(field.key);
          const picked = level >= 0;
          const dim = full && !picked;
          return (
            <li key={field.key}>
              <button
                type="button"
                aria-pressed={picked}
                aria-disabled={dim || undefined}
                onClick={() => toggle(field.key)}
                className={cn(
                  'focus-ring tap flex min-h-9 w-full items-center gap-2 rounded-control px-2 text-left text-body',
                  dim ? 'cursor-not-allowed text-fg-disabled' : 'hover:bg-hover',
                  picked && 'font-semibold',
                )}
              >
                <span className="flex size-5 shrink-0 items-center justify-center">
                  {picked && <Icon name="checkMark" size={16} className="text-link" />}
                </span>
                <span className="flex-1">{field.label}</span>
                {picked && (
                  <span className="tabular rounded-full bg-selected px-2 text-caption text-on-selected">
                    Cấp {level + 1}
                  </span>
                )}
              </button>
            </li>
          );
        })}
      </ul>
      <p className="px-4 pt-1 pb-3 text-caption text-fg-muted">
        Chọn tối đa {MAX_GROUP_LEVELS} cấp, theo thứ tự bấm. Bấm lại để bỏ.
      </p>
    </div>
  );
}

/** Cột hiển thị: tick cột, kéo hoặc dùng nút mũi tên để đổi thứ tự, Mặc định. Cột khoá luôn hiện. */
export function ColumnsPanel<Row>({
  config,
  state,
  onChange,
}: {
  config: ListConfig<Row>;
  state: ListState;
  onChange: (next: ListState) => void;
}) {
  const visible = visibleColumnKeys(config, state);
  const locked = config.columns.filter((c) => c.locked);
  // Danh sách hiển thị: cột đang hiện theo thứ tự, rồi các cột đang ẩn theo khai báo.
  const order = [
    ...visible,
    ...config.columns.filter((c) => !visible.includes(c.key)).map((c) => c.key),
  ];
  const [dragging, setDragging] = useState<string | null>(null);

  const commit = (nextOrder: string[], nextVisible: string[]) => {
    const shown = nextOrder.filter((k) => nextVisible.includes(k));
    onChange({ ...state, columns: shown });
  };
  const toggle = (key: string) => {
    const next = visible.includes(key) ? visible.filter((k) => k !== key) : [...visible, key];
    commit(order, next);
  };
  const move = (key: string, delta: number) => {
    const from = order.indexOf(key);
    const to = from + delta;
    if (to < 0 || to >= order.length) return;
    const next = [...order];
    next.splice(from, 1);
    next.splice(to, 0, key);
    // Cột khoá luôn đứng đầu: không cho chen lên trên chúng.
    if (to < locked.length) return;
    commit(next, visible);
  };
  const drop = (event: DragEvent, targetKey: string) => {
    event.preventDefault();
    if (!dragging || dragging === targetKey) return;
    const next = order.filter((k) => k !== dragging);
    next.splice(next.indexOf(targetKey), 0, dragging);
    commit(next, visible);
    setDragging(null);
  };

  return (
    <div className="flex flex-col">
      <div className="flex items-baseline justify-between px-4 pt-3 pb-1">
        <p className="font-display text-h4">Cột hiển thị</p>
        <p className="tabular text-caption text-fg-muted">
          {visible.length} / {config.columns.length}
        </p>
      </div>
      <ul className="flex flex-col px-2">
        {order.map((key) => {
          const column = config.columns.find((c) => c.key === key);
          if (!column) return null;
          const on = visible.includes(key);
          return (
            <li
              key={key}
              draggable={!column.locked}
              onDragStart={() => setDragging(key)}
              onDragOver={(e) => !column.locked && e.preventDefault()}
              onDrop={(e) => !column.locked && drop(e, key)}
              className="flex min-h-9 items-center gap-1 rounded-control hover:bg-hover"
            >
              <span aria-hidden="true" className="flex w-5 justify-center text-fg-muted">
                ⠿
              </span>
              <label className="flex min-h-9 flex-1 items-center gap-2 max-md:min-h-11">
                <input
                  type="checkbox"
                  checked={on}
                  disabled={column.locked}
                  onChange={() => toggle(key)}
                  className="focus-ring size-4 accent-[var(--action-primary-bg)]"
                />
                <span className="text-body">{column.label}</span>
              </label>
              {column.locked ? (
                <Icon name="forbidden" size={16} className="mr-2 text-fg-muted" />
              ) : (
                on && (
                  <span className="flex">
                    <IconButton
                      icon="sortAsc"
                      label={`Đưa lên: ${column.label}`}
                      onClick={() => move(key, -1)}
                    />
                    <IconButton
                      icon="sortDesc"
                      label={`Đưa xuống: ${column.label}`}
                      onClick={() => move(key, 1)}
                    />
                  </span>
                )
              )}
            </li>
          );
        })}
      </ul>
      <p className="px-4 pt-1 pb-2 text-caption text-fg-muted">
        Tick để hiện hoặc ẩn. Kéo tay nắm bên trái hoặc dùng nút mũi tên để đổi thứ tự.
        {locked.length > 0 && ` ${locked.map((c) => c.label).join(' và ')} luôn hiện.`}
      </p>
      <div className="flex justify-end border-t border-border px-4 py-3">
        <Button onClick={() => onChange({ ...state, columns: defaultColumnKeys(config) })}>
          Mặc định
        </Button>
      </div>
    </div>
  );
}

/** Hộp Lọc nâng cao: các dòng điều kiện nối bằng VÀ, gộp với lọc nhanh đang chọn. */
export function AdvancedDialog<Row>({
  open,
  onOpenChange,
  config,
  conditions,
  onApply,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  config: ListConfig<Row>;
  conditions: Condition[];
  onApply: (conditions: Condition[]) => void;
}) {
  if (!open) return null;
  return (
    <AdvancedBody
      onOpenChange={onOpenChange}
      config={config}
      initial={conditions}
      onApply={onApply}
    />
  );
}

function AdvancedBody<Row>({
  onOpenChange,
  config,
  initial,
  onApply,
}: {
  onOpenChange: (open: boolean) => void;
  config: ListConfig<Row>;
  initial: Condition[];
  onApply: (conditions: Condition[]) => void;
}) {
  const first = config.filterFields[0];
  const [rows, setRows] = useState<Condition[]>(initial);
  const update = (id: string, patch: Partial<Condition>) =>
    setRows((current) => current.map((r) => (r.id === id ? { ...r, ...patch } : r)));

  return (
    <Dialog
      open
      wide
      onOpenChange={onOpenChange}
      title="Lọc nâng cao"
      footer={
        <>
          <Button
            onClick={() => {
              onApply([]);
              onOpenChange(false);
            }}
          >
            Xoá lọc
          </Button>
          <Button
            variant="primary"
            onClick={() => {
              onApply(rows);
              onOpenChange(false);
            }}
          >
            Áp dụng
          </Button>
        </>
      }
    >
      {rows.length === 0 && (
        <p className="text-fg-muted">Chưa có điều kiện nào. Bấm “Thêm điều kiện”.</p>
      )}
      <ul className="flex flex-col gap-2">
        {rows.map((row, index) => {
          const field = config.filterFields.find((f) => f.key === row.field);
          const type = field?.type ?? 'text';
          return (
            <li
              key={row.id}
              className="grid grid-cols-[1fr_auto] items-start gap-2 md:grid-cols-[1fr_1fr_2fr_auto]"
            >
              <Select
                label={`Trường, điều kiện ${index + 1}`}
                value={row.field}
                onChange={(key) => {
                  const next = config.filterFields.find((f) => f.key === key);
                  if (next) update(row.id, { ...blankCondition(next), id: row.id });
                }}
                options={config.filterFields.map((f) => ({ value: f.key, label: f.label }))}
              />
              <Select
                label={`Phép so sánh, điều kiện ${index + 1}`}
                value={row.op}
                onChange={(op) => update(row.id, { op: op as Operator })}
                options={OPERATORS_BY_TYPE[type].map((o) => ({ value: o.op, label: o.label }))}
              />
              <div className="col-span-2 md:col-span-1">
                <ValueInput
                  index={index}
                  type={type}
                  options={field?.options}
                  value={row.value}
                  onChange={(value) => update(row.id, { value })}
                />
              </div>
              <IconButton
                icon="trash"
                label={`Xoá điều kiện ${index + 1}`}
                className="row-start-1 col-start-2 md:col-start-4"
                onClick={() => setRows((current) => current.filter((r) => r.id !== row.id))}
              />
            </li>
          );
        })}
      </ul>
      <div>
        <Button
          variant="text"
          icon="plus"
          disabled={!first}
          onClick={() => first && setRows((current) => [...current, blankCondition(first)])}
        >
          Thêm điều kiện
        </Button>
      </div>
      <p className="text-caption text-fg-muted">
        Bản ghi phải khớp tất cả các điều kiện. Bộ lọc này gộp với các lọc nhanh đang chọn.
      </p>
    </Dialog>
  );
}

function ValueInput({
  index,
  type,
  options,
  value,
  onChange,
}: {
  index: number;
  type: 'text' | 'select' | 'multi' | 'date';
  options: { value: string; label: string }[] | undefined;
  value: string | string[];
  onChange: (value: string | string[]) => void;
}) {
  const label = `Giá trị, điều kiện ${index + 1}`;
  if (type === 'select') {
    return (
      <Select
        label={label}
        value={typeof value === 'string' ? value : ''}
        onChange={onChange}
        options={options ?? []}
        placeholder="Chọn…"
      />
    );
  }
  if (type === 'multi') {
    const picked = Array.isArray(value) ? value : [];
    return (
      <fieldset className="flex flex-wrap gap-x-4 gap-y-1 rounded-control border border-border-strong px-2.5 py-1">
        <legend className="sr-only">{label}</legend>
        {(options ?? []).map((o) => (
          <Checkbox
            key={o.value}
            label={o.label}
            checked={picked.includes(o.value)}
            onChange={() =>
              onChange(
                picked.includes(o.value)
                  ? picked.filter((v) => v !== o.value)
                  : [...picked, o.value],
              )
            }
          />
        ))}
      </fieldset>
    );
  }
  return (
    <TextField
      label={label}
      type={type === 'date' ? 'date' : 'text'}
      value={typeof value === 'string' ? value : ''}
      onChange={(e) => onChange(e.target.value)}
    />
  );
}
