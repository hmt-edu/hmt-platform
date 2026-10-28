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
// Bộ riêng cho bài bản ghi đơn (BH-05), để hai file bài chạy song song không đè nhau.
export const RECORD_SETUPS = {
  'may-tinh': { mark: 'E2EBHMT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 1000 },
  'dien-thoai': { mark: 'E2EBHDT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 1050 },
} as const;
export const recordSetupOf = (project: string): Setup =>
  RECORD_SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

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

export type SeededRecords = SeededOrders & {
  /** Mã đơn: bị từ chối (Nháp có lịch sử từ chối, hai dòng), huỷ, đã trình, đã duyệt. */
  records: { rejected: string; cancelled: string };
};

/**
 * Bộ đơn cho bản ghi BH-05: thêm hai đơn thẳng từ cơ hội (không qua báo giá): một đơn Nháp từng bị từ chối (lịch sử TRINH rồi TU_CHOI),
 * một đơn đã huỷ (huỷ bằng hàm nghiệp vụ). Đã trình, Đã duyệt có người duyệt đã chốt (Trưởng cơ sở) để bản ghi hiện tên.
 */
export async function seedOrderRecords(setup: Setup): Promise<SeededRecords> {
  const base = await seedOrders(setup);
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await db.query('begin');
    const ids = await db.query<{ code: string; opp: string; ps: string[] }>(
      `select q.code, q.opportunity_id as opp,
              array(select ps.id::text from app.prospect_student ps where ps.opportunity_id = q.opportunity_id order by ps.position) as ps
         from app.quotation q where q.code = any($1::text[])`,
      [[base.code.draft, base.code.rejected]],
    );
    const find = (code: string) => ids.rows.find((r) => r.code === code);
    const draft = find(base.code.draft);
    const rejectedQ = find(base.code.rejected);
    const packageId = (
      await db.query<{ id: string }>(`select id from app.sales_package where code = 'LC-TOAN-K09'`)
    ).rows[0]?.id;
    // Cơ hội phải ở L8 (R-CRM-16) mới tạo được đơn thẳng.
    await db.query(
      `update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = any($1::uuid[])`,
      [[draft?.opp, rejectedQ?.opp]],
    );
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.sale}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const line = (ps: string, hours: number) => ({
      kind: 'ENROL',
      prospect_student_id: ps,
      package_id: packageId,
      delivery_mode_code: 'OFF',
      quantity: hours,
      discounts: [],
    });
    const make = async (
      opp: string | undefined,
      lines: object[],
    ): Promise<{ id: string; code: string }> => {
      const r = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.create_order_from_opportunity($1::uuid, $2::jsonb) as r) x`,
        [opp, JSON.stringify(lines)],
      );
      return { id: r.rows[0]?.id ?? '', code: r.rows[0]?.code ?? '' };
    };
    const rejected = await make(draft?.opp, [
      line(draft?.ps[0] ?? '', 10),
      line(draft?.ps[1] ?? '', 5),
    ]);
    const cancelled = await make(rejectedQ?.opp, [line(rejectedQ?.ps[0] ?? '', 8)]);
    await db.query(`select app.cancel_order($1::uuid, 'KHACH_DOI_Y', 'Phụ huynh đổi ý')`, [
      cancelled.id,
    ]);
    await db.query('reset role');
    // Lịch sử bị từ chối dựng trực tiếp (đơn vẫn Nháp, R-TIEN-06): trình rồi bị từ chối kèm lý do.
    await db.query("set local session_replication_role = 'replica'");
    await db.query(
      `insert into app.sales_order_event (order_id, branch_id, event_code, from_status, to_status, created_by)
       select o.id, o.branch_id, 'TRINH', 'NHAP', 'DA_TRINH', o.created_by from app.sales_order o where o.id = $1::uuid`,
      [rejected.id],
    );
    await db.query(
      `insert into app.sales_order_event (order_id, branch_id, event_code, from_status, to_status, reason_catalog, reason_code, note, created_by)
       select o.id, o.branch_id, 'TU_CHOI', 'DA_TRINH', 'NHAP', 'REJECT_REASON', 'KHONG_DUNG_CHINH_SACH',
              'Chiết khấu dòng 2 chưa có văn bản phê duyệt', m.id
         from app.sales_order o, app.user_account m where o.id = $1::uuid and m.login_name = $2`,
      [rejected.id, `${setup.manager}@${DOMAIN}`],
    );
    // Người duyệt đã chốt cho đơn Đã trình, Đã duyệt (dựng trực tiếp ở bộ đơn BH-06 không có).
    await db.query(
      `update app.sales_order o set approval_route = 'QUAN_LY', assigned_approver_id = m.id, submitted_by = o.created_by
         from app.user_account m
        where m.login_name = $2 and o.code = any($1::text[])`,
      [[base.orders.dtrinh, base.orders.dduyet], `${setup.manager}@${DOMAIN}`],
    );
    await db.query(
      `update app.sales_order o set approved_by = m.id from app.user_account m where m.login_name = $2 and o.code = $1`,
      [base.orders.dduyet, `${setup.manager}@${DOMAIN}`],
    );
    await db.query('commit');
    return { ...base, records: { rejected: rejected.code, cancelled: cancelled.code } };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}
