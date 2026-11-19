// E32: bảng ánh xạ «tên ảnh trong docs/huong-dan/*.md → vai, màn cần chụp». Dùng cho e2e/chup-anh.spec.ts (chỉ chạy khi CHUP_ANH=1).
// `route`: địa chỉ cần mở. `row`: bấm dòng đầu tiên của bảng (mở bản ghi) trước khi chụp. `view`: chọn kiểu xem (nút tên này) trước khi chụp.
// Ảnh nào là HỘP THOẠI hoặc bước cần dữ liệu riêng chưa dựng được tự động thì ghi `approx`: chụp màn gần nhất (danh sách hoặc bản ghi), báo cáo ghi rõ «xấp xỉ».
export type Shot = {
  name: string;
  route: string;
  row?: boolean;
  view?: string;
  /** Bấm lần lượt sau khi mở bản ghi: tên nút, hoặc «tab:Tên» cho thẻ (tab). Có `clicks` thì ảnh không còn là xấp xỉ (nếu không ghi `approx`). */
  clicks?: string[];
  approx?: string;
};

export type Role = {
  /** Thư mục ảnh và tên tệp hướng dẫn. */
  folder: string;
  /** Tài khoản giả (xem scripts/seed-users.ts). */
  account: string;
  kind: 'crm' | 'crm-hai-buoc' | 'gv';
  shots: Shot[];
};

export const ROLES: Role[] = [
  {
    folder: 'sale',
    account: 'sale.cs5',
    kind: 'crm',
    shots: [
      { name: 'lead-ban-ghi', route: '/crm/lead', row: true },
      {
        name: 'lead-hanh-dong',
        route: '/crm/lead',
        row: true,
        clicks: ['Hành động'],
      },
      {
        name: 'lead-tao-co-hoi',
        route: '/crm/lead',
        row: true,
        approx: 'bản ghi lead; hộp Tạo cơ hội chưa mở tự động',
      },
      { name: 'co-hoi-lien-ket', route: '/crm/co-hoi', row: true },
      { name: 'co-hoi-thanh-giai-doan', route: '/crm/co-hoi', row: true },
      { name: 'bao-gia-tao', route: '/crm/bao-gia' },
      {
        name: 'bao-gia-in',
        route: '/crm/bao-gia',
        row: true,
        approx: 'bản ghi báo giá; bản in chưa mở tự động',
      },
      { name: 'don-hang-dong-don', route: '/crm/don-hang', row: true },
      {
        name: 'don-hang-chon-lop',
        route: '/crm/don-hang',
        row: true,
        approx: 'bản ghi đơn; tab Ghi danh chưa bấm được tự động',
      },
      { name: 'don-hang-trinh', route: '/crm/don-hang', row: true },
      { name: 'phieu-thu-tao', route: '/crm/phieu-thu' },
      { name: 'phieu-thu-trinh', route: '/crm/phieu-thu', row: true },
    ],
  },
  {
    folder: 'cskh',
    account: 'cskh.cs5',
    kind: 'crm',
    shots: [
      { name: 'ghi-danh-cho-xep', route: '/crm/cho-xep-lop' },
      {
        name: 'ghi-danh-xep-lop',
        route: '/crm/ghi-danh',
        row: true,
        approx: 'bản ghi ghi danh; hộp xếp lớp chưa mở tự động',
      },
      { name: 'ghi-danh-so-gio', route: '/crm/ghi-danh', row: true },
      { name: 'lop-tao', route: '/crm/lop' },
      { name: 'lop-trinh', route: '/crm/lop', row: true },
      { name: 'buoi-ban-ghi', route: '/crm/buoi-hoc', row: true },
      { name: 'diem-danh-trong-ngay', route: '/crm/diem-danh-trong-ngay' },
      { name: 'hoc-sinh-ho-so', route: '/crm/hoc-sinh', row: true },
      { name: 'phu-huynh-ds', route: '/crm/phu-huynh' },
      { name: 'ticket-ds', route: '/crm/ticket' },
      { name: 'ticket-kanban', route: '/crm/ticket', view: 'Kanban' },
      { name: 'ticket-ban-ghi', route: '/crm/ticket', row: true },
      {
        name: 'ticket-doi-trang-thai',
        route: '/crm/ticket',
        row: true,
        approx: 'bản ghi ticket; hộp đổi trạng thái chưa mở tự động',
      },
      {
        name: 'phieu-tao-tu-ticket',
        route: '/crm/phieu-nghiep-vu',
        approx: 'danh sách phiếu nghiệp vụ; hộp tạo từ ticket chưa mở tự động',
      },
      { name: 'phieu-trinh-duyet', route: '/crm/phieu-nghiep-vu', row: true },
      { name: 'phieu-thuc-hien', route: '/crm/phieu-nghiep-vu', row: true },
    ],
  },
  {
    folder: 'ke-toan',
    account: 'ketoan.cs5',
    kind: 'crm-hai-buoc',
    shots: [
      { name: 'phieu-thu-cho-ke-toan', route: '/crm/cho-ke-toan-duyet' },
      { name: 'phieu-thu-duyet', route: '/crm/cho-ke-toan-duyet', row: true },
      {
        name: 'phieu-thu-tu-choi',
        route: '/crm/cho-ke-toan-duyet',
        row: true,
        approx: 'bản ghi; hộp từ chối chưa mở tự động',
      },
      { name: 'khoan-tien-vao-ds', route: '/crm/khoan-tien-vao' },
      { name: 'khoan-tien-hoan-tac', route: '/crm/khoan-tien-vao', row: true },
      { name: 'cong-no', route: '/crm/cong-no' },
      {
        name: 'thu-no-dau-ky',
        route: '/crm/phieu-thu',
        approx: 'danh sách phiếu thu; bước thu nợ đầu kỳ chưa mở tự động',
      },
      { name: 'phieu-chi-ban-ghi', route: '/crm/phieu-chi', row: true },
      {
        name: 'phieu-chi-in',
        route: '/crm/phieu-chi',
        row: true,
        approx: 'bản ghi phiếu chi; bản in chưa mở tự động',
      },
      { name: 'hoan-hoc-phi-duyet', route: '/crm/phieu-nghiep-vu', row: true },
      { name: 'so-du-ds', route: '/crm/so-du-khach-hang' },
      { name: 'so-du-lich-su', route: '/crm/so-du-khach-hang', row: true },
    ],
  },
  {
    folder: 'truong-co-so',
    account: 'truongcs.cs5',
    kind: 'crm',
    shots: [
      { name: 'lop-duyet', route: '/crm/lop', row: true },
      {
        name: 'lop-dong-bi-chan',
        route: '/crm/lop',
        row: true,
        approx: 'bản ghi lớp; câu chặn hiện khi bấm Đóng, chưa mở tự động',
      },
      { name: 'don-hang-duyet', route: '/crm/don-hang', row: true },
      { name: 'phieu-thu-duyet-quan-ly', route: '/crm/phieu-thu', row: true },
      { name: 'lich-tuan', route: '/crm/lich-tuan' },
      {
        name: 'buoi-huy',
        route: '/crm/buoi-hoc',
        row: true,
        approx: 'bản ghi buổi; hộp huỷ chưa mở tự động',
      },
      {
        name: 'buoi-doi',
        route: '/crm/buoi-hoc',
        row: true,
        approx: 'bản ghi buổi; hộp dời chưa mở tự động',
      },
      {
        name: 'buoi-sua-diem-danh',
        route: '/crm/buoi-hoc',
        row: true,
        approx: 'bản ghi buổi; hộp sửa điểm danh chưa mở tự động',
      },
      {
        name: 'dieu-chinh-gio',
        route: '/crm/ghi-danh',
        row: true,
        approx: 'bản ghi ghi danh; hộp điều chỉnh giờ chưa mở tự động',
      },
      { name: 'phieu-nghiep-vu-cho-toi', route: '/crm/phieu-nghiep-vu' },
      { name: 'phieu-nghiep-vu-duyet', route: '/crm/phieu-nghiep-vu', row: true },
    ],
  },
  {
    folder: 'giao-vien',
    account: 'gv.cs5',
    kind: 'gv',
    shots: [
      { name: 'gv-hom-nay', route: '/gv' },
      { name: 'gv-lich-day', route: '/gv/lich-day' },
      {
        name: 'gv-diem-danh',
        route: '/gv',
        row: true,
        approx: 'trang Hôm nay; màn điểm danh cần mở một buổi cụ thể, chưa chụp tự động',
      },
      { name: 'gv-diem-danh-luu', route: '/gv', approx: 'trang Hôm nay; chưa chụp tự động' },
      { name: 'gv-noi-dung-buoi', route: '/gv', approx: 'trang Hôm nay; chưa chụp tự động' },
      { name: 'gv-cham-nhan-xet', route: '/gv', approx: 'trang Hôm nay; chưa chụp tự động' },
      { name: 'gv-cham-nhan-xet-bang', route: '/gv', approx: 'trang Hôm nay; chưa chụp tự động' },
      { name: 'gv-cham-btvn', route: '/gv', approx: 'trang Hôm nay; chưa chụp tự động' },
      { name: 'gv-hoan-tat-buoi', route: '/gv', approx: 'trang Hôm nay; chưa chụp tự động' },
      { name: 'gv-ticket-tao', route: '/gv/ticket/tao' },
    ],
  },
  {
    folder: 'quan-tri',
    account: 'quantri.cs5',
    kind: 'crm-hai-buoc',
    shots: [
      { name: 'nguoi-dung-tao', route: '/crm/quan-tri/nguoi-dung' },
      { name: 'nguoi-dung-ban-ghi', route: '/crm/quan-tri/nguoi-dung', row: true },
      { name: 'vai-tro-ds', route: '/crm/quan-tri/vai-tro' },
      { name: 'ma-tran-quyen', route: '/crm/quan-tri/ma-tran-quyen' },
      { name: 'danh-muc-ds', route: '/crm/quan-tri/danh-muc' },
      { name: 'tham-so-nhom', route: '/crm/quan-tri/tham-so' },
      { name: 'cong-tac-bang', route: '/crm/quan-tri/cong-tac' },
      { name: 'nhat-ky-thao-tac', route: '/crm/quan-tri/nhat-ky' },
      { name: 'nhat-ky-dang-nhap', route: '/crm/quan-tri/nhat-ky-dang-nhap' },
    ],
  },
];
