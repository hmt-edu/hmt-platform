// Dựng và dọn cơ hội giả cho bài Playwright màn Cơ hội. Dữ liệu giả dựng bằng hàm nghiệp vụ (create_lead, create_opportunity,
// change_opportunity_stage, create_student_test) với quyền của một nhân viên Tuyển sinh; tìm bằng dấu riêng của từng dự án.
import pg from 'pg';
import { DOMAIN } from './helpers';

export const DB_URL = process.env.DB_URL ?? '';

// Tài khoản có quyền Cơ hội · Tạo, Sửa ở CS5. Mỗi dự án một dấu, một tài khoản.
export const SETUPS = {
  'may-tinh': { mark: 'E2ECHMT', account: 'sale.cs5', phone: 500 },
  'dien-thoai': { mark: 'E2ECHDT', account: 'kiem.cs5', phone: 600 },
} as const;
export type Setup = { mark: string; account: string; phone: number };
export const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

/** Mã cơ hội, lead dựng sẵn: `fresh` L1 có học sinh; `nostudent` L1 chưa có học sinh; `gated` L5 còn phiếu dang dở; `skip` L5 chưa có phiếu; `lonely` là lead chưa có cơ hội. */
export type Seeded = {
  run: string;
  parent: Record<'fresh' | 'nostudent' | 'gated' | 'skip' | 'lonely', string>;
  opportunity: Record<'fresh' | 'nostudent' | 'gated' | 'skip', { id: string; code: string }>;
  lonelyLeadId: string;
};

export async function clear(db: pg.Client, mark: string): Promise<void> {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const leads = `(select id from app.lead where parent_name like $1)`;
  const opps = `(select id from app.opportunity where lead_id in ${leads})`;
  const like = [`%${mark}%`];
  await db.query(
    `delete from app.note where (entity_type = 'LEAD' and entity_id in ${leads}) or (entity_type = 'OPPORTUNITY' and entity_id in ${opps})`,
    like,
  );
  await db.query(
    `delete from app.appointment where lead_id in ${leads} or opportunity_id in ${opps}`,
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
    const parent = {
      fresh: `Chị ${setup.mark} moi ${run}`,
      nostudent: `Chị ${setup.mark} chuaco ${run}`,
      gated: `Chị ${setup.mark} dangdo ${run}`,
      skip: `Chị ${setup.mark} botest ${run}`,
      lonely: `Chị ${setup.mark} chuacohoi ${run}`,
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
    const lead = async (name: string, i: number, student: string | null): Promise<string> => {
      const r = await db.query<{ id: string }>(
        `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
           'student_name', $3::text, 'student_birth_year', case when $3::text is null then null else 2012 end,
           'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
           'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
        [name, phone(i), student],
      );
      return r.rows[0]?.id ?? '';
    };
    const opp = async (leadId: string): Promise<{ id: string; code: string }> => {
      const r = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_opportunity($1::uuid) as r) x`,
        [leadId],
      );
      return { id: r.rows[0]?.id ?? '', code: r.rows[0]?.code ?? '' };
    };
    const fresh = await opp(await lead(parent.fresh, 0, 'Em Mới'));
    const nostudent = await opp(await lead(parent.nostudent, 1, null));
    const gated = await opp(await lead(parent.gated, 2, 'Em Dở'));
    const skip = await opp(await lead(parent.skip, 3, 'Em Bỏ'));
    const lonelyLeadId = await lead(parent.lonely, 4, 'Em Một Mình');
    for (const o of [gated, skip]) {
      await db.query(`select app.change_opportunity_stage($1::uuid, 'L5')`, [o.id]);
    }
    await db.query(
      `select app.create_student_test($1::uuid, jsonb_build_object('subject_code', 'TOAN',
         'grade_code', (select code from app.catalog_item where catalog_code = 'GRADE' order by sort_order limit 1),
         'mode_code', 'OFFLINE', 'level_code', 'CO_BAN', 'exam_name', 'Toán cơ bản',
         'scheduled_at', now() + interval '3 days'))`,
      [gated.id],
    );
    await db.query('reset role');
    await db.query('commit');
    return { run, parent, opportunity: { fresh, nostudent, gated, skip }, lonelyLeadId };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}

/** Dọn các cơ hội, lead giả của một dấu (kết nối riêng). */
export async function clearMark(mark: string): Promise<void> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, mark);
  } finally {
    await db.end();
  }
}
