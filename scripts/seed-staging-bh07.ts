// Dựng dữ liệu GIẢ trên hmt-staging để anh Trường thử BH-07 (Duyệt, Từ chối đơn): 1 Trưởng cơ sở giả, 1 Sale giả cùng cơ sở (CS5, bật Bán hàng),
// 3 đơn Đã trình do Sale giả lập: A trong trần (10%), B vượt trần (15% cộng tặng 4/48 giờ, khoảng 23,3%), C bình thường (để thử Từ chối).
// CHỈ chạy trên hmt-staging (workflow staging-du-lieu-thu.yml, bản chạy thật không có workflow này). Mật khẩu KHÔNG nằm trong repo hay log:
// nhận mã băm bcrypt qua biến HASH_TCS, HASH_SALE (anh giữ mật khẩu gốc ở file riêng trên máy). Chạy lại không nhân đôi (bỏ qua nếu đã có).
// Biến: STAGING_API_URL, STAGING_SECRET_KEY, STAGING_DB_URL, HASH_TCS, HASH_SALE.
import pg from 'pg';

const DOMAIN = 'thu.hoamatoan.invalid';
const PROD_REF = 'nwnvzmbouqlvtbnncgbm';
const ACCOUNTS = [
  {
    key: 'truongcs.thu',
    name: 'Trưởng cơ sở thử BH-07 (giả)',
    role: 'BRANCH_MANAGER',
    hashEnv: 'HASH_TCS',
  },
  { key: 'sale.thu', name: 'Sale thử BH-07 (giả)', role: 'SALES', hashEnv: 'HASH_SALE' },
] as const;

type AuthBody = {
  id?: string;
  users?: { id: string; email: string }[];
  msg?: string;
  message?: string;
};

async function authAdmin(
  apiUrl: string,
  key: string,
  path: string,
  init: RequestInit = {},
): Promise<AuthBody> {
  const response = await fetch(`${apiUrl}/auth/v1/admin${path}`, {
    ...init,
    headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
  });
  const body = (await response.json().catch(() => ({}))) as AuthBody;
  if (!response.ok)
    throw new Error(`Supabase Auth ${path}: ${response.status} ${body.msg ?? body.message ?? ''}`);
  return body;
}

async function main() {
  const { STAGING_API_URL: api, STAGING_SECRET_KEY: key, STAGING_DB_URL: dbUrl } = process.env;
  if (!api || !key || !dbUrl)
    throw new Error('Thiếu STAGING_API_URL, STAGING_SECRET_KEY hoặc STAGING_DB_URL.');
  if (`${api} ${dbUrl}`.includes(PROD_REF)) throw new Error('Địa chỉ trỏ vào bản chạy thật: dừng.');
  const db = new pg.Client({ connectionString: dbUrl });
  await db.connect();
  try {
    const marker = await db.query<{ staging: boolean }>(
      "select exists (select from app.holiday where name like '%(thử nghiệm)') as staging",
    );
    if (!marker.rows[0]?.staging)
      throw new Error(
        'Không thấy dữ liệu giả (seed.sql): dừng, để không tạo dữ liệu giả trên bản chạy thật.',
      );

    // 1. Tài khoản: Auth (mật khẩu qua mã băm) rồi hồ sơ, vai trò, quản lý trực tiếp.
    const existing = await authAdmin(api, key, '/users?per_page=1000');
    const byEmail = new Map((existing.users ?? []).map((u) => [u.email, u.id]));
    const ids: Record<string, string> = {};
    for (const a of ACCOUNTS) {
      const email = `${a.key}@${DOMAIN}`;
      const hash = process.env[a.hashEnv];
      let id = byEmail.get(email);
      if (!id) {
        if (!hash?.startsWith('$2a$')) throw new Error(`Thiếu mã băm bcrypt ${a.hashEnv}.`);
        const created = await authAdmin(api, key, '/users', {
          method: 'POST',
          body: JSON.stringify({ email, password_hash: hash, email_confirm: true }),
        });
        id = created.id;
      }
      if (!id) throw new Error(`Không tạo được tài khoản ${a.key}.`);
      ids[a.key] = id;
      await db.query(
        `insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
         values ($1, $2, $3, (select id from app.branch where code = 'CS5'), false)
         on conflict (id) do update set display_name = excluded.display_name, is_locked = false`,
        [id, a.name, email],
      );
      await db.query('update app.user_role set is_active = (role_code = $2) where user_id = $1', [
        id,
        a.role,
      ]);
      await db.query(
        `insert into app.user_role (user_id, role_code) values ($1, $2) on conflict (user_id, role_code) do update set is_active = true`,
        [id, a.role],
      );
    }
    // Quản lý trực tiếp của Sale là Trưởng cơ sở (R-HT-06): cờ cục bộ của hàm set_manager, bỏ qua trigger bằng vai trò sao chép trong giao dịch.
    await db.query('begin');
    await db.query("set local session_replication_role = 'replica'");
    await db.query('update app.user_account set manager_id = $1 where id = $2', [
      ids['truongcs.thu'],
      ids['sale.thu'],
    ]);
    await db.query('commit');

    // 2. Ba đơn Đã trình do Sale giả lập (bỏ qua nếu đã có).
    const have = await db.query("select 1 from app.parent where phone = '0900000101'");
    if (have.rowCount && have.rowCount > 0) {
      console.log('Đã có dữ liệu đơn thử: bỏ qua phần đơn.');
    } else {
      await db.query('begin');
      await db.query('select pg_advisory_xact_lock(7101)');
      await db.query(
        `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
           'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
           from app.user_account u where u.login_name = $1`,
        [`sale.thu@${DOMAIN}`],
      );
      await db.query('set local role authenticated');
      const pkg = (
        await db.query<{ id: string }>(
          "select id from app.sales_package where code = 'LC-TOAN-K09'",
        )
      ).rows[0]?.id;
      const pol = async (code: string) =>
        (
          await db.query<{ id: string }>('select id from app.discount_policy where code = $1', [
            code,
          ])
        ).rows[0]?.id;
      const term = (
        await db.query<{ id: string }>(
          "select id from app.payment_term where code = 'CHIA_3_DOT' and version = 1",
        )
      ).rows[0]?.id;
      const thuongLuong = await pol('GIAM_THUONG_LUONG');
      const sauThang = await pol('GIAM_6_THANG');
      const tangGio = await pol('TANG_GIO');
      const cases = [
        {
          n: 1,
          hours: 48,
          discounts: [{ policy_id: thuongLuong, value: 10 }],
          note: 'A trong trần 10%',
        },
        {
          n: 2,
          hours: 48,
          discounts: [
            { policy_id: thuongLuong, value: 10 },
            { policy_id: sauThang, value: null },
            { policy_id: tangGio, value: 4 },
          ],
          note: 'B vượt trần: 15% cộng tặng 4/48 giờ',
        },
        { n: 3, hours: 24, discounts: [], note: 'C bình thường' },
      ];
      const codes: string[] = [];
      for (const c of cases) {
        const nn = String(c.n).padStart(2, '0');
        const phone = `0900000${100 + c.n}`;
        const lead = await db.query<{ id: string }>(
          `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text, 'student_name', $3::text,
             'student_birth_year', 2012, 'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
             'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
          [`Chị Thử ${nn}`, phone, `HS Thử ${nn}`],
        );
        const leadId = lead.rows[0]?.id ?? '';
        await db.query(`select app.change_lead_stage($1::uuid, 'C4', 'C4C')`, [leadId]);
        const opp = await db.query<{ id: string }>(
          `select r ->> 'id' as id from (select app.create_opportunity($1::uuid) as r) x`,
          [leadId],
        );
        const oppId = opp.rows[0]?.id ?? '';
        const ps = (
          await db.query<{ id: string }>(
            'select id from app.prospect_student where opportunity_id = $1::uuid and position = 1',
            [oppId],
          )
        ).rows[0]?.id;
        // Cơ hội phải ở L8 mới tạo được đơn (R-CRM-16): dựng dữ liệu giả bằng quyền chủ rồi quay lại quyền Sale.
        await db.query('reset role');
        await db.query("set local session_replication_role = 'replica'");
        await db.query(
          "update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = $1::uuid",
          [oppId],
        );
        await db.query("set local session_replication_role = 'origin'");
        await db.query('set local role authenticated');
        const lines = [
          {
            kind: 'ENROL',
            prospect_student_id: ps,
            package_id: pkg,
            delivery_mode_code: 'OFF',
            quantity: c.hours,
            discounts: c.discounts,
          },
        ];
        const order = await db.query<{ id: string; code: string }>(
          `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_order_from_opportunity($1::uuid, $2::jsonb) as r) x`,
          [oppId, JSON.stringify(lines)],
        );
        const o = order.rows[0];
        await db.query('select app.save_order($1::uuid, null, $2::uuid)', [o?.id, term]);
        await db.query('select app.submit_order($1::uuid)', [o?.id]);
        codes.push(`${o?.code ?? '?'} (${c.note})`);
      }
      await db.query('commit');
      console.log(`Đã lập 3 đơn Đã trình: ${codes.join('; ')}`);
    }
    console.log('Tài khoản giả: truongcs.thu, sale.thu (cơ sở CS5).');
  } catch (error) {
    await db.query('rollback').catch(() => undefined);
    throw error;
  } finally {
    await db.end();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
