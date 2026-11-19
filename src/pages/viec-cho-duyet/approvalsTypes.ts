// Kiểu dữ liệu màn CHUNG-15 Việc chờ tôi duyệt: khớp app.list_my_approvals (migration 556, 557).
export type ApprovalKind =
  | 'DON_HANG'
  | 'PHIEU_THU'
  | 'LOP'
  | 'YEU_CAU_BUOI'
  | 'HOAN_PHI'
  | 'DUNG_HOC'
  | 'BAO_LUU'
  | 'CHUYEN_LOP'
  | 'PHIEU_NGHIEP_VU';

export type ApprovalRow = {
  kind: ApprovalKind;
  ref_id: string;
  /** Id bản ghi để mở khi bấm dòng (ghi danh cho hoàn phí, dừng học, bảo lưu, chuyển lớp). */
  open_id: string;
  code: string;
  subject_name: string | null;
  subject_code: string | null;
  detail: string | null;
  level_no: number;
  level_total: number;
  level_label: string;
  creator_name: string | null;
  waiting_since: string;
  branch_code: string | null;
};

export type ApprovalPage = {
  total: number;
  counts: Partial<Record<ApprovalKind, number>>;
  rows: ApprovalRow[];
};

export type ApprovalFilters = { kind?: string; branch_id?: string };
