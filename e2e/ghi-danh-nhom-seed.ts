// Dựng dữ liệu giả cho bài "xếp lớp theo nhóm lớp" (GD-03): hai lớp cùng một nhóm lớp ở CS5 (Đại số khối 8, Hình học khối 8; duyệt luôn để có buổi), một học sinh có hai ghi danh
// Chờ xếp lớp (gói Đại, gói Hình). Gói giả được thêm nếu chưa có. Mã có dấu riêng từng lần dựng để không trùng khi thử lại. Ngày dùng giờ Việt Nam hoặc tính theo tuần, không phụ thuộc ngày máy chủ.
import pg from 'pg';
import { DOMAIN } from './helpers';
import { DB_URL } from './bao-gia-seed';

export type GroupSeed = {
  tag: string;
  student: string;
  groupName: string;
  daiClass: string;
  hinhClass: string;
  daiEnrollment: string;
  hinhEnrollment: string;
};

export async function seedGroup(project: string): Promise<GroupSeed> {
  const tag = `${project === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query('select pg_advisory_xact_lock(7104)');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    await db.query(
      `insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code, grade_to_code) values
         ('LC-DAI-K08', 'Đại số 8 (giả)', 'LC', 'DAI', 'K08', null), ('LC-HINH-K08', 'Hình học 8 (giả)', 'LC', 'HINH', 'K08', null)
       on conflict (code) do nothing`,
    );
    const admin =
      (
        await db.query<{ id: string }>('select id from auth.users where email = $1', [
          `quantri.cs5@${DOMAIN}`,
        ])
      ).rows[0]?.id ?? '';
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [admin],
    );
    await db.query('set local role authenticated');
    const mk = async (subject: string, weekday: number) => {
      const r = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'),
           'year_code', '2627', 'subject_code', $1::text, 'grade_code', 'K08', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
           'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 6,
           'slots', jsonb_build_array(jsonb_build_object('weekday', $2::int, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
             'first_date', (date_trunc('week', current_date) + interval '14 days' + make_interval(days => $2::int - 1))::date)))) as r) x`,
        [subject, weekday],
      );
      const c = r.rows[0];
      if (!c) throw new Error('Không tạo được lớp giả.');
      for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET']) {
        await db.query('select app.transition_class($1::uuid, $2)', [c.id, step]);
      }
      return c;
    };
    // Hai lớp khác thứ trong tuần để không trùng giờ của cùng một học sinh.
    const dai = await mk('DAI', 1);
    const hinh = await mk('HINH', 2);
    await db.query('reset role');
    const branch = "(select id from app.branch where code = 'CS5')";
    const groupName = `Nhóm E2E ${tag}`;
    await db.query(
      `update app.class set group_id = (select app.create_class_group(${branch}, 'K08', $1)) where id = any($2::uuid[])`,
      [groupName, [dai.id, hinh.id]],
    );
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [
        `PHE2EGN${tag}`,
        `Phụ huynh E2E GN ${tag}`,
        `09${tag.slice(-6)}${project === 'dien-thoai' ? '2' : '1'}3`,
      ],
    );
    const student = `Em E2E ${tag} Nhóm`;
    const st = await db.query<{ id: string }>(
      `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
       values ($1, (select id from app.parent where code = $2), $3, 2013, ${branch}) returning id`,
      [`HSE2EGN${tag}`, `PHE2EGN${tag}`, student],
    );
    const enroll = async (n: number, pkg: string, subject: string) =>
      (
        await db.query<{ code: string }>(
          `insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
           values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = $4), $5, 'OFF', 'CHO_XEP_LOP', 12)
           returning code`,
          [`GNE2E${tag}${n}`, st.rows[0]?.id, `PHE2EGN${tag}`, pkg, subject],
        )
      ).rows[0]?.code ?? '';
    const daiEnrollment = await enroll(1, 'LC-DAI-K08', 'DAI');
    const hinhEnrollment = await enroll(2, 'LC-HINH-K08', 'HINH');
    await db.query('commit');
    return {
      tag,
      student,
      groupName,
      daiClass: dai.code,
      hinhClass: hinh.code,
      daiEnrollment,
      hinhEnrollment,
    };
  } catch (e) {
    await db.query('rollback').catch(() => undefined);
    throw e;
  } finally {
    await db.end();
  }
}
