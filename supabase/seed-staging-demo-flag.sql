-- Bật «Dữ liệu mẫu của tôi» CHỈ trên hmt-staging (E-23-32; anh Trường duyệt trên GitHub trước khi gộp).
-- Làm gì: (1) ghi khoá môi trường STAGING vào app.deployment_env; (2) đặt tham số demo_data_enabled = true (giá trị chung).
-- Chỉ deploy-staging.yml chạy file này, bằng STAGING_DB_URL. hmt-deploy (chạy thật) KHÔNG có bước này nên chạy thật không có dòng STAGING:
-- hàm tạo/xoá bộ luôn từ chối (HMT_DEMO_TAT) dù công tắc có bị bật nhầm. Chạy lại nhiều lần không sao (ghi đè cùng giá trị).
-- Tắt lại: sửa demo_data_enabled về «false» ở màn Cài đặt tham số, hoặc bỏ bước này khỏi deploy-staging.yml rồi xoá dòng deployment_env.
-- KHÔNG đưa file này vào seed.sql: seed.sql cũng chạy ở local và CI (bài pgTAP 648 tự chèn dòng STAGING, có sẵn thì trùng khoá).
\set ON_ERROR_STOP on
begin;
select set_config('hmt.migration', 'on', true);
insert into app.deployment_env (singleton, env_code) values (true, 'STAGING')
on conflict (singleton) do update set env_code = 'STAGING';
update app.setting_def set value = 'true' where key = 'demo_data_enabled';
commit;
