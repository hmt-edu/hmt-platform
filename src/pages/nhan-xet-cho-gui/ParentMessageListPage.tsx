// CS-16 Nhận xét chờ gửi phụ huynh (khuôn K03, canvas CSN10): CSKH xem lời nhắn của giáo viên, sao chép hoặc xuất ảnh để gửi Zalo tay, rồi đánh dấu đã gửi.
// Luật: R-V2-39 (lời nhắn là chữ giáo viên, không sửa), R-GV-04, R-CS-13, QĐ-Đ291 (gửi tay, không tự gửi). Phân trang, lọc ở máy chủ (migration 622).
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import type { ListConfig, ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { formatDateTime } from '../../lib/format';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { Button } from '../../ui/Button';
import { FormDialog } from '../../ui/Dialogs';
import { useToast } from '../../ui/toastContext';
import logoUrl from '../../../design/hmt-p0-p2/assets/Logo-HMT-cropped.svg';
import { downloadCanvas } from '../../print/canvasFile';
import { drawCard, loadImage } from '../gv/exportRender';
import {
  EMPTY_PARENT_MESSAGE_STATE,
  buildParentMessageFilters,
  keepOneStatus,
  clipMessage,
  messageCard,
  sessionLabel,
  type ParentMessageRow,
} from './parentMessageTypes';
import { useMarkParentMessageSent, useParentMessagePage } from './useParentMessages';

const CLIP_LENGTH = 90; // allow-number: độ dài hiển thị một dòng lời nhắn trong bảng (canvas CSN10)

export function ParentMessageListPage() {
  const access = useAccess();
  const toast = useToast();
  const mark = useMarkParentMessageSent();
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_PARENT_MESSAGE_STATE);
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [viewing, setViewing] = useState<ParentMessageRow | null>(null);
  const [busy, setBusy] = useState(false);
  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildParentMessageFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  const list = useParentMessagePage(filters, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const counts = list.data?.counts;

  const copy = async (row: ParentMessageRow) => {
    try {
      await navigator.clipboard.writeText(row.message);
      toast({ tone: 'success', title: 'Đã sao chép lời nhắn.' });
    } catch {
      toast({ tone: 'danger', title: 'Không sao chép được. Hãy chọn chữ và sao chép tay.' });
    }
  };
  const exportImage = async (row: ParentMessageRow) => {
    try {
      const canvas = drawCard(messageCard(row), await loadImage(logoUrl));
      await downloadCanvas(canvas, `loi-nhan-${row.student_name}.png`);
    } catch (cause) {
      toast({ tone: 'danger', title: errorOf(cause).message });
    }
  };
  const markSent = async (row: ParentMessageRow) => {
    setBusy(true);
    try {
      await mark(row.attendance_id);
      toast({ tone: 'success', title: 'Đã đánh dấu đã gửi.' });
      setViewing(null);
    } catch (cause) {
      toast({ tone: 'danger', title: errorOf(cause).message });
    } finally {
      setBusy(false);
    }
  };

  const config = useMemo<ListConfig<ParentMessageRow>>(
    () => ({
      screenCode: 'CS-16',
      title: 'Nhận xét chờ gửi phụ huynh',
      searchPlaceholder: 'Tìm tên học sinh hoặc mã lớp…',
      columns: [
        {
          key: 'student',
          label: 'Học sinh',
          locked: true,
          primary: true,
          render: (r) => (
            <button
              type="button"
              className="font-medium text-link underline"
              onClick={(e) => {
                e.stopPropagation();
                setViewing(r);
              }}
            >
              {r.student_name}
            </button>
          ),
        },
        { key: 'class', label: 'Lớp', render: (r) => r.class_code },
        {
          key: 'session',
          label: 'Buổi',
          render: (r) => sessionLabel(r.session_no, r.session_date),
        },
        { key: 'parent', label: 'Phụ huynh', render: (r) => r.parent_name },
        { key: 'message', label: 'Lời nhắn', render: (r) => clipMessage(r.message, CLIP_LENGTH) },
        {
          key: 'status',
          label: 'Trạng thái',
          render: (r) =>
            r.sent && r.sent_at
              ? `Đã gửi ${formatDateTime(r.sent_at)}`
              : r.sent
                ? 'Đã gửi'
                : 'Chờ gửi',
        },
        {
          key: 'actions',
          label: 'Thao tác',
          render: (r) => (
            <span className="flex flex-wrap gap-2" onClick={(e) => e.stopPropagation()}>
              <Button size="sm" onClick={() => void copy(r)}>
                Sao chép
              </Button>
              <Button size="sm" onClick={() => void exportImage(r)}>
                Xuất ảnh
              </Button>
              {!r.sent && (
                <Button size="sm" onClick={() => void markSent(r)}>
                  Đánh dấu đã gửi
                </Button>
              )}
            </span>
          ),
        },
      ],
      quickGroups: [
        {
          key: 'status',
          label: 'Trạng thái',
          options: [
            { value: 'CHO_GUI', label: `Chờ gửi${counts ? ` ${counts.cho_gui}` : ''}` },
            { value: 'DA_GUI', label: `Đã gửi${counts ? ` ${counts.da_gui}` : ''}` },
          ],
        },
      ],
      filterFields: access.seesAllBranches
        ? [
            {
              key: 'branch',
              label: 'Cơ sở',
              type: 'select' as const,
              ops: ['eq' as const],
              options: access.teachingBranches.map((b) => ({
                value: b.id,
                label: `${b.code} ${b.name}`,
              })),
            },
          ]
        : [],
      groupFields: [],
      dateFields: [],
      views: ['list'],
    }),
    // copy, exportImage, markSent chỉ dùng hàm ổn định của trang; cấu hình dựng lại khi đổi đếm chip hoặc phạm vi.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [access, counts],
  );

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={(next) => setState((prev) => keepOneStatus(prev, next))}
        view="list"
        onViewChange={() => undefined}
        rows={rows}
        rowKey={(r) => r.attendance_id}
        rowLabel={(r) => `${r.student_name} ${r.class_code}`}
        onRowClick={(r) => setViewing(r)}
        loading={list.isPending || list.isPlaceholderData}
        error={list.isError ? errorOf(list.error).message : null}
        onRetry={() => void list.refetch()}
        onRefresh={() => void list.refetch()}
        pager={{
          from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
          to: page * (pageSize ?? 0) + rows.length,
          total,
          ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
          ...(page * (pageSize ?? 0) + rows.length < total
            ? { onNext: () => setPage(page + 1) }
            : {}),
        }}
        emptyMessage={{
          title: 'Chưa có nhận xét nào chờ gửi',
          hint: 'Lời nhắn xuất hiện sau khi giáo viên chấm xong nhận xét của buổi.',
        }}
      />
      <FormDialog
        open={viewing !== null}
        onOpenChange={(open) => !open && setViewing(null)}
        title="Lời nhắn gửi phụ huynh"
        subtitle={
          viewing ? `${viewing.student_name} · ${viewing.class_code} · ${viewing.parent_name}` : ''
        }
        confirmLabel="Đánh dấu đã gửi"
        cancelLabel="Đóng"
        canSubmit={viewing !== null && !viewing.sent}
        busy={busy}
        onSubmit={() => viewing && void markSent(viewing)}
      >
        {viewing && (
          <>
            <p className="whitespace-pre-wrap text-body">{viewing.message}</p>
            <div className="flex gap-2">
              <Button onClick={() => void copy(viewing)}>Sao chép</Button>
              <Button onClick={() => void exportImage(viewing)}>Xuất ảnh</Button>
            </div>
          </>
        )}
      </FormDialog>
    </>
  );
}
