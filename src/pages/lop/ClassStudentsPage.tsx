// LOP-09 Học sinh của lớp (danh sách, khuôn K03; canvas 9933 khung LOP09): mọi dòng xếp lớp của một lớp, đang học và đã rời. Lọc, tìm, sắp xếp, phân trang ở máy chủ
// (app.list_class_students). «Xếp thêm» dẫn tới Hàng chờ xếp lớp (GD-06). «Xuất» chưa làm: ma trận quyền chưa có quyền Xuất cho phân hệ Lớp (chờ anh chốt).
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  EMPTY_CLASS_STUDENT_STATE,
  buildClassStudentFilters,
  classStudentSortParam,
  useClassStudentPage,
} from './classStudents';
import { buildClassStudentsConfig } from './classStudentsConfig';

export function ClassStudentsPage() {
  const { id } = useParams();
  const access = useAccess();
  const navigate = useNavigate();
  const catalogs = useLeadCatalogs();
  const pageSize = useIntSetting('list_page_size_default');

  const [state, setState] = useState<ListState>(EMPTY_CLASS_STUDENT_STATE);
  const [sort, setSort] = useState<SortState>(null);
  const [paging, setPaging] = useState({ key: '', page: 0 });

  const debounced = useDebounced(state.search);
  const filters = useMemo(
    () => buildClassStudentFilters({ ...state, search: debounced }),
    [state, debounced],
  );
  const sortValue = classStudentSortParam(sort?.key ?? null, sort?.direction ?? null);
  const pagingKey = `${JSON.stringify(filters)}|${sortValue}`;
  const page = paging.key === pagingKey ? paging.page : 0;
  const setPage = (next: number) => setPaging({ key: pagingKey, page: next });

  const list = useClassStudentPage(id, filters, sortValue, page * (pageSize ?? 0), pageSize);
  const rows = list.data?.rows ?? [];
  const total = list.data?.total ?? 0;
  const errorText = list.isError ? errorOf(list.error).message : null;

  const config = useMemo(
    () =>
      buildClassStudentsConfig({
        modes: catalogs.options('STUDY_MODE'),
        modeName: (code) => (code ? (catalogs.name('STUDY_MODE', code) ?? code) : '—'),
        statusName: (code) => catalogs.name('ENROLLMENT_STATUS', code),
      }),
    [catalogs],
  );
  const canAssign = access.can('ENROLLMENT', 'SUA');

  return (
    <ListScreen
      config={config}
      state={state}
      onStateChange={setState}
      view="list"
      onViewChange={() => undefined}
      rows={rows}
      rowKey={(r) => r.id}
      rowLabel={(r) => r.full_name}
      loading={list.isPending || list.isPlaceholderData}
      error={errorText}
      onRetry={() => void list.refetch()}
      actions={
        canAssign
          ? [
              {
                label: 'Xếp thêm',
                icon: 'plus' as const,
                onClick: () => void navigate('/crm/ghi-danh/cho-xep-lop'),
              },
            ]
          : []
      }
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
      sort={sort}
      onSortChange={(next) => setSort(next?.key === 'start' || next?.key === 'hours' ? next : null)}
      onRowClick={(r) => void navigate(`/crm/ghi-danh/${r.enrollment_id}`)}
      emptyMessage={{
        title: 'Chưa có học sinh',
        hint: 'Lớp chưa có học sinh nào trong bộ lọc này.',
      }}
    />
  );
}
