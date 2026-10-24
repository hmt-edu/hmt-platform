-- Thử quyền ghi bảng Auth của hàm app.admin_reset_mfa (Đ49) trên hmt-staging. Chạy trong giao dịch rồi HOÀN TÁC: không để lại
-- dữ liệu nào. Hàm admin_reset_mfa chạy bằng quyền chủ sở hữu bản migration, nên cần chủ sở hữu được xoá ở auth.mfa_factors,
-- auth.sessions. Dùng ở bước "Thử quyền ghi bảng Auth" của .github/workflows/deploy-staging.yml; chạy được cả ở DB local.
-- Kết quả: in "DAT" nếu mọi quyền đủ; lỗi (thoát khác 0) nếu thiếu quyền.
\set ON_ERROR_STOP on
begin;
do $$
declare
  v_owner oid;
  v_uid uuid := gen_random_uuid();
  v_n integer;
begin
  select p.proowner into v_owner from pg_proc p where p.oid = 'app.admin_reset_mfa(uuid)'::regprocedure;
  if not has_table_privilege(v_owner, 'auth.mfa_factors', 'DELETE') then
    raise exception 'KHONG_DAT: chu so huu ham admin_reset_mfa khong xoa duoc auth.mfa_factors';
  end if;
  if not has_table_privilege(v_owner, 'auth.sessions', 'DELETE') then
    raise exception 'KHONG_DAT: chu so huu ham admin_reset_mfa khong xoa duoc auth.sessions';
  end if;
  -- Thử thật bằng dữ liệu giả trong giao dịch (sẽ hoàn tác).
  insert into auth.users (id, aud, role, email) values (v_uid, 'authenticated', 'authenticated', 'probe-' || v_uid || '@probe.hoamatoan.invalid');
  insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret)
  values (gen_random_uuid(), v_uid, 'probe', 'totp', 'verified', now(), now(), 'x');
  insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), v_uid, now(), now());
  delete from auth.mfa_factors where user_id = v_uid;
  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'KHONG_DAT: xoa thiet bi hai buoc khong thanh cong (% dong)', v_n;
  end if;
  delete from auth.sessions where user_id = v_uid;
  get diagnostics v_n = row_count;
  if v_n <> 1 then
    raise exception 'KHONG_DAT: xoa phien khong thanh cong (% dong)', v_n;
  end if;
  raise notice 'DAT: chu so huu ham (%) xoa duoc auth.mfa_factors va auth.sessions', v_owner::regrole;
end
$$;
rollback;
