// LOP-09 Học sinh của lớp (danh sách, khuôn K03; canvas 9933 khung LOP09): mọi dòng xếp lớp của một lớp, đang học và đã rời. Lọc, tìm, sắp xếp, phân trang ở máy chủ
// (app.list_class_students). «Xếp thêm» dẫn tới Hàng chờ xếp lớp (GD-06). «Xuất» chưa làm: ma trận quyền chưa có quyền Xuất cho phân hệ Lớp (chờ anh chốt).
import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { ListScreen } from '../../list/ListScreen';
import { buildLeadGroupTree } from '../lead/leadGroups';
import { useLeafRows } from '../lead/useLeadData';
import { useToast } from '../../ui/toastContext';
import type { ListState } from '../../list/types';
import { errorOf, useIntSetting } from '../../lib/db';
import { useDebounced } from '../../lib/useDebounced';
import { useClassRecord } from './useClassData';
import { useAccess } from '../../nav/AccessContext';
import type { SortState } from '../../ui/Data';
import { useLeadCatalogs } from '../lead/useCatalogs';
import {
  CLASS_STUDENT_GROUP_FIELD_OF,
  EMPTY_CLASS_STUDENT_STATE,
  buildClassStudentFilters,
  classStudentGroupFilter,
  classStudentSortParam,
  classTitleLabel,
  useClassStudentGroupCounts,
  useClassStudentPage,
  type ClassStudentRow,
} from './classStudents';
import { buildClassStudentsConfig } from './classStudentsConfig';

export function ClassStudentsPage() {
  const { id } = useParams();
  const access = useAccess();
  const navigate = useNavigate();
  const catalogs = useLeadCatalogs();
  const classRecord = useClassRecord(id).data;
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

  // Group By ở máy chủ (tối đa hai cấp): số đếm từ class_student_group_counts, dòng tải khi mở từng nhóm lá (list_class_students).
  const toast = useToast();
  const groupFields = state.group.flatMap((k) =>
    CLASS_STUDENT_GROUP_FIELD_OF[k] ? [CLASS_STUDENT_GROUP_FIELD_OF[k]] : [],
  );
  const grouped = groupFields.length > 0;
  const [tick, setTick] = useState(0);
  const list = useClassStudentPage(
    id,
    filters,
    sortValue,
    page * (pageSize ?? 0),
    pageSize,
    !grouped,
  );
  const counts = useClassStudentGroupCounts(id, filters, groupFields, true);
  const leafExtra = useMemo(() => ({ p_class_id: id }), [id]);
  const leaves = useLeafRows<ClassStudentRow>(
    filters,
    sortValue,
    pageSize,
    `${JSON.stringify(filters)}|${sortValue}|${tick}`,
    (message) => toast({ tone: 'danger', title: message }),
    'list_class_students',
    leafExtra,
  );
  const grouping = useMemo(
    () =>
      grouped && counts.data
        ? buildLeadGroupTree<ClassStudentRow>(
            counts.data,
            groupFields,
            leaves.leaves,
            (key, spec) => leaves.more(key, spec.filters),
            classStudentGroupFilter,
          )
        : null,
    // groupFields suy ra từ state.group; leaves.more đổi theo bộ lọc.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [grouped, counts.data, state.group, leaves.leaves, leaves.more],
  );
  const rows = list.data?.rows ?? [];
  const total = grouped ? (counts.data?.total ?? 0) : (list.data?.total ?? 0);
  const activeQuery = grouped ? counts : list;
  const errorText = activeQuery.isError ? errorOf(activeQuery.error).message : null;

  const config = useMemo(
    () =>
      buildClassStudentsConfig({
        classLabel: classRecord ? classTitleLabel(classRecord) : undefined,
        modes: catalogs.options('STUDY_MODE'),
        modeName: (code) => (code ? (catalogs.name('STUDY_MODE', code) ?? code) : '—'),
        statusName: (code) => catalogs.name('ENROLLMENT_STATUS', code),
      }),
    [catalogs, classRecord],
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
      loading={activeQuery.isPending || activeQuery.isPlaceholderData}
      error={errorText}
      onRetry={() => void activeQuery.refetch()}
      groupTree={grouping?.tree}
      onGroupToggle={(key, open) => {
        const spec = grouping?.specs.get(key);
        if (spec) leaves.toggle(key, spec.filters, open);
      }}
      actions={[
        {
          label: `Quay lại lớp ${classRecord?.code ?? ''}`.trim(),
          icon: 'back' as const,
          onClick: () => void navigate(`/crm/lop/${id ?? ''}`),
        },
        ...(canAssign
          ? [
              {
                label: 'Xếp thêm',
                icon: 'plus' as const,
                onClick: () => void navigate('/crm/ghi-danh/cho-xep-lop'),
              },
            ]
          : []),
      ]}
      onRefresh={() => {
        setTick((t) => t + 1);
        void activeQuery.refetch();
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
