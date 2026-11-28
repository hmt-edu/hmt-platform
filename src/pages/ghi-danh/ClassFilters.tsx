// Các ô lọc của hộp xếp lớp (GD-03): Môn, Khối, Trình độ, Hình thức học. Chỉ lọc trong danh sách lớp máy chủ trả (đúng cơ sở, đúng gói, còn chỗ).
import { Select } from '../../ui/Overlays';
import { MODE_NAME, type ClassFilter } from './enrollLogic';
import type { MatchingClass } from './enrollTypes';

/** Giá trị của mục «Tất cả» trong ô chọn (ô chọn không nhận giá trị rỗng). */
const ALL = 'all';

export function ClassFilters({
  classes,
  value,
  onChange,
  gradeName,
  enrollMode,
}: {
  classes: MatchingClass[];
  value: ClassFilter;
  onChange: (next: ClassFilter) => void;
  gradeName: (code: string) => string;
  enrollMode: string | null | undefined;
}) {
  const unique = (values: (string | null | undefined)[]) =>
    [...new Set(values.filter((v): v is string => Boolean(v)))].sort();
  const modes = unique([enrollMode, ...classes.map((c) => c.delivery_mode_code)]);
  const fields = [
    { key: 'subject', label: 'Môn', values: unique(classes.map((c) => c.subject_name)) },
    { key: 'grade', label: 'Khối', values: unique(classes.map((c) => c.grade_code)) },
    { key: 'level', label: 'Trình độ', values: unique(classes.map((c) => c.level_name)) },
    { key: 'mode', label: 'Hình thức học', values: modes },
  ] as const;
  const text = (key: keyof ClassFilter, v: string) =>
    key === 'grade' ? gradeName(v) : key === 'mode' ? (MODE_NAME[v] ?? v) : v;
  return (
    <div role="group" aria-label="Lọc lớp" className="grid grid-cols-2 gap-2 md:grid-cols-4">
      {fields.map((f) => (
        <div key={f.key} className="flex min-w-0 flex-col gap-1">
          <span className="text-caption text-fg-label">{f.label}</span>
          <Select
            label={`Lọc theo ${f.label}`}
            value={value[f.key] || ALL}
            onChange={(v) => onChange({ ...value, [f.key]: v === ALL ? '' : v })}
            options={[
              { value: ALL, label: 'Tất cả' },
              ...f.values.map((v) => ({ value: v, label: text(f.key, v) })),
            ]}
          />
        </div>
      ))}
    </div>
  );
}
