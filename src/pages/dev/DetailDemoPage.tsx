// Trang mẫu K3 Chi tiết (PR 4b), dữ liệu giả: xem, Sửa, Tạo trống, bốn kiểu đổi giai đoạn, nút liên kết,
// cảnh báo trùng khi Lưu, ghi chú & hoạt động. Có `?ban-ghi=<id tài khoản>` thì cột phải dùng dữ liệu thật
// (ghi chú, lịch sử, nhắc tên của tài khoản đó) để kiểm đường dữ liệu. Chỉ có ở bản không phải chạy thật.
import { useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { RecordChatter } from '../../features/chatter/RecordChatter';
import { foldText } from '../../lib/format';
import { DetailField, DetailSection, RecordDetail, type DetailMode } from '../../record/Detail';
import { Button } from '../../ui/Button';
import { Chatter, type ChatterEntry } from '../../ui/Chatter';
import { BlockingDialog, DuplicateDialog, FormDialog } from '../../ui/Dialogs';
import { Combobox } from '../../ui/Inputs';
import { Checkbox, INPUT_CLASS, TextAreaField } from '../../ui/Field';
import { Select, Tabs } from '../../ui/Overlays';
import type { StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';

const STEPS: StageStep[] = [
  { code: 'L1', label: 'Khách hàng mới' },
  { code: 'L2', label: 'Chưa liên hệ được' },
  { code: 'L3', label: 'Không có nhu cầu' },
  { code: 'L4', label: 'Khách hàng tiềm năng' },
  { code: 'L5', label: 'Đồng ý tham gia test' },
  {
    code: 'L6',
    label: 'Đã tham gia test',
    lockedReason: 'Hệ thống tự chuyển khi phiếu Test Hoàn thành.',
  },
  { code: 'L7', label: 'Tư vấn' },
  { code: 'L8', label: 'Đăng ký học' },
];
// Giai đoạn con theo từng giai đoạn (chữ mẫu; danh sách thật lấy từ danh mục "Giai đoạn cơ hội").
const SUB_STAGES: { [stage: string]: { value: string; label: string }[] } = {
  L4: [
    { value: 'L4A', label: 'L4A Cần gửi thêm thông tin' },
    { value: 'L4B', label: 'L4B Cần tư vấn thêm' },
    { value: 'L4C', label: 'L4C Cần tham khảo ý kiến' },
  ],
  L5: [
    { value: 'L5A', label: 'L5A Chờ xếp lịch test' },
    { value: 'L5B', label: 'L5B Đã xếp lịch test' },
  ],
  L8: [
    { value: 'L8A', label: 'L8A PH đặt cọc' },
    { value: 'L8B', label: 'L8B PH thanh toán chia để trả' },
    { value: 'L8C', label: 'L8C PH hoàn thành 100% học phí' },
  ],
};
// Từ L5 trở lên bắt buộc có tên và năm sinh học sinh (R-CRM-03).
const NEEDS_STUDENT = ['L5', 'L6', 'L7', 'L8'];
// Giai đoạn bắt buộc chọn nhóm con và xác nhận khi chuyển.
const SUB_REQUIRED = ['L8'];
const PEOPLE = ['Trần Thu Hà', 'Nguyễn Hoàng Long', 'Phạm Ngọc Ánh', 'Lê Văn Nam'];
const DUPLICATE_PHONE = '0912345678';
const DEMO_TOTAL = 250; // allow-number: số bản ghi giả của trang mẫu

type Record = {
  parentName: string;
  phone: string;
  studentName: string;
  birthYear: string;
  school: string;
  need: string;
  owner: string[];
};
const FULL: Record = {
  parentName: 'Chị Lê Thu Hằng',
  phone: '0912000121',
  studentName: 'Lê Gia Huy',
  birthYear: '2012',
  school: 'THCS Giảng Võ',
  need: 'Ôn thi vào lớp 10, học buổi tối',
  owner: ['Trần Thu Hà'],
};
const BLANK: Record = {
  parentName: '',
  phone: '',
  studentName: '',
  birthYear: '',
  school: '',
  need: '',
  owner: [],
};

export function DetailDemoPage() {
  const toast = useToast();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const realRecord = params.get('ban-ghi');
  const code = params.get('ma') ?? 'CO000121';

  const [mode, setMode] = useState<DetailMode>('view');
  const [saved, setSaved] = useState<Record>(FULL);
  const [draft, setDraft] = useState<Record>(FULL);
  const [errors, setErrors] = useState<Partial<Record>>({});
  const [stage, setStage] = useState('L4');
  const [subStage, setSubStage] = useState('L4B');
  const [tab, setTab] = useState('source');
  const [askStage, setAskStage] = useState<StageStep | null>(null);
  const [askSub, setAskSub] = useState('L4A');
  const [askNote, setAskNote] = useState('');
  const [paid, setPaid] = useState(false);
  const [missing, setMissing] = useState<{
    step: StageStep;
    fields: { key: keyof Record; label: string }[];
  } | null>(null);
  const [duplicate, setDuplicate] = useState(false);
  const fieldRefs = useRef<Partial<globalThis.Record<keyof Record, HTMLInputElement | null>>>({});
  const [entries, setEntries] = useState<ChatterEntry[]>([
    {
      kind: 'note',
      id: 'n1',
      at: new Date().toISOString(),
      author: 'Trần Thu Hà',
      body: 'Chị Hằng muốn con học tối T3, T5; hỏi có học thử được không.',
      mentions: [],
    },
    {
      kind: 'change',
      id: 'c1',
      at: new Date(Date.now() - 3_600_000).toISOString(), // allow-number: một giờ trước (dữ liệu mẫu)
      author: 'Trần Thu Hà',
      changes: [
        { label: 'Giai đoạn', from: 'L2 Chưa liên hệ được', to: 'L4 Khách hàng tiềm năng' },
      ],
    },
  ]);

  const view = mode === 'view' ? saved : draft;
  const set = (key: keyof Record, value: string | string[]) => {
    setDraft((d) => ({ ...d, [key]: value }));
    setErrors((e) => ({ ...e, [key]: undefined }));
  };
  const dirty =
    mode !== 'view' && JSON.stringify(draft) !== JSON.stringify(mode === 'create' ? BLANK : saved);

  const required = (rec: Record) => {
    const out: Partial<Record> = {};
    if (rec.parentName.trim() === '') out.parentName = 'Nhập họ tên phụ huynh.';
    if (!/^\d{10}$/.test(rec.phone)) out.phone = 'Số điện thoại cần đủ 10 số.';
    return out;
  };

  const finishSave = () => {
    setSaved(draft);
    setMode('view');
    toast({ title: 'Đã lưu' });
  };
  const save = () => {
    const found = required(draft);
    setErrors(found);
    if (Object.keys(found).length > 0) return;
    // Cảnh báo trùng (K07c, TS-14): hiện khi bấm Lưu, không chặn.
    if (mode === 'create' && draft.phone === DUPLICATE_PHONE) setDuplicate(true);
    else finishSave();
  };

  // Bốn kiểu đổi giai đoạn: hệ thống tự đổi (ổ khoá), cần đủ điều kiện (hộp chặn), hỏi thêm (hộp sub-stage), đổi ngay.
  const changeStage = (step: StageStep) => {
    if (NEEDS_STUDENT.includes(step.code)) {
      const lack = (['studentName', 'birthYear'] as const)
        .filter((k) => saved[k].trim() === '')
        .map((k) => ({
          key: k,
          label: k === 'studentName' ? 'Thiếu tên học sinh' : 'Thiếu năm sinh học sinh',
        }));
      if (lack.length > 0) {
        setMissing({ step, fields: lack });
        return;
      }
    }
    if (step.code === 'L5' || step.code === 'L8') {
      setAskSub(SUB_REQUIRED.includes(step.code) ? '' : 'L5A');
      setAskNote('');
      setPaid(false);
      setAskStage(step);
      return;
    }
    if (step.code === 'L4') {
      setAskSub('L4A');
      setAskNote('');
      setAskStage(step);
      return;
    }
    const before = stage;
    const beforeSub = subStage;
    setStage(step.code);
    setSubStage('');
    toast({
      title: `Đã chuyển sang ${step.code}`,
      action: {
        label: 'Hoàn tác',
        onClick: () => {
          setStage(before);
          setSubStage(beforeSub);
        },
      },
    });
  };

  const send = (body: string, mentionIds: string[]) => {
    void mentionIds;
    setEntries((e) => [
      {
        kind: 'note',
        id: String(Date.now()),
        at: new Date().toISOString(),
        author: 'Bạn',
        body,
        mentions: [],
      },
      ...e,
    ]);
    return Promise.resolve();
  };

  const input = (
    key: keyof Record,
    label: string,
    extra?: { required?: boolean; hint?: string },
  ) => (
    <DetailField
      key={key}
      label={label}
      required={extra?.required}
      hint={extra?.hint}
      mode={mode}
      value={view[key]}
      error={typeof errors[key] === 'string' ? errors[key] : null}
      editor={
        <input
          ref={(node) => {
            fieldRefs.current[key] = node;
          }}
          aria-label={label}
          value={draft[key]}
          onChange={(e) => set(key, e.target.value)}
          aria-invalid={errors[key] ? true : undefined}
          className={INPUT_CLASS}
        />
      }
    />
  );

  const title =
    mode === 'create'
      ? ''
      : [view.parentName, view.studentName, 'Toán lớp 9'].filter(Boolean).join(' · ');

  return (
    <>
      <RecordDetail
        kind="Cơ hội"
        title={title}
        mode={mode}
        dirty={dirty}
        onEdit={() => {
          setDraft(saved);
          setErrors({});
          setMode('edit');
        }}
        onSave={save}
        onCancel={() => {
          setDraft(saved);
          setErrors({});
          setMode('view');
        }}
        headerActions={
          <Button
            icon="plus"
            onClick={() => {
              setDraft(BLANK);
              setErrors({});
              setMode('create');
            }}
          >
            Tạo
          </Button>
        }
        attachments={{ count: 2 }}
        menu={{
          label: 'Hành động',
          items: [
            {
              kind: 'action',
              label: 'Đưa về Nháp',
              onSelect: () => toast({ tone: 'warning', title: 'Cơ hội không có bước Nháp' }),
            },
          ],
        }}
        pager={{ index: 3, total: DEMO_TOTAL, onPrev: () => undefined, onNext: () => undefined }}
        onRefresh={() => toast({ title: 'Đã làm mới' })}
        stage={{
          steps: STEPS,
          current: stage,
          onSelect: changeStage,
          onLockedClick: (_step, reason) => toast({ tone: 'warning', title: reason }),
        }}
        businessActions={
          <>
            <Button>Tạo báo giá</Button>
            {/* Anh chốt 16/10: phải lên L8 trước, sau đó mới tạo được đơn hàng. */}
            <Button disabled={stage !== 'L8'}>Tạo đơn hàng</Button>
          </>
        }
        subStage={
          SUB_STAGES[stage] && (
            <>
              <span className="text-caption font-semibold text-fg-label">Sub-stage</span>
              <Select
                label="Sub-stage"
                value={subStage}
                onChange={setSubStage}
                options={SUB_STAGES[stage]}
                className="w-60"
              />
            </>
          )
        }
        smart={[
          { key: 'lich-hen', label: 'Lịch hẹn', icon: 'calendar', count: 2 },
          { key: 'kiem-tra', label: 'Kiểm tra', icon: 'tasks', count: 1 },
          { key: 'bao-gia', label: 'Báo giá', icon: 'sales', count: 0 },
          { key: 'don-hang', label: 'Đơn hàng', icon: 'file', count: 0 },
          { key: 'phu-huynh', label: 'Phụ huynh', icon: 'user', count: 1 },
          { key: 'lead-goc', label: 'Lead gốc', icon: 'recruit', count: 1 },
        ].map((item) => ({
          ...item,
          icon: item.icon as 'calendar',
          onOpen: (target) => {
            if (target === 'record')
              toast({ title: `Mở thẳng bản ghi ${item.label} (đúng 1 bản ghi)` });
            else void navigate(`/dev/danh-sach?cha=${code}&loai=${item.key}`);
          },
        }))}
        aside={
          realRecord ? (
            <RecordChatter
              entityType="USER_ACCOUNT"
              entityId={realRecord}
              createdText="Tạo tài khoản."
              format={{
                labels: {
                  display_name: 'Họ tên',
                  is_locked: 'Khoá tài khoản',
                  lock_reason: 'Lý do khoá',
                },
              }}
            />
          ) : (
            <Chatter
              entries={entries}
              status="ready"
              disabled={mode === 'create'}
              onSend={send}
              searchPeople={(q) =>
                Promise.resolve(
                  PEOPLE.filter((n) => foldText(n).includes(foldText(q))).map((n) => ({
                    id: n,
                    name: n,
                    hint: 'Tuyển sinh · CS1',
                  })),
                )
              }
              actions={
                <>
                  <Button icon="calendar">Lên lịch hẹn</Button>
                  <Button icon="tasks">Tạo lịch Test</Button>
                </>
              }
            />
          )
        }
      >
        <div className="grid grid-cols-1 gap-x-10 gap-y-6 lg:grid-cols-2">
          <DetailSection title="Thông tin phụ huynh">
            {input('parentName', 'Họ tên', { required: true })}
            {input('phone', 'Số điện thoại', { required: true })}
          </DetailSection>
          <DetailSection title="Thông tin học sinh">
            {input('studentName', 'Tên học sinh', { hint: 'bắt buộc từ L5' })}
            {input('birthYear', 'Năm sinh', { hint: 'bắt buộc từ L5' })}
            {input('school', 'Trường học')}
          </DetailSection>
        </div>
        <div className="mt-6">
          <Tabs
            label="Nội dung bản ghi"
            value={tab}
            onChange={setTab}
            items={[
              {
                value: 'source',
                label: 'Nguồn và phụ trách',
                content: (
                  <dl className="grid grid-cols-1 gap-x-10 lg:grid-cols-2">
                    <DetailField label="Cơ sở" mode="view" value="CS1 Nguyễn Chí Thanh" />
                    <DetailField
                      label="Nhân sự phụ trách"
                      mode={mode}
                      value={view.owner.join(', ')}
                      editor={
                        <Combobox
                          compact
                          label="Nhân sự phụ trách"
                          options={PEOPLE.map((n) => ({ value: n, label: n }))}
                          value={draft.owner}
                          onChange={(v) => set('owner', v)}
                          placeholder="Chọn nhân sự"
                        />
                      }
                    />
                  </dl>
                ),
              },
              {
                value: 'time',
                label: 'Mốc thời gian',
                content: <p className="text-fg-muted">Mốc thời gian của bản ghi.</p>,
              },
            ]}
          />
        </div>
        <div className="mt-6 max-w-xl">
          {mode === 'view' ? null : (
            <TextAreaField
              label="Nhu cầu"
              value={draft.need}
              onChange={(e) => set('need', e.target.value)}
            />
          )}
        </div>
      </RecordDetail>

      {/* Hỏi thêm: hộp chọn sub-stage + ghi chú rồi mới đổi. */}
      <FormDialog
        open={askStage !== null}
        onOpenChange={(o) => !o && setAskStage(null)}
        title={`Chuyển sang ${askStage?.code ?? ''}`}
        subtitle={askStage?.label}
        confirmLabel="Chuyển"
        canSubmit={!SUB_REQUIRED.includes(askStage?.code ?? '') || (askSub !== '' && paid)}
        onSubmit={() => {
          if (!askStage) return;
          setStage(askStage.code);
          setSubStage(askSub);
          setEntries((e) => [
            {
              kind: 'change',
              id: String(Date.now()),
              at: new Date().toISOString(),
              author: 'Bạn',
              changes: [
                { label: 'Giai đoạn', from: stage, to: `${askStage.code} ${askStage.label}` },
              ],
            },
            ...e,
          ]);
          setAskStage(null);
          toast({ title: `Đã chuyển sang ${askStage.code}` });
        }}
      >
        <div className="flex flex-col gap-1">
          <span className="text-caption font-semibold text-fg-label">
            {SUB_REQUIRED.includes(askStage?.code ?? '') ? 'Sub-stage *' : 'Sub-stage (tuỳ chọn)'}
          </span>
          <Select
            label="Sub-stage"
            value={askSub}
            onChange={setAskSub}
            options={SUB_STAGES[askStage?.code ?? ''] ?? []}
            className="w-full"
          />
        </div>
        {SUB_REQUIRED.includes(askStage?.code ?? '') && (
          <Checkbox
            label="Phụ huynh đã thanh toán?"
            checked={paid}
            onChange={(e) => setPaid(e.target.checked)}
          />
        )}
        <TextAreaField
          label="Ghi chú"
          placeholder="Không bắt buộc"
          value={askNote}
          onChange={(e) => setAskNote(e.target.value)}
        />
      </FormDialog>

      {/* Cần đủ điều kiện: hộp chặn liệt kê chỗ thiếu, mỗi dòng có nút đi tới ô cần điền. */}
      <BlockingDialog
        open={missing !== null}
        onOpenChange={(o) => !o && setMissing(null)}
        title={`Chưa chuyển sang ${missing?.step.code ?? ''} được`}
        message="Cơ hội cần đủ thông tin học sinh trước khi đặt lịch kiểm tra."
        reasons={(missing?.fields ?? []).map((f) => ({
          text: f.label,
          goLabel: 'Đến ô này',
          onGo: () => {
            setDraft(saved);
            setMode('edit');
            requestAnimationFrame(() => fieldRefs.current[f.key]?.focus());
          },
        }))}
      />

      {/* Cảnh báo trùng SĐT khi Lưu (K07c / TS-14). */}
      <DuplicateDialog
        existingCode="LD000227"
        existingName="Lê Thị Hằng"
        open={duplicate}
        onOpenChange={setDuplicate}
        onAttach={() => {
          setMode('view');
          toast({ title: 'Đã gắn vào hồ sơ LD000227' });
        }}
        onCreateNew={finishSave}
      />
    </>
  );
}
