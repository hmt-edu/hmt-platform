// Danh sách nhãn tiếng Anh giữ nguyên (anh Trường chốt 23/11/2026): một file duy nhất cho mọi script dò chữ giao diện.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

const file = JSON.parse(
  readFileSync(join(process.cwd(), 'config/nhan-tieng-anh-giu-nguyen.json'), 'utf8'),
) as { nhan: string[] };

describe('config/nhan-tieng-anh-giu-nguyen.json', () => {
  it('có đủ nhãn anh chốt và nhãn khuôn K03, không trùng, không rỗng', () => {
    const need = [
      'Filters',
      'Group By',
      'Favorites',
      'Save to Favorites',
      'Stage',
      'Sub-stage',
      'Source',
      'Sub-source',
      'Source type',
      'Medium',
      'Assign',
      'Campaign',
      'Time Table',
      'Done',
    ];
    for (const label of need) expect(file.nhan).toContain(label);
    expect(new Set(file.nhan).size).toBe(file.nhan.length);
    expect(file.nhan.every((l) => l.trim() !== '')).toBe(true);
  });
});
