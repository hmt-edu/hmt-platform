// Các loại nạp dữ liệu cũ của màn Nhập (QT-18, chỉ Admin). Cột theo file mẫu HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx (từng tab xuất ra CSV UTF-8)
// và docs/nghiep-vu/nap-du-lieu.md. Mọi luật kiểm dòng nằm ở hàm trong cơ sở dữ liệu / Edge Function; giao diện chỉ kiểm tên cột.

export type ImportKind = 'NGUOI_DUNG' | 'CO_HOI' | 'PHU_HUYNH' | 'HOC_SINH' | 'LOP' | 'GHI_DANH';

export type ImportKindConfig = {
  kind: ImportKind;
  title: string;
  description: string;
  /** Tên cột nhận (đúng như dòng đầu của file, chữ thường, không dấu). Cột khác trong file bị bỏ qua. */
  columns: string[];
  /** Cột bắt buộc có trong file (ô trống từng dòng do máy chủ kiểm). */
  required: string[];
  /** Gọi Edge Function (cần quyền máy chủ để tạo tài khoản) thay vì hàm DB. */
  viaFunction: boolean;
  /** Tên cột người trong kết quả (chỉ để đặt tên bảng). */
  subject: string;
  /** Loại đào tạo (D1e): gọi hàm import_training_records; kết quả có Cảnh báo và báo cáo lỗi theo loại. */
  training?: boolean;
  /** Một dòng lỗi thì không cho nạp cả loại (xem trước còn lỗi thì khoá nút Nạp). */
  blockOnError?: boolean;
};

export const IMPORT_KINDS: ImportKindConfig[] = [
  {
    kind: 'NGUOI_DUNG',
    title: 'Người dùng',
    description:
      'Nhân viên, giáo viên, trợ giảng. Tạo tài khoản, cấp mật khẩu tạm (hiện một lần để tải file).',
    columns: [
      'username',
      'ho_ten',
      'ma_nv',
      'vai_tro',
      'co_so_truy_cap',
      'trang_thai',
      'email',
      'quan_ly',
    ],
    required: ['username', 'ho_ten', 'vai_tro', 'co_so_truy_cap'],
    viaFunction: true,
    subject: 'Người dùng',
  },
  {
    kind: 'CO_HOI',
    title: 'Cơ hội',
    description:
      'Cơ hội kèm phụ huynh và lead gốc, đúng giai đoạn trong file. Nạp Người dùng trước (người phụ trách). Cơ hội từ L5 thiếu tên hoặc năm sinh em vẫn nạp, đánh dấu thiếu thông tin em.',
    columns: [
      'ma_cu',
      'ngay_tao',
      'ho_ten_ph',
      'sdt_ph',
      'sdt_2',
      'danh_sach_em',
      'nam_sinh',
      'khoi',
      'truong',
      'dia_chi',
      'nhu_cau',
      'nguon_goc',
      'nguon',
      'medium',
      'co_so',
      'nguoi_phu_trach',
      'nguoi_phu_trach_goc',
      'tinh_trang_cu',
      'giai_doan',
      'nhom_con',
      'ghi_chu',
    ],
    required: [
      'ma_cu',
      'ngay_tao',
      'ho_ten_ph',
      'sdt_ph',
      'nguon_goc',
      'nguon',
      'co_so',
      'nguoi_phu_trach',
      'giai_doan',
    ],
    viaFunction: false,
    subject: 'Phụ huynh',
  },
  {
    kind: 'PHU_HUYNH',
    title: 'Phụ huynh',
    description:
      'Hồ sơ phụ huynh theo mã cũ. Trùng mã cũ hoặc số điện thoại thì bỏ qua, không tự gộp.',
    columns: ['ma_cu', 'ho_ten', 'sdt', 'sdt_2', 'ho_ten_2', 'dia_chi', 'co_so'],
    required: ['ma_cu', 'ho_ten', 'sdt', 'co_so'],
    viaFunction: false,
    subject: 'Phụ huynh',
  },
  {
    kind: 'HOC_SINH',
    title: 'Học sinh',
    description:
      'Hồ sơ học sinh theo mã cũ, gắn phụ huynh theo số điện thoại (nạp Phụ huynh trước).',
    columns: [
      'ma_cu',
      'ho_ten',
      'ngay_sinh',
      'gioi_tinh',
      'sdt_ph',
      'truong',
      'loai_truong',
      'khoi',
      'ghi_chu',
      'co_so',
    ],
    required: ['ma_cu', 'ho_ten', 'ngay_sinh', 'khoi', 'sdt_ph', 'co_so'],
    viaFunction: false,
    subject: 'Học sinh',
  },
  {
    kind: 'LOP',
    title: 'Lớp',
    description:
      'Lớp học theo mã lớp cũ. Chỉ sinh buổi từ ngày chốt số dư; so_buoi là số buổi CÒN LẠI. Lớp chưa ghép được giáo viên vẫn nạp, có cảnh báo.',
    columns: [
      'ma_lop_cu',
      'loai_lop',
      'phan_loai',
      'trinh_do',
      'nam_hoc',
      'mon',
      'khoi',
      'lich_hoc',
      'so_buoi',
      'ma_gv',
      'ngay_khai_giang',
      'si_so_toi_da',
      'tinh_trang',
      'co_so',
    ],
    required: [
      'ma_lop_cu',
      'loai_lop',
      'nam_hoc',
      'mon',
      'khoi',
      'lich_hoc',
      'so_buoi',
      'tinh_trang',
      'co_so',
    ],
    viaFunction: false,
    subject: 'Lớp',
    training: true,
  },
  {
    kind: 'GHI_DANH',
    title: 'Ghi danh',
    description:
      'Ghi danh học sinh vào lớp kèm giờ còn lại (sinh một dòng Số dư đầu kỳ). Nạp Lớp và Học sinh trước. Một dòng lỗi thì không nạp cả loại.',
    columns: [
      'hoc_sinh_ma_cu',
      'ma_lop_cu',
      'tinh_trang_moi',
      'ngay_vao_lop',
      'thoi_luong_buoi',
      'gio_du_kien',
      'gio_da_hoc',
      'gio_con_lai',
      'gio_da_hoc_cu',
      'nguon_tab',
      'nguon_dong',
    ],
    required: [
      'hoc_sinh_ma_cu',
      'ma_lop_cu',
      'tinh_trang_moi',
      'thoi_luong_buoi',
      'gio_du_kien',
      'gio_da_hoc',
      'gio_con_lai',
    ],
    viaFunction: false,
    subject: 'Ghi danh',
    training: true,
    blockOnError: true,
  },
];

export function kindConfig(kind: ImportKind): ImportKindConfig {
  const found = IMPORT_KINDS.find((k) => k.kind === kind);
  if (!found) throw new Error(`Loại nạp không có: ${kind}`);
  return found;
}

/** Một dòng của bảng chọn loại (khung QT18_chon_loai): đủ 8 loại theo thứ tự nạp đã chốt; loại chưa có hàm nạp là "Sắp có", nút Nhập khoá. */
export type ImportKindRow = {
  title: string;
  description: string;
  /** Loại cần nạp trước (chữ hiển thị); "Không cần" nếu không phụ thuộc. */
  needs: string;
  /** null = Sắp có (chưa có hàm nạp). */
  kind: ImportKind | null;
};

// Thứ tự nạp (Q-209, anh OK 10/11): Người dùng, Lớp, Phụ huynh, Học sinh, Ghi danh, Số dư, Cơ hội, Phiếu test.
// Buổi học, Điểm danh chỉ để đối chiếu, không nạp. Lớp, Ghi danh, Số dư, Phiếu test: chờ hàm nạp (D1e, B2), nên "Sắp có".
export const IMPORT_KIND_ROWS: ImportKindRow[] = [
  {
    title: 'Người dùng',
    description:
      'Tài khoản nhân viên, giáo viên, trợ giảng. Nạp xong cấp mật khẩu tạm hàng loạt, hiện một lần.',
    needs: 'Không cần',
    kind: 'NGUOI_DUNG',
  },
  {
    title: 'Lớp',
    description: 'Lớp học và mã lớp cũ.',
    needs: 'Người dùng (giáo viên)',
    kind: 'LOP',
  },
  {
    title: 'Phụ huynh',
    description: 'Hồ sơ phụ huynh, khớp theo SĐT đã chuẩn hoá. Giữ mã cũ để tra cứu.',
    needs: 'Không cần',
    kind: 'PHU_HUYNH',
  },
  {
    title: 'Học sinh',
    description: 'Hồ sơ học sinh, khớp theo phụ huynh + tên + năm sinh. Giữ mã cũ.',
    needs: 'Phụ huynh',
    kind: 'HOC_SINH',
  },
  {
    title: 'Ghi danh',
    description: 'Ghi danh của học sinh vào lớp. Một dòng lỗi thì không nạp cả loại.',
    needs: 'Lớp, Học sinh',
    kind: 'GHI_DANH',
  },
  {
    title: 'Số dư',
    description: 'Số dư giờ, số dư tiền. Một dòng lỗi thì không nạp cả loại.',
    needs: 'Phụ huynh, Học sinh',
    kind: null,
  },
  {
    title: 'Cơ hội',
    description: 'Cơ hội tuyển sinh đang theo dõi.',
    needs: 'Phụ huynh, Học sinh',
    kind: 'CO_HOI',
  },
  {
    title: 'Phiếu test',
    description: 'Phiếu kiểm tra đầu vào đã làm.',
    needs: 'Cơ hội',
    kind: null,
  },
];

// Giá trị mẫu GIẢ cho file mẫu (nút "Tải file mẫu"): không phải dữ liệu thật. Cột không có trong bảng này lấy chữ "ví dụ".
const SAMPLE_VALUES: Record<string, string> = {
  username: 'nguyen.van.a',
  ho_ten: 'Nguyễn Văn A',
  ma_nv: 'NV0001',
  vai_tro: 'SALES',
  co_so_truy_cap: 'CS5',
  trang_thai: 'DANG_DUNG',
  email: 'nguyen.van.a@example.com',
  quan_ly: 'tran.van.b',
  ma_cu: 'CU0001',
  sdt: '0900000001',
  sdt_2: '',
  sdt_ph: '0900000001',
  ho_ten_ph: 'Nguyễn Thị B',
  ho_ten_2: '',
  dia_chi: 'Số 1 đường Mẫu',
  co_so: 'CS5',
  ngay_tao: '2026-01-15',
  ngay_sinh: '2012-05-20',
  nam_sinh: '2012',
  khoi: '6',
  giai_doan: 'L1',
  ma_lop_cu: '4M1',
  loai_lop: 'Lớp chung',
  phan_loai: 'CB',
  trinh_do: 'A',
  nam_hoc: '2627',
  mon: 'Toán',
  lich_hoc: 'Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)',
  so_buoi: '20',
  ma_gv: '2001',
  ngay_khai_giang: '2026-09-01',
  si_so_toi_da: '15',
  tinh_trang: 'Đang chạy',
  hoc_sinh_ma_cu: 'HS0001',
  tinh_trang_moi: 'Đang học',
  ngay_vao_lop: '2026-11-17',
  thoi_luong_buoi: '2.5',
  gio_du_kien: '50',
  gio_da_hoc: '20',
  gio_con_lai: '30',
};

/** Nội dung CSV của file mẫu: dòng tên cột (đúng cột hàm nạp nhận) và một dòng ví dụ giả. */
export function sampleCsvText(config: ImportKindConfig): string {
  const cols = Array.from(new Set(config.columns));
  const example = cols.map((c) => SAMPLE_VALUES[c] ?? 'ví dụ');
  return `${cols.join(',')}\n${example.join(',')}\n`;
}
