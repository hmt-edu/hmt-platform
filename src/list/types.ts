// Khuôn danh sách (K1), Kanban (K2), Calendar (K5): kiểu dữ liệu cấu hình.
// Khung KHÔNG biết nghiệp vụ nào: mỗi màn truyền cấu hình (cột, bộ lọc nhanh, trường lọc nâng cao, trường
// nhóm) từ đặc tả của phân hệ đó. Không viết cứng bộ lọc của màn nào trong khung này.
import type { ReactNode } from 'react';

export type ViewMode = 'list' | 'kanban' | 'calendar';

/** Một lựa chọn trong nhóm lọc nhanh (tick). */
export type QuickOption<Row> = {
  value: string;
  label: string;
  /** Giải thích ngắn dưới nhãn ("lịch hẹn kế tiếp đã quá hạn, chưa xong"). */
  hint?: string | undefined;
  /** Dùng khi lọc ngay trong trình duyệt (màn nhỏ, mẫu); màn dữ liệu lớn lọc ở máy chủ theo `state`. */
  test?: ((row: Row) => boolean) | undefined;
};

/** Nhóm lọc nhanh: cùng nhóm là HOẶC, khác nhóm là VÀ (R-CRM-07). */
export type QuickGroup<Row> = {
  key: string;
  label: string;
  options: QuickOption<Row>[];
};

export type FieldType = 'text' | 'select' | 'multi' | 'date';

/** Trường dùng cho lọc nâng cao. */
export type FilterField<Row> = {
  key: string;
  label: string;
  type: FieldType;
  options?: { value: string; label: string }[] | undefined;
  /** Chỉ cho các phép so sánh này (mặc định mọi phép của kiểu trường): dùng khi máy chủ không hiểu hết các phép. */
  ops?: Operator[] | undefined;
  /** Lấy giá trị của dòng (chuỗi; trường nhiều giá trị thì chuỗi chuẩn hoá). Chỉ dùng khi lọc trong trình duyệt. */
  get?: ((row: Row) => string) | undefined;
};

export type Operator = 'contains' | 'eq' | 'ne' | 'in' | 'from' | 'to';

export type Condition = {
  id: string;
  field: string;
  op: Operator;
  value: string | string[];
};

/** Cột của danh sách. Cột `locked` luôn hiện (Mã, tên bản ghi). */
export type ColumnDef<Row> = {
  key: string;
  label: string;
  render: (row: Row) => ReactNode;
  locked?: boolean | undefined;
  /** Cột làm tiêu đề thẻ khi bảng thành danh sách thẻ trên điện thoại. */
  primary?: boolean | undefined;
  defaultVisible?: boolean | undefined;
  numeric?: boolean | undefined;
  sortable?: boolean | undefined;
};

/** Trường dùng để nhóm (Group By), tối đa hai cấp. */
export type GroupField<Row> = {
  key: string;
  label: string;
  /** Giá trị nhóm của dòng; chuỗi rỗng = "Chưa có". */
  value: (row: Row) => string;
  /** Tên hiển thị của giá trị nhóm (mặc định chính giá trị). */
  valueLabel?: ((value: string) => string) | undefined;
};

/** Toàn bộ trạng thái của một màn danh sách. Lưu nguyên khối vào bộ lọc yêu thích (app.saved_filter.filters). */
export type ListState = {
  search: string;
  quick: Record<string, string[]>;
  conditions: Condition[];
  group: string[];
  /** Thứ tự và tập cột đang hiện; rỗng = mặc định của cấu hình. */
  columns: string[];
  /** Trường ngày dùng cho ô "Ngày tạo" và mốc thời gian. */
  dateField: string;
  datePreset: string;
};

export type ListConfig<Row> = {
  /** Mã màn (QT-01, TS-07…), khoá của bộ lọc yêu thích. */
  screenCode: string;
  title: string;
  searchPlaceholder: string;
  columns: ColumnDef<Row>[];
  quickGroups: QuickGroup<Row>[];
  filterFields: FilterField<Row>[];
  groupFields: GroupField<Row>[];
  /** Các trường ngày chọn được ở ô "Ngày tạo" (tên trường + nhãn). */
  dateFields: { key: string; label: string; get?: ((row: Row) => Date | null) | undefined }[];
  /** Kiểu xem màn này hỗ trợ (danh sách luôn có). */
  views: ViewMode[];
};

export const OPERATORS_BY_TYPE: Record<FieldType, { op: Operator; label: string }[]> = {
  text: [
    { op: 'contains', label: 'chứa' },
    { op: 'eq', label: 'là' },
  ],
  select: [
    { op: 'eq', label: 'là' },
    { op: 'ne', label: 'khác' },
  ],
  multi: [{ op: 'in', label: 'là một trong' }],
  date: [
    { op: 'from', label: 'từ ngày' },
    { op: 'to', label: 'đến ngày' },
  ],
};
