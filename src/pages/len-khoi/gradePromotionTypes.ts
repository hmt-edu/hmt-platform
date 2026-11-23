// Kiểu dữ liệu màn Lên khối đầu năm học (KH-08): khớp kết quả app.preview_grade_promotion, app.list_grade_promotion_batches (migration 566).
export type PromotionRow = {
  student_id: string;
  code: string;
  full_name: string;
  branch_code: string;
  old_grade: number;
  /** null = tốt nghiệp (lớp 12). */
  new_grade: number | null;
};

export type PromotionPreview = {
  eligible: number;
  graduating: number;
  skipped: {
    da_tot_nghiep: number;
    chua_co_khoi: number;
    khong_dang_hoc: number;
    tiem_nang: number;
    /** Em đủ điều kiện nhưng đã lên khối trong năm học này (KH-08, migration 635). */
    da_len_khoi_nam_nay: number;
  };
  /** Lúc chạy gần nhất của những em đã lên khối năm học này; null nếu chưa có. */
  last_run_at: string | null;
  total: number;
  rows: PromotionRow[];
};

export type PromotionBatch = {
  id: string;
  created_at: string;
  created_by_name: string | null;
  branch_code: string | null;
  promoted: number;
  graduated: number;
  excluded: number;
  status: 'DA_CHAY' | 'DA_HOAN_TAC';
  undo_until: string;
  can_undo: boolean;
};

export type PromotionBatches = { undo_days: number; rows: PromotionBatch[] };
export type RunResult = { batch_id: string; promoted: number; graduated: number; excluded: number };
