// QT-18 Nhập dữ liệu cũ (hộp nhiều bước, khuôn K4b ⑤ StepDialog): 1 Tải file, 2 Xem trước từng dòng, nạp thật, rồi hộp kết quả
// (tải dòng lỗi; Người dùng thì tải file mật khẩu tạm, hiện MỘT lần). CSV UTF-8 đọc ở trình duyệt; mọi luật kiểm dòng ở máy chủ.
import { useQuery } from '@tanstack/react-query';
import { useMemo, useRef, useState, type DragEvent } from 'react';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { Button } from '../../ui/Button';
import { Pagination, Tag } from '../../ui/Data';
import { StepDialog } from '../../ui/Dialogs';
import { Alert, Spinner } from '../../ui/Feedback';
import { Icon } from '../../ui/icons';
import { Dialog } from '../../ui/Overlays';
import { cn } from '../../ui/cn';
import { downloadText } from '../lead/csv';
import { parseCsv, type CsvTable } from '../lead/importCsv';
import {
  buildRows,
  errorRowsCsv,
  explainLine,
  passwordsCsv,
  type ImportLine,
  type ImportResult,
  type ImportRowStatus,
  type ImportSummary,
  type TrainingSummary,
} from './importFile';
import { sampleCsvText, type ImportKindConfig } from './importKinds';
import { runImport } from './useImportData';

const STEPS = ['Tải file', 'Xem trước'];
const PAGE_SIZE = 50;
type Shown = 'ALL' | ImportRowStatus;

const STATUS_TEXT: Record<ImportRowStatus, string> = {
  HOP_LE: 'Hợp lệ',
  TRUNG: 'Trùng',
  LOI: 'Lỗi',
};
const STATUS_TONE = { HOP_LE: 'success', TRUNG: 'warning', LOI: 'danger' } as const;

export function ImportDataDialog(props: {
  config: ImportKindConfig;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  // Mỗi lần mở là một lần nạp mới.
  return props.open ? <ImportForm {...props} /> : null;
}

function ImportForm({
  config,
  open,
  onOpenChange,
}: {
  config: ImportKindConfig;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const supabase = useDb();
  const maxRows = useIntSetting('import_max_rows');
  const [step, setStep] = useState(0);
  const [file, setFile] = useState<{ name: string; table: CsvTable } | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);
  const [shown, setShown] = useState<Shown>('ALL');
  const [page, setPage] = useState(1);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const [done, setDone] = useState<ImportResult | null>(null);
  const input = useRef<HTMLInputElement>(null);

  const built = useMemo(() => (file ? buildRows(file.table, config) : null), [file, config]);
  const overLimit = maxRows !== null && file !== null && file.table.rows.length > maxRows;

  const preview = useQuery({
    queryKey: ['import-preview', config.kind, nonce],
    enabled: step === 1 && file !== null && built !== null && built.missing.length === 0,
    staleTime: 0,
    gcTime: 0,
    retry: false,
    queryFn: () => runImport(supabase, config, built?.rows ?? [], false, file?.name ?? ''),
  });

  async function readFile(picked: File | undefined) {
    if (!picked) return;
    setFileError(null);
    try {
      // Khung QT18_sai_dinh_dang: chỉ nhận CSV; file Excel thì chỉ cách lưu lại.
      if (!/\.csv$/i.test(picked.name))
        throw new Error(
          'File không đọc được. Chỉ nhận file CSV (UTF-8). Hãy mở file trong Excel, chọn Lưu thành → CSV UTF-8 rồi tải lại.',
        );
      const table = parseCsv(await picked.text());
      if (table.rows.length === 0)
        throw new Error('File chưa có dòng dữ liệu nào (chỉ có dòng tên cột).');
      setFile({ name: picked.name, table });
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
    if (!file || !built) return;
    setBusy(true);
    setError(null);
    try {
      setDone(await runImport(supabase, config, built.rows, true, file.name));
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  const result = preview.data;
  const canNext =
    step === 0
      ? file !== null && built !== null && built.missing.length === 0 && !overLimit
      : result !== undefined &&
        result.imported > 0 &&
        !preview.isFetching &&
        !(config.blockOnError && result.errors > 0);
  const shownRows = (result?.rows ?? []).filter((r) => shown === 'ALL' || r.status === shown);
  const pageRows = shownRows.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  if (done && file) {
    return (
      <ResultDialog config={config} file={file} result={done} onClose={() => onOpenChange(false)} />
    );
  }

  return (
    <StepDialog
      open={open}
      onOpenChange={onOpenChange}
      title={`Nhập ${config.title.toLowerCase()} từ file`}
      steps={STEPS}
      step={step}
      onStepChange={(next) => {
        setError(null);
        if (next === 1) {
          setShown('ALL');
          setPage(1);
          setNonce((n) => n + 1);
        }
        setStep(next);
      }}
      canNext={canNext}
      onFinish={() => void finish()}
      finishLabel="Nạp"
      busy={busy}
    >
      {step === 0 && (
        <div className="flex flex-col gap-2">
          <label
            htmlFor="import-data-file"
            onDragOver={(e) => {
              e.preventDefault();
              setDragging(true);
            }}
            onDragLeave={() => setDragging(false)}
            onDrop={onDrop}
            className={cn(
              'flex min-h-[160px] cursor-pointer flex-col items-center justify-center gap-1 rounded-control border border-dashed border-border-strong bg-canvas px-3 py-6 text-center',
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
            id="import-data-file"
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
            File CSV UTF-8, dòng đầu là tên cột: {config.columns.join(', ')}. Cột bắt buộc có trong
            file: {config.required.join(', ')}.
            {maxRows !== null && ` Tối đa ${maxRows} dòng mỗi lần.`}
          </p>
          <div>
            <Button
              icon="download"
              onClick={() =>
                downloadText(`mau-${config.kind.toLowerCase()}.csv`, sampleCsvText(config))
              }
            >
              Tải file mẫu
            </Button>
          </div>
          {fileError && <Alert tone="danger">{fileError}</Alert>}
          {built && built.missing.length > 0 && (
            <Alert tone="danger">
              File thiếu cột bắt buộc: <b>{built.missing.join(', ')}</b>. Sửa tên cột rồi chọn lại.
            </Alert>
          )}
          {built && built.ignored.length > 0 && (
            <Alert tone="warning">
              {built.ignored.length} cột không thuộc loại này, sẽ bỏ qua:{' '}
              <b>{built.ignored.join(', ')}</b>.
            </Alert>
          )}
          {overLimit && file && maxRows !== null && (
            <Alert tone="danger">
              File có {file.table.rows.length} dòng, tối đa {maxRows} dòng mỗi lần nạp. Tách file
              rồi chọn lại.
            </Alert>
          )}
        </div>
      )}

      {step === 1 && (
        <div className="flex flex-col gap-3">
          {(preview.isPending || preview.isFetching) && <Spinner label="Đang kiểm các dòng…" />}
          {preview.isError && <Alert tone="danger">{errorOf(preview.error).message}</Alert>}
          {result && (
            <>
              <Tiles
                result={result}
                shown={shown}
                onShown={(s) => {
                  setShown(s);
                  setPage(1);
                }}
              />
              {config.blockOnError && result.errors > 0 && (
                <Alert tone="danger">
                  Còn <b>{result.errors}</b> dòng lỗi. Loại này không nạp từng phần: sửa file cho
                  hết lỗi rồi chọn lại, thì mới nạp được.
                </Alert>
              )}
              {result.summary && <SummaryBlock summary={result.summary} />}
              <ResultTable config={config} rows={pageRows} />
              <Pagination
                page={page}
                pageSize={PAGE_SIZE}
                total={shownRows.length}
                onPageChange={setPage}
              />
              <p className="text-caption text-fg-muted">
                Bấm ô đếm để lọc bảng. Dòng trùng bị bỏ qua, dòng lỗi không nạp.
                {result.imported === 0 && ' Chưa có dòng hợp lệ nào để nạp.'}
              </p>
            </>
          )}
          {error && <Alert tone="danger">{error}</Alert>}
        </div>
      )}
    </StepDialog>
  );
}

function Tiles({
  result,
  shown,
  onShown,
}: {
  result: ImportResult;
  shown: Shown;
  onShown: (s: Shown) => void;
}) {
  // Khung QT18_xem_truoc: bốn ô «Tất cả dòng», «Hợp lệ», «Trùng (bỏ qua)», «Lỗi (bỏ qua)».
  const items: { status: Shown; count: number; label: string }[] = [
    { status: 'ALL', count: result.total, label: 'Tất cả dòng' },
    { status: 'HOP_LE', count: result.imported, label: 'Hợp lệ' },
    { status: 'TRUNG', count: result.duplicates, label: 'Trùng (bỏ qua)' },
    { status: 'LOI', count: result.errors, label: 'Lỗi (bỏ qua)' },
  ];
  const style = {
    ALL: 'bg-surface-subtle text-fg',
    HOP_LE: 'bg-success-subtle text-on-success-subtle',
    TRUNG: 'bg-warning-subtle text-on-warning-subtle',
    LOI: 'bg-danger-subtle text-on-danger-subtle',
  };
  return (
    <div className="flex gap-2">
      {items.map((t) => (
        <button
          key={t.status}
          type="button"
          aria-pressed={shown === t.status}
          onClick={() => onShown(t.status === 'ALL' || shown === t.status ? 'ALL' : t.status)}
          className={cn(
            'focus-ring flex flex-1 flex-col gap-0.5 rounded-control border px-3 py-2.5 text-left',
            style[t.status],
            shown === t.status ? 'border-2 border-border-strong' : 'border-border',
          )}
        >
          <b className="text-h2 tabular">{t.count}</b>
          <span className="text-caption">{t.label}</span>
        </button>
      ))}
    </div>
  );
}

function ResultTable({ config, rows }: { config: ImportKindConfig; rows: ImportLine[] }) {
  return (
    <div className="max-h-[420px] overflow-auto rounded-control border border-border">
      <table className="w-full text-body" aria-label="Kết quả từng dòng">
        <thead className="sticky top-0 bg-surface-subtle text-left text-caption text-fg-label">
          <tr>
            <th className="px-3 py-2 text-right font-semibold">Dòng</th>
            <th className="px-3 py-2 font-semibold">
              {config.training ? config.subject : 'Chữ cái đầu tên'}
            </th>
            <th className="px-3 py-2 font-semibold">Kết quả</th>
            <th className="px-3 py-2 font-semibold">Giải thích</th>
            <th className="px-3 py-2 font-semibold">Cảnh báo</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.row} className="border-t border-border align-top">
              <td className="px-3 py-1.5 text-right text-fg-muted tabular">{r.row}</td>
              <td className="px-3 py-1.5">
                {config.training ? (
                  (r.code ?? <span className="text-fg-muted">{r.label}</span>)
                ) : r.initial ? (
                  `${r.initial}.`
                ) : (
                  <span className="text-fg-muted">(trống)</span>
                )}
              </td>
              <td className="px-3 py-1.5">
                <Tag tone={STATUS_TONE[r.status]}>{STATUS_TEXT[r.status]}</Tag>
              </td>
              <td className="px-3 py-1.5 text-fg-muted">{explainLine(r) || '—'}</td>
              <td className="px-3 py-1.5">
                {(r.warnings ?? []).length === 0 ? (
                  <span className="text-fg-muted">—</span>
                ) : (
                  (r.warnings ?? []).map((w) => (
                    <div key={w} className="text-caption text-on-warning-subtle">
                      {w}
                    </div>
                  ))
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** Hộp kết quả sau khi nạp thật. Người dùng: mật khẩu tạm chỉ hiện một lần, tải ngay. */
function ResultDialog({
  config,
  file,
  result,
  onClose,
}: {
  config: ImportKindConfig;
  file: { name: string; table: CsvTable };
  result: ImportResult;
  onClose: () => void;
}) {
  const [saved, setSaved] = useState(false);
  const passwords = result.passwords ?? [];
  const problems = result.rows.filter((r) => r.status !== 'HOP_LE');
  return (
    <Dialog
      open
      onOpenChange={() => undefined}
      title={`Đã nạp ${config.title.toLowerCase()}`}
      wide
      dismissible={false}
      footer={
        <Button variant="primary" disabled={passwords.length > 0 && !saved} onClick={onClose}>
          Xong
        </Button>
      }
    >
      <div className="flex flex-col gap-3">
        <p>
          <b className="tabular">{result.imported}</b> dòng đã nạp,{' '}
          <b className="tabular">{result.duplicates}</b> dòng trùng bỏ qua,{' '}
          <b className="tabular">{result.errors}</b> dòng lỗi (tổng {result.total} dòng).
        </p>
        {result.summary && <SummaryBlock summary={result.summary} />}
        {passwords.length > 0 && (
          <Alert tone="warning">
            Mật khẩu tạm của {passwords.length} tài khoản chỉ hiện <b>một lần</b>, không lưu ở đâu.
            Tải file ngay để giao từng người; người dùng phải đổi mật khẩu ở lần đăng nhập đầu. Chưa
            tải thì chưa đóng được hộp này.
            <div className="mt-2">
              <Button
                icon="download"
                onClick={() => {
                  downloadText('mat-khau-tam.csv', passwordsCsv(passwords));
                  setSaved(true);
                }}
              >
                Tải file mật khẩu tạm
              </Button>
              {saved && <span className="ml-2 text-caption">Đã tải.</span>}
            </div>
          </Alert>
        )}
        {problems.length > 0 && (
          <div>
            <Button
              icon="download"
              onClick={() =>
                downloadText(`dong-loi-${file.name}`, errorRowsCsv(file.table, config, result))
              }
            >
              Tải dòng lỗi và trùng ({problems.length})
            </Button>
            <p className="mt-1 text-caption text-fg-muted">
              File giữ nguyên các cột của file gốc, thêm cột ket_qua và ly_do. Sửa rồi nạp lại: dòng
              đã nạp sẽ báo trùng, bỏ qua.
            </p>
          </div>
        )}
      </div>
    </Dialog>
  );
}

/** Báo cáo nạp Cơ hội (chỉ số lượng): theo giai đoạn, số dòng thiếu thông tin em, số dòng gắn vào phụ huynh có sẵn. */
function SummaryBlock({ summary }: { summary: ImportSummary | TrainingSummary }) {
  if ('errors_by_type' in summary) return <TrainingSummaryBlock summary={summary} />;
  const stages = Object.entries(summary.by_stage).sort(([a], [b]) => a.localeCompare(b));
  return (
    <div
      className="rounded-control border border-border bg-surface-subtle p-3 text-body"
      aria-label="Báo cáo cơ hội"
    >
      <p className="font-semibold">Báo cáo cơ hội hợp lệ</p>
      <p>
        Theo giai đoạn:{' '}
        {stages.length === 0 ? (
          'chưa có'
        ) : (
          <span className="tabular">
            {stages.map(([stage, n]) => `${stage}: ${n}`).join(' · ')}
          </span>
        )}
      </p>
      <p>
        <b className="tabular">{summary.missing_student_info}</b> dòng thiếu thông tin em (dữ liệu
        cũ), cần bổ sung tên và năm sinh em trước khi tiến tới ghi danh.
      </p>
      <p>
        <b className="tabular">{summary.attached_parent}</b> dòng gắn vào phụ huynh có sẵn (trùng số
        điện thoại).
      </p>
    </div>
  );
}

/** Báo cáo nạp loại đào tạo: lỗi theo từng loại kèm số dòng; lớp chưa có giáo viên (cần gán sau). */
function TrainingSummaryBlock({ summary }: { summary: TrainingSummary }) {
  const types = Object.entries(summary.errors_by_type);
  const noTeacher = summary.classes_without_teacher;
  if (types.length === 0 && noTeacher.length === 0) return null;
  return (
    <div
      className="rounded-control border border-border bg-surface-subtle p-3 text-body"
      aria-label="Báo cáo nạp"
    >
      {types.length > 0 && (
        <div>
          <p className="font-semibold">Lỗi theo loại</p>
          {types.map(([code, lines]) => (
            <p key={code}>
              <span className="text-fg-muted">{code}</span>: dòng{' '}
              <span className="tabular">
                {lines.slice(0, 20).join(', ')}
                {lines.length > 20 && ` … (${lines.length} dòng)`}
              </span>
            </p>
          ))}
        </div>
      )}
      {noTeacher.length > 0 && (
        <div className={types.length > 0 ? 'mt-2' : undefined}>
          <p className="font-semibold">Lớp chưa có giáo viên ({noTeacher.length})</p>
          <p className="tabular">
            {noTeacher.slice(0, 30).join(', ')}
            {noTeacher.length > 30 && ' …'}
          </p>
          <p className="text-caption text-fg-muted">Lớp vẫn được nạp; cần gán giáo viên sau.</p>
        </div>
      )}
    </div>
  );
}
