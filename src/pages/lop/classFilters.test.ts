import { describe, expect, it } from 'vitest';
import type { ListState } from '../../list/types';
import { buildClassFilters, classGroupFilter, classSortParam } from './classFilters';
import { scheduleText } from './classConfig';
const empty: ListState = {
  search: '',
  quick: {},
  conditions: [],
  group: [],
  columns: [],
  dateField: '',
  datePreset: '',
};

describe('Bộ lọc danh sách lớp (LOP-01)', () => {
  it('không lọc gì thì rỗng', () => {
    expect(buildClassFilters(empty)).toEqual({});
  });

  it('tìm theo mã lớp hoặc mã cũ, cắt khoảng trắng (R-LOP-15)', () => {
    expect(buildClassFilters({ ...empty, search: '  4M1 ' })).toEqual({ search: '4M1' });
  });

  it('lọc nhanh tình trạng duyệt và vận hành', () => {
    const f = buildClassFilters({
      ...empty,
      quick: { status: ['DA_DUYET', 'NHAP'], operating: ['DANG_HOC'] },
    });
    expect(f).toEqual({ status: ['DA_DUYET', 'NHAP'], operating: ['DANG_HOC'] });
  });

  it('điều kiện: cơ sở, môn, khối, phân loại; bỏ qua phép khác máy chủ chưa hiểu', () => {
    const f = buildClassFilters({
      ...empty,
      conditions: [
        { id: '1', field: 'branch', op: 'eq', value: 'b1' },
        { id: '2', field: 'subject', op: 'eq', value: 'TOAN' },
        { id: '3', field: 'grade', op: 'ne', value: 'K08' },
        { id: '4', field: 'type', op: 'eq', value: 'CB' },
      ],
    });
    expect(f).toEqual({ branch_id: 'b1', subject_code: 'TOAN', class_type_code: 'CB' });
  });

  it('sắp xếp: mặc định theo mã tăng dần', () => {
    expect(classSortParam(null, null)).toBe('code_asc');
    expect(classSortParam('code', 'desc')).toBe('code_desc');
    expect(classSortParam('start', 'desc')).toBe('start_desc');
  });
});

describe('scheduleText (lịch học ở danh sách Lớp, T2 mục 10)', () => {
  const t = (weekday: number, teacher?: string | null, room?: string | null) => ({
    weekday,
    start_time: '18:00:00',
    end_time: '19:30:00',
    teacher_name: teacher ?? null,
    room_name: room ?? null,
  });
  it('gộp các thứ cùng giờ, giáo viên, phòng; ghi giáo viên và phòng', () => {
    expect(scheduleText([t(1, 'A', 'P201'), t(3, 'B', 'P201'), t(5, 'A', 'P201')])).toBe(
      'Thứ 2, Thứ 6 · 18:00–19:30 · GV A · P201; Thứ 4 · 18:00–19:30 · GV B · P201',
    );
  });
  it('khung chưa có giáo viên, phòng thì chỉ ghi giờ', () => {
    expect(scheduleText([t(2)])).toBe('Thứ 3 · 18:00–19:30');
  });
});

describe('classGroupFilter (bộ lọc của một nhóm Group By)', () => {
  it('ánh xạ trường nhóm sang bộ lọc của list_classes', () => {
    expect(classGroupFilter('subject', 'TOAN')).toEqual({ subject_code: 'TOAN' });
    expect(classGroupFilter('grade', 'K09')).toEqual({ grade_code: 'K09' });
    expect(classGroupFilter('type', 'CB')).toEqual({ class_type_code: 'CB' });
    expect(classGroupFilter('branch', 'b1')).toEqual({ branch_id: 'b1' });
    expect(classGroupFilter('status', 'DA_DUYET')).toEqual({ status: ['DA_DUYET'] });
    expect(classGroupFilter('operating', 'DANG_HOC')).toEqual({ operating: ['DANG_HOC'] });
  });
  it('nhóm «Chưa có» (khoá rỗng) hoặc trường lạ không lọc thêm', () => {
    expect(classGroupFilter('subject', '')).toEqual({});
    expect(classGroupFilter('khac', 'x')).toEqual({});
  });
});
