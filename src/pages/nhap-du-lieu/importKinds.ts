// Các loại nạp dữ liệu cũ của màn Nhập (QT-18, chỉ Admin). Cột theo file mẫu HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx (từng tab xuất ra CSV UTF-8)
// và docs/nghiep-vu/nap-du-lieu.md. Mọi luật kiểm dòng nằm ở hàm trong cơ sở dữ liệu / Edge Function; giao diện chỉ kiểm tên cột.

export type ImportKind = 'NGUOI_DUNG' | 'PHU_HUYNH' | 'HOC_SINH';

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
];

export function kindConfig(kind: ImportKind): ImportKindConfig {
  const found = IMPORT_KINDS.find((k) => k.kind === kind);
  if (!found) throw new Error(`Loại nạp không có: ${kind}`);
  return found;
}
