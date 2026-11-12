-- Q-262 phần còn thiếu (Code 2, 12/11/2026, lệnh Chat/kế hoạch 17/11 §2 mục 8): bật công tắc tính năng BAN_HANG (Bán hàng: lead, cơ hội, test, báo giá, đơn, phiếu thu, ghi danh chọn lớp) cho cơ sở CS5.
-- Lý do: BAN_HANG chỉ được bật ở supabase/seed.sql (dữ liệu giả của staging/CI), KHÔNG có migration nào bật. Bản chạy thật chỉ áp migration, không áp seed, nên ở đó BAN_HANG tắt:
-- 38 chỗ app.require_feature('BAN_HANG', …) báo HMT_TINH_NANG_TAT và các màn báo giá, đơn, phiếu thu, cơ hội ẩn theo công tắc. CS5 chạy trước (nạp 17/11/2026).
-- Cách làm giống migration 110 (VAN_HANH_LOP): cờ lưu ở app.feature_flag (phân hệ × cơ sở); migration này áp lên MỌI môi trường nó được áp tới (staging khi gộp vào main,
-- bản chạy thật khi anh Trường chạy workflow bản chạy thật). Chỉ bật; chạy lại không lỗi và không nhân đôi dòng; staging đã có dòng từ seed thì chỉ giữ bật.
-- Cơ sở khác KHÔNG bật ở đây; thêm sau khi anh Trường xác nhận cơ sở đó chạy Bán hàng. CONG_GIAO_VIEN không bật: không có hàm hay màn nào kiểm phân hệ này.
-- Chạy sau migration 124 (GV-07K).
insert into app.feature_flag (module_code, branch_id, enabled)
select 'BAN_HANG', b.id, true
  from app.branch b
 where b.code = 'CS5'
on conflict (module_code, branch_id) do update set enabled = true;
