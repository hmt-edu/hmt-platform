// Cấu hình hai danh sách Khách hàng (khuôn K03): KH-01 Phụ huynh, KH-04 Học sinh. Tìm, lọc, sắp xếp, phân trang ở máy chủ.
import { Link } from 'react-router';
import type { ListConfig, ListState } from '../../list/types';
import { Tag } from '../../ui/Data';
import {
  STUDENT_STATUS_LABEL,
  type ParentRow,
  type StudentRow,
  type StudentStatus,
} from './custTypes';

export const EMPTY_CUST_STATE: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

export const parentPath = (id: string) => `/crm/phu-huynh/${id}`;
export const studentPath = (id: string) => `/crm/hoc-sinh/${id}`;

type Option = { value: string; label: string };

const STATUS_TONE: Record<StudentStatus, 'success' | 'warning' | 'neutral' | 'info'> = {
  DANG_HOC: 'success',
  BAO_LUU: 'warning',
  DUNG: 'neutral',
  TIEM_NANG: 'info',
};

export function buildParentConfig(branches: Option[]): ListConfig<ParentRow> {
  return {
    screenCode: 'KH-01',
    title: 'Phụ huynh',
    searchPlaceholder: 'Tìm tên, số điện thoại, mã…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        render: (r) => <span className="tabular">{r.code}</span>,
      },
      {
        key: 'name',
        label: 'Họ tên',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <Link to={parentPath(r.id)} className="font-medium text-link hover:underline">
            {r.full_name}
          </Link>
        ),
      },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => (
          <Tag tone={r.is_studying ? 'success' : 'neutral'}>
            {r.is_studying ? 'Có con đang học' : 'Chưa có con đang học'}
          </Tag>
        ),
      },
      { key: 'branch', label: 'Cơ sở tiếp nhận', render: (r) => r.branch_code },
      {
        key: 'studying',
        label: 'Đang học tại',
        render: (r) => (r.studying_at.length > 0 ? r.studying_at.join(', ') : '—'),
      },
      { key: 'phone', label: 'SĐT', render: (r) => <span className="tabular">{r.phone}</span> },
      { key: 'children', label: 'Số con', numeric: true, render: (r) => r.children_count },
    ],
    quickGroups: [
      {
        key: 'status',
        label: 'Tình trạng',
        options: [
          { value: 'DANG_HOC', label: 'Có con đang học' },
          { value: 'CHUA_DANG_HOC', label: 'Chưa có con đang học' },
        ],
      },
    ],
    filterFields: [
      { key: 'branch', label: 'Cơ sở tiếp nhận', type: 'select', ops: ['eq'], options: branches },
    ],
    groupFields: [
      {
        key: 'status',
        label: 'Tình trạng',
        value: (r) => (r.is_studying ? 'DANG_HOC' : 'CHUA_DANG_HOC'),
      },
      { key: 'branch', label: 'Cơ sở tiếp nhận', value: (r) => r.branch_code },
    ],
    dateFields: [],
    views: ['list'],
  };
}

export function buildStudentConfig(branches: Option[], grades: Option[]): ListConfig<StudentRow> {
  return {
    screenCode: 'KH-04',
    title: 'Học sinh',
    searchPlaceholder: 'Tìm tên, mã, mã cũ…',
    columns: [
      {
        key: 'code',
        label: 'Mã',
        locked: true,
        render: (r) => (
          <span className="flex flex-col">
            <span className="tabular">{r.code}</span>
            {r.legacy_ref && <span className="text-caption text-fg-muted">{r.legacy_ref}</span>}
          </span>
        ),
      },
      {
        key: 'name',
        label: 'Họ tên',
        locked: true,
        primary: true,
        sortable: true,
        render: (r) => (
          <Link to={studentPath(r.id)} className="font-medium text-link hover:underline">
            {r.full_name}
          </Link>
        ),
      },
      { key: 'grade', label: 'Khối', render: (r) => (r.grade ? `Lớp ${r.grade}` : '—') },
      {
        key: 'status',
        label: 'Tình trạng',
        render: (r) => <Tag tone={STATUS_TONE[r.status]}>{STUDENT_STATUS_LABEL[r.status]}</Tag>,
      },
      { key: 'branch', label: 'Cơ sở tiếp nhận', render: (r) => r.branch_code },
      {
        key: 'studying',
        label: 'Đang học tại',
        render: (r) => (r.studying_at.length > 0 ? r.studying_at.join(', ') : '—'),
      },
      {
        key: 'classes',
        label: 'Lớp',
        render: (r) => (r.classes.length > 0 ? r.classes.join(', ') : '—'),
      },
      { key: 'parent', label: 'Phụ huynh', defaultVisible: false, render: (r) => r.parent_name },
      {
        key: 'phone',
        label: 'SĐT phụ huynh',
        render: (r) => <span className="tabular">{r.parent_phone ?? '—'}</span>,
      },
    ],
    quickGroups: [
      {
        key: 'status',
        label: 'Tình trạng',
        options: (Object.keys(STUDENT_STATUS_LABEL) as StudentStatus[]).map((value) => ({
          value,
          label: STUDENT_STATUS_LABEL[value],
        })),
      },
    ],
    filterFields: [
      { key: 'branch', label: 'Cơ sở tiếp nhận', type: 'select', ops: ['eq'], options: branches },
      { key: 'grade', label: 'Khối', type: 'select', ops: ['eq'], options: grades },
    ],
    groupFields: [],
    dateFields: [],
    views: ['list'],
  };
}
