// Hộp thoại màn Gói bán (CH-01, canvas ca9b: CH01_tao, CH01_sua_ten, CH01_ngung): Tạo gói, Sửa tên và mã cũ, Ngừng bán / Dùng lại.
// Luật và quyền do hàm DB kiểm; hộp chỉ hiện lỗi của chúng. Mã gói tự ghép theo Loại-Môn-Khối, không sửa được.
import { useState } from 'react';
import { errorOf, useDb } from '../../lib/db';
import { ConfirmDialog, FormDialog } from '../../ui/Dialogs';
import { Field, TextField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { createPackage, editPackage, setPackageActive, type PackageRow } from './usePackageData';
import { buildPackageCode, gradeRangeError, isHourType, packageDialogText } from './packageLogic';

type Option = { value: string; label: string };

function useRun(onOpenChange: (open: boolean) => void, onDone: (message: string) => void) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = async (action: () => Promise<void>, message: string) => {
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

type CreateProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  types: Option[];
  subjects: Option[];
  grades: Option[];
  onDone: (message: string) => void;
};

export function CreatePackageDialog(props: CreateProps) {
  return props.open ? <CreateForm {...props} /> : null;
}

function CreateForm({ open, onOpenChange, types, subjects, grades, onDone }: CreateProps) {
  const supabase = useDb();
  const [type, setType] = useState('');
  const [subject, setSubject] = useState('');
  const [gradeFrom, setGradeFrom] = useState('');
  const [gradeTo, setGradeTo] = useState('');
  const [suffix, setSuffix] = useState('');
  const [name, setName] = useState('');
  const [legacy, setLegacy] = useState('');
  const { busy, error, run } = useRun(onOpenChange, onDone);
  const hour = type !== '' && isHourType(type);
  const code = buildPackageCode({ type, subject, gradeFrom, gradeTo, suffix });
  const rangeProblem = gradeRangeError(
    grades.map((g) => g.value),
    gradeFrom,
    gradeTo,
  );
  return (
    <FormDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Tạo gói bán"
      confirmLabel="Tạo gói"
      canSubmit={code !== '' && name.trim() !== '' && rangeProblem === null}
      busy={busy}
      error={error ?? rangeProblem}
      onSubmit={() =>
        void run(async () => {
          await createPackage(supabase, {
            code,
            name: name.trim(),
            package_type_code: type,
            subject_code: hour ? subject : '',
            grade_from_code: hour ? gradeFrom : '',
            grade_to_code: hour && gradeTo !== gradeFrom ? gradeTo : '',
            legacy_ref: legacy.trim(),
          });
        }, `Đã tạo gói ${code}.`)
      }
    >
      <div className="flex flex-col gap-3">
        <Field label="Loại gói" required>
          {(f) => (
            <Select
              id={f.id}
              label="Loại gói"
              value={type}
              onChange={setType}
              options={types}
              placeholder="Chọn loại gói"
              className="w-full"
            />
          )}
        </Field>
        {hour && (
          <>
            <Field label="Môn" required>
              {(f) => (
                <Select
                  id={f.id}
                  label="Môn"
                  value={subject}
                  onChange={setSubject}
                  options={subjects}
                  placeholder="Chọn môn"
                  className="w-full"
                />
              )}
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Khối từ" required>
                {(f) => (
                  <Select
                    id={f.id}
                    label="Khối từ"
                    value={gradeFrom}
                    onChange={(v) => {
                      setGradeFrom(v);
                      if (gradeTo === '') setGradeTo(v);
                    }}
                    options={grades}
                    placeholder="Chọn khối"
                    className="w-full"
                  />
                )}
              </Field>
              <Field label="Khối đến" required help="Bằng khối từ nếu chỉ một khối.">
                {(f) => (
                  <Select
                    id={f.id}
                    label="Khối đến"
                    value={gradeTo}
                    onChange={setGradeTo}
                    options={grades}
                    placeholder="Chọn khối"
                    className="w-full"
                  />
                )}
              </Field>
            </div>
          </>
        )}
        {type !== '' && !hour && (
          <TextField
            label="Tên viết tắt trong mã"
            required
            value={suffix}
            onChange={(e) => setSuffix(e.target.value)}
            help="Chữ hoa và số, không dấu (ví dụ CSGK, MATOAN)."
          />
        )}
        <TextField
          label="Mã gói"
          readOnly
          value={code === '' ? 'Tự tạo theo Loại-Môn-Khối' : code}
          help="Tự tạo theo Loại-Môn-Khối, không sửa được."
        />
        <TextField
          label="Mã cũ (Sheet)"
          value={legacy}
          onChange={(e) => setLegacy(e.target.value)}
          help={packageDialogText.legacyCreateHelp}
        />
        <TextField
          label="Tên gói"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <p className="text-caption text-fg-muted">
          Giá offline, online đặt ở Bảng giá có ngày hiệu lực. Số giờ nhập khi lập dòng đơn, không
          đặt ở gói.
        </p>
      </div>
    </FormDialog>
  );
}

type EditProps = {
  row: PackageRow | null;
  onOpenChange: (open: boolean) => void;
  onDone: (message: string) => void;
};

/** Sửa gói: chỉ đổi tên và mã cũ; mã, loại, môn, khối luôn khoá. */
export function EditPackageDialog({ row, onOpenChange, onDone }: EditProps) {
  return row ? <EditForm row={row} onOpenChange={onOpenChange} onDone={onDone} /> : null;
}

function EditForm({ row, onOpenChange, onDone }: EditProps & { row: PackageRow }) {
  const supabase = useDb();
  const [name, setName] = useState(row.name);
  const [legacy, setLegacy] = useState(row.legacy_ref ?? '');
  const { busy, error, run } = useRun(onOpenChange, onDone);
  const changed = name.trim() !== row.name || legacy.trim() !== (row.legacy_ref ?? '');
  return (
    <FormDialog
      open
      onOpenChange={onOpenChange}
      title={packageDialogText.editTitle(row.code)}
      confirmLabel="Lưu"
      canSubmit={name.trim() !== '' && changed}
      busy={busy}
      error={error}
      onSubmit={() =>
        void run(
          () => editPackage(supabase, row.id, { name: name.trim(), legacy_ref: legacy.trim() }),
          `Đã lưu gói ${row.code}.`,
        )
      }
    >
      <div className="flex flex-col gap-3">
        <TextField label="Mã gói" readOnly value={row.code} help={packageDialogText.codeHelp} />
        <TextField
          label="Mã cũ (Sheet)"
          value={legacy}
          onChange={(e) => setLegacy(e.target.value)}
          help={packageDialogText.legacyHelp}
        />
        <TextField
          label="Tên gói"
          required
          value={name}
          onChange={(e) => setName(e.target.value)}
          help={packageDialogText.nameHelp}
        />
      </div>
    </FormDialog>
  );
}

/** Ngừng bán hoặc Dùng lại: không xoá gói; gói ngừng không hiện ở ô chọn mới, đơn đã tạo giữ nguyên. */
export function ActivePackageDialog({ row, onOpenChange, onDone }: EditProps) {
  const supabase = useDb();
  const { busy, error, run } = useRun(onOpenChange, onDone);
  const stopping = row?.is_active ?? true;
  return (
    <ConfirmDialog
      open={row !== null}
      onOpenChange={onOpenChange}
      title={stopping ? packageDialogText.stopTitle(row?.code ?? '') : 'Dùng lại gói'}
      summary={
        stopping
          ? undefined
          : [
              { label: 'Mã gói', value: row?.code ?? '' },
              { label: 'Tên gói', value: row?.name ?? '' },
            ]
      }
      description={
        stopping
          ? packageDialogText.stopBody(row?.code ?? '')
          : 'Gói hiện lại ở ô chọn khi lập báo giá, đơn mới.'
      }
      confirmLabel={stopping ? 'Ngừng bán' : 'Dùng lại'}
      tone={stopping ? 'danger' : 'primary'}
      busy={busy}
      error={error}
      onConfirm={() =>
        void run(
          () => setPackageActive(supabase, row?.id ?? '', !stopping),
          stopping ? `Đã ngừng bán gói ${row?.code ?? ''}.` : `Đã dùng lại gói ${row?.code ?? ''}.`,
        )
      }
    />
  );
}
