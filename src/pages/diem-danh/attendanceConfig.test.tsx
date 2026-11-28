import { describe, expect, it } from 'vitest';
import { visibleColumnKeys } from '../../list/state';
import { buildAttendanceConfig, COLUMN_KEYS } from './attendanceConfig';

describe('cấu hình màn Điểm danh', () => {
  const config = buildAttendanceConfig({ statuses: [], reasons: [], canEdit: true });
  it('hiện đủ cột, đúng thứ tự canvas', () => {
    expect(config.columns.map((c) => c.key)).toEqual(COLUMN_KEYS);
    expect(
      visibleColumnKeys(config, {
        search: '',
        quick: {},
        conditions: [],
        group: [],
        columns: COLUMN_KEYS,
        dateField: '',
        datePreset: '',
      }),
    ).toEqual(COLUMN_KEYS);
  });
});
