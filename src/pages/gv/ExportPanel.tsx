// GV-07X Xuất nhận xét (khung 9189 GV07X_*): nút «Xuất nhận xét» của em đang chọn và «Xuất cả lớp», hộp thoại chọn PDF hoặc ảnh, trạng thái đang tạo, lỗi có thử lại,
// khoá khi còn thay đổi chưa lưu. File tạo trên trình duyệt, không lưu lên máy chủ; xuất xong đặt dấu «Đã xuất» (R-V2-38). Giáo viên tự gửi file vào group Zalo.
import { useState } from 'react';
import logoUrl from '../../../design/hmt-p0-p2/assets/Logo-HMT-cropped.svg';
import { errorOf } from '../../lib/db';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { Field } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';
import { cardFileName, type ExportCard } from './exportCard';
import { canShareImages, downloadCanvas, shareOrDownloadCanvases } from '../../print/canvasFile';
import { cardsToPrintHtml, drawCard, loadImage, printHtml } from './exportRender';
import { useMarkExported } from './useExported';

export type ExportItem = {
  studentId: string;
  name: string;
  card: ExportCard | null;
  exported: boolean;
};
type Scope = 'ONE' | 'ALL';
type Format = 'PNG' | 'PDF';

export function ExportPanel({
  sessionId,
  classCode,
  sessionDate,
  items,
  currentStudentId,
  dirty,
  showOne = true,
}: {
  sessionId: string;
  classCode: string;
  sessionDate: string;
  items: ExportItem[];
  currentStudentId: string | null;
  dirty: boolean;
  /** Màn không có «em đang chọn» (chấm kiểm tra: danh sách phẳng) thì ẩn nút xuất một em. */
  showOne?: boolean;
}) {
  const toast = useToast();
  const mark = useMarkExported(sessionId);
  const [scope, setScope] = useState<Scope | null>(null);
  const [format, setFormat] = useState<Format>('PNG');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const current = items.find((i) => i.studentId === currentStudentId) ?? null;
  const ready = items.filter((i) => i.card !== null);
  const chosen = scope === 'ONE' ? (current && current.card ? [current] : []) : ready;

  const shareable = format === 'PNG' && canShareImages();

  async function run(share = false) {
    setBusy(true);
    setError(null);
    try {
      const withCard = chosen.filter(
        (i): i is ExportItem & { card: ExportCard } => i.card !== null,
      );
      if (format === 'PNG') {
        const logo = await loadImage(logoUrl);
        const images = withCard.map((item) => ({
          canvas: drawCard(item.card, logo),
          fileName: cardFileName(classCode, sessionDate, item.name, 'png'),
        }));
        if (share) {
          // Đóng bảng chia sẻ thì chưa gửi gì: giữ hộp thoại, không đặt dấu «Đã xuất».
          if ((await shareOrDownloadCanvases(images)) === 'cancelled') return;
        } else {
          for (const image of images) await downloadCanvas(image.canvas, image.fileName);
        }
      } else {
        await printHtml(
          cardsToPrintHtml(
            withCard.map((i) => i.card),
            logoUrl,
          ),
        );
      }
      await mark.mutateAsync(withCard.map((i) => i.studentId));
      toast({
        tone: 'success',
        title: withCard.length === 1 ? 'Đã xuất nhận xét' : `Đã xuất ${withCard.length} nhận xét`,
      });
      setScope(null);
    } catch (e) {
      setError(errorOf(e).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section
      aria-label="Xuất nhận xét"
      className="flex flex-col gap-2 rounded-lg border border-border p-3"
    >
      <div className="flex flex-wrap items-center gap-2">
        {showOne && (
          <Button
            variant="secondary"
            disabled={dirty || !current || current.card === null}
            onClick={() => setScope('ONE')}
          >
            Xuất nhận xét
          </Button>
        )}
        <Button
          variant="secondary"
          disabled={dirty || ready.length === 0}
          onClick={() => setScope('ALL')}
        >
          Xuất cả lớp
        </Button>
      </div>
      {ready.some((i) => i.exported) && (
        <p className="text-caption text-fg-muted">
          Đã xuất {ready.filter((i) => i.exported).length}/{ready.length} em có mặt.
        </p>
      )}
      <p className="text-caption text-fg-muted">
        {dirty
          ? 'Bạn đã sửa điểm hoặc nhận xét nhưng chưa bấm Lưu. Lưu xong mới xuất được.'
          : 'Xuất nhận xét ra PDF hoặc ảnh ngay khi em đã lưu đủ. Giáo viên tự gửi vào group Zalo. File tạo trên trình duyệt, không lưu lên máy chủ.'}
      </p>
      {scope !== null && (
        <FormDialog
          open
          onOpenChange={(open) => !open && !busy && setScope(null)}
          title={scope === 'ONE' ? 'Xuất nhận xét' : 'Xuất nhận xét cả lớp'}
          subtitle={scope === 'ONE' ? current?.name : `${chosen.length} em có mặt`}
          confirmLabel={busy ? 'Đang tạo…' : 'Xuất'}
          canSubmit={chosen.length > 0 && !busy}
          busy={busy}
          error={error}
          onSubmit={() => void run()}
        >
          <Field label="Định dạng">
            {(field) => (
              <Select
                id={field.id}
                label="Định dạng"
                value={format}
                onChange={(v) => setFormat(v === 'PDF' ? 'PDF' : 'PNG')}
                options={[
                  { value: 'PNG', label: 'Ảnh (PNG), mỗi em một tệp' },
                  { value: 'PDF', label: 'PDF khổ A4 (qua hộp thoại in, chọn Lưu thành PDF)' },
                ]}
              />
            )}
          </Field>
          {shareable && (
            <Button
              variant="secondary"
              disabled={chosen.length === 0 || busy}
              onClick={() => void run(true)}
            >
              Chia sẻ (Zalo…)
            </Button>
          )}
        </FormDialog>
      )}
    </section>
  );
}
