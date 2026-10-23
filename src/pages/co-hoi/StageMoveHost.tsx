// Mở hộp chuyển giai đoạn (TS-09) cho một cơ hội chỉ biết mã: tải cơ hội (get_opportunity) để biết thiếu gì (tên, năm sinh học sinh,
// phiếu dang dở, phiếu hoàn thành), rồi hiện đúng dạng hộp. Dùng khi kéo thẻ Kanban (thẻ không mang đủ thông tin).
import { errorOf, rpc, useDb } from '../../lib/db';
import { Spinner } from '../../ui/Feedback';
import { useToast } from '../../ui/toastContext';
import { codeAndName } from '../lead/leadFormat';
import { useLeadCatalogs } from '../lead/useCatalogs';
import { oppTitle } from './oppConfig';
import { planStageChange } from './oppStage';
import { StageDialog, type StageSubmit } from './StageDialog';
import { changeOpportunityStage, useOpportunity } from './useOppData';

export function StageMoveHost({
  id,
  target,
  onClose,
  onDone,
  onFillMissing,
  onOpenTest,
}: {
  id: string;
  target: string;
  onClose: () => void;
  /** Gọi sau khi chuyển xong (tải lại danh sách, Kanban). */
  onDone: (stageName: string) => void;
  /** Dạng thiếu thông tin học sinh: mở trang cơ hội để điền. */
  onFillMissing: (id: string) => void;
  /** Dạng chặn vì còn phiếu dang dở: mở trang phiếu. */
  onOpenTest: (testId: string) => void;
}) {
  const supabase = useDb();
  const toast = useToast();
  const catalogs = useLeadCatalogs();
  const query = useOpportunity(id);

  if (query.isPending) return <Spinner label="Đang kiểm tra điều kiện chuyển…" />;
  if (query.isError) {
    // Không đọc được cơ hội: báo lỗi nghiệp vụ rồi đóng (hàm chuyển giai đoạn vẫn kiểm lại).
    toast({ tone: 'danger', title: errorOf(query.error).message });
    onClose();
    return null;
  }
  const record = query.data;
  const stageName = (code: string) => codeAndName(code, catalogs.name('OPP_STAGE', code));

  async function submit(data: StageSubmit) {
    await changeOpportunityStage(supabase, {
      id: record.id,
      stage: target,
      substage: data.substage,
      skipReason: data.skipReason,
      skipNote: data.skipReason ? (data.note.trim() === '' ? null : data.note.trim()) : null,
      confirmL8: data.confirmL8,
    });
    if (!data.skipReason && data.note.trim() !== '') {
      try {
        await rpc<string>(supabase, 'add_note', {
          p_entity_type: 'OPPORTUNITY',
          p_entity_id: record.id,
          p_body: data.note.trim(),
        });
      } catch (e) {
        toast({
          tone: 'warning',
          title: `Đã chuyển giai đoạn nhưng chưa lưu ghi chú: ${errorOf(e).message}`,
        });
      }
    }
    onDone(stageName(target));
  }

  return (
    <StageDialog
      open
      onOpenChange={(open) => !open && onClose()}
      subtitle={`Cơ hội ${record.code} · ${oppTitle(record)} · đang ở ${stageName(record.stage_code)}`}
      target={target}
      plan={planStageChange(record, target)}
      catalogs={catalogs}
      lastCompleted={record.tests.find((t) => t.status_code === 'COMPLETED') ?? null}
      onFillMissing={() => onFillMissing(record.id)}
      onOpenTest={onOpenTest}
      onSubmit={submit}
    />
  );
}
