// Dựng và dọn lịch hẹn giả cho bài Playwright màn Lịch hẹn (dùng chung bài chức năng và bài so sánh bản vẽ).
import pg from 'pg';
import { DOMAIN } from './helpers';

export const DB_URL = process.env.DB_URL ?? '';

export const SETUPS = {
  'may-tinh': { mark: 'E2ELHMT', account: 'truongcs.cs5', phone: 300 },
  'dien-thoai': { mark: 'E2ELHDT', account: 'cskh.cs5', phone: 400 },
} as const;
export type Setup = { mark: string; account: string; phone: number };
export const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

export type Seeded = { parent: string; run: string };

export async function clear(db: pg.Client, mark: string): Promise<void> {
  await db.query('begin');
  await db.query("set local session_replication_role = 'replica'");
  const ids = `(select id from app.lead where parent_name like $1)`;
  await db.query(`delete from app.note where entity_type = 'LEAD' and entity_id in ${ids}`, [
    `%${mark}%`,
  ]);
  await db.query(`delete from app.appointment where lead_id in ${ids}`, [`%${mark}%`]);
  await db.query('delete from app.lead where parent_name like $1', [`%${mark}%`]);
  await db.query('delete from app.parent where full_name like $1', [`%${mark}%`]);
  await db.query('commit');
}

export async function seed(setup: Setup): Promise<Seeded> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, setup.mark);
    const run = Date.now().toString(36).slice(-4).toUpperCase();
    const phoneBase = (Date.now() % 1e6) * 1000 + setup.phone;
    const parent = `Chị ${setup.mark} ${run}`;
    await db.query('begin');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.account}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const lead = await db.query<{ id: string }>(
      `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
         'student_name', 'Em Thử', 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
         'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
      [parent, `0${String(phoneBase).padStart(9, '0').slice(-9)}`],
    );
    const id = lead.rows[0]?.id ?? '';
    const make = async (code: string, title: string, shift: string): Promise<string> => {
      const r = await db.query<{ id: string }>(
        // Mốc 12:00 hôm nay theo giờ Việt Nam, không dùng now(): chạy gần nửa đêm (sau 23:10 hoặc ngay sau 00:00) thì các lịch lệch vài phút
        // không nhảy sang ngày khác, nhóm "Hôm nay" vẫn đủ (bài từng trượt khi chạy sau 00:00).
        `select app.create_appointment($1::uuid, $2,
           ((date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '12 hours') at time zone 'Asia/Ho_Chi_Minh') + $3::interval, $4) as id`,
        [id, code, shift, `${title} ${setup.mark}`],
      );
      return r.rows[0]?.id ?? '';
    };
    await make('GOI_DIEN', 'Gọi tư vấn', '0 minutes');
    await make('ZALO', 'Zalo báo giá', '-1 minute');
    const done = await make('GAP_TRUC_TIEP', 'Gặp xong', '-2 minutes');
    await make('EMAIL', 'Email quá hạn', '-10 days');
    await make('GOI_DIEN', 'Hẹn để dời', '30 minutes');
    await make('GOI_DIEN', 'Hẹn hoàn tác trong danh sách', '40 minutes');
    await make('GOI_DIEN', 'Hẹn hoàn tác ở trang lead', '50 minutes');
    await db.query('select app.complete_appointment($1::uuid)', [done]);
    await db.query('reset role');
    await db.query('commit');
    return { parent, run };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}

/** Dọn các lịch hẹn, lead giả của một dấu (kết nối riêng). */
export async function clearMark(mark: string): Promise<void> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, mark);
  } finally {
    await db.end();
  }
}
