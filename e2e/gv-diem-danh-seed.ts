// Dựng buổi học giả cho bài Playwright màn Điểm danh (GV-05): một lớp (tạo bằng hàm nghiệp vụ với quyền Admin CS5), hai buổi hôm nay do
// giáo viên gv.cs5 dạy (một Đã chốt có 3 em, một Nháp), một buổi của người khác. Dữ liệu giả, mã có dấu riêng của từng dự án.
import pg from 'pg';
import { DOMAIN } from './helpers';
import { DB_URL } from './bao-gia-seed';

export type AttendanceSeed = {
  chot: string;
  nhap: string;
  khac: string;
  /** Tên các em của buổi Đã chốt (em đầu đã có điểm nhận xét). */
  names: [string, string, string];
};

export async function seedAttendance(project: string): Promise<AttendanceSeed> {
  // Dấu riêng mỗi lần dựng (kể cả lần thử lại của Playwright): mã và tên không trùng lần trước.
  const tag = `${project === 'dien-thoai' ? 'DT' : 'MT'}${Date.now().toString().slice(-6)}`;
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query('select pg_advisory_xact_lock(7102)');
    await db.query(
      `insert into app.feature_flag (module_code, branch_id, enabled)
       select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
       on conflict (module_code, branch_id) do update set enabled = true`,
    );
    const id = async (key: string) =>
      (
        await db.query<{ id: string }>('select id from auth.users where email = $1', [
          `${key}@${DOMAIN}`,
        ])
      ).rows[0]?.id ?? '';
    const [gv, ta, gv2, admin] = [
      await id('gv.cs5'),
      await id('tg.cs5'),
      await id('gv2.cs5'),
      await id('quantri.cs5'),
    ];
    // Tạo lớp bằng hàm nghiệp vụ, đăng nhập giả là Admin (có hai bước), lớp bắt đầu hai tuần sau để không sinh buổi hôm nay.
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', $1::uuid,
         'claims', jsonb_build_object('sub', $1::uuid, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true)`,
      [admin],
    );
    await db.query('set local role authenticated');
    const created = await db.query<{ cls: string }>(
      `select app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'), 'year_code', '2627',
         'subject_code', 'TOAN', 'grade_code', 'K08', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
         'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
         'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
           'first_date', (date_trunc('week', current_date) + interval '14 days')::date, 'teacher_id', $1::uuid)))) ->> 'id' as cls`,
      [gv],
    );
    const cls = created.rows[0]?.cls ?? '';
    await db.query('reset role');
    const branch = "(select id from app.branch where code = 'CS5')";
    const today = "(now() at time zone 'Asia/Ho_Chi_Minh')::date";
    const session = async (no: number, status: string, teacher: string, assistant: string | null) =>
      (
        await db.query<{ id: string }>(
          `insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, assistant_id, status_code, type_code)
           values ($1, ${branch}, $2, ${today}, '18:00', '19:30', $3, $4, $5, 'CHINH') returning id`,
          [cls, no, teacher, assistant, status],
        )
      ).rows[0]?.id ?? '';
    const chot = await session(901, 'DA_CHOT', gv, ta);
    const nhap = await session(902, 'NHAP', gv, null);
    // Buổi của người khác: giáo viên thứ hai (đủ vai trò Giáo viên, F5), không phải gv.cs5.
    const khac = await session(903, 'DA_CHOT', gv2, null);
    const names: [string, string, string] = [
      `Em E2E ${tag} A`,
      `Em E2E ${tag} B`,
      `Em E2E ${tag} C`,
    ];
    await db.query(
      `insert into app.parent (code, full_name, phone, branch_id) values ($1, $2, $3, ${branch})`,
      [
        `PHE2EGV${tag}`,
        `Phụ huynh E2E GV ${tag}`,
        `09${tag.slice(-6)}${project === 'dien-thoai' ? '2' : '1'}1`,
      ],
    );
    for (const [i, name] of names.entries()) {
      const st = await db.query<{ id: string }>(
        `insert into app.student (code, parent_id, full_name, birth_year, branch_id)
         values ($1, (select id from app.parent where code = $2), $3, 2012, ${branch}) returning id`,
        [`HSE2EGV${tag}${i + 1}`, `PHE2EGV${tag}`, name],
      );
      const studentId = st.rows[0]?.id ?? '';
      for (const sid of [chot, khac]) {
        await db.query(
          `insert into app.session_attendance (session_id, class_id, branch_id, student_id) values ($1, $2, ${branch}, $3)`,
          [sid, cls, studentId],
        );
      }
    }
    // Em đầu đã có điểm nhận xét ở buổi Đã chốt (để thử hộp xác nhận Có mặt → Vắng, R-V2-36).
    await db.query(
      `insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
       select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
         from app.class_session s join app.class c on c.id = s.class_id join lateral app.review_criteria_for_subject(c.subject_code) rc on true
        where s.id = $1 on conflict do nothing`,
      [chot],
    );
    await db.query(
      `insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
       select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 3
         from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
        where sa.session_id = $1 and sa.student_id = (select id from app.student where code = $2) limit 1`,
      [chot, `HSE2EGV${tag}1`],
    );
    await db.query('commit');
    return { chot, nhap, khac, names };
  } catch (e) {
    await db.query('rollback').catch(() => undefined);
    throw e;
  } finally {
    await db.end();
  }
}

/** Giả một người khác vừa sửa ô của em (dùng cho bài hai người cùng sửa một ô, R-GV-09). */
export async function markAsAssistant(
  sessionId: string,
  studentName: string,
  status: string,
): Promise<void> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query(
      `update app.session_attendance set teacher_status_code = $3, teacher_marked_at = now(),
              teacher_marked_by = (select id from auth.users where email = $4)
        where session_id = $1 and student_id = (select id from app.student where full_name = $2)`,
      [sessionId, studentName, status, `tg.cs5@${DOMAIN}`],
    );
  } finally {
    await db.end();
  }
}
