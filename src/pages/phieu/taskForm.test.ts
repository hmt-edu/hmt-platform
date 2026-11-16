import { describe, expect, it } from 'vitest';
import {
  EMPTY_TASK_DRAFT,
  buildTaskPayload,
  changesOf,
  validateTaskDraft,
  type TaskFieldDef,
} from './taskForm';

const FIELDS: TaskFieldDef[] = [
  { entity: 'STUDENT', field_code: 'school', label: 'Trường' },
  { entity: 'STUDENT', field_code: 'grade', label: 'Khối' },
  { entity: 'PARENT', field_code: 'address', label: 'Địa chỉ' },
];

describe('Tạo phiếu Cập nhật hồ sơ: biểu mẫu', () => {
  it('chỉ lấy ô đã gõ của hồ sơ đang chọn, cắt khoảng trắng', () => {
    const d = {
      ...EMPTY_TASK_DRAFT,
      values: { school: ' Trường A ', grade: '  ', address: 'Số 1' },
    };
    expect(changesOf(d, FIELDS)).toEqual({ school: 'Trường A' });
    expect(changesOf({ ...d, entity: 'PARENT' }, FIELDS)).toEqual({ address: 'Số 1' });
  });
  it('báo thiếu thay đổi và thiếu lý do', () => {
    expect(Object.keys(validateTaskDraft(EMPTY_TASK_DRAFT, FIELDS, true)).sort()).toEqual([
      'reason',
      'values',
    ]);
  });
  it('ticket chưa gắn học sinh thì chặn sửa hồ sơ học sinh', () => {
    const d = { ...EMPTY_TASK_DRAFT, values: { school: 'A' }, reason: 'x' };
    expect(validateTaskDraft(d, FIELDS, false).values).toContain('chưa gắn học sinh');
    expect(validateTaskDraft(d, FIELDS, true)).toEqual({});
  });
  it('dữ liệu gửi có hồ sơ và thay đổi', () => {
    expect(buildTaskPayload({ ...EMPTY_TASK_DRAFT, values: { school: 'A' } }, FIELDS)).toEqual({
      entity: 'STUDENT',
      changes: { school: 'A' },
    });
  });
});
