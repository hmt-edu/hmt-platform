import { describe, expect, it } from 'vitest';
import { QUEUE_GROUP_FIELD_OF, queueGroupFilter } from '../pages/ghi-danh/enrollFilters';
import { STUDENT_GROUP_FIELD_OF, studentGroupFilter } from '../pages/khach-hang/custFilters';
import { CLASS_STUDENT_GROUP_FIELD_OF, classStudentGroupFilter } from '../pages/lop/classStudents';
import { EXPIRING_GROUP_FIELD_OF, expiringGroupFilter } from '../pages/sap-het-gio/expiringLogic';
import {
  ABSENT_GROUP_FIELD_OF,
  PENDING_GROUP_FIELD_OF,
  absentGroupFilter,
  pendingGroupFilter,
} from '../pages/buoi/sessionLogic';

// Group By ở máy chủ cho các danh sách K03 còn thiếu theo canvas 9933 (migration 606): ánh xạ trường nhóm và bộ lọc mở một nhóm.
describe('Group By KH-04 Học sinh (canvas KH04)', () => {
  it('ba trường nhóm; mở nhóm lọc đúng khoá của list_students', () => {
    expect(STUDENT_GROUP_FIELD_OF).toEqual({ status: 'status', grade: 'grade', branch: 'branch' });
    expect(studentGroupFilter('status', 'DANG_HOC')).toEqual({ status: ['DANG_HOC'] });
    expect(studentGroupFilter('grade', '9')).toEqual({ grade: '9' });
    expect(studentGroupFilter('branch', 'b-1')).toEqual({ branch_id: 'b-1' });
    expect(studentGroupFilter('grade', '')).toEqual({});
  });
});

describe('Group By LOP-09 Học sinh của lớp (canvas LOP09)', () => {
  it('Tình trạng, Cơ sở phụ trách, Hình thức học; mở nhóm lọc đúng khoá của list_class_students', () => {
    expect(CLASS_STUDENT_GROUP_FIELD_OF).toEqual({
      state: 'state',
      branch: 'branch',
      delivery: 'delivery',
    });
    expect(classStudentGroupFilter('state', 'DA_ROI')).toEqual({ state: ['DA_ROI'] });
    expect(classStudentGroupFilter('branch', 'b-1')).toEqual({ branch_id: 'b-1' });
    expect(classStudentGroupFilter('delivery', 'OFF')).toEqual({ delivery: ['OFF'] });
    expect(classStudentGroupFilter('delivery', '')).toEqual({});
  });
});

describe('Group By GD-06 Hàng chờ xếp lớp (canvas GD06, anh chốt 21/11)', () => {
  it('Lý do chờ và Hình thức; lý do chờ không lọc thêm, hình thức lọc delivery_mode_code (giá trị đơn)', () => {
    expect(QUEUE_GROUP_FIELD_OF).toEqual({ reason: 'reason', mode: 'delivery' });
    expect(queueGroupFilter('reason', 'CHUA_CO_LOP')).toEqual({});
    expect(queueGroupFilter('mode', 'OFF')).toEqual({ delivery_mode_code: 'OFF' });
    expect(queueGroupFilter('mode', '')).toEqual({});
  });
});

describe('Group By GD-07 Sắp hết giờ (canvas GD07)', () => {
  it('Tình trạng; mở nhóm lọc status dạng mảng', () => {
    expect(EXPIRING_GROUP_FIELD_OF).toEqual({ status: 'status' });
    expect(expiringGroupFilter('status', 'HET_GIO')).toEqual({ status: ['HET_GIO'] });
    expect(expiringGroupFilter('status', '')).toEqual({});
  });
});

describe('Group By BUOI-12 Buổi chưa Done và BUOI-11 Điểm danh trong ngày (canvas BUOI12, BUOI11)', () => {
  it('Giáo viên: mở nhóm lọc teacher_id; buổi chưa có giáo viên không lọc thêm', () => {
    expect(PENDING_GROUP_FIELD_OF).toEqual({ teacher: 'teacher' });
    expect(pendingGroupFilter('teacher', 'u-1')).toEqual({ teacher_id: 'u-1' });
    expect(pendingGroupFilter('teacher', '')).toEqual({});
  });

  it('Tình trạng Vắng, Chưa tới: mở nhóm lọc kind dạng giá trị đơn (như bộ lọc có sẵn)', () => {
    expect(ABSENT_GROUP_FIELD_OF).toEqual({ status: 'status' });
    expect(absentGroupFilter('status', 'VANG')).toEqual({ kind: 'VANG' });
    expect(absentGroupFilter('status', '')).toEqual({});
  });
});
