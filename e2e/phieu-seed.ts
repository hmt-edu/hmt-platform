// Dựng và dọn phiếu kiểm tra giả cho bài Playwright màn Phiếu kiểm tra. Dữ liệu dựng bằng hàm nghiệp vụ (create_lead,
// create_opportunity, change_opportunity_stage, create_student_test, start_student_test, submit_student_test, cancel_student_test)
// với quyền của một nhân viên Tuyển sinh; tìm bằng dấu riêng của từng dự án.
import pg from 'pg';
import { DOMAIN } from './helpers';

export const DB_URL = process.env.DB_URL ?? '';

// Tài khoản có quyền Phiếu kiểm tra · Tạo, Sửa, Huỷ ở CS5. Mỗi dự án một dấu, một tài khoản.
export const SETUPS = {
  'may-tinh': { mark: 'E2EPKMT', account: 'kiem.cs5', phone: 700 },
  'dien-thoai': { mark: 'E2EPKDT', account: 'sale.cs5', phone: 800 },
} as const;
export type Setup = { mark: string; account: string; phone: number };
export const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

type Item = { id: string; code: string };
/** `edit`: phiếu Nháp để đổi lịch, huỷ, mở lại; `kanban`: Nháp để bấm Bắt đầu test ở thẻ; `review`: Chờ giáo viên chấm để nhập kết quả,
 *  Hoàn thành, lùi bước; `gated`: cơ hội có phiếu Nháp dang dở; `fresh`: cơ hội L5 chưa có phiếu (thử Tạo phiếu). */
export type Seeded = {
  run: string;
  student: Record<'edit' | 'kanban' | 'review' | 'fresh', string>;
  test: Record<'edit' | 'kanban' | 'review', Item>;
  opportunity: Record<'edit' | 'kanban' | 'review' | 'fresh', Item>;
};

export async function clear(db: pg.Client, mark: string): Promise<void> {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const leads = `(select id from app.lead where parent_name like $1)`;
  const opps = `(select id from app.opportunity where lead_id in ${leads})`;
  const tests = `(select id from app.student_test where opportunity_id in ${opps})`;
  const like = [`%${mark}%`];
  await db.query(
    `delete from app.note where (entity_type = 'LEAD' and entity_id in ${leads}) or (entity_type = 'OPPORTUNITY' and entity_id in ${opps}) or (entity_type = 'STUDENT_TEST' and entity_id in ${tests})`,
    like,
  );
  await db.query(
    `delete from app.appointment where lead_id in ${leads} or opportunity_id in ${opps} or student_test_id in ${tests}`,
    like,
  );
  await db.query(`delete from app.student_test where opportunity_id in ${opps}`, like);
  await db.query(`delete from app.opportunity where lead_id in ${leads}`, like);
  await db.query('delete from app.lead where parent_name like $1', like);
  await db.query(
    'delete from app.student where parent_id in (select id from app.parent where full_name like $1)',
    like,
  );
  await db.query('delete from app.parent where full_name like $1', like);
  await db.query('commit');
}

export async function seed(setup: Setup): Promise<Seeded> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, setup.mark);
    const run = Date.now().toString(36).slice(-4).toUpperCase();
    const phoneBase = (Date.now() % 1e6) * 1000 + setup.phone;
    const student = {
      edit: `Em Sửa ${setup.mark}`,
      kanban: `Em Thẻ ${setup.mark}`,
      review: `Em Chấm ${setup.mark}`,
      fresh: `Em Mới ${setup.mark}`,
    };
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.account}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const phone = (i: number) =>
      `0${String(phoneBase + i)
        .padStart(9, '0')
        .slice(-9)}`;
    const opp = async (key: keyof typeof student, i: number): Promise<Item> => {
      const lead = await db.query<{ id: string }>(
        `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
           'student_name', $3::text, 'student_birth_year', 2012,
           'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
           'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
        [`Chị ${setup.mark} ${key} ${run}`, phone(i), student[key]],
      );
      // Lead chỉ tạo được cơ hội khi ở C4C (luật 26/10).
      await db.query(`select app.change_lead_stage($1::uuid, 'C4', 'C4C')`, [lead.rows[0]?.id]);
      const o = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_opportunity($1::uuid) as r) x`,
        [lead.rows[0]?.id],
      );
      const item = { id: o.rows[0]?.id ?? '', code: o.rows[0]?.code ?? '' };
      await db.query(`select app.change_opportunity_stage($1::uuid, 'L5')`, [item.id]);
      return item;
    };
    const test = async (o: Item, days: number): Promise<Item> => {
      const r = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_student_test($1::uuid, jsonb_build_object(
           'subject_code', 'TOAN', 'grade_code', (select code from app.catalog_item where catalog_code = 'GRADE' order by sort_order limit 1),
           'mode_code', 'OFFLINE', 'level_code', 'CO_BAN', 'exam_name', 'Toán cơ bản',
           'scheduled_at', now() + ($2::int * interval '1 day'))) as r) x`,
        [o.id, days],
      );
      return { id: r.rows[0]?.id ?? '', code: r.rows[0]?.code ?? '' };
    };
    const edit = await opp('edit', 0);
    const kanban = await opp('kanban', 1);
    const review = await opp('review', 2);
    const fresh = await opp('fresh', 3);
    const tEdit = await test(edit, 2);
    const tKanban = await test(kanban, 1);
    const tReview = await test(review, 1);
    await db.query('select app.start_student_test($1::uuid)', [tReview.id]);
    await db.query('select app.submit_student_test($1::uuid)', [tReview.id]);
    await db.query('reset role');
    await db.query('commit');
    return {
      run,
      student,
      test: { edit: tEdit, kanban: tKanban, review: tReview },
      opportunity: { edit, kanban, review, fresh },
    };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}

/** Dọn các phiếu, cơ hội, lead giả của một dấu (kết nối riêng). */
export async function clearMark(mark: string): Promise<void> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, mark);
  } finally {
    await db.end();
  }
}
