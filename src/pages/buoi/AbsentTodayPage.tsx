// BUOI-11 Học sinh vắng / chưa đến (khuôn K03): các em vắng hoặc chưa đến của buổi hôm nay để CSKH gọi nhắc. "Ghi lý do" ghi lý do liên hệ (R-DD-03) bằng
// app.set_attendance_ops, giữ nguyên trạng thái vận hành đã ghi; "Mở buổi" sang BUOI-03. Quy tắc hiển thị tạm (Chat 10/11, chưa vào luật): ô giáo viên quyết định;
// giáo viên đã chọn Có mặt thì không hiện dù vận hành ghi gì; ô vận hành chỉ dùng khi ô giáo viên trống.
// Chưa làm: ghi lý do hàng loạt nhiều em một lần (canvas chỉ vẽ ghi từng em).
import { useMemo, useState } from 'react';
import { ListScreen } from '../../list/ListScreen';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import type { ListState, ViewMode } from '../../list/types';
import { errorOf, rpc, useDb, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import { FormDialog } from '../../ui/Dialogs';
import { TextAreaField } from '../../ui/Field';
import { OptionalSelect } from '../../ui/OptionalSelect';
import { useToast } from '../../ui/toastContext';
import { useQuery } from '@tanstack/react-query';
import { buildAbsentConfig } from './sessionConfig';
import {
  ABSENT_GROUP_FIELD_OF,
  EMPTY_ABSENT_STATE,
  absentGroupFilter,
  buildAbsentFilters,
} from './sessionLogic';
import type { AbsentRow, OpsSheet } from './sessionTypes';
import {
  useAbsentGroupCounts,
  useAbsentPage,
  useRefreshSessions,
  useSaveOps,
} from './useSessionData';

export function AbsentTodayPage() {
  const access = useAccess();
  const refreshData = useRefreshSessions();
  const pageSize = useIntSetting('list_page_size_default');
  const [state, setState] = useState<ListState>(EMPTY_ABSENT_STATE);
  const [view, setView] = useState<ViewMode>('list');
  const [paging, setPaging] = useState({ key: '', page: 0 });
  const [editing, setEditing] = useState<AbsentRow | null>(null);

  const debouncedSearch = useDebounced(state.search);
  const filters = useMemo(
    () => buildAbsentFilters({ ...state, search: debouncedSearch }),
    [state, debouncedSearch],
  );
  const pagingKey = JSON.stringify(filters);
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });
  // Group By ở máy chủ: số đếm từ absent_today_group_counts, dòng tải khi mở nhóm lá (absent_today_list, không có p_sort).
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    ABSENT_GROUP_FIELD_OF[k] ? [ABSENT_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useAbsentPage(filters, page * (pageSize ?? 0), pageSize, !grouped);
  const counts = useAbsentGroupCounts(filters, groupFields);
  const leaves = useLeafRows<AbsentRow>(
    filters,
    null,
    pageSize,
    `${pagingKey}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'absent_today_list',
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<AbsentRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            absentGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const config = useMemo(() => buildAbsentConfig(access, setEditing), [access]);

  return (
    <>
      <ListScreen
        config={config}
        state={state}
        onStateChange={setState}
        view={view}
        onViewChange={setView}
        rows={rows}
        rowKey={(r) => `${r.session_id}-${r.student_id}`}
        rowLabel={(r) => `${r.student_name} ${r.class_code}`}
        loading={activeQuery.isPending || activeQuery.isPlaceholderData}
        error={activeQuery.isError ? errorOf(activeQuery.error).message : null}
        onRetry={() => void activeQuery.refetch()}
        onRefresh={() => {
          setTick((t) => t + 1);
          void refreshData();
        }}
        groupTree={grouping?.tree}
        onGroupToggle={(key, open) => {
          const spec = grouping?.specs.get(key);
          if (spec) leaves.toggle(key, spec.filters, open);
        }}
        pager={
          grouped
            ? undefined
            : {
                from: total === 0 ? 0 : page * (pageSize ?? 0) + 1,
                to: page * (pageSize ?? 0) + rows.length,
                total,
                ...(page > 0 ? { onPrev: () => setPage(page - 1) } : {}),
                ...(page * (pageSize ?? 0) + rows.length < total
                  ? { onNext: () => setPage(page + 1) }
                  : {}),
              }
        }
        emptyMessage={{
          title: 'Hôm nay chưa có học sinh vắng',
          hint: 'Học sinh vắng hoặc chưa đến lớp trong ngày sẽ hiện ở đây để CSKH liên hệ.',
        }}
      />
      <ReasonDialog row={editing} onClose={() => setEditing(null)} />
    </>
  );
}

/** Hộp ghi lý do liên hệ của một em. Danh mục lý do lấy từ máy chủ (R-DD-03); "Khác" bắt buộc ghi chú (máy chủ kiểm). */
function ReasonDialog({ row, onClose }: { row: AbsentRow | null; onClose: () => void }) {
  // Khoá theo em để đổi em thì dựng lại trạng thái nhập, không dùng effect.
  return row ? (
    <ReasonBody key={`${row.session_id}-${row.student_id}`} row={row} onClose={onClose} />
  ) : null;
}

function ReasonBody({ row, onClose }: { row: AbsentRow; onClose: () => void }) {
  const supabase = useDb();
  const toast = useToast();
  const save = useSaveOps(row.session_id);
  const [reason, setReason] = useState(row.contact_reason_code ?? '');
  const [note, setNote] = useState(row.ops_note ?? '');
  const [error, setError] = useState<string | null>(null);
  const sheet = useQuery({
    queryKey: ['session-ops-sheet', row.session_id],
    retry: false,
    queryFn: () => rpc<OpsSheet>(supabase, 'session_ops_sheet', { p_session_id: row.session_id }),
  });
  const reasons = sheet.data?.reasons ?? [];
  const needsNote = reasons.find((r) => r.code === reason)?.requires_note ?? false;

  async function submit() {
    setError(null);
    try {
      await save.mutateAsync([
        {
          student_id: row.student_id,
          status_code: row.ops_status_code,
          contact_reason_code: reason === '' ? null : reason,
          note: note.trim() === '' ? null : note.trim(),
        },
      ]);
      toast({ tone: 'success', title: 'Đã ghi lý do liên hệ' });
      onClose();
    } catch (e) {
      setError(errorOf(e).message);
    }
  }

  return (
    <FormDialog
      open
      onOpenChange={(open) => !open && onClose()}
      title="Ghi lý do liên hệ"
      subtitle={`${row.student_name} · ${row.class_code}`}
      confirmLabel="Lưu"
      canSubmit={reasons.length > 0 && (!needsNote || note.trim() !== '')}
      busy={save.isPending}
      error={error ?? (sheet.isError ? errorOf(sheet.error).message : null)}
      onSubmit={() => void submit()}
    >
      <div className="flex flex-col gap-3">
        <OptionalSelect
          label="Lý do liên hệ"
          value={reason}
          onChange={setReason}
          options={reasons.map((r) => ({ value: r.code, label: r.name }))}
          placeholder="Chọn lý do…"
        />
        <TextAreaField
          label="Ghi chú"
          value={note}
          required={needsNote}
          onChange={(e) => setNote(e.target.value)}
        />
      </div>
    </FormDialog>
  );
}
