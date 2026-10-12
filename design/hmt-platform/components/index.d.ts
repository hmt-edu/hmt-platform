import type * as React from 'react';

type Tone = 'success' | 'warning' | 'danger' | 'info';
type Children = { children?: React.ReactNode };

export interface ButtonProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'children'>, Children {
  /** primary: một nút/vùng · secondary: viền · tertiary: chữ · destructive: viền đỏ (solid chỉ trong ConfirmDialog) */
  variant?: 'primary' | 'secondary' | 'tertiary' | 'destructive';
  solid?: boolean;
  size?: 'sm';
  loading?: boolean;
  loadingLabel?: string;
  iconStart?: string;
  iconEnd?: string;
  /** Tên icon; khi có, `label` bắt buộc (aria-label + tooltip) */
  iconOnly?: string;
  label?: string;
  fullWidth?: boolean;
  /** tertiary dùng màu chữ thường thay vì màu link */
  neutral?: boolean;
}
export declare function Button(props: ButtonProps): React.ReactElement;

export interface FieldProps extends Children { label: React.ReactNode; helper?: React.ReactNode; error?: React.ReactNode; required?: boolean; optional?: boolean; counter?: React.ReactNode; className?: string; /** Ẩn nhãn (vẫn đọc được bằng trình đọc màn hình) — dùng trong bảng có tiêu đề cột */ hideLabel?: boolean }
export declare function Field(props: FieldProps): React.ReactElement;
export interface TextInputProps extends React.InputHTMLAttributes<HTMLInputElement> { leadingIcon?: string; trailing?: React.ReactNode; invalid?: boolean }
export declare function TextInput(props: TextInputProps): React.ReactElement;
export interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> { options: { value: string; label: string }[]; placeholder?: string; invalid?: boolean }
export declare function Select(props: SelectProps): React.ReactElement;
export interface TextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement> { value?: string; maxLength?: number; invalid?: boolean }
export declare function Textarea(props: TextareaProps): React.ReactElement;
export declare function MonthGrid(props: { value?: Date | null; onSelect: (d: Date) => void; rangeFrom?: Date | null; rangeTo?: Date | null; today?: Date; autoFocus?: boolean }): React.ReactElement;
export interface DateInputProps { /** dd/mm/yyyy */ value?: string; onChange?: (value: string) => void; native?: boolean; invalid?: boolean; disabled?: boolean }
export declare function DateInput(props: DateInputProps): React.ReactElement;

export interface TableColumn<R = any> { key: string; header: React.ReactNode; numeric?: boolean; sortable?: boolean; width?: number | string; render?: (row: R) => React.ReactNode }
export interface TableProps<R = any> {
  columns: TableColumn<R>[]; rows: R[]; rowKey?: string; caption?: string;
  selectable?: boolean; selected?: any[]; onSelectedChange?: (ids: any[]) => void;
  sort?: { key: string; dir: 'asc' | 'desc' }; onSortChange?: (s: { key: string; dir: 'asc' | 'desc' }) => void;
  loading?: boolean; empty?: React.ReactNode; bulkActions?: React.ReactNode; rowLabel?: (row: R) => string;
  /** Dưới độ rộng này (px) bảng thành danh sách thẻ. Mặc định 640 */
  cardsBelow?: number; maxHeight?: number | string;
}
export declare function Table<R = any>(props: TableProps<R>): React.ReactElement;
export interface PaginationProps { page: number; pageCount: number; onPageChange: (p: number) => void; total?: number; pageSize?: number; compact?: boolean }
export declare function Pagination(props: PaginationProps): React.ReactElement;
export interface BadgeProps extends Children { tone?: Tone | 'neutral'; solid?: boolean; /** tên icon, hoặc false để bỏ (chỉ cho tone neutral) */ icon?: string | false }
export declare function Badge(props: BadgeProps): React.ReactElement;
export declare function CountBadge(props: { count: number; label?: string }): React.ReactElement | null;
export interface AvatarProps { name: string; src?: string; size?: 'sm' | 'md' | 'lg'; decorative?: boolean }
export declare function Avatar(props: AvatarProps): React.ReactElement;
export interface ChipProps extends Children { selected?: boolean; onToggle?: () => void; count?: number }
export declare function Chip(props: ChipProps): React.ReactElement;
export interface TooltipProps { content: string; children: React.ReactElement; delay?: number }
export declare function Tooltip(props: TooltipProps): React.ReactElement;

export interface NavItem { id: string; label: string; icon: string; badge?: number; href?: string }
export interface SidebarProps { title?: string; subtitle?: string; sections: { label?: string; items: NavItem[] }[]; activeId: string; onNavigate?: (id: string) => void; collapsed?: boolean; onCollapsedChange: (c: boolean) => void; footer?: React.ReactNode }
export declare function Sidebar(props: SidebarProps): React.ReactElement;
export interface TopNavProps extends Children { title: React.ReactNode; leading?: React.ReactNode; actions?: React.ReactNode }
export declare function TopNav(props: TopNavProps): React.ReactElement;
export interface TabsProps extends Children { items: { value: string; label: React.ReactNode; count?: number }[]; value: string; onChange: (v: string) => void; label: string }
export declare function Tabs(props: TabsProps): React.ReactElement;
export interface BreadcrumbProps { items: { label: string; href?: string; onClick?: () => void }[]; compact?: boolean }
export declare function Breadcrumb(props: BreadcrumbProps): React.ReactElement;
export interface BottomNavProps { items: NavItem[]; activeId: string; onNavigate: (id: string) => void }
export declare function BottomNav(props: BottomNavProps): React.ReactElement;

export interface ToastOptions { tone?: Tone; message: React.ReactNode; action?: { label: string; onClick: () => void }; duration?: number }
export declare function ToastProvider(props: Children & { placement?: 'bottom-right' | 'bottom' }): React.ReactElement;
export declare function useToast(): { push: (t: ToastOptions) => string; dismiss: (id: string) => void };
export interface AlertProps extends Children { tone?: Tone; title?: React.ReactNode; actions?: React.ReactNode; onDismiss?: () => void; live?: boolean }
export declare function Alert(props: AlertProps): React.ReactElement;
export interface StateViewProps { kind?: 'empty' | 'no-results' | 'error' | 'offline' | 'no-access'; title: React.ReactNode; description?: React.ReactNode; actions?: React.ReactNode; compact?: boolean }
export declare function StateView(props: StateViewProps): React.ReactElement;
export declare function Skeleton(props: { width?: number | string; height?: number | string; radius?: number | string }): React.ReactElement;
export declare function Spinner(props: { label?: string }): React.ReactElement;

export interface DialogProps extends Children { open: boolean; onClose: () => void; title: React.ReactNode; description?: React.ReactNode; tone?: Tone; size?: 'lg'; footer?: React.ReactNode; initialFocus?: string; dismissible?: boolean }
export declare function Dialog(props: DialogProps): React.ReactElement | null;
export interface ConfirmDialogProps extends Children { open: boolean; onClose: () => void; onConfirm: (r: { reason: string; note: string }) => void; /** Có → bắt buộc lý do */ reasonLabel?: string; reasonOptions?: { value: string; label: string }[]; reasonHelper?: string; title: React.ReactNode; description?: React.ReactNode; confirmLabel: string; cancelLabel?: string; tone?: 'danger' | 'warning' | 'info'; loading?: boolean }
export declare function ConfirmDialog(props: ConfirmDialogProps): React.ReactElement | null;
export interface DrawerProps extends Children { open: boolean; onClose: () => void; title: React.ReactNode; description?: React.ReactNode; placement?: 'right' | 'bottom'; footer?: React.ReactNode }
export declare function Drawer(props: DrawerProps): React.ReactElement | null;
export interface PopoverProps { trigger: React.ReactElement; label: string; children: React.ReactNode | ((close: () => void) => React.ReactNode); placement?: 'bottom-start' | 'bottom-end' }
export declare function Popover(props: PopoverProps): React.ReactElement;

export interface SegmentOption { value: string; label: string; short?: string; icon?: string; tone?: Tone; emphasis?: 'subtle' | 'solid' }
export interface SegmentedControlProps { name: string; label: string; options: SegmentOption[]; value: string | null; onChange: (v: string) => void; colored?: boolean; layout?: 'stack' | 'row'; disabled?: boolean }
export declare function SegmentedControl(props: SegmentedControlProps): React.ReactElement;
export interface StudentListItemProps { name: string; meta?: React.ReactNode; avatar?: string; trailing?: React.ReactNode; onClick?: () => void }
export declare function StudentListItem(props: StudentListItemProps): React.ReactElement;
export interface ClassCardProps { name: string; campus?: string; schedule?: string; teacher?: string; enrolled?: number; capacity?: number; status?: React.ReactNode; href?: string; footer?: React.ReactNode }
export declare function ClassCard(props: ClassCardProps): React.ReactElement;
export interface ProgressBarProps { value: number; max?: number; label?: React.ReactNode; valueText?: string; variant?: 'default' | 'lms'; size?: 'lg' }
export declare function ProgressBar(props: ProgressBarProps): React.ReactElement;
export interface AttendanceStudent { id: string | number; name: string; code?: string; meta?: string; note?: string; avatar?: string }
export type AttendanceStatus = 'present' | 'late' | 'excused' | 'absent';
export interface AttendanceSheetProps {
  session: { className: string; label?: string; time: string; campus: string };
  students: AttendanceStudent[];
  /** teacher: chính thức · ops: vận hành ghi kèm lý do liên hệ · compare: xem hai cột chỉ đọc (R-DD-02/03) */
  mode?: 'teacher' | 'ops' | 'compare';
  /** Trạng thái của giáo viên (compare) hoặc giá trị ban đầu; không có = chưa điểm danh */
  initial?: Record<string, AttendanceStatus>;
  opsMarks?: Record<string, { status?: AttendanceStatus; reason?: string }>;
  onChange?: (marks: Record<string, AttendanceStatus | null>) => void;
  /** Có → hiện nút "Tiếp"; còn em chưa điểm danh thì mở BlockingDialog */
  onRequestNext?: (marks: Record<string, AttendanceStatus>) => void;
}
export declare function AttendanceSheet(props: AttendanceSheetProps): React.ReactElement;
export declare function AttBadge(props: { value?: AttendanceStatus | null }): React.ReactElement;
export declare function SaveState(props: { state?: 'saving' | 'saved' | 'error' | null }): React.ReactElement | null;

/* ===== Đợt 5.0 ===== */
export interface BlockingDialogProps { open: boolean; onClose: () => void; /** block: lỗi chặn · warn: cảnh báo, vẫn làm tiếp được */ kind?: 'block' | 'warn'; title: React.ReactNode; description?: React.ReactNode;
  reasons: { text: React.ReactNode; detail?: React.ReactNode; actionLabel?: string; onAction?: () => void }[]; continueLabel?: string; onContinue?: () => void }
export declare function BlockingDialog(props: BlockingDialogProps): React.ReactElement | null;
export interface StatusStep { id: string; label: string; short?: string }
export interface StatusBarProps { steps: StatusStep[]; current: string; terminal?: { label: string; tone?: Tone; icon?: string }; substatus?: string; forwardOnly?: boolean; locked?: boolean; actions?: React.ReactNode; onStepClick?: (id: string) => void; label?: string }
export declare function StatusBar(props: StatusBarProps): React.ReactElement;
export interface SmartButtonProps { icon: string; label: string; count: number; onClick?: () => void }
export declare function SmartButton(props: SmartButtonProps): React.ReactElement;
export declare function SmartButtonGroup(props: { items: SmartButtonProps[]; max?: number }): React.ReactElement;
export interface ChatterEntry { id: string | number; type: 'note' | 'change' | 'system'; author: string; at: string; text?: string; files?: string[]; changes?: { field: string; from?: string; to: string }[] }
export declare function Chatter(props: { entries: ChatterEntry[]; people?: { name: string; role?: string }[]; me?: string; onPost?: (e: ChatterEntry) => void }): React.ReactElement;
export declare function BulkActionBar(props: Children & { count: number; onClear: () => void; label?: string }): React.ReactElement;
export interface FilterBarProps {
  search: string; onSearch: (q: string) => void; searchPlaceholder?: string;
  /** Lọc nhanh: trong nhóm là HOẶC, giữa nhóm là VÀ (R-CRM-07) */
  groups?: { id: string; label: string; options: { id: string; label: string; count?: number }[] }[]; value?: Record<string, string[]>; onChange?: (v: Record<string, string[]>) => void;
  advancedCount?: number; onAdvanced?: () => void; groupByOptions?: { value: string; label: string }[]; groupBy?: string; onGroupBy?: (v: string) => void;
  favorites?: { name: string; isDefault?: boolean; shared?: boolean }[]; onSaveFavorite?: (f: { name: string; isDefault: boolean; shared: boolean }) => void; onApplyFavorite?: (f: any) => void;
  columns?: { key: string; label: string; visible: boolean; locked?: boolean }[]; onColumnsChange?: (c: any[]) => void;
  views?: ('list' | 'kanban' | 'calendar')[]; view?: string; onViewChange?: (v: string) => void; resultCount?: number;
}
export declare function FilterBar(props: FilterBarProps): React.ReactElement;
export interface KanbanCardData { id: string; code: string; title: string; lines?: string[]; owner?: string; due?: string }
export interface KanbanProps { columns: { id: string; label: string; cards: KanbanCardData[] }[]; onMove: (cardId: string, from: string, to: string) => void;
  /** Trả { ok:false, reason } để chặn (ví dụ chỉ đi tới) — mở BlockingDialog */ canMove?: (cardId: string, from: string, to: string) => { ok: boolean; reason?: string; detail?: string }; renderCard?: (c: KanbanCardData) => React.ReactNode; label?: string }
export declare function Kanban(props: KanbanProps): React.ReactElement;
export interface CalendarEvent { id: string | number; title: string; type: string; start: string; end: string; room: string; teacher: string; dow?: number; date?: string; mday?: number; cancelled?: boolean; conflict?: boolean | 'room' | 'teacher' | 'both' }
export interface CalendarProps { events: CalendarEvent[]; view?: 'day' | 'week' | 'month'; onViewChange?: (v: string) => void; by?: 'room' | 'person'; onByChange?: (v: string) => void; resources?: string[]; weekStart?: number; day?: string; onOpen?: (e: CalendarEvent) => void; startHour?: number; endHour?: number }
export declare function Calendar(props: CalendarProps): React.ReactElement;
export interface ComboOption { value: string; label: string; code?: string; legacyCode?: string; meta?: string; disabled?: boolean; disabledReason?: string }
export interface ComboboxProps { options: ComboOption[]; value: string | string[] | null; onChange: (v: any) => void; multiple?: boolean; placeholder?: string; invalid?: boolean; disabled?: boolean; loading?: boolean; emptyText?: string }
export declare function Combobox(props: ComboboxProps): React.ReactElement;
export declare function DateRange(props: { value: { from: Date; to: Date } | null; onChange: (v: { from: Date; to: Date }) => void; today?: Date }): React.ReactElement;
export declare function MoneyInput(props: { value: number; onChange?: (n: number) => void; readOnly?: boolean; systemNote?: string; invalid?: boolean; disabled?: boolean }): React.ReactElement;
export interface HoursDisplayProps { granted: number; used: number; bonus?: number; /** giờ tặng chưa cấp vì chưa thu đủ */ bonusLocked?: boolean; expectedEnd: string; packageEnd?: string; /** quá hạn gói nhưng còn giờ — chỉ là thông tin (R-GD-07) */ packageExpired?: boolean; threshold?: number; compact?: boolean }
export declare function HoursDisplay(props: HoursDisplayProps): React.ReactElement;
export declare function RatingScale(props: { name: string; label: string; value: number | null; onChange: (n: number | null) => void; descriptions?: Record<number, string>; required?: boolean }): React.ReactElement;
export type HomeworkStatusValue = { status: 'graded' | 'partial' | 'none' | 'late' | 'na'; score?: number | null };
/** Điểm BTVN gõ tay 1–10 (chốt 11/10). */
export declare function HomeworkStatus(props: { value: HomeworkStatusValue | null; onChange?: (v: HomeworkStatusValue) => void; readOnly?: boolean; name?: string; min?: number; max?: number; decimals?: number; showMissing?: boolean; hideLabels?: boolean }): React.ReactElement;
/** Ô nhập điểm số; đặt trong Field. Mặc định 1–10, cho một chữ số thập phân (7,5). Ô trống = chưa có điểm (khác 0). */
export declare function ScoreInput(props: { value: number | null; onChange?: (v: number | null) => void; onErrorChange?: (msg: string | null) => void; min?: number; max?: number; decimals?: number; invalid?: boolean; disabled?: boolean; id?: string; name?: string }): React.ReactElement;
export declare function RadarChart(props: { title: string; axes: string[]; series: { name: string; values: number[]; kind?: 'ref' }[]; max?: number; size?: number }): React.ReactElement;
export declare function FileUpload(props: { label?: string; helper?: string; accept?: string; maxMB?: number; multiple?: boolean; mobile?: boolean }): React.ReactElement;
export interface TaskStepperProps extends Children { title: string; steps: { id: string; label: string; short?: string; status: 'done' | 'todo' }[]; current: string; onStepChange?: (id: string) => void; deadline?: React.ReactNode;
  nav?: { index: number; total: number; hasPrev: boolean; hasNext: boolean; onPrev: () => void; onNext: () => void } | null; footer?: React.ReactNode }
export declare function TaskStepper(props: TaskStepperProps): React.ReactElement;
export declare function SlaBadge(props: { kind: 'remaining' | 'overdue' | 'ontime' | 'late'; hours?: number; threshold?: number }): React.ReactElement;
export declare function ApprovalChain(props: { levels: { role: string; approver?: string; status: 'approved' | 'rejected' | 'pending' | 'waiting'; at?: string; reason?: string }[]; layout?: 'vertical' | 'horizontal' }): React.ReactElement;
export declare function VersionedConfig(props: { title: string; versions: { id: string; label: string; status: 'active' | 'scheduled' | 'past'; effectiveFrom: string; effectiveTo?: string; author: string; note?: string }[]; rows: { key: string; label: string; values: Record<string, any> }[]; format?: (v: any, row: any) => string }): React.ReactElement;
export interface PrintLayoutProps { size?: 'A4' | 'A5'; logoSrc?: string; campus: { code: string; name: string; address: string; phone: string }; docTitle: string; code: string; date: string; status?: string;
  party?: { k: string; v: string }[]; columns: { key: string; header: string; numeric?: boolean }[]; lines: Record<string, string>[]; totals?: { k: string; v: string; strong?: boolean }[]; amountInWords?: string; notes?: string; signatures?: { role: string; name?: string }[] }
export declare function PrintLayout(props: PrintLayoutProps): React.ReactElement;

/* ===== Đợt 5.2 · khuôn ===== */
export type CrmRole = 'AD' | 'BM' | 'SA' | 'CS' | 'KT';
/** [nhóm, nhóm con, nhãn, mã màn, vai trò dùng (chuỗi ghép, vd "BMSACS"), vai trò chỉ xem] */
export declare const CRM_MENU_ROWS: [string, string | null, string, string, string, string][];
export declare function menuFor(role: CrmRole): { id: string; label: string; icon: string; subs: { label: string | null; items: { id: string; label: string; access: 'full' | 'view'; external?: boolean }[] }[] }[];
export declare const CAMPUSES: { code: 'CS1' | 'CS2' | 'CS3' | 'CS4' | 'CS5'; name: string; hasRooms: boolean }[];
export declare const ROLE_LABEL: Record<string, string>;
/** K01 · Khung CRM (CHUNG-10). Cố định: menu trái + thanh trên; children = vùng nội dung. Chọn cơ sở chỉ hiện với AD, KT. */
export declare function AppShell(props: Children & { role: CrmRole; user: { name: string; campus: string }; activeId?: string; onNavigate?: (code: string) => void; campus?: string; onCampusChange?: (code: string) => void; notifications?: number; onSearch?: () => void; onNotifications?: () => void; onAccount?: (a: 'profile' | 'portal' | 'logout') => void; multiPortal?: boolean; badges?: Record<string, number>; loading?: boolean; mobile?: boolean; defaultCollapsed?: boolean }): React.ReactElement;
export declare function PageHeader(props: Children & { title: React.ReactNode; code?: string; breadcrumb?: { label: string; href?: string }[]; meta?: React.ReactNode; actions?: React.ReactNode }): React.ReactElement;
/** K09 · thẻ số mở danh sách lọc sẵn */
/** GV-01 · khung cổng Giáo viên: điện thoại (tiêu đề + thanh dưới 5 mục) hoặc laptop (menu trái thu gọn + nội dung rộng). Chữ 16. */
export declare function TeacherShell(props: { device?: 'phone' | 'laptop'; activeId?: 'today' | 'cal' | 'cls' | 'todo' | 'me'; onNavigate?: (id: string) => void; title: React.ReactNode; onBack?: () => void; actions?: React.ReactNode; user?: string; badges?: Record<string, number>; saveState?: 'saving' | 'saved' | 'error'; height?: number; contentMaxWidth?: number; flush?: boolean; children?: React.ReactNode }): React.ReactElement;
export declare function StudentShell(props: { portal?: 'hs' | 'ph'; device?: 'phone' | 'laptop'; young?: boolean; activeId?: string; onNavigate?: (id: string) => void; title: React.ReactNode; onBack?: () => void; actions?: React.ReactNode; user?: string; badges?: Record<string, number>; bottom?: React.ReactNode; height?: number; flush?: boolean; children?: React.ReactNode }): React.ReactElement;
export interface SubmissionPage { id: string; kind?: 'img' | 'pdf'; src?: string; name: string; size?: number; pages?: number; status: 'done' | 'uploading' | 'error'; progress?: number; error?: string }
export declare function PhotoPages(props: { pages: SubmissionPage[]; onChange?: (pages: SubmissionPage[]) => void; onView?: (id: string) => void; onRetry?: (id: string) => void; onAdd?: () => void; addLabel?: string; review?: boolean; columns?: number }): React.ReactElement;
export declare function SubmissionViewer(props: { pages: { id: string; src: string; label?: string }[]; page?: number; onPage?: (i: number) => void; height?: number; compact?: boolean }): React.ReactElement;
export type QuickGridColumn =
  | { key: string; label: string; kind: 'radio'; field: string; value: string; hotkey?: string; tone?: 'success' | 'warning' | 'danger'; icon?: string; group?: string }
  | { key: string; label: string; kind: 'select'; options: { value: string; label: string; hotkey?: string; tone?: string; icon?: string }[]; group?: string; disabled?: (vals: any) => string | null }
  | { key: string; label: string; kind: 'score'; min: number; max: number; decimals?: number; group?: string; sub?: string; help?: string; disabled?: (vals: any) => string | null }
  | { key: string; label: string; kind: 'text'; group?: string; disabled?: (vals: any) => string | null }
  | { key: string; label: string; kind: 'read'; render: (vals: any, row: any) => React.ReactNode; group?: string };
/** K14 · Bảng chấm nhanh (laptop): hàng = học sinh, cột = trạng thái/tiêu chí; phím số, Tab, mũi tên; ô trống ≠ điểm; cột tên + tiêu đề cố định; lưu tự động. */
export declare function QuickGrid(props: { rows: { id: string; name: string; note?: string }[]; columns: QuickGridColumn[]; values?: Record<string, Record<string, any>>; onChange?: (all: any) => void; onOpenRow?: (row: any) => void; caption: string; maxHeight?: number; rowDisabled?: (row: any, vals: any) => string | null; rowNote?: (row: any, vals: any) => string | null; failOnSave?: (all: any) => boolean; help?: boolean; onSaveState?: (s: 'saving' | 'saved' | 'error') => void }): React.ReactElement;
export interface LineSeries { name: string; short?: string; values: (number | null)[]; color?: string; dashed?: boolean }
/** Biểu đồ đường 1–4 chuỗi, một trục y; chú giải khi ≥ 2 chuỗi; chuỗi 2+ nét đứt; rê chuột / phím mũi tên hiện hộp số; có bảng ẩn. */
export declare function LineChart(props: { labels: string[]; series: LineSeries[]; format?: (n: number) => string; axisFormat?: (n: number) => string; height?: number; label: string; yMax?: number; tooltipTitle?: (i: number) => string }): React.ReactElement;
export declare function StatTile(props: { label: string; value: React.ReactNode; hint?: string; hintTone?: 'success' | 'warning' | 'danger' | 'info'; icon?: string; target?: string; linkLabel?: string; onOpen?: () => void; loading?: boolean }): React.ReactElement;
/** K11 · trang đơn (đăng nhập, lỗi, khoá), không có menu */
export declare function AuthLayout(props: Children & { product?: 'crm' | 'lms'; logoSrc?: string; logoWhiteSrc?: string; title: React.ReactNode; subtitle?: React.ReactNode; footer?: React.ReactNode; mobile?: boolean }): React.ReactElement;
/** Giữ chỗ cho ô Cloudflare Turnstile (300 × 65) */
export declare function TurnstileSlot(props: { state?: 'verifying' | 'success' | 'error' | 'expired'; onRetry?: () => void }): React.ReactElement;
export declare function OtpInput(props: { value: string; onChange: (v: string) => void; length?: number; invalid?: boolean; label?: string; autoFocus?: boolean }): React.ReactElement;
export declare function PasswordInput(props: { value: string; onChange: (e: any) => void; invalid?: boolean; autoComplete?: string; id?: string }): React.ReactElement;
/** Luật mật khẩu S03-04: ≥ 8 ký tự, có chữ, có số */
export declare function PasswordRules(props: { value: string }): React.ReactElement;
export declare function passwordOk(v: string): boolean;

declare global { interface Window { HMT: {
  Button: typeof Button; Field: typeof Field; TextInput: typeof TextInput; Select: typeof Select; Textarea: typeof Textarea; DateInput: typeof DateInput;
  Table: typeof Table; Pagination: typeof Pagination; Badge: typeof Badge; CountBadge: typeof CountBadge; Avatar: typeof Avatar; Chip: typeof Chip; Tooltip: typeof Tooltip;
  Sidebar: typeof Sidebar; TopNav: typeof TopNav; Tabs: typeof Tabs; Breadcrumb: typeof Breadcrumb; BottomNav: typeof BottomNav;
  ToastProvider: typeof ToastProvider; useToast: typeof useToast; Alert: typeof Alert; StateView: typeof StateView; Skeleton: typeof Skeleton; Spinner: typeof Spinner;
  Dialog: typeof Dialog; ConfirmDialog: typeof ConfirmDialog; Drawer: typeof Drawer; Popover: typeof Popover;
  SegmentedControl: typeof SegmentedControl; BlockingDialog: typeof BlockingDialog; StatusBar: typeof StatusBar; SmartButton: typeof SmartButton; SmartButtonGroup: typeof SmartButtonGroup; Chatter: typeof Chatter; BulkActionBar: typeof BulkActionBar; FilterBar: typeof FilterBar; Kanban: typeof Kanban; Calendar: typeof Calendar; Combobox: typeof Combobox; DateRange: typeof DateRange; MoneyInput: typeof MoneyInput; HoursDisplay: typeof HoursDisplay; RatingScale: typeof RatingScale; HomeworkStatus: typeof HomeworkStatus; ScoreInput: typeof ScoreInput; AppShell: typeof AppShell; PageHeader: typeof PageHeader; StatTile: typeof StatTile; LineChart: typeof LineChart; TeacherShell: typeof TeacherShell; QuickGrid: typeof QuickGrid; StudentShell: typeof StudentShell; PhotoPages: typeof PhotoPages; SubmissionViewer: typeof SubmissionViewer; AuthLayout: typeof AuthLayout; TurnstileSlot: typeof TurnstileSlot; OtpInput: typeof OtpInput; PasswordInput: typeof PasswordInput; PasswordRules: typeof PasswordRules; menuFor: typeof menuFor; RadarChart: typeof RadarChart; FileUpload: typeof FileUpload; TaskStepper: typeof TaskStepper; SlaBadge: typeof SlaBadge; ApprovalChain: typeof ApprovalChain; VersionedConfig: typeof VersionedConfig; PrintLayout: typeof PrintLayout; MonthGrid: typeof MonthGrid; StudentListItem: typeof StudentListItem; ClassCard: typeof ClassCard; ProgressBar: typeof ProgressBar; AttendanceSheet: typeof AttendanceSheet;
} } }
