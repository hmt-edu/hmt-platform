// Trang mẫu các hộp thoại của khuôn K4 (PR 4b), dữ liệu giả, không lưu. Chỉ có ở bản không phải chạy thật.
import { useState } from 'react';
import { Button } from '../../ui/Button';
import {
  BlockingDialog,
  ChoiceDialog,
  ConfirmDialog,
  DuplicateDialog,
  FormDialog,
  ImpactDialog,
  ReasonDialog,
  StepDialog,
  type ChoiceOption,
  type ImpactRow,
} from '../../ui/Dialogs';
import { Alert } from '../../ui/Feedback';
import { Checkbox, TextAreaField } from '../../ui/Field';
import { DateInput } from '../../ui/Inputs';
import { Select } from '../../ui/Overlays';
import { useToast } from '../../ui/toastContext';

const REJECT_REASONS = [
  { value: 'thieu', label: 'Thiếu thông tin' },
  { value: 'tien', label: 'Sai số tiền' },
  { value: 'chung-tu', label: 'Sai chứng từ' },
  { value: 'khac', label: 'Khác', needsNote: true },
];
const BRANCHES = [
  { value: 'cs1', label: 'CS1 Nguyễn Chí Thanh' },
  { value: 'cs5', label: 'CS5 Mỹ Đình' },
];
const STAFF: Record<string, { value: string; label: string }[]> = {
  cs1: [
    { value: 'ha', label: 'Trần Thu Hà' },
    { value: 'long', label: 'Nguyễn Hoàng Long' },
  ],
  cs5: [{ value: 'nam', label: 'Lê Văn Nam' }],
};
const IMPACT: ImpactRow[] = [
  'T3 20/10/2026',
  'T5 22/10/2026',
  'T3 27/10/2026',
  'T5 29/10/2026',
].map((day, i) => ({
  id: day,
  cells: [day, '18:00–19:30', 'P.201', 'Trần Văn Nam → Lê Minh Quân'],
  warning: i === 3 ? 'Lê Minh Quân đang dạy 8B2 cùng giờ (P.103)' : undefined,
}));
const CLASSES: ChoiceOption[] = [
  { id: '9A1', cells: ['9A1', 'Trần Văn Nam', 'T3, T5 18:00–19:30', '24/30 · CS1'] },
  { id: '9A2', cells: ['9A2', 'Nguyễn Thị Lan', 'T4, T6 18:00–19:30', '18/30 · CS1'] },
  {
    id: '9B1',
    cells: ['9B1', 'Phạm Đức Hải', 'T2, T4 19:45–21:15', '30/30 · CS1'],
    reasons: ['Đầy chỗ (30/30)'],
  },
  {
    id: '9E1',
    cells: ['9E1', 'Hoàng Mai Anh', 'T7 08:00–11:00', '30/30 · CS2'],
    reasons: ['Sai môn (Tiếng Anh)', 'Sai cơ sở (CS2)', 'Đầy chỗ (30/30)'],
  },
];
const STEPS = ['Tải file', 'Ghép cột', 'Xem trước'];

export function DialogsDemoPage() {
  const toast = useToast();
  const [open, setOpen] = useState<string | null>(null);
  const close = () => setOpen(null);

  // Biến thể ③b: trường phụ thuộc (đổi cơ sở thì xoá nhân sự đã chọn).
  const [branch, setBranch] = useState('');
  const [staff, setStaff] = useState('');
  const [notify, setNotify] = useState(false);
  // Nhiều bước.
  const [step, setStep] = useState(0);
  const [file, setFile] = useState(false);
  // Chọn lớp.
  const [choice, setChoice] = useState<string | null>('9A1');
  const [day, setDay] = useState<Date | null>(null);

  const sundayWarn = day !== null && day.getDay() === 0;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="font-display text-h2">Trang mẫu hộp thoại</h1>
        <p className="text-fg-muted">
          Năm biến thể của khuôn K4 và các hộp thoại đi kèm. Dữ liệu giả, không lưu. Trên điện thoại
          hộp thành tấm trượt từ dưới lên.
        </p>
      </div>
      <div className="flex flex-wrap gap-2 rounded-box border border-border bg-surface p-card">
        <Button onClick={() => setOpen('confirm')}>① Xác nhận đơn giản</Button>
        <Button onClick={() => setOpen('reason')}>② Bắt buộc lý do</Button>
        <Button onClick={() => setOpen('form')}>③ Điền vài trường</Button>
        <Button onClick={() => setOpen('dependent')}>③b Có trường phụ thuộc</Button>
        <Button onClick={() => setOpen('block')}>④ Chặn</Button>
        <Button onClick={() => setOpen('warn')}>④ Cảnh báo, không chặn</Button>
        <Button onClick={() => setOpen('steps')}>⑤ Nhiều bước</Button>
        <Button onClick={() => setOpen('impact')}>Xem trước tác động</Button>
        <Button onClick={() => setOpen('choice')}>Chọn từ danh sách có kiểm tra</Button>
        <Button onClick={() => setOpen('dup')}>Cảnh báo trùng SĐT</Button>
      </div>

      <ConfirmDialog
        open={open === 'confirm'}
        onOpenChange={(o) => !o && close()}
        title="Duyệt đơn hàng DH-CS1-2610-0388?"
        summary={[
          { label: 'Phụ huynh', value: 'Lê Thị Hằng PH000061' },
          { label: 'Học sinh', value: 'Lê Gia Huy HS000123' },
          { label: 'Gói', value: 'LC · Lớp chung · Offline' },
          { label: 'Số giờ', value: '48 giờ' },
          { label: 'Chiết khấu', value: '12% (trần 20%)' },
          { label: 'Thành tiền', value: '9.504.000 đ' },
        ]}
        note="Duyệt xong đơn tự khoá, không sửa được."
        confirmLabel="Duyệt"
        confirmIcon="checkMark"
        onConfirm={() => {
          close();
          toast({ title: 'Đã duyệt đơn hàng' });
        }}
      />

      <ReasonDialog
        open={open === 'reason'}
        onOpenChange={(o) => !o && close()}
        title="Huỷ phiếu thu PT-CS1-2610-0871"
        description="Số tiền 4.752.000 đ (Chuyển khoản) sẽ không được ghi nhận."
        options={REJECT_REASONS}
        confirmLabel="Xác nhận huỷ"
        onConfirm={() => {
          close();
          toast({ title: 'Đã huỷ phiếu thu' });
        }}
      />

      <FormDialog
        open={open === 'form'}
        onOpenChange={(o) => !o && close()}
        title="Giao sale"
        subtitle="Áp dụng cho 3 lead đã chọn: LD000231, LD000232, LD000235."
        confirmLabel="Giao"
        canSubmit={staff !== ''}
        onSubmit={() => {
          close();
          toast({ title: 'Đã giao 3 lead' });
        }}
      >
        <div className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label after:text-on-danger-subtle after:content-['_*']">
            Sale phụ trách
          </span>
          <Select
            label="Sale phụ trách"
            value={staff}
            onChange={setStaff}
            placeholder="Chọn sale cùng cơ sở…"
            options={STAFF['cs1'] ?? []}
            className="w-full"
          />
        </div>
        <Checkbox
          label="Gửi thông báo cho người nhận"
          checked={notify}
          onChange={(e) => setNotify(e.target.checked)}
        />
        <TextAreaField label="Ghi chú bàn giao" placeholder="Không bắt buộc" />
      </FormDialog>

      <FormDialog
        open={open === 'dependent'}
        onOpenChange={(o) => !o && close()}
        title="Assign cơ hội"
        subtitle="Chị Lê Thu Hằng · Lê Gia Huy · Toán lớp 9"
        confirmLabel="Assign"
        canSubmit={branch !== '' && staff !== ''}
        onSubmit={() => {
          close();
          toast({ title: 'Đã assign cơ hội' });
        }}
      >
        <div className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label after:text-on-danger-subtle after:content-['_*']">
            Cơ sở
          </span>
          <Select
            label="Cơ sở"
            value={branch}
            onChange={(v) => {
              setBranch(v);
              setStaff('');
            }}
            placeholder="Chọn cơ sở…"
            options={BRANCHES}
            className="w-full"
          />
        </div>
        <div className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label after:text-on-danger-subtle after:content-['_*']">
            Nhân sự phụ trách
          </span>
          <Select
            label="Nhân sự phụ trách"
            value={staff}
            onChange={setStaff}
            placeholder={branch ? 'Chọn nhân sự…' : 'Chọn cơ sở trước'}
            options={STAFF[branch] ?? []}
            className="w-full"
          />
          <p className="text-caption text-fg-muted">Chỉ hiện nhân sự thuộc cơ sở đã chọn.</p>
        </div>
      </FormDialog>

      <BlockingDialog
        open={open === 'block'}
        onOpenChange={(o) => !o && close()}
        title="Chưa đóng được lớp 9A1"
        code="CS1-2627-TOAN-K09-CB-A-001"
        message="Còn 3 em còn giờ học. Chuyển hoặc kết thúc ghi danh của các em trước."
        items={[
          { left: 'Lê Gia Huy · GD000123', right: 'còn 12 giờ' },
          { left: 'Phạm Bảo An · GD000131', right: 'còn 6 giờ' },
          { left: 'Trần Minh Khôi · GD000140', right: 'còn 9,5 giờ' },
        ]}
      />
      <BlockingDialog
        open={open === 'warn'}
        onOpenChange={(o) => !o && close()}
        mode="warn"
        title="Trùng giờ với lớp khác"
        message="Giáo viên đang dạy lớp 8B2 cùng giờ. Chỉ cảnh báo, bạn vẫn tiếp tục được."
        onContinue={() => toast({ title: 'Đã tiếp tục' })}
      />

      <StepDialog
        open={open === 'steps'}
        onOpenChange={(o) => {
          if (!o) {
            close();
            setStep(0);
            setFile(false);
          }
        }}
        title="Nhập lead từ file"
        steps={STEPS}
        step={step}
        onStepChange={setStep}
        canNext={step > 0 || file}
        finishLabel="Nhập"
        onFinish={() => {
          close();
          setStep(0);
          setFile(false);
          toast({ title: 'Đã nhập 112 · Bỏ qua 9 trùng SĐT · 7 dòng lỗi' });
        }}
      >
        {step === 0 && (
          <div className="flex flex-col items-center gap-1 rounded-control border border-dashed border-border-strong bg-canvas p-4 text-center">
            <p>Kéo file Excel, CSV vào đây, hoặc</p>
            <Button variant="text" onClick={() => setFile(true)}>
              chọn file
            </Button>
            {file && <p className="text-caption text-fg-muted">leads-thang-10.xlsx · 128 dòng</p>}
          </div>
        )}
        {step === 1 && (
          <Alert tone="warning">
            2 cột chưa ghép: Ghi chú KH, Mã nội bộ. Dữ liệu của 2 cột này không được nhập.
          </Alert>
        )}
        {step === 2 && (
          <div className="grid grid-cols-3 gap-2 text-center">
            <p className="rounded-control bg-success-subtle p-2 text-on-success-subtle">
              <b className="block text-h2">112</b>dòng hợp lệ
            </p>
            <p className="rounded-control bg-warning-subtle p-2 text-on-warning-subtle">
              <b className="block text-h2">9</b>dòng trùng SĐT
            </p>
            <p className="rounded-control bg-danger-subtle p-2 text-on-danger-subtle">
              <b className="block text-h2">7</b>dòng lỗi
            </p>
          </div>
        )}
      </StepDialog>

      <ImpactDialog
        open={open === 'impact'}
        onOpenChange={(o) => !o && close()}
        title="Xem trước tác động trước khi xác nhận"
        headline={
          <>
            Đổi giáo viên lớp <b>9A1</b> từ <b>20/10/2026</b>
          </>
        }
        totalLabel="Tổng 4 buổi bị đổi"
        warning={
          <>
            <b>1 buổi trùng lịch</b> của giáo viên mới (dòng tô đỏ: 29/10). Chỉ cảnh báo, vẫn bấm
            Xác nhận được; buổi này giữ nguyên để CSKH xử lý sau.
          </>
        }
        columns={['Ngày', 'Giờ', 'Phòng', 'Giáo viên (cũ → mới)']}
        rows={IMPACT}
        onConfirm={() => {
          close();
          toast({ title: 'Đã đổi giáo viên' });
        }}
      />

      <ChoiceDialog
        open={open === 'choice'}
        onOpenChange={(o) => !o && close()}
        title="Chọn lớp và ngày vào lớp"
        info={
          <>
            Dòng đơn: <b>Toán lớp 9 · Offline</b> · Học sinh Lê Gia Huy (HS000123) · Cơ sở CS1. Chỉ
            lớp Đã duyệt, còn chỗ, đúng môn, khối, cơ sở và không trùng giờ lớp em đang học mới chọn
            được.
          </>
        }
        columns={['Mã lớp', 'Giáo viên', 'Lịch', 'Sĩ số · Cơ sở']}
        options={CLASSES}
        value={choice}
        onValueChange={setChoice}
        canSubmit={day !== null && !sundayWarn}
        onConfirm={() => {
          close();
          toast({ title: `Đã chọn lớp ${choice ?? ''}` });
        }}
      >
        <DateInput
          label="Ngày vào lớp"
          required
          value={day}
          onChange={setDay}
          error={
            sundayWarn
              ? `${day ? day.toLocaleDateString('vi-VN') : ''} là Chủ nhật, lớp 9A1 chỉ học Thứ Ba và Thứ Năm. Chọn một ngày đúng thứ.`
              : null
          }
        />
      </ChoiceDialog>

      <DuplicateDialog
        open={open === 'dup'}
        onOpenChange={(o) => !o && close()}
        existingCode="LD000227"
        existingName="Lê Thị Hằng"
        onAttach={() => toast({ title: 'Đã gắn vào hồ sơ LD000227' })}
        onCreateNew={() => toast({ title: 'Đã tạo hồ sơ mới' })}
      />
    </div>
  );
}
