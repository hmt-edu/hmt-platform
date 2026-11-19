// Hộp thoại QT-07 Danh mục (canvas bổ sung v2 `1794108604-3066`: QT07_them_muc, QT07_them_kenh, QT07_doi_ten, QT07_ngung_dung_lai, QT07_loi_nhap):
// Thêm mục (mã không đổi, tên hiển thị; thêm con có ô "Thuộc …"), Đổi tên, Ngừng (hỏi lại). Luật và quyền do hàm DB kiểm; hộp chỉ hiện câu lỗi
// của máy chủ (mã sai dạng, tên trống, mã trùng). Câu lỗi trong khung của Design là câu tạm: dùng câu thật của hàm DB.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { Alert } from '../../ui/Feedback';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { Icon } from '../../ui/icons';
import { Select } from '../../ui/Overlays';
import { addInputErrors, type CatalogNode } from './catalogLogic';
import {
  addCatalogItem,
  renameCatalogItem,
  setCatalogItemActive,
  setSessionTypeForm,
} from './useCatalogData';

function useRun(onOpenChange: (open: boolean) => void, onDone: (message: string) => void) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = async (action: () => Promise<unknown>, message: string) => {
    setBusy(true);
    setError(null);
    try {
      await action();
      onOpenChange(false);
      onDone(message);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  };
  return { busy, error, run };
}

export type AddTarget = {
  /** Mã danh mục (tầng) của mục sẽ thêm. */
  catalogCode: string;
  /** Tên tầng: "mục", "nguồn", "kênh". */
  levelName: string;
  /** Tên danh mục gốc (tiêu đề hộp). */
  catalogName: string;
  /** Mục cha gợi ý (thêm con); null khi thêm ở tầng đầu. */
  parent: CatalogNode | null;
  /** Các mục cha chọn được ở ô "Thuộc …" (tầng cha); rỗng khi thêm ở tầng đầu. */
  parents: CatalogNode[];
  parentLevelName: string;
  /** Số thứ tự hiển thị của mục mới: đếm lại từ 1 trong nhóm cùng cha, mục mới luôn đặt cuối (Q-132). */
  nextOrder: number;
};

export function AddItemDialog({
  target,
  onOpenChange,
  onDone,
}: {
  target: AddTarget | null;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  return target ? (
    <AddForm
      key={`${target.catalogCode}:${target.parent?.id ?? ''}`}
      target={target}
      onOpenChange={onOpenChange}
      onDone={onDone}
    />
  ) : null;
}

function AddForm({
  target,
  onOpenChange,
  onDone,
}: {
  target: AddTarget;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  const supabase = useDb();
  const [code, setCode] = useState('');
  const [name, setName] = useState('');
  const [parentId, setParentId] = useState(target.parent?.id ?? '');
  const { busy, error, run } = useRun(onOpenChange, onDone);
  const child = target.parents.length > 0;
  const errors = addInputErrors(code);
  const title = `Thêm ${target.levelName} · ${target.catalogName}`;
  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title={title}
      confirmLabel={`Thêm ${target.levelName}`}
      canSubmit={
        code.trim() !== '' && name.trim() !== '' && !errors.code && (!child || parentId !== '')
      }
      busy={busy}
      error={error}
      onSubmit={() =>
        void run(
          () =>
            addCatalogItem(supabase, {
              catalog_code: target.catalogCode,
              code,
              name,
              parent_id: child ? parentId : null,
              sort_order: null,
            }),
          `Đã thêm ${target.levelName} ${code.trim().toUpperCase()}.`,
        )
      }
    >
      <div className="flex flex-col gap-3">
        {child && (
          <Field label={`Thuộc ${target.parentLevelName.toLowerCase()}`} required>
            {(field) => (
              <Select
                id={field.id}
                label={`Thuộc ${target.parentLevelName.toLowerCase()}`}
                value={parentId}
                onChange={setParentId}
                options={target.parents.map((p) => ({
                  value: p.id,
                  label: `${p.code} · ${p.name}`,
                }))}
              />
            )}
          </Field>
        )}
        <div className="grid gap-3 sm:grid-cols-2">
          <TextField
            label="Mã"
            required
            value={code}
            onChange={(e) => setCode(e.target.value)}
            invalid={!!errors.code}
            error={errors.code}
            help="Viết hoa, không dấu. Không đổi được sau khi tạo."
          />
          <TextField
            label="Thứ tự"
            value={String(target.nextOrder)}
            readOnly
            disabled
            help="Mục mới đặt cuối. Đổi chỗ bằng nút ▲▼."
          />
        </div>
        <TextField
          label="Tên hiển thị"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}

export function RenameItemDialog({
  node,
  onOpenChange,
  onDone,
}: {
  node: CatalogNode | null;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  return node ? (
    <RenameForm key={node.id} node={node} onOpenChange={onOpenChange} onDone={onDone} />
  ) : null;
}

function RenameForm({
  node,
  onOpenChange,
  onDone,
}: {
  node: CatalogNode;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  const supabase = useDb();
  const [name, setName] = useState(node.name);
  const { busy, error, run } = useRun(onOpenChange, onDone);
  const changed = name.trim() !== '' && name.trim() !== node.name;
  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title={`Đổi tên hiển thị · ${node.code}`}
      confirmLabel="Lưu tên"
      canSubmit={changed}
      busy={busy}
      error={error}
      onSubmit={() =>
        void run(() => renameCatalogItem(supabase, node.id, name), 'Đã đổi tên hiển thị.')
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Mã" help="Mã không đổi được.">
          {(field) => (
            <span className="relative block">
              <input
                id={field.id}
                value={node.code}
                readOnly
                disabled
                aria-describedby={field['aria-describedby']}
                className="h-control w-full rounded-control border border-border bg-surface-subtle px-2.5 pr-9 text-body text-fg-label"
              />
              <Icon
                name="lock"
                size={16}
                className="pointer-events-none absolute top-1/2 right-2.5 -translate-y-1/2 text-fg-muted"
              />
            </span>
          )}
        </Field>
        <TextField
          label="Tên hiển thị"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
          help="Đổi tên không đổi mã, dữ liệu cũ vẫn gắn mục này."
        />
      </div>
    </FormDialog>
  );
}

/** Sửa form nhận xét của một loại buổi (A25, Q-176): 9 tiêu chí hoặc form điểm. Chỉ áp dụng cho buổi tạo SAU; buổi đã tạo giữ form lúc tạo. Mã loại buổi không đổi. */
export function EditSessionFormDialog({
  node,
  formCode,
  onOpenChange,
  onDone,
}: {
  node: CatalogNode | null;
  formCode: string;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  return node ? (
    <EditSessionForm
      key={node.id}
      node={node}
      formCode={formCode}
      onOpenChange={onOpenChange}
      onDone={onDone}
    />
  ) : null;
}

function EditSessionForm({
  node,
  formCode,
  onOpenChange,
  onDone,
}: {
  node: CatalogNode;
  formCode: string;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  const supabase = useDb();
  const [value, setValue] = useState(formCode);
  const { busy, error, run } = useRun(onOpenChange, onDone);
  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title={`Sửa form nhận xét · ${node.name}`}
      confirmLabel="Lưu form"
      canSubmit={value !== formCode}
      busy={busy}
      error={error}
      onSubmit={() =>
        void run(() => setSessionTypeForm(supabase, node.code, value), 'Đã đổi form nhận xét.')
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Form nhận xét">
          {(field) => (
            <Select
              id={field.id}
              label="Form nhận xét"
              value={value}
              onChange={setValue}
              options={[
                { value: 'TIEU_CHI', label: '9 tiêu chí' },
                { value: 'DIEM', label: 'Form điểm' },
              ]}
            />
          )}
        </Field>
        <Alert tone="info">
          Đổi form chỉ áp dụng cho buổi tạo sau. Buổi đã tạo giữ form lúc tạo.
        </Alert>
      </div>
    </FormDialog>
  );
}

export function StopItemDialog({
  node,
  childCount,
  onOpenChange,
  onDone,
}: {
  node: CatalogNode | null;
  /** Số mục con đang dùng của mục này (hiện câu cho biết con tự ẩn khỏi ô chọn, trạng thái từng con giữ nguyên: R-V2-43). */
  childCount: number;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
}) {
  const supabase = useDb();
  const { busy, error, run } = useRun(onOpenChange, onDone);
  return (
    <ConfirmDialog
      open={node !== null}
      onOpenChange={onOpenChange}
      title={node ? `Ngừng mục "${node.name}"?` : 'Ngừng mục'}
      description={
        node ? (
          <Alert tone="warning">
            Mục <b>{node.name}</b> sẽ không hiện ở ô chọn mới. Dữ liệu cũ vẫn giữ mục này. Muốn dùng
            lại, bấm Dùng lại ở dòng mục.
            {childCount > 0 &&
              ` Các mục con (${childCount} đang dùng) cũng không hiện ở ô chọn mới; trạng thái từng mục con giữ nguyên, Dùng lại mục này thì các mục con đang dùng hiện lại.`}
          </Alert>
        ) : undefined
      }
      confirmLabel="Ngừng mục"
      tone="danger"
      busy={busy}
      error={error}
      onConfirm={() =>
        node &&
        void run(() => setCatalogItemActive(supabase, node.id, false), `Đã ngừng mục ${node.code}.`)
      }
    />
  );
}
