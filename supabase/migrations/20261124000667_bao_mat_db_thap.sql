-- Bảo mật DB mức THẤP (A-23-36, số 667). Hai việc nhỏ, không đổi giao diện:
--  1) Đặt lại mật khẩu thì thu hồi mọi phiên đang mở của người đó (soát E1): trước đây hàm chỉ bật «phải đổi mật khẩu»,
--     phiên cũ còn sống nên người giữ phiên cũ tự đổi mật khẩu và giữ luôn tài khoản. Khoá tài khoản, đổi vai, đổi cơ sở đã làm như vậy.
--  2) enrollment_hours_balance (quỹ giờ của một ghi danh) trước đây ai đăng nhập cũng gọi được nếu biết mã ghi danh (soát Q5).
--     Nay chỉ cho: nhân viên (cổng CRM/GV), chính học sinh hoặc phụ huynh của em đó, hoặc chạy nền không có người dùng.
--     Không thu hồi quyền gọi vì nhiều hàm và bài kiểm gọi trực tiếp; kiểm bên trong (CLAUDE.md: kiểm quyền bên trong hàm).
-- Không có bảng mới, không đổi RLS. Nhật ký sửa cấu hình: không áp dụng (không đổi cấu hình).

-- 1) Luật soát E1: đặt lại mật khẩu thu hồi phiên cũ (session_version tăng, auth.sessions của người đó bị xoá).
create or replace function app.admin_mark_password_reset(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  update app.user_account
     set must_change_password = true, failed_login_count = 0, temp_locked_until = null
   where id = p_user_id;
  perform app.remember_temp_password(p_user_id);
  -- Luật E1: phiên đang mở của người bị đặt lại mật khẩu không dùng được nữa.
  perform app.revoke_user_sessions(p_user_id);
end;
$$;

-- 2) Luật soát Q5: chỉ người có quyền xem quỹ giờ của ghi danh này mới đọc được.
create or replace function app.enrollment_hours_balance(p_enrollment_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Có người đăng nhập (auth.uid() không rỗng): phải là nhân viên, hoặc học sinh/phụ huynh của đúng em có ghi danh này.
  -- Không có người đăng nhập (chạy nền, hàm nội bộ gọi từ máy chủ): giữ nguyên hành vi cũ.
  if (select auth.uid()) is not null
     and not (select app.is_staff())
     and not exists (
       select 1 from app.enrollment e
        where e.id = p_enrollment_id
          and e.student_id in (select app.portal_student_ids())
     ) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem quỹ giờ của ghi danh này.');
  end if;
  return (select coalesce(sum(hours), 0)::numeric(6, 2) from app.hour_ledger where enrollment_id = p_enrollment_id);
end;
$$;
