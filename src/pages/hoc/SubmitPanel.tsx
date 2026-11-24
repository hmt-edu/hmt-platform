// HT-04 Nộp bài (cổng Học sinh): chọn ảnh/PDF, xem lại, nộp (khung HT04_dt_trong, _da_chon, _xem_lai, _dang_nop, _loi_tep, _loi_mang, _da_nop; HT04_pc).
// Luật: R-LMS-02 (nộp muộn), R-LMS-03 (chấm rồi khoá), R-LMS-04 (giới hạn đọc từ tham số file_*). Máy chủ kiểm lại mọi giới hạn.
import { useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useRef, useState } from 'react';
import { errorOf, useDb, useIntSetting } from '../../lib/db';
import { compressImage } from '../../lib/files/imageCompress';
import { outputMime, validateBatch } from '../../lib/files/imageProcess';
import { submitAssignment, uploadFiles, type FileToUpload } from '../../lib/files/fileApi';
import { Button } from '../../ui/Button';
import { Alert } from '../../ui/Feedback';
import { formatFileSize } from '../../ui/lmsFiles';

const MB = 1024 * 1024; // allow-number: đổi MB sang byte

type Step = 'CHON' | 'XEM_LAI' | 'DANG_NOP';
interface Picked {
  key: string;
  file: File;
  url: string | null; // xem trước (ảnh); PDF không có
}

export function SubmitPanel({
  studentId,
  assignmentId,
  isLate,
  resubmit,
}: {
  studentId: string;
  assignmentId: string;
  isLate: boolean;
  resubmit: boolean;
}) {
  const supabase = useDb();
  const queryClient = useQueryClient();
  const maxMb = useIntSetting('file_max_mb');
  const maxCount = useIntSetting('file_max_count_per_upload');
  const maxTotalMb = useIntSetting('file_max_total_mb_per_upload');
  const [step, setStep] = useState<Step>('CHON');
  const [picked, setPicked] = useState<Picked[]>([]);
  const [problems, setProblems] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);
  const urlsRef = useRef<string[]>([]);

  useEffect(() => {
    const urls = urlsRef.current;
    return () => urls.forEach((u) => URL.revokeObjectURL(u));
  }, []);

  const limits = useMemo(
    () =>
      maxMb === null || maxCount === null || maxTotalMb === null
        ? null
        : { maxBytes: maxMb * MB, maxCount, maxTotalBytes: maxTotalMb * MB },
    [maxMb, maxCount, maxTotalMb],
  );

  function addFiles(list: FileList | null) {
    if (!list || !limits) return;
    const incoming = Array.from(list);
    const next = [...picked.map((p) => p.file), ...incoming];
    const errors = validateBatch(next, limits);
    if (errors.length > 0) {
      setProblems(errors.map((e) => e.message));
      return;
    }
    setProblems([]);
    setError(null);
    setPicked([
      ...picked,
      ...incoming.map((file) => {
        const url = file.type.startsWith('image/') ? URL.createObjectURL(file) : null;
        if (url) urlsRef.current.push(url);
        return { key: `${file.name}-${file.size}-${crypto.randomUUID()}`, file, url };
      }),
    ]);
  }

  async function send() {
    setError(null);
    setStep('DANG_NOP');
    try {
      setProgress('Đang chuẩn bị ảnh…');
      const files: FileToUpload[] = [];
      for (const p of picked) {
        if (p.file.type === 'application/pdf') {
          files.push({ blob: p.file, thumb: null, mime: outputMime(p.file.type) });
        } else {
          const img = await compressImage(p.file, { keepColor: false });
          files.push({ blob: img.blob, thumb: img.thumb, mime: img.mime });
        }
      }
      const ids = await uploadFiles(
        supabase,
        { kind: 'BAI_NOP', assignmentId, studentId, files },
        (s) =>
          setProgress(
            s.phase === 'prepare'
              ? 'Đang chuẩn bị ảnh…'
              : s.phase === 'retry'
                ? `Mạng chập chờn, đang thử lại lần ${s.attempt ?? 1}…`
                : `Đang gửi ${files.length} trang…`,
          ),
      );
      setProgress('Đang chốt bài nộp…');
      await submitAssignment(supabase, assignmentId, ids);
      await queryClient.invalidateQueries({ queryKey: ['portal-assignment'] });
      await queryClient.invalidateQueries({ queryKey: ['portal-assignments'] });
      setPicked([]);
      setStep('CHON');
    } catch (e) {
      setError(errorOf(e).message);
      setStep('XEM_LAI'); // giữ nguyên các trang đã chọn để bấm Thử lại
    }
  }

  const hint =
    limits === null
      ? 'Đang tải giới hạn…'
      : `Ảnh hoặc PDF. Tối đa ${maxMb} MB mỗi tệp, ${maxCount} tệp mỗi lần. Ảnh tự nén.`;

  if (step === 'DANG_NOP')
    return (
      <section aria-label="Nộp bài" aria-live="polite" className="flex flex-col gap-2">
        <p className="text-h3">Đang nộp bài…</p>
        <p className="text-caption text-fg-muted">{progress} Em đừng đóng màn này.</p>
        <Button variant="primary" loading disabled>
          Đang nộp…
        </Button>
      </section>
    );

  if (step === 'XEM_LAI')
    return (
      <section aria-label="Xem lại bài nộp" className="flex flex-col gap-3">
        <h2 className="text-h3">Xem lại · {picked.length} trang</h2>
        <PickedList picked={picked} />
        {error && (
          <Alert tone="danger" title="Chưa nộp được bài">
            {error}
          </Alert>
        )}
        <p className="text-caption text-fg-muted">
          {isLate ? 'Đã quá hạn: bài nộp bây giờ sẽ ghi là nộp muộn.' : 'Nộp bây giờ là đúng hạn.'}
        </p>
        <div className="flex gap-2">
          <Button variant="primary" onClick={() => void send()}>
            {error ? 'Thử lại' : 'Nộp bài'}
          </Button>
          <Button onClick={() => setStep('CHON')}>Quay lại sửa</Button>
        </div>
      </section>
    );

  return (
    <section aria-label="Nộp bài" className="flex flex-col gap-3">
      <h2 className="text-h3">{resubmit ? 'Nộp lại bài' : 'Thêm bài làm của em'}</h2>
      <div className="flex flex-wrap gap-2">
        <Button disabled={!limits} onClick={() => cameraRef.current?.click()}>
          Chụp ảnh
        </Button>
        <Button disabled={!limits} onClick={() => inputRef.current?.click()}>
          Chọn tệp
        </Button>
      </div>
      <input
        ref={cameraRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="sr-only"
        aria-label="Chụp ảnh bài làm"
        onChange={(e) => {
          addFiles(e.target.files);
          e.target.value = '';
        }}
      />
      <input
        ref={inputRef}
        type="file"
        accept="image/*,application/pdf"
        multiple
        className="sr-only"
        aria-label="Chọn tệp bài làm"
        onChange={(e) => {
          addFiles(e.target.files);
          e.target.value = '';
        }}
      />
      <p className="text-caption text-fg-muted">{hint}</p>
      {problems.map((m) => (
        <Alert key={m} tone="danger" title="Tệp không hợp lệ">
          {m} Em chọn ảnh khác hoặc chụp lại.
        </Alert>
      ))}
      {picked.length > 0 && (
        <>
          <p className="font-medium">{picked.length} trang đã chọn</p>
          <PickedList
            picked={picked}
            onRemove={(key) => setPicked((l) => l.filter((p) => p.key !== key))}
          />
        </>
      )}
      <Button variant="primary" disabled={picked.length === 0} onClick={() => setStep('XEM_LAI')}>
        Xem lại trước khi nộp
      </Button>
    </section>
  );
}

function PickedList({ picked, onRemove }: { picked: Picked[]; onRemove?: (key: string) => void }) {
  return (
    <ul className="grid grid-cols-3 gap-2">
      {picked.map((p, i) => (
        <li key={p.key} className="relative rounded-lg border border-border bg-surface p-1">
          {p.url ? (
            <img src={p.url} alt={`Trang ${i + 1}`} className="aspect-[3/4] w-full object-cover" />
          ) : (
            <div className="flex aspect-[3/4] items-center justify-center text-caption">PDF</div>
          )}
          <p className="truncate text-caption text-fg-muted">
            Trang {i + 1} · {formatFileSize(p.file.size)}
          </p>
          {onRemove && (
            <button
              type="button"
              aria-label={`Bỏ trang ${i + 1}`}
              className="absolute right-1 top-1 rounded-full bg-surface px-2"
              onClick={() => onRemove(p.key)}
            >
              ×
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}
