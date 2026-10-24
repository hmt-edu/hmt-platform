// Dựng và dọn lead, cơ hội trùng cho bài Playwright gộp trùng (TS-10). Dựng bằng hàm nghiệp vụ (create_lead, create_opportunity,
// create_appointment) với quyền của một nhân viên Tuyển sinh; tìm bằng dấu riêng của từng dự án.
import pg from 'pg';
import { clearMark } from './co-hoi-seed';
import { DOMAIN } from './helpers';

export { clearMark };
export const DB_URL = process.env.DB_URL ?? '';

export const SETUPS = {
  'may-tinh': { mark: 'E2EGTMT', account: 'sale.cs5', phone: 700 },
  'dien-thoai': { mark: 'E2EGTDT', account: 'cskh.cs5', phone: 800 },
} as const;
export type Setup = { mark: string; account: string; phone: number };
export const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

type Rec = { id: string; code: string };
/** Hai lead cùng SĐT (lead.a, lead.b; b có lịch hẹn và hai ghi chú), hai cơ hội cùng phụ huynh (opp.a, opp.b; b có lịch hẹn), một lead không trùng. */
export type Seeded = {
  run: string;
  /** SĐT chung của lead a, b. */
  phone: string;
  lead: { a: Rec; b: Rec; alone: Rec };
  opp: { a: Rec; b: Rec };
};

export async function seed(setup: Setup): Promise<Seeded> {
  await clearMark(setup.mark);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    const run = Date.now().toString(36).slice(-4).toUpperCase();
    const phoneBase = (Date.now() % 1e6) * 1000 + setup.phone;
    const phone = (i: number) =>
      `0${String(phoneBase + i)
        .padStart(9, '0')
        .slice(-9)}`;
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.account}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const lead = async (name: string, i: number): Promise<Rec> => {
      const r = await db.query<Rec>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_lead(jsonb_build_object(
           'parent_name', $1::text, 'parent_phone', $2::text, 'student_name', 'Em Một', 'student_birth_year', 2012,
           'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
           'channel_code', 'FACEBOOK_ADS_LEAD_FORM'), true) as r) x`,
        [name, phone(i)],
      );
      return r.rows[0] ?? { id: '', code: '' };
    };
    const opp = async (leadId: string): Promise<Rec> => {
      const r = await db.query<Rec>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_opportunity($1::uuid) as r) x`,
        [leadId],
      );
      return r.rows[0] ?? { id: '', code: '' };
    };
    const a = await lead(`Chị ${setup.mark} a ${run}`, 0);
    const b = await lead(`Chị ${setup.mark} b ${run}`, 0);
    const alone = await lead(`Chị ${setup.mark} mot ${run}`, 1);
    await db.query(
      `select app.create_appointment($1::uuid, 'GOI_DIEN', now() + interval '2 days', 'Gọi lại hỏi lịch học')`,
      [b.id],
    );
    const c = await lead(`Chị ${setup.mark} c ${run}`, 2);
    const d = await lead(`Chị ${setup.mark} d ${run}`, 2);
    const oa = await opp(c.id);
    const ob = await opp(d.id);
    await db.query(
      `select app.create_appointment(null, 'GOI_DIEN', now() + interval '3 days', 'Hẹn của cơ hội b', null, null, $1::uuid)`,
      [ob.id],
    );
    await db.query('reset role');
    // Ghi chú thường của lead b (hai dòng), để hộp liệt kê.
    await db.query(
      `insert into app.note (entity_type, entity_id, body) values
         ('LEAD', $1::uuid, 'PH nhắn Zalo hỏi học phí lớp 9.'), ('LEAD', $1::uuid, 'Hẹn gọi lại sáng thứ 5.')`,
      [b.id],
    );
    await db.query('commit');
    return { run, phone: phone(0), lead: { a, b, alone }, opp: { a: oa, b: ob } };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}

/**
 * Lead cùng SĐT ở CƠ SỞ KHÁC (tài khoản Tuyển sinh CS1): dựng để Admin thấy bản ở cơ sở khác trong hộp Gộp trùng (R-CRM-22).
 * Tên có dấu của dự án nên `clearMark` dọn được.
 */
export async function seedOtherBranchLead(setup: Setup, phone: string, run: string): Promise<Rec> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`sale.cs1@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const r = await db.query<Rec>(
      `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_lead(jsonb_build_object(
         'parent_name', $1::text, 'parent_phone', $2::text, 'student_name', 'Em Một', 'student_birth_year', 2012,
         'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
         'channel_code', 'FACEBOOK_ADS_LEAD_FORM'), true) as r) x`,
      [`Chị ${setup.mark} khac co so ${run}`, phone],
    );
    await db.query('reset role');
    await db.query('commit');
    return r.rows[0] ?? { id: '', code: '' };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}
