// Menu cổng CRM. Cấu trúc (nhóm, thứ tự, đường dẫn) theo bản đồ màn hình và thẻ RoleMenu của thiết kế;
// AI THẤY MỤC NÀO thì đọc từ ma trận quyền trong cơ sở dữ liệu (app.permission), không ghi theo vai trò ở đây.
import type { IconName } from '../ui/icons';

export type MenuRequirement =
  /** Luôn hiện với người vào được cổng. */
  | { kind: 'always' }
  /** Có quyền (phân hệ, hành động) trong ma trận. */
  | { kind: 'permission'; module: string; action: string }
  /** Có ít nhất một quyền với hành động này ở bất kỳ phân hệ nào (vd hàng chờ duyệt). */
  | { kind: 'any-action'; action: string };

export type MenuEntry = {
  /** Mã màn trong docs/design/ban-do-man-hinh.md. */
  code: string;
  label: string;
  /** Đường dẫn dưới /crm. */
  slug: string;
  requires: MenuRequirement;
  /** Nhóm con trong nhóm (vd Đào tạo > Ghi danh). */
  sub?: string | undefined;
  /** Giai đoạn màn này được dựng; chưa tới thì mở ra trang "Sắp có". */
  stage: string;
  /** Công tắc tính năng (danh mục MODULE) riêng của mục này, ngoài công tắc của cả nhóm; tắt thì ẩn mục và mở thẳng đường dẫn báo chưa bật. */
  feature?: string | undefined;
  /** Công tắc phân hệ vẫn phải bật khi mục được đặt ở nhóm khác phân hệ của nó (vd Sắp hết giờ nằm ở Chăm sóc khách hàng). */
  moduleFeature?: string | undefined;
  /**
   * Mục là một tab của mục khác (đường dẫn mục cha, cùng nhóm): không có dòng riêng trên menu, đường dẫn giữ nguyên.
   * Quyền và công tắc vẫn kiểm theo chính mục này; người không thấy mục cha thì mục này hiện thành dòng menu.
   */
  tabOf?: string | undefined;
  /** Chữ trên tab khi khác nhãn mục. */
  tabLabel?: string | undefined;
};

export type MenuGroup = {
  id: string;
  label: string;
  icon: IconName;
  /** Công tắc tính năng (danh mục MODULE) của cả nhóm; tắt ở cơ sở thì ẩn nhóm. */
  feature?: string | undefined;
  entries: MenuEntry[];
};

const can = (module: string, action = 'XEM'): MenuRequirement => ({
  kind: 'permission',
  module,
  action,
});
const GD1 = 'giai đoạn 1';
const GD2 = 'giai đoạn 2';
const GD3 = 'giai đoạn 3';
const GD5 = 'giai đoạn 5';
const B4 = 'bước 4 (bản tiếp theo)';

export const CRM_MENU: MenuGroup[] = [
  {
    id: 'tong-quan',
    label: 'Tổng quan',
    icon: 'home',
    entries: [
      { code: 'CHUNG-14', label: 'Trang chủ', slug: '', requires: { kind: 'always' }, stage: '' },
      {
        code: 'VC-01',
        label: 'Việc của tôi',
        slug: 'viec-cua-toi',
        requires: { kind: 'always' },
        stage: GD1,
      },
      {
        code: 'CHUNG-15',
        label: 'Việc chờ tôi duyệt',
        slug: 'viec-cho-duyet',
        requires: { kind: 'any-action', action: 'DUYET' },
        stage: GD1,
      },
    ],
  },
  {
    id: 'tuyen-sinh',
    label: 'Tuyển sinh',
    icon: 'recruit',
    feature: 'BAN_HANG',
    entries: [
      { code: 'TS-01', label: 'Lead', slug: 'lead', requires: can('LEAD'), stage: GD1 },
      { code: 'TS-07', label: 'Cơ hội', slug: 'co-hoi', requires: can('OPPORTUNITY'), stage: GD1 },
      {
        code: 'TS-11',
        label: 'Lịch hẹn',
        slug: 'lich-hen',
        requires: can('APPOINTMENT'),
        stage: GD1,
      },
      {
        code: 'TS-16',
        label: 'Phiếu Test',
        slug: 'phieu-kiem-tra',
        requires: can('STUDENT_TEST'),
        stage: GD1,
      },
    ],
  },
  {
    id: 'khach-hang',
    label: 'Khách hàng',
    icon: 'customers',
    entries: [
      { code: 'KH-01', label: 'Phụ huynh', slug: 'phu-huynh', requires: can('PARENT'), stage: '' },
      { code: 'KH-04', label: 'Học sinh', slug: 'hoc-sinh', requires: can('STUDENT'), stage: '' },
    ],
  },
  {
    id: 'ban-hang',
    label: 'Bán hàng',
    icon: 'sales',
    feature: 'BAN_HANG',
    entries: [
      { code: 'BH-01', label: 'Báo giá', slug: 'bao-gia', requires: can('QUOTATION'), stage: '' },
      {
        code: 'BH-06',
        label: 'Đơn hàng',
        slug: 'don-hang',
        requires: can('SALES_ORDER'),
        stage: '',
      },
    ],
  },
  {
    id: 'ke-toan',
    label: 'Kế toán',
    icon: 'payment',
    feature: 'BAN_HANG',
    entries: [
      {
        code: 'TC-01',
        label: 'Phiếu thu',
        slug: 'phieu-thu',
        requires: can('RECEIPT'),
        stage: GD1,
      },
      {
        code: 'TC-04',
        label: 'Hàng chờ kế toán duyệt',
        slug: 'cho-ke-toan-duyet',
        requires: can('RECEIPT', 'DUYET'),
        stage: GD1,
        tabOf: 'phieu-thu',
        tabLabel: 'Chờ kế toán duyệt',
      },
      {
        code: 'TC-08',
        label: 'Khoản tiền vào',
        slug: 'khoan-tien-vao',
        requires: can('ACCOUNTING'),
        stage: '',
      },
      {
        code: 'TC-13',
        label: 'Công nợ',
        slug: 'cong-no',
        requires: can('SALES_ORDER'),
        stage: '',
      },
      {
        code: 'TC-10',
        label: 'Phiếu chi',
        slug: 'phieu-chi',
        requires: can('ACCOUNTING'),
        stage: GD2,
      },
      {
        code: 'TC-14',
        label: 'Số dư khách hàng',
        slug: 'so-du-khach-hang',
        requires: can('ACCOUNTING'),
        stage: GD2,
      },
      {
        code: 'TC-15',
        label: 'Đối soát thu tiền',
        slug: 'doi-soat-thu-tien',
        // Kế toán và Admin (cùng có Kế toán · Xuất; Trưởng cơ sở chỉ Xem). Máy chủ kiểm lại phạm vi toàn hệ thống.
        requires: can('ACCOUNTING', 'XUAT'),
        stage: GD1,
      },
    ],
  },
  {
    id: 'dao-tao',
    label: 'Đào tạo',
    icon: 'training',
    feature: 'VAN_HANH_LOP',
    entries: [
      {
        code: 'GD-01',
        label: 'Ghi danh',
        slug: 'ghi-danh',
        requires: can('ENROLLMENT'),
        stage: GD2,
      },
      {
        code: 'GD-06',
        label: 'Hàng chờ xếp lớp',
        slug: 'cho-xep-lop',
        requires: can('ENROLLMENT', 'SUA'),
        stage: GD2,
        tabOf: 'ghi-danh',
        tabLabel: 'Chờ xếp lớp',
      },
      { code: 'LOP-01', label: 'Lớp học', slug: 'lop', requires: can('CLASS'), stage: '' },
      {
        code: 'LOP-08',
        label: 'Lịch tuần cơ sở',
        slug: 'lich-tuan',
        requires: can('CLASS'),
        stage: '',
      },
      {
        code: 'BUOI-01',
        label: 'Buổi học',
        slug: 'buoi-hoc',
        requires: can('SESSION'),
        stage: GD2,
      },
      {
        code: 'BUOI-10',
        label: 'Yêu cầu buổi',
        slug: 'yeu-cau-buoi',
        requires: can('SESSION'),
        stage: '',
        feature: 'YEU_CAU_BUOI',
        tabOf: 'buoi-hoc',
      },
      {
        code: 'BUOI-15',
        label: 'Điểm danh trong ngày',
        slug: 'diem-danh-trong-ngay',
        requires: can('SESSION'),
        stage: '',
        feature: 'DIEM_DANH_TRONG_NGAY',
      },
      {
        code: 'BUOI-11',
        label: 'Điểm danh vận hành',
        slug: 'diem-danh',
        requires: can('ATTENDANCE', 'SUA'),
        stage: GD2,
      },
      {
        code: 'BUOI-12',
        label: 'Buổi chưa hoàn tất',
        slug: 'buoi-chua-done',
        requires: can('SESSION'),
        stage: GD2,
      },
    ],
  },
  {
    id: 'cham-soc',
    label: 'Chăm sóc khách hàng',
    icon: 'service',
    entries: [
      {
        code: 'CS-01',
        label: 'Tất cả ticket',
        slug: 'ticket',
        requires: can('TICKET'),
        stage: '',
        feature: 'AFTERSALE',
      },
      {
        code: 'CS-05',
        label: 'Phiếu nghiệp vụ',
        slug: 'phieu-nghiep-vu',
        requires: can('TICKET'),
        stage: '',
        feature: 'AFTERSALE',
      },
      // CS-16 «Nhận xét chờ gửi» sống lại 23/11/2026 (anh Trường, sửa R-V2-40): CSKH gửi tay qua Zalo rồi đánh dấu đã gửi. Cần quyền sửa Ticket (giáo viên không có).
      {
        code: 'CS-16',
        label: 'Nhận xét chờ gửi',
        slug: 'nhan-xet-cho-gui',
        requires: can('TICKET', 'SUA'),
        stage: '',
      },
      {
        code: 'CS-07',
        label: 'Phiếu chuyển cơ sở đến',
        slug: 'phieu-chuyen-co-so-den',
        requires: can('TICKET', 'DUYET'),
        stage: '',
        feature: 'AFTERSALE',
        tabOf: 'phieu-nghiep-vu',
      },
      {
        code: 'TT-01',
        label: 'Tái tục',
        slug: 'tai-tuc',
        requires: can('UPSALE'),
        stage: '',
      },
      {
        code: 'TT-04',
        label: 'Đối chiếu tái tục',
        slug: 'doi-chieu-tai-tuc',
        requires: can('UPSALE'),
        stage: '',
        tabOf: 'tai-tuc',
      },
      {
        code: 'GD-07',
        label: 'Sắp hết giờ',
        slug: 'sap-het-gio',
        requires: can('ENROLLMENT'),
        stage: '',
        feature: 'SAP_HET_GIO',
        moduleFeature: 'VAN_HANH_LOP',
      },
    ],
  },
  {
    id: 'bao-cao',
    label: 'Báo cáo',
    icon: 'reports',
    feature: 'BAO_CAO',
    entries: [
      {
        code: 'BC-01',
        label: 'Tổng quan Ban giám đốc',
        slug: 'bao-cao/tong-quan',
        requires: can('REPORT'),
        stage: GD5,
      },
      {
        code: 'BC-08',
        label: 'Giáo viên trễ hạn',
        slug: 'bao-cao/giao-vien-tre-han',
        requires: can('REPORT'),
        stage: GD3,
      },
      {
        code: 'BC-09',
        label: 'Giờ dạy giáo viên',
        slug: 'bao-cao/gio-day',
        requires: can('REPORT'),
        stage: GD3,
      },
    ],
  },
  {
    id: 'cau-hinh',
    label: 'Cấu hình',
    icon: 'config',
    entries: [
      {
        code: 'CH-01',
        label: 'Gói bán',
        slug: 'cau-hinh/goi-ban',
        requires: can('CONFIG_SALES'),
        stage: GD1,
        sub: 'Bán hàng',
      },
      {
        code: 'CH-03',
        label: 'Bảng giá',
        slug: 'cau-hinh/bang-gia',
        requires: can('CONFIG_SALES'),
        stage: GD1,
        sub: 'Bán hàng',
      },
      {
        code: 'CH-04',
        label: 'Chính sách ưu đãi',
        slug: 'cau-hinh/chiet-khau',
        requires: can('CONFIG_SALES'),
        stage: GD1,
        sub: 'Bán hàng',
      },
      {
        code: 'CH-09',
        label: 'Điều khoản thanh toán',
        slug: 'cau-hinh/dieu-khoan-thanh-toan',
        requires: can('CONFIG_SALES'),
        stage: GD1,
        sub: 'Bán hàng',
      },
      {
        code: 'CH-08',
        label: 'Chiến dịch marketing',
        slug: 'cau-hinh/chien-dich',
        requires: { kind: 'always' }, // R-CRM-11 (19/11): mọi vai trò vào được cổng CRM đều xem và tạo được
        stage: GD1,
        sub: 'Bán hàng',
      },
      {
        code: 'CH-05',
        label: 'Khung chương trình',
        slug: 'cau-hinh/khung-chuong-trinh',
        requires: can('CONFIG_TRAINING'),
        stage: GD2,
        sub: 'Đào tạo',
      },
      {
        code: 'CH-07',
        label: 'Rubric nhận xét',
        slug: 'cau-hinh/rubric',
        requires: can('CONFIG_TRAINING'),
        stage: GD2,
        sub: 'Đào tạo',
      },
      {
        code: 'QT-14',
        label: 'Ngày nghỉ lễ',
        slug: 'cau-hinh/ngay-nghi',
        requires: can('HOLIDAY'),
        stage: GD2,
        sub: 'Đào tạo',
      },
      {
        code: 'CSN-08',
        label: 'Nhóm ticket',
        slug: 'cau-hinh/nhom-ticket',
        requires: can('ADMIN'),
        stage: GD2,
        sub: 'Chăm sóc',
      },
      {
        code: 'CSN-09',
        label: 'SLA ticket',
        slug: 'cau-hinh/sla-ticket',
        requires: can('ADMIN'),
        stage: GD2,
        sub: 'Chăm sóc',
      },
      {
        code: 'QT-15',
        label: 'Người duyệt ticket',
        slug: 'cau-hinh/nguoi-duyet-ticket',
        requires: can('ADMIN'),
        stage: GD2,
        sub: 'Chăm sóc',
      },
    ],
  },
  {
    id: 'quan-tri',
    label: 'Quản trị',
    icon: 'settings',
    entries: [
      {
        code: 'QT-01',
        label: 'Người dùng',
        slug: 'quan-tri/nguoi-dung',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Tài khoản',
      },
      {
        code: 'QT-16',
        label: 'Giáo viên, trợ giảng',
        slug: 'quan-tri/giao-vien',
        requires: can('ADMIN'),
        stage: GD2,
        sub: 'Tài khoản',
      },
      {
        code: 'QT-13',
        label: 'Tài khoản học sinh',
        slug: 'quan-tri/tai-khoan-hoc-sinh',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Tài khoản',
      },
      {
        code: 'QT-17',
        label: 'Tài khoản phụ huynh',
        slug: 'quan-tri/tai-khoan-phu-huynh',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Tài khoản',
      },
      {
        code: 'QT-04',
        label: 'Vai trò',
        slug: 'quan-tri/vai-tro',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Quyền',
      },
      {
        code: 'QT-05',
        label: 'Ma trận quyền',
        slug: 'quan-tri/ma-tran-quyen',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Quyền',
      },
      {
        code: 'QT-06',
        label: 'Danh mục',
        slug: 'quan-tri/danh-muc',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Hệ thống',
      },
      {
        code: 'QT-08',
        label: 'Cơ sở và phòng',
        slug: 'quan-tri/co-so',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Hệ thống',
      },
      {
        code: 'QT-09',
        label: 'Tham số nghiệp vụ',
        slug: 'quan-tri/tham-so',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Hệ thống',
      },
      {
        code: 'QT-10',
        label: 'Công tắc tính năng',
        slug: 'quan-tri/cong-tac',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Hệ thống',
      },
      {
        code: 'QT-18',
        label: 'Nhập dữ liệu',
        slug: 'quan-tri/nhap-du-lieu',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Hệ thống',
      },
      {
        code: 'KH-08',
        label: 'Lên khối đầu năm',
        slug: 'len-khoi-dau-nam',
        requires: can('ADMIN'),
        stage: '',
        sub: 'Hệ thống',
      },
      {
        code: 'QT-11',
        label: 'Nhật ký',
        slug: 'quan-tri/nhat-ky',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Nhật ký',
      },
      {
        code: 'QT-12',
        label: 'Nhật ký đăng nhập, xuất file',
        slug: 'quan-tri/nhat-ky-dang-nhap',
        requires: can('ADMIN'),
        stage: B4,
        sub: 'Nhật ký',
      },
    ],
  },
];

export type MenuAccess = {
  can: (module: string, action: string) => boolean;
  canAnyModule: (action: string) => boolean;
  featureOn: (feature: string) => boolean;
  /**
   * Quản trị viên (có quyền Quản trị · Xem): vào được mọi mục menu và mọi phân hệ để xem, kể cả mục cần quyền riêng (Hàng chờ kế toán duyệt,
   * Ticket, Báo cáo) và phân hệ đang tắt ở cơ sở đang chọn (anh Trường chốt 21/11/2026). Chỉ mở XEM màn; việc ghi (tiền, duyệt) vẫn do
   * ma trận quyền và hàm cơ sở dữ liệu quyết.
   */
  isAdmin?: boolean;
};

export function entryAllowed(entry: MenuEntry, access: MenuAccess): boolean {
  if (access.isAdmin) return true;
  switch (entry.requires.kind) {
    case 'always':
      return true;
    case 'permission':
      return access.can(entry.requires.module, entry.requires.action);
    case 'any-action':
      return access.canAnyModule(entry.requires.action);
  }
}

function entryFeaturesOn(entry: MenuEntry, access: MenuAccess): boolean {
  return [entry.moduleFeature, entry.feature].every((f) => !f || access.featureOn(f));
}

/** Menu một người thấy: bỏ mục không có quyền, bỏ nhóm bị tắt công tắc hoặc không còn mục nào. */
export function visibleMenu(menu: MenuGroup[], access: MenuAccess): MenuGroup[] {
  return menu
    .filter((group) => !group.feature || access.isAdmin || access.featureOn(group.feature))
    .map((group) => ({
      ...group,
      entries: group.entries.filter(
        (e) => entryAllowed(e, access) && (access.isAdmin || entryFeaturesOn(e, access)),
      ),
    }))
    .filter((group) => group.entries.length > 0);
}

export type RouteCheck =
  | { status: 'ok'; group: MenuGroup; entry: MenuEntry }
  | { status: 'forbidden' }
  | { status: 'feature-off' }
  | { status: 'not-found' };

/** Mở thẳng một đường dẫn: có quyền không, phân hệ có bật không (CHUNG-16, CHUNG-24). */
export function checkRoute(menu: MenuGroup[], slug: string, access: MenuAccess): RouteCheck {
  for (const group of menu) {
    const entry = group.entries.find((e) => e.slug === slug);
    if (!entry) continue;
    if (!entryAllowed(entry, access)) return { status: 'forbidden' };
    if (!access.isAdmin) {
      if (group.feature && !access.featureOn(group.feature)) return { status: 'feature-off' };
      if (!entryFeaturesOn(entry, access)) return { status: 'feature-off' };
    }
    return { status: 'ok', group, entry };
  }
  return { status: 'not-found' };
}

/** Dòng hiện trên thanh bên: bỏ mục đã là tab của một mục đang thấy trong cùng nhóm. */
export function sidebarEntries(group: MenuGroup): MenuEntry[] {
  return group.entries.filter((e) => !e.tabOf || !group.entries.some((p) => p.slug === e.tabOf));
}

export type RouteTab = { slug: string; label: string };

/**
 * Thanh tab của trang đang mở (theo menu đã lọc quyền): mục cha rồi các mục con. Trang không thuộc cụm tab nào,
 * hoặc người xem chỉ thấy một mục của cụm, thì rỗng.
 */
export function routeTabs(menu: MenuGroup[], slug: string): RouteTab[] {
  for (const group of menu) {
    const entry = group.entries.find((e) => e.slug === slug);
    if (!entry) continue;
    const root = entry.tabOf ?? entry.slug;
    const parent = group.entries.find((e) => e.slug === root);
    const children = group.entries.filter((e) => e.tabOf === root);
    if (!parent || children.length === 0) return [];
    return [parent, ...children].map((e) => ({ slug: e.slug, label: e.tabLabel ?? e.label }));
  }
  return [];
}
