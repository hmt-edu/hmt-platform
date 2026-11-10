// Dựng dữ liệu giả cho bài Playwright cụm Ghi danh (GD-01, GD-02, GD-04, GD-06, GD-03, BH-08): lớp đã duyệt ở CS5 (tạo bằng hàm nghiệp vụ với quyền Admin),
// học sinh, ghi danh (Chờ xếp lớp, Đang học có sổ giờ). Dữ liệu giả; mã có dấu riêng mỗi lần dựng (kể cả lần thử lại của Playwright).
import pg from 'pg';
import { DOMAIN } from './helpers';
import { DB_URL } from './bao-gia-seed';

export type GhiDanhSeed = {
  tag: string;
  classCode: string;
  /** Học sinh, mã ghi danh. */
  waiting: { student: string; code: string; id: string };
  learning: { student: string; code: string; id: string };
};

export async function seedGhiDanh(project: string): Promise<GhiDanhSeed> {
  const tag = `${project === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query('select pg_advisory_xact_lock(7103)');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
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
    // Lớp Đại số khối 9 (khớp gói LC-TOAN-K09), thứ Hai mỗi tuần, bắt đầu hai tuần sau; duyệt luôn để có buổi.
    const created = await db.query<{ id: string; code: string }>(
      `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'),
         'year_code', '2627', 'subject_code', 'DAI', 'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 6,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', current_date) + interval '14 days')::date)))) as r) x`,
    );
    const cls = created.rows[0];
    if (!cls) throw new Error('Không tạo được lớp giả.');
    for (const step of ['DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET']) {
      await db.query('select app.transition_class($1::uuid, $2)', [cls.id, step]);
    }
    await db.query('reset role');
    const branch = "(select id from app.branch where code = 'CS5')";
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [
        `PHE2EGD${tag}`,
        `Phụ huynh E2E GD ${tag}`,
        `09${tag.slice(-6)}${project === 'dien-thoai' ? '2' : '1'}2`,
      ],
    );
    const students = [`Em E2E ${tag} Chờ`, `Em E2E ${tag} Học`];
    const out: { id: string; code: string }[] = [];
    for (const [i, name] of students.entries()) {
      const st = await db.query<{ id: string }>(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2011, ${branch}) returning id`,
        [`HSE2EGD${tag}${i + 1}`, `PHE2EGD${tag}`, name],
      );
      const e = await db.query<{ id: string; code: string }>(
        `insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
         values ($1, $2, (select id from app.parent where code = $3), ${branch}, (select id from app.sales_package where code = 'LC-TOAN-K09'), 'DAI', 'OFF', $4, 24)
         returning id, code`,
        [
          `GDE2E${tag}${i + 1}`,
          st.rows[0]?.id,
          `PHE2EGD${tag}`,
          i === 0 ? 'CHO_XEP_LOP' : 'DANG_HOC',
        ],
      );
      out.push(e.rows[0] ?? { id: '', code: '' });
    }
    const learning = out[1];
    if (!learning) throw new Error('Thiếu ghi danh giả.');
    await db.query(
      `insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values ($1, $2, ${branch}, current_date)`,
      [learning.id, cls.id],
    );
    await db.query(
      `insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values ($1, ${branch}, 'CAP_MUA', 24)`,
      [learning.id],
    );
    await db.query('commit');
    return {
      tag,
      classCode: cls.code,
      waiting: { student: students[0] ?? '', code: out[0]?.code ?? '', id: out[0]?.id ?? '' },
      learning: { student: students[1] ?? '', code: learning.code, id: learning.id },
    };
  } catch (e) {
    await db.query('rollback').catch(() => undefined);
    throw e;
  } finally {
    await db.end();
  }
}
