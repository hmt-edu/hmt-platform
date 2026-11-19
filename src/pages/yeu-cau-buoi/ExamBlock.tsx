// A25: khối «Buổi kiểm tra» dùng chung ở ba form yêu cầu buổi (khung 9189 BUOI07/08/09_bs_loai_kiem_tra): tích để sinh buổi Kiểm tra, rồi nhập phạm vi kiến thức, điểm tối đa,
// cách nhập điểm (điểm tổng hoặc ba nhóm Ghi nhớ·Hiểu·Vận dụng) kèm lỗi tổng ba nhóm lệch. Luật ở examFields.ts; máy chủ kiểm lại.
import { Checkbox, Field, TextAreaField, TextField } from '../../ui/Field';
import { Select } from '../../ui/Overlays';
import { useSessionTypeForms } from '../danh-muc/useCatalogData';
import { examChargeNote, type ExamError, type ExamInput } from './examFields';

export function ExamBlock({
  kind,
  enabled,
  onEnabled,
  value,
  onChange,
  errors,
}: {
  kind: 'CUNG_CO' | 'BO_TRO' | 'HOC_BU';
  enabled: boolean;
  onEnabled: (on: boolean) => void;
  value: ExamInput;
  onChange: (next: ExamInput) => void;
  errors: ExamError;
}) {
  const set = (patch: Partial<ExamInput>) => onChange({ ...value, ...patch });
  // Loại kiểm tra chọn được: các loại buổi đang dùng form điểm (tra ở Danh mục · Loại buổi, không viết cứng).
  const types = useSessionTypeForms();
  const typeOptions = (types.data ?? [])
    .filter((t) => t.form_code === 'DIEM' && t.is_active)
    .map((t) => ({ value: t.type_code, label: t.name }));
  return (
    <fieldset className="flex flex-col gap-2 rounded-lg border border-border p-3">
      <legend className="px-1 text-body font-semibold">Loại buổi</legend>
      <Checkbox
        label="Buổi kiểm tra"
        checked={enabled}
        onChange={(e) => onEnabled(e.target.checked)}
      />
      <p className="text-caption text-fg-muted">{examChargeNote(kind)}</p>
      {enabled && (
        <div className="flex flex-col gap-3">
          {typeOptions.length > 1 && (
            <Field label="Loại kiểm tra">
              {(field) => (
                <Select
                  id={field.id}
                  label="Loại kiểm tra"
                  value={value.typeCode}
                  onChange={(v) => set({ typeCode: v })}
                  options={typeOptions}
                />
              )}
            </Field>
          )}
          <TextAreaField
            label="Phạm vi kiến thức"
            placeholder="Nội dung được kiểm tra"
            value={value.scope}
            onChange={(e) => set({ scope: e.target.value })}
          />
          <TextField
            label="Điểm tối đa"
            inputMode="decimal"
            placeholder="Mặc định 10"
            value={value.maxScore}
            error={errors.maxScore ?? null}
            onChange={(e) => set({ maxScore: e.target.value })}
          />
          <Field label="Cách nhập điểm">
            {(field) => (
              <Select
                id={field.id}
                label="Cách nhập điểm"
                value={value.mode}
                onChange={(v) => set({ mode: v === 'NHOM' ? 'NHOM' : 'TONG' })}
                options={[
                  { value: 'TONG', label: 'Điểm tổng' },
                  { value: 'NHOM', label: '3 nhóm: Ghi nhớ, Hiểu, Vận dụng' },
                ]}
              />
            )}
          </Field>
          {value.mode === 'NHOM' && (
            <div className="grid grid-cols-3 gap-2">
              <TextField
                label="Điểm tối đa · Ghi nhớ"
                inputMode="decimal"
                value={value.memory}
                onChange={(e) => set({ memory: e.target.value })}
              />
              <TextField
                label="Điểm tối đa · Hiểu"
                inputMode="decimal"
                value={value.understand}
                onChange={(e) => set({ understand: e.target.value })}
              />
              <TextField
                label="Điểm tối đa · Vận dụng"
                inputMode="decimal"
                value={value.apply}
                onChange={(e) => set({ apply: e.target.value })}
              />
            </div>
          )}
          {errors.groups && (
            <p role="alert" className="text-body text-danger">
              {errors.groups} Sửa lại các nhóm trước khi lưu nháp hoặc gửi duyệt.
            </p>
          )}
        </div>
      )}
    </fieldset>
  );
}
