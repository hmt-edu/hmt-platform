// Dựng đơn hàng giả cho bài Playwright màn Đơn hàng (BH-06). Dựa trên bộ báo giá giả của bao-gia-seed (hàm nghiệp vụ create_lead, create_opportunity,
// save_quotation, send_quotation, create_order_from_quotation), rồi đặt tình trạng Đã trình, Đã duyệt trực tiếp trong cơ sở dữ liệu giả (chỉ để dựng
// danh sách; luồng trình, duyệt đã có bài pgTAP).
import pg from 'pg';
import { DOMAIN } from './helpers';
import { DB_URL, seed, type Seeded, type Setup } from './bao-gia-seed';

export { DB_URL, clearMark } from './bao-gia-seed';

// Mỗi dự án một dấu và số điện thoại riêng, khác bộ bao-gia để hai file bài chạy song song không đè nhau.
export const ORDER_SETUPS = {
  'may-tinh': { mark: 'E2EDHMT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 900 },
  'dien-thoai': { mark: 'E2EDHDT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 950 },
} as const;
export const orderSetupOf = (project: string): Setup =>
  ORDER_SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

export type SeededOrders = Seeded & { orders: { nhap: string; dtrinh: string; dduyet: string } };

export async function seedOrders(setup: Setup): Promise<SeededOrders> {
  const base = await seed(setup);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    // Báo giá Đã gửi và Quá hạn chuyển thành đơn: cơ hội phải ở L8 (R-CRM-16).
    for (const code of [base.code.sent, base.code.overdue]) {
      await db.query(
        `update app.opportunity set stage_code = 'L8', substage_code = 'L8A'
          where id = (select opportunity_id from app.quotation where code = $1)`,
        [code],
      );
    }
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.sale}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const make = async (quotationCode: string): Promise<string> => {
      const r = await db.query<{ code: string }>(
        `select r ->> 'code' as code from (select app.create_order_from_quotation(
           (select id from app.quotation where code = $1)) as r) x`,
        [quotationCode],
      );
      return r.rows[0]?.code ?? '';
    };
    const dtrinh = await make(base.code.sent);
    const dduyet = await make(base.code.overdue);
    await db.query('reset role');
    // Đặt tình trạng trực tiếp (bỏ qua ràng buộc để dựng dữ liệu hiển thị).
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `update app.sales_order set status_code = 'DA_TRINH', submitted_at = now() where code = $1`,
      [dtrinh],
    );
    await db.query(
      `update app.sales_order set status_code = 'DA_DUYET', submitted_at = now(), approved_at = now() where code = $1`,
      [dduyet],
    );
    await db.query('commit');
    return { ...base, orders: { nhap: base.orderCode, dtrinh, dduyet } };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}
