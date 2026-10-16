// Trang mẫu nội bộ: chỉ có ở bản thử nghiệm và xem trước (không có ở bản chạy thật). Hiện từng thành phần
// của hệ thiết kế với dữ liệu giả để anh kiểm trên staging và để đối chiếu ảnh với gói thiết kế.
// Mỗi PR thêm các khuôn mới vào đây. Không đọc, không ghi cơ sở dữ liệu.
import { useState, type ReactNode } from 'react';
import { Button, IconButton } from '../../ui/Button';
import { Code, Pagination, Skeleton, Table, Tag, type Column } from '../../ui/Data';
import { Alert, Avatar, CountBadge, StateView } from '../../ui/Feedback';
import { Checkbox, PasswordInput, TextAreaField, TextField } from '../../ui/Field';
import {
  Combobox,
  DateInput,
  DateRange,
  FileUpload,
  MoneyInput,
  type DateRangeValue,
} from '../../ui/Inputs';
import { Dialog, Drawer, DropdownMenu, Popover, Select, Tabs } from '../../ui/Overlays';
import { StageBar, type StageStep } from '../../ui/Stage';
import { useToast } from '../../ui/toastContext';

const STEPS: StageStep[] = [
  { code: 'L1', label: 'Khách hàng mới' },
  { code: 'L2', label: 'Chưa liên hệ được' },
  { code: 'L3', label: 'Không có nhu cầu' },
  { code: 'L4', label: 'Khách hàng tiềm năng' },
  { code: 'L5', label: 'Đồng ý tham gia test' },
  { code: 'L6', label: 'Đã tham gia test' },
];

const DEMO_DEPOSIT = 500_000; // allow-number: số tiền giả để minh hoạ ô nhập tiền
const DEMO_PRICE = 220_000; // allow-number: số tiền giả cho ô "hệ thống tính"
const CLASSES = [
  { value: '8a1', label: '8A1 Đại', hint: 'CS1 · 13/15 em', keywords: 'LOP-CS1-0001' },
  { value: '9a2', label: '9A2 Đại', hint: 'CS1 · 12/15 em', keywords: 'LOP-CS1-0002' },
  { value: '7a1', label: '7A1 Hình', hint: 'CS5 · 15/15 em', disabledReason: 'Hết chỗ' },
  { value: '6b1', label: '6B1 Số học', hint: 'CS5 · 9/15 em', keywords: 'LOP-CS5-0004' },
];

const DEMO_PAGE_SIZE = 25; // allow-number: số giả của trang mẫu, không phải số nghiệp vụ
const DEMO_TOTAL = 187; // allow-number: như trên

type Row = { id: string; code: string; name: string; stage: string; owner: string; due: string };
const ROWS: Row[] = [
  {
    id: '1',
    code: 'CO000133',
    name: 'Toán lớp 8 · Đặng Minh Châu',
    stage: 'L1',
    owner: 'Trần Thu Hà',
    due: 'Hôm nay 16:00',
  },
  {
    id: '2',
    code: 'CO000121',
    name: 'Toán lớp 9 · Lê Gia Huy',
    stage: 'L4',
    owner: 'Trần Thu Hà',
    due: 'Quá hạn 10/10',
  },
  {
    id: '3',
    code: 'CO000105',
    name: 'Toán lớp 9 · Đinh Quốc Bảo',
    stage: 'L6',
    owner: 'Nguyễn Hoàng Long',
    due: '14/10 17:00',
  },
];
const COLUMNS: Column<Row>[] = [
  { key: 'code', header: 'Mã', sortable: true, cell: (r) => <Code>{r.code}</Code> },
  {
    key: 'name',
    header: 'Cơ hội',
    primary: true,
    cell: (r) => <span className="font-medium text-link">{r.name}</span>,
  },
  { key: 'stage', header: 'Stage', cell: (r) => <Tag>{r.stage}</Tag> },
  { key: 'owner', header: 'Sale phụ trách', cell: (r) => r.owner },
  {
    key: 'due',
    header: 'Lịch hẹn kế tiếp',
    cell: (r) => (
      <Tag
        tone={r.due.startsWith('Quá') ? 'danger' : r.due.startsWith('Hôm') ? 'warning' : 'success'}
        dot
      >
        {r.due}
      </Tag>
    ),
  },
];

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-3 rounded-box border border-border bg-surface p-card">
      <h2 className="font-display text-h3">{title}</h2>
      {children}
    </section>
  );
}

export function PatternPage() {
  const toast = useToast();
  const [stage, setStage] = useState('L4');
  const [dialog, setDialog] = useState(false);
  const [drawer, setDrawer] = useState(false);
  const [tab, setTab] = useState('a');
  const [select, setSelect] = useState('all');
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [page, setPage] = useState(1);
  const [one, setOne] = useState<string[]>([]);
  const [many, setMany] = useState<string[]>(['8a1']);
  const [day, setDay] = useState<Date | null>(null);
  const [range, setRange] = useState<DateRangeValue>(null);
  const [money, setMoney] = useState<number | null>(DEMO_DEPOSIT);

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="font-display text-h2">Trang mẫu thành phần</h1>
        <p className="text-fg-muted">
          Chỉ có ở bản thử nghiệm. Dữ liệu giả, không lưu. Dùng để kiểm hệ thiết kế (PR 2).
        </p>
      </div>

      <Section title="Nút">
        <div className="flex flex-wrap items-center gap-2">
          <Button variant="primary" icon="plus">
            Tạo
          </Button>
          <Button>Nhập</Button>
          <Button icon="download">Xuất</Button>
          <Button variant="danger" icon="trash">
            Huỷ
          </Button>
          <Button variant="text">Xoá tất cả</Button>
          <Button size="sm">Nhỏ</Button>
          <Button size="lg">Lớn</Button>
          <Button disabled>Đã tắt</Button>
          <Button loading>Đang lưu</Button>
          <IconButton icon="edit" label="Sửa" bordered />
        </div>
      </Section>

      <Section title="Ô nhập">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <TextField label="Họ tên phụ huynh" required placeholder="Nguyễn Văn A" />
          <TextField label="Số điện thoại" error="Số điện thoại chưa đúng." defaultValue="09123" />
          <TextField
            label="Mã (chỉ đọc)"
            readOnly
            defaultValue="CO000121"
            help="Hệ thống cấp, không sửa."
          />
          <PasswordInput label="Mật khẩu" defaultValue="matkhau123" />
          <Select
            label="Cơ sở"
            value={select}
            onChange={setSelect}
            options={[
              { value: 'all', label: 'Tất cả cơ sở' },
              { value: 'cs1', label: 'CS1 Nguyễn Chí Thanh' },
              { value: 'cs5', label: 'CS5 Mỹ Đình' },
            ]}
            icon="branch"
          />
          <Checkbox label="Dùng cho mọi người" />
          <TextAreaField label="Ghi chú" placeholder="Ghi chú…" />
        </div>
      </Section>

      <Section title="Ô chọn có tìm, ngày, tiền, đính kèm">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Combobox
            label="Lớp"
            options={CLASSES}
            value={one}
            onChange={setOne}
            placeholder="Chọn lớp"
            required
            help="Gõ tên hoặc mã lớp, không cần dấu."
          />
          <Combobox
            label="Lớp (chọn nhiều)"
            options={CLASSES}
            value={many}
            onChange={setMany}
            multiple
          />
          <DateInput
            label="Ngày vào lớp"
            value={day}
            onChange={setDay}
            help="Gõ dd/mm/yyyy hoặc bấm biểu tượng lịch."
          />
          <div className="flex flex-col gap-1">
            <span className="text-caption font-semibold text-fg-label">Khoảng ngày</span>
            <DateRange label="Khoảng ngày" value={range} onChange={setRange} />
          </div>
          <MoneyInput
            label="Tiền cọc"
            value={money}
            onChange={setMoney}
            required
            error={money === null ? 'Hãy nhập số tiền cọc.' : null}
          />
          <MoneyInput label="Đơn giá một giờ" value={DEMO_PRICE} readOnly />
          <FileUpload label="Tải chứng từ lên" available={false} />
        </div>
      </Section>

      <Section title="Thẻ trạng thái, mã, huy hiệu">
        <div className="flex flex-wrap items-center gap-2">
          <Tag>Nháp</Tag>
          <Tag tone="success" icon="checkMark">
            Đang dùng
          </Tag>
          <Tag tone="warning" dot>
            Hôm nay 16:00
          </Tag>
          <Tag tone="danger" icon="forbidden">
            Khoá
          </Tag>
          <Tag tone="info">Đang test</Tag>
          <Tag tone="brand">L4 Khách hàng tiềm năng</Tag>
          <Code>DH-CS1-2610-0001</Code>
          <Avatar name="Trần Thu Hà" large />
          <CountBadge count={3} label="thông báo" />
        </div>
      </Section>

      <Section title="Thanh Stage (bấm Stage để đổi giai đoạn, chỉ đi tới)">
        <StageBar
          steps={STEPS}
          current={stage}
          onSelect={(step) => {
            setStage(step.code);
            toast({ title: `Đã chuyển sang ${step.code}` });
          }}
        />
      </Section>

      <Section title="Thông báo tại chỗ, trạng thái rỗng, đang tải">
        <Alert tone="info">Lead này đã có người phụ trách.</Alert>
        <Alert tone="warning">2 buổi trùng lịch. Chỉ cảnh báo, vẫn xác nhận được.</Alert>
        <Alert tone="danger">Không lưu được. Kiểm tra kết nối rồi thử lại.</Alert>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <div className="rounded-box border border-border">
            <StateView kind="empty" title="Chưa có lead nào" headingLevel={2}>
              Khi có dữ liệu, danh sách sẽ hiện ở đây.
            </StateView>
          </div>
          <div
            className="flex flex-col gap-3 rounded-box border border-border p-4"
            aria-busy="true"
          >
            <Skeleton className="h-6 w-1/2" />
            <Skeleton className="w-full" />
            <Skeleton className="w-3/4" />
          </div>
        </div>
      </Section>

      <Section title="Bảng và phân trang (điện thoại: thành thẻ)">
        <Table
          caption="Danh sách cơ hội mẫu"
          columns={COLUMNS}
          rows={ROWS}
          rowKey={(r) => r.id}
          rowLabel={(r) => r.name}
          empty={<p>Không có dòng nào</p>}
          selected={selected}
          onSelectedChange={setSelected}
        />
        <Pagination
          page={page}
          pageSize={DEMO_PAGE_SIZE}
          total={DEMO_TOTAL}
          onPageChange={setPage}
        />
      </Section>

      <Section title="Tab, menu, khung nổi, hộp thoại, ngăn kéo, thông báo nổi">
        <Tabs
          label="Tab mẫu"
          value={tab}
          onChange={setTab}
          items={[
            { value: 'a', label: 'Thông tin', content: <p>Nội dung tab Thông tin.</p> },
            { value: 'b', label: 'Phiếu thu', count: 2, content: <p>Nội dung tab Phiếu thu.</p> },
          ]}
        />
        <div className="flex flex-wrap items-center gap-2">
          <DropdownMenu
            trigger={<Button icon="more">Hành động</Button>}
            items={[
              { kind: 'action', label: 'Assign', onSelect: () => toast({ title: 'Đã giao' }) },
              { kind: 'action', label: 'Đưa về Nháp', onSelect: () => undefined },
            ]}
          />
          <Popover trigger={<Button icon="filter">Filters</Button>}>
            <p className="w-64">Khung nổi neo dưới nút (nội dung bộ lọc làm ở PR danh sách).</p>
          </Popover>
          <Button onClick={() => setDialog(true)}>Mở hộp thoại</Button>
          <Button onClick={() => setDrawer(true)}>Mở ngăn kéo</Button>
          <Button onClick={() => toast({ title: 'Đã lưu' })}>Toast thành công</Button>
          <Button
            onClick={() =>
              toast({ tone: 'danger', title: 'Không lưu được. Kiểm tra kết nối rồi thử lại.' })
            }
          >
            Toast lỗi
          </Button>
          <Button
            onClick={() =>
              toast({
                title: 'Đã giao lead',
                action: { label: 'Hoàn tác', onClick: () => undefined },
              })
            }
          >
            Toast có Hoàn tác
          </Button>
        </div>
      </Section>

      <Dialog
        open={dialog}
        onOpenChange={setDialog}
        title="Từ chối đơn hàng"
        description="Đơn sẽ chuyển sang Từ chối và quay về người tạo."
        footer={
          <>
            <Button onClick={() => setDialog(false)}>Giữ lại</Button>
            <Button variant="danger" icon="forbidden" onClick={() => setDialog(false)}>
              Xác nhận từ chối
            </Button>
          </>
        }
      >
        <TextAreaField label="Lý do" required />
      </Dialog>
      <Drawer
        open={drawer}
        onOpenChange={setDrawer}
        side="right"
        title="Tạo nhanh lead"
        footer={
          <>
            <Button onClick={() => setDrawer(false)}>Huỷ</Button>
            <Button variant="primary" onClick={() => setDrawer(false)}>
              Lưu
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4 p-4">
          <TextField label="Họ tên phụ huynh" required />
          <TextField label="Số điện thoại" required />
        </div>
      </Drawer>
    </div>
  );
}
