// TS-04 Nhập lead từ file (hộp nhiều bước, khuôn K4b ⑤ StepDialog): 1 Tải file, 2 Ghép cột, 3 Xem trước. CSV đọc ở trình duyệt
// (UTF-8, có hoặc không BOM; dấu "," hoặc ";"). Xem trước và nhập gọi cùng hàm `import_leads` (p_commit false rồi true), nên kết
// quả khớp nhau; mọi luật của lead do hàm trong cơ sở dữ liệu kiểm. Excel (.xlsx) làm sau (anh chốt 18/10: CSV trước).
import { useQuery } from '@tanstack/react-query';
import { useMemo, useRef, useState, type DragEvent } from 'react';
import { useAssignableStaff } from '../../features/assign/useAssignableStaff';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { foldText } from '../../lib/format';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { Tag } from '../../ui/Data';
import { StepDialog } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { Field } from '../../ui/Field';
import { Icon } from '../../ui/icons';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { Select } from '../../ui/Overlays';
import { cn } from '../../ui/cn';
import { downloadText } from './csv';
import { parseCsv, type CsvTable } from './importCsv';
import { SAMPLE_MARK, dropSampleRows, leadTemplateCsv } from './importTemplate';
import {
  IMPORT_FIELDS,
  autoMap,
  buildImportRows,
  missingRequired,
  setColumnField,
  unmappedColumns,
  type CatalogLookup,
  type ImportField,
  type Mapping,
} from './importMapping';
import { formatPhone } from './leadFormat';
import { useLeadCatalogs } from './useCatalogs';

type ImportLine = {
  row: number;
  status: 'HOP_LE' | 'TRUNG' | 'LOI';
  code: string | null;
  message: string | null;
};
type ImportResult = {
  mode: 'XEM_TRUOC' | 'NHAP';
  total: number;
  imported: number;
  duplicates: number;
  errors: number;
  rows: ImportLine[];
};
type Defaults = {
  source: string;
  channel: string;
  campaign: string;
  branch: string;
  owner: string;
};
type Shown = 'ALL' | ImportLine['status'];

const STEPS = ['Tải file', 'Ghép cột', 'Xem trước'];
const NO_FIELD = '__none';
const EMPTY_DEFAULTS: Defaults = { source: '', channel: '', campaign: '', branch: '', owner: '' };

export function ImportLeadsDialog(props: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Nhập xong (đã có lead mới): trang tải lại danh sách. */
  onImported: (result: ImportResult) => void;
}) {
  // Mỗi lần mở là một lần nhập mới.
  return props.open ? <ImportForm {...props} /> : null;
}

function ImportForm({
  open,
  onOpenChange,
  onImported,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onImported: (result: ImportResult) => void;
}) {
  const supabase = useDb();
  const access = useAccess();
  const catalogs = useLeadCatalogs();
  const maxRows = useIntSetting('lead_import_max_rows');
  const [step, setStep] = useState(0);
  const [file, setFile] = useState<{ name: string; table: CsvTable } | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [mapping, setMapping] = useState<Mapping>([]);
  const [defaults, setDefaults] = useState<Defaults>(EMPTY_DEFAULTS);
  const [nonce, setNonce] = useState(0);
  const [shown, setShown] = useState<Shown>('ALL');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  const canAssign = access.can('LEAD', 'GIAO_VIEC');
  const branchOptions = (access.seesAllBranches ? access.teachingBranches : []).map((b) => ({
    value: b.id,
    label: `${b.code} ${b.name}`,
  }));
  const staff = useAssignableStaff(
    'LEAD',
    defaults.branch || null,
    canAssign && defaults.branch !== '',
  );

  const lookup = useMemo<CatalogLookup>(() => {
    const fold = (t: string) =>
      foldText(t)
        .replace(/[^a-z0-9]+/g, ' ')
        .trim();
    return {
      findSource: (text) => {
        const key = fold(text);
        const hit = catalogs
          .options('SOURCE')
          .find((o) => fold(o.label) === key || fold(o.value) === key);
        return hit
          ? { code: hit.value, typeCode: catalogs.parentCode('SOURCE', hit.value, 'SOURCE_TYPE') }
          : undefined;
      },
      findChannel: (sourceCode, text) => {
        const key = fold(text);
        return catalogs
          .childrenOf('SOURCE_CHANNEL', 'SOURCE', sourceCode)
          .find((o) => fold(o.label) === key || fold(o.value) === key)?.value;
      },
    };
  }, [catalogs]);

  const rows = useMemo(
    () => (file ? buildImportRows(file.table, mapping, lookup) : []),
    [file, mapping, lookup],
  );
  const overLimit = maxRows !== null && file !== null && file.table.rows.length > maxRows;
  const missing = missingRequired(mapping);
  const unmapped = file ? unmappedColumns(file.table.header, mapping) : [];

  // Giá trị mặc định gửi kèm: nguồn (kèm loại nguồn), kênh, chiến dịch, cơ sở, người phụ trách; ô trống thì bỏ.
  const defaultsPayload = useMemo(() => {
    const out: Record<string, string> = {};
    if (defaults.source !== '') {
      out.source_code = defaults.source;
      const type = catalogs.parentCode('SOURCE', defaults.source, 'SOURCE_TYPE');
      if (type) out.source_type_code = type;
    }
    if (defaults.channel !== '') out.channel_code = defaults.channel;
    if (defaults.campaign !== '') out.campaign_id = defaults.campaign;
    if (defaults.branch !== '') out.branch_id = defaults.branch;
    if (defaults.owner !== '') out.owner_id = defaults.owner;
    return out;
  }, [defaults, catalogs]);

  const preview = useQuery({
    queryKey: ['lead-import-preview', nonce],
    enabled: step === 2 && file !== null,
    staleTime: 0,
    gcTime: 0,
    retry: false,
    queryFn: () =>
      rpc<ImportResult>(supabase, 'import_leads', {
        p_rows: rows,
        p_commit: false,
        p_defaults: defaultsPayload,
        p_file_name: file?.name ?? null,
      }),
  });

  // File mẫu: giá trị Source, Sub-source lấy từ danh mục đang dùng tại lúc tải.
  const sourceOptions = catalogs.options('SOURCE');
  function downloadTemplate() {
    const sources = sourceOptions.map((s) => ({
      name: s.label,
      channels: catalogs.childrenOf('SOURCE_CHANNEL', 'SOURCE', s.value).map((c) => c.label),
    }));
    downloadText('mau-nhap-lead.csv', leadTemplateCsv(sources));
  }

  async function readFile(picked: File | undefined) {
    if (!picked) return;
    setFileError(null);
    try {
      const table = dropSampleRows(parseCsv(await picked.text()));
      if (table.rows.length === 0)
        throw new Error('File chưa có dòng dữ liệu nào (chỉ có dòng tên cột).');
      setFile({ name: picked.name, table });
      setMapping(autoMap(table.header));
    } catch (e) {
      setFile(null);
      setFileError(e instanceof Error ? e.message : 'Không đọc được file.');
    }
  }

  function onDrop(event: DragEvent<HTMLLabelElement>) {
    event.preventDefault();
    setDragging(false);
    void readFile(event.dataTransfer.files[0]);
  }

  async function finish() {
    setBusy(true);
    setError(null);
    try {
      const result = await rpc<ImportResult>(supabase, 'import_leads', {
        p_rows: rows,
        p_commit: true,
        p_defaults: defaultsPayload,
        p_file_name: file?.name ?? null,
      });
      onOpenChange(false);
      onImported(result);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const result = preview.data;
  const canNext =
    step === 0
      ? file !== null && !overLimit
      : step === 1
        ? missing.length === 0
        : result !== undefined && result.imported > 0 && !preview.isFetching;

  return (
    <StepDialog
      open={open}
      onOpenChange={onOpenChange}
      title="Nhập lead từ file"
      steps={STEPS}
      step={step}
      onStepChange={(next) => {
        setError(null);
        if (next === 2) {
          setShown('ALL');
          setNonce((n) => n + 1);
        }
        setStep(next);
      }}
      canNext={canNext}
      onFinish={() => void finish()}
      finishLabel="Nhập"
      busy={busy}
    >
      {step === 0 && (
        <div className="flex flex-col gap-2">
          <label
            htmlFor="import-file"
            onDragOver={(e) => {
              e.preventDefault();
              setDragging(true);
            }}
            onDragLeave={() => setDragging(false)}
            onDrop={onDrop}
            className={cn(
              'flex min-h-[180px] cursor-pointer flex-col items-center justify-center gap-1 rounded-control border border-dashed border-border-strong bg-canvas px-3 py-4 text-center hover:bg-hover',
              dragging && 'bg-hover',
            )}
          >
            <Icon name="upload" size={24} />
            <span>
              Kéo file CSV vào đây, hoặc <span className="text-link underline">chọn file</span>
            </span>
            {file && (
              <span className="text-caption text-fg-muted">
                {file.name} · {file.table.rows.length} dòng · {file.table.header.length} cột
              </span>
            )}
          </label>
          <input
            ref={input}
            id="import-file"
            type="file"
            accept=".csv,text/csv"
            aria-label="Chọn file CSV"
            className="sr-only"
            onChange={(e) => {
              void readFile(e.target.files?.[0]);
              e.target.value = '';
            }}
          />
          <p className="text-caption text-fg-muted">
            Nhận file CSV (.csv), dòng đầu là tên cột. Từ Excel, lưu bằng “CSV UTF-8” rồi tải lên.
            {maxRows !== null && ` Tối đa ${maxRows} dòng mỗi lần.`}
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <Button
              icon="download"
              disabled={sourceOptions.length === 0}
              onClick={downloadTemplate}
            >
              Tải file mẫu
            </Button>
            <span className="text-caption text-fg-muted">
              Cột có dấu * là bắt buộc. Dòng bắt đầu bằng {SAMPLE_MARK} được bỏ qua khi nhập.
            </span>
          </div>
          {fileError && <Alert tone="danger">{fileError}</Alert>}
          {overLimit && file && maxRows !== null && (
            <Alert tone="danger">
              File có {file.table.rows.length} dòng, tối đa {maxRows} dòng mỗi lần nhập. Tách file
              rồi chọn lại.
            </Alert>
          )}
        </div>
      )}

      {step === 1 && file && (
        <div className="flex flex-col gap-3">
          {missing.length > 0 && (
            <Alert tone="danger">Chưa ghép cột bắt buộc: {missing.join(', ')}.</Alert>
          )}
          {unmapped.length > 0 && (
            <Alert tone="warning">
              {unmapped.length} cột chưa ghép: <b>{unmapped.join(', ')}</b>. Dữ liệu của các cột này
              không được nhập vào hệ thống.
            </Alert>
          )}
          <div className="max-h-[320px] overflow-auto rounded-control border border-border">
            <table className="w-full text-body">
              <thead className="sticky top-0 bg-surface-subtle text-left text-caption text-fg-label">
                <tr>
                  <th className="px-3 py-2 font-semibold">Cột trong file</th>
                  <th className="w-8" aria-hidden="true" />
                  <th className="px-3 py-2 font-semibold">Trường trong hệ thống</th>
                  <th className="px-3 py-2 font-semibold">Trạng thái</th>
                </tr>
              </thead>
              <tbody>
                {file.table.header.map((name, i) => {
                  const field = mapping[i] ?? null;
                  return (
                    <tr key={`${name}-${i}`} className="border-t border-border">
                      <td className="px-3 py-1.5 whitespace-nowrap">{name || `(cột ${i + 1})`}</td>
                      <td className="text-fg-muted">
                        <Icon name="arrowRight" size={16} />
                      </td>
                      <td className="min-w-[170px] px-3 py-1.5">
                        <Select
                          label={`Trường cho cột ${name || i + 1}`}
                          value={field ?? NO_FIELD}
                          onChange={(v) =>
                            setMapping((m) =>
                              setColumnField(m, i, v === NO_FIELD ? null : (v as ImportField)),
                            )
                          }
                          options={[
                            { value: NO_FIELD, label: 'Không nhập' },
                            ...IMPORT_FIELDS.map((f) => ({ value: f.key, label: f.label })),
                          ]}
                          className="w-full"
                        />
                      </td>
                      <td className="px-3 py-1.5">
                        {field ? (
                          <span className="inline-flex items-center gap-1 text-on-success-subtle">
                            <Icon name="checkMark" size={16} /> Đã ghép
                          </span>
                        ) : (
                          <Tag tone="warning">Chưa ghép</Tag>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <fieldset className="flex flex-col gap-2 rounded-control border border-border p-3">
            <legend className="px-1 text-caption font-semibold text-fg-label">
              Giá trị mặc định (ô nào trong file để trống thì lấy ở đây)
            </legend>
            <div className="grid gap-3 md:grid-cols-2">
              <Field label="Source">
                {(f) => (
                  <OptionalSelect
                    label="Source mặc định"
                    value={defaults.source}
                    onChange={(v) => setDefaults((d) => ({ ...d, source: v, channel: '' }))}
                    options={catalogs.options('SOURCE')}
                    placeholder="Chưa chọn"
                    {...f}
                  />
                )}
              </Field>
              <Field label="Sub-source">
                {() => (
                  <OptionalSelect
                    label="Sub-source mặc định"
                    value={defaults.channel}
                    onChange={(v) => setDefaults((d) => ({ ...d, channel: v }))}
                    options={catalogs.childrenOf('SOURCE_CHANNEL', 'SOURCE', defaults.source)}
                    placeholder={defaults.source === '' ? 'Chọn Source trước' : 'Chưa chọn'}
                    disabled={defaults.source === ''}
                  />
                )}
              </Field>
              <Field label="Chiến dịch">
                {() => (
                  <OptionalSelect
                    label="Chiến dịch mặc định"
                    value={defaults.campaign}
                    onChange={(v) => setDefaults((d) => ({ ...d, campaign: v }))}
                    options={catalogs.campaigns}
                    placeholder="Chưa chọn"
                  />
                )}
              </Field>
              {canAssign && branchOptions.length > 0 && (
                <Field label="Cơ sở">
                  {() => (
                    <OptionalSelect
                      label="Cơ sở nhập"
                      value={defaults.branch}
                      onChange={(v) => setDefaults((d) => ({ ...d, branch: v, owner: '' }))}
                      options={branchOptions}
                      placeholder="Cơ sở của tôi"
                    />
                  )}
                </Field>
              )}
              {canAssign && (
                <Field label="Người phụ trách">
                  {() => (
                    <OptionalSelect
                      label="Người phụ trách mặc định"
                      value={defaults.owner}
                      onChange={(v) => setDefaults((d) => ({ ...d, owner: v }))}
                      options={(staff.data ?? []).map((s) => ({
                        value: s.id,
                        label: s.display_name,
                      }))}
                      placeholder={defaults.branch === '' ? 'Chính tôi' : 'Chưa chọn'}
                      disabled={defaults.branch === ''}
                    />
                  )}
                </Field>
              )}
            </div>
          </fieldset>
        </div>
      )}

      {step === 2 && (
        <div className="flex flex-col gap-3">
          {(preview.isPending || preview.isFetching) && <Spinner label="Đang kiểm các dòng…" />}
          {preview.isError && <Alert tone="danger">{errorOf(preview.error).message}</Alert>}
          {result && (
            <>
              <div className="flex gap-2">
                <Tile
                  count={result.imported}
                  label="dòng hợp lệ"
                  tone="success"
                  active={shown === 'HOP_LE'}
                  onClick={() => setShown(shown === 'HOP_LE' ? 'ALL' : 'HOP_LE')}
                />
                <Tile
                  count={result.duplicates}
                  label="dòng trùng SĐT"
                  tone="warning"
                  active={shown === 'TRUNG'}
                  onClick={() => setShown(shown === 'TRUNG' ? 'ALL' : 'TRUNG')}
                />
                <Tile
                  count={result.errors}
                  label="dòng lỗi"
                  tone="danger"
                  active={shown === 'LOI'}
                  onClick={() => setShown(shown === 'LOI' ? 'ALL' : 'LOI')}
                />
              </div>
              <div className="max-h-[420px] overflow-auto rounded-control border border-border">
                <table className="w-full text-body" aria-label="Kết quả từng dòng">
                  <thead className="sticky top-0 bg-surface-subtle text-left text-caption text-fg-label">
                    <tr>
                      <th className="px-3 py-2 text-right font-semibold">Dòng</th>
                      <th className="px-3 py-2 font-semibold">Phụ huynh</th>
                      <th className="px-3 py-2 font-semibold">SĐT</th>
                      <th className="px-3 py-2 font-semibold">Kết quả</th>
                    </tr>
                  </thead>
                  <tbody>
                    {result.rows
                      .filter((r) => shown === 'ALL' || r.status === shown)
                      .map((r) => {
                        const source = rows.find((x) => x.row === r.row);
                        return (
                          <tr key={r.row} className="border-t border-border align-top">
                            <td className="px-3 py-1.5 text-right text-fg-muted tabular">
                              {r.row}
                            </td>
                            <td className="px-3 py-1.5">
                              {source?.parent_name ?? (
                                <span className="text-fg-muted">(trống)</span>
                              )}
                            </td>
                            <td className="px-3 py-1.5 tabular">
                              {source?.parent_phone ? formatPhone(String(source.parent_phone)) : ''}
                            </td>
                            <td className="px-3 py-1.5">
                              <Tag
                                tone={
                                  r.status === 'HOP_LE'
                                    ? 'success'
                                    : r.status === 'TRUNG'
                                      ? 'warning'
                                      : 'danger'
                                }
                              >
                                {r.status === 'HOP_LE'
                                  ? 'Hợp lệ'
                                  : r.status === 'TRUNG'
                                    ? 'Trùng SĐT'
                                    : 'Lỗi'}
                              </Tag>
                              {r.message && (
                                <div className="text-caption text-fg-muted">{r.message}</div>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                  </tbody>
                </table>
              </div>
              <p className="text-caption text-fg-muted">
                Bấm ô đếm để lọc bảng. Dòng trùng SĐT sẽ bị bỏ qua khi nhập, dòng lỗi không nhập.
                {result.imported === 0 && ' Chưa có dòng hợp lệ nào để nhập.'}
              </p>
            </>
          )}
          {error && <Alert tone="danger">{error}</Alert>}
        </div>
      )}
    </StepDialog>
  );
}

function Tile({
  count,
  label,
  tone,
  active,
  onClick,
}: {
  count: number;
  label: string;
  tone: 'success' | 'warning' | 'danger';
  active: boolean;
  onClick: () => void;
}) {
  const style = {
    success: 'bg-success-subtle text-on-success-subtle',
    warning: 'bg-warning-subtle text-on-warning-subtle',
    danger: 'bg-danger-subtle text-on-danger-subtle',
  }[tone];
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={cn(
        'focus-ring flex flex-1 flex-col gap-0.5 rounded-control border px-3 py-2.5 text-left',
        style,
        active ? 'border-2 border-border-strong' : 'border-border',
      )}
    >
      <b className="text-h2 tabular">{count}</b>
      <span className="text-caption">{label}</span>
    </button>
  );
}
