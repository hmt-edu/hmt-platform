// Dựng và dọn báo giá giả cho bài Playwright màn Báo giá (BH-01). Dữ liệu dựng bằng hàm nghiệp vụ (create_lead, create_opportunity,
// save_quotation, send_quotation, reject_quotation) với quyền của một nhân viên Sale CS5; tìm bằng dấu riêng của từng dự án.
import pg from 'pg';
import { DOMAIN } from './helpers';

export const DB_URL = process.env.DB_URL ?? '';

// Sale CS5 lập báo giá; Trưởng cơ sở CS5 xem và xuất. Mỗi dự án một dấu, một cặp tài khoản (CS5 đã bật Bán hàng, seed.sql).
export const SETUPS = {
  'may-tinh': { mark: 'E2EBGMT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 700 },
  'dien-thoai': { mark: 'E2EBGDT', sale: 'sale.cs5', manager: 'truongcs.cs5', phone: 800 },
} as const;
export type Setup = { mark: string; sale: string; manager: string; phone: number };
export const setupOf = (project: string): Setup =>
  SETUPS[project === 'dien-thoai' ? 'dien-thoai' : 'may-tinh'];

export type Seeded = {
  /** Tên phụ huynh của từng báo giá dựng sẵn. */
  parent: Record<'draft' | 'sent' | 'overdue' | 'rejected' | 'converted', string>;
  /** Mã báo giá. */
  code: Record<'draft' | 'sent' | 'overdue' | 'rejected' | 'converted', string>;
  /** Mã đơn nháp sinh từ báo giá "Đã chuyển đơn". */
  orderCode: string;
  students: { draft: [string, string] };
};

export async function clearMark(mark: string): Promise<void> {
  const db = new pg.Client({ connectionString: DB_URL });
  await db.connect();
  try {
    await clear(db, mark);
  } finally {
    await db.end();
  }
}

async function clear(db: pg.Client, mark: string): Promise<void> {
  await db.query('begin');
  // Các bộ dữ liệu bán hàng cùng cấp mã (bộ đếm khoá dòng): chạy tuần tự để hai dự án chạy song song không khoá chéo (deadlock).
  await db.query('select pg_advisory_xact_lock(7101)');
  await db.query("set local session_replication_role = 'replica'");
  const like = [`%${mark}%`];
  const leads = `(select id from app.lead where parent_name like $1)`;
  const opps = `(select id from app.opportunity where lead_id in ${leads})`;
  const quotes = `(select id from app.quotation where opportunity_id in ${opps})`;
  // Đơn sinh từ báo giá, và đơn tạo thẳng từ cơ hội (không có dòng báo giá).
  const orders = `(select order_id from app.sales_order_line where quotation_line_id in (select id from app.quotation_line where quotation_id in ${quotes})
    union select id from app.sales_order where opportunity_id in ${opps})`;
  await db.query(
    `delete from app.sales_order_line_discount where line_id in (select id from app.sales_order_line where order_id in ${orders})`,
    like,
  );
  await db.query(
    `delete from app.note where entity_type = 'SALES_ORDER' and entity_id in ${orders}`,
    like,
  );
  // Phiếu thu của các đơn này (khoản tiền vào, phân bổ, lịch sử, phiếu), nếu bài phiếu thu đã tạo.
  const receipts = `(select id from app.receipt where order_id in ${orders})`;
  await db.query(
    `delete from app.money_in_allocation where money_in_id in (select id from app.money_in where receipt_id in ${receipts})`,
    like,
  );
  await db.query(`delete from app.money_in where receipt_id in ${receipts}`, like);
  await db.query(`delete from app.receipt_event where receipt_id in ${receipts}`, like);
  await db.query(`delete from app.receipt where order_id in ${orders}`, like);
  await db.query(`delete from app.sales_order_installment where order_id in ${orders}`, like);
  await db.query(`delete from app.sales_order_event where order_id in ${orders}`, like);
  const orderIds = (
    await db.query<{ id: string }>(`select id from ${orders} as x(id)`, like)
  ).rows.map((r) => r.id);
  await db.query(`delete from app.sales_order_line where order_id = any($1::uuid[])`, [orderIds]);
  await db.query(`delete from app.sales_order where id = any($1::uuid[])`, [orderIds]);
  await db.query(
    `delete from app.quotation_line_discount where line_id in (select id from app.quotation_line where quotation_id in ${quotes})`,
    like,
  );
  await db.query(`delete from app.quotation_line where quotation_id in ${quotes}`, like);
  await db.query(`delete from app.quotation where opportunity_id in ${opps}`, like);
  await db.query(
    `delete from app.note where (entity_type = 'LEAD' and entity_id in ${leads}) or (entity_type = 'OPPORTUNITY' and entity_id in ${opps})`,
    like,
  );
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
      draft: `Chị ${setup.mark} nhap ${run}`,
      sent: `Chị ${setup.mark} dagui ${run}`,
      overdue: `Chị ${setup.mark} quahan ${run}`,
      rejected: `Chị ${setup.mark} tuchoi ${run}`,
      converted: `Chị ${setup.mark} lendon ${run}`,
    };
    const students = { draft: ['Em Nháp Một', 'Em Nháp Hai'] as [string, string] };
    await db.query('begin');
    // Các bộ dữ liệu bán hàng cùng cấp mã (bộ đếm khoá dòng): chạy tuần tự để hai dự án chạy song song không khoá chéo (deadlock).
    await db.query('select pg_advisory_xact_lock(7101)');
    await db.query(
      `select set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object(
         'user_id', u.id, 'claims', jsonb_build_object('sub', u.id, 'role', 'authenticated', 'aal', 'aal1'))) -> 'claims')::text, true)
         from app.user_account u where u.login_name = $1`,
      [`${setup.sale}@${DOMAIN}`],
    );
    await db.query('set local role authenticated');
    const phone = (i: number) =>
      `0${String(phoneBase + i)
        .padStart(9, '0')
        .slice(-9)}`;
    // Cơ hội với một em (và em thứ hai nếu có); trả mã cơ hội, id em.
    const opp = async (
      name: string,
      i: number,
      student: string,
    ): Promise<{ id: string; ps: string }> => {
      const lead = await db.query<{ id: string }>(
        `select (app.create_lead(jsonb_build_object('parent_name', $1::text, 'parent_phone', $2::text,
           'student_name', $3::text, 'student_birth_year', 2012,
           'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
           'channel_code', 'FACEBOOK_ADS_LEAD_FORM'))) ->> 'id' as id`,
        [name, phone(i), student],
      );
      const leadId = lead.rows[0]?.id ?? '';
      // Lead chỉ tạo được cơ hội khi ở C4C (R-CRM-40).
      await db.query(`select app.change_lead_stage($1::uuid, 'C4', 'C4C')`, [leadId]);
      const o = await db.query<{ id: string }>(
        `select r ->> 'id' as id from (select app.create_opportunity($1::uuid) as r) x`,
        [leadId],
      );
      const id = o.rows[0]?.id ?? '';
      const ps = await db.query<{ id: string }>(
        `select id from app.prospect_student where opportunity_id = $1::uuid and position = 1`,
        [id],
      );
      return { id, ps: ps.rows[0]?.id ?? '' };
    };
    const packageId = (
      await db.query<{ id: string }>(`select id from app.sales_package where code = 'LC-TOAN-K09'`)
    ).rows[0]?.id;
    const policyId = (
      await db.query<{ id: string }>(
        `select id from app.discount_policy where code = 'GIAM_6_THANG'`,
      )
    ).rows[0]?.id;
    const line = (ps: string, hours: number, withDiscount = false) => ({
      kind: 'ENROL',
      prospect_student_id: ps,
      package_id: packageId,
      delivery_mode_code: 'OFF',
      quantity: hours,
      discounts: withDiscount ? [{ policy_id: policyId, value: null }] : [],
    });
    const quote = async (oppId: string, lines: object[]): Promise<{ id: string; code: string }> => {
      const r = await db.query<{ id: string; code: string }>(
        `select r ->> 'id' as id, r ->> 'code' as code from (select app.save_quotation(null, $1::uuid, $2::jsonb) as r) x`,
        [oppId, JSON.stringify(lines)],
      );
      return { id: r.rows[0]?.id ?? '', code: r.rows[0]?.code ?? '' };
    };
    // Nháp: hai em (cột Học sinh hiện đủ hai tên).
    const draft = await opp(parent.draft, 0, students.draft[0]);
    // Em thứ hai: danh sách em chưa có hàm thêm (DB-2) nên dựng bằng quyền chủ, rồi quay lại quyền nhân viên.
    await db.query('reset role');
    const ps2 = await db.query<{ id: string }>(
      `insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
       select o.id, o.branch_id, 2, $2::text, 2014 from app.opportunity o where o.id = $1::uuid returning id`,
      [draft.id, students.draft[1]],
    );
    await db.query('set local role authenticated');
    const draftQ = await quote(draft.id, [line(draft.ps, 10), line(ps2.rows[0]?.id ?? '', 5)]);
    const sent = await opp(parent.sent, 1, 'Em Đã Gửi');
    const sentQ = await quote(sent.id, [line(sent.ps, 12)]);
    await db.query(`select app.send_quotation($1::uuid)`, [sentQ.id]);
    const overdue = await opp(parent.overdue, 2, 'Em Quá Hạn');
    const overdueQ = await quote(overdue.id, [line(overdue.ps, 6, true)]);
    await db.query(`select app.send_quotation($1::uuid)`, [overdueQ.id]);
    const rejected = await opp(parent.rejected, 3, 'Em Từ Chối');
    const rejectedQ = await quote(rejected.id, [line(rejected.ps, 8)]);
    await db.query(`select app.send_quotation($1::uuid)`, [rejectedQ.id]);
    await db.query(
      `select app.reject_quotation($1::uuid, 'KHONG_DUNG_CHINH_SACH', 'Giá chưa đúng')`,
      [rejectedQ.id],
    );
    // Đã chuyển đơn: cơ hội đã thanh toán thật (L8, R-CRM-16) rồi tạo đơn từ báo giá Đã gửi (mọi dòng lên đơn).
    const converted = await opp(parent.converted, 4, 'Em Lên Đơn');
    const convertedQ = await quote(converted.id, [line(converted.ps, 4)]);
    await db.query(`select app.send_quotation($1::uuid)`, [convertedQ.id]);
    await db.query('reset role');
    await db.query(
      `update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = $1::uuid`,
      [converted.id],
    );
    await db.query('set local role authenticated');
    const order = await db.query<{ code: string }>(
      `select r ->> 'code' as code from (select app.create_order_from_quotation($1::uuid) as r) x`,
      [convertedQ.id],
    );
    await db.query('reset role');
    // Báo giá "Quá hạn": lùi hạn hiệu lực về 3 ngày trước (hạn chỉ để hiển thị, R-TIEN-05).
    await db.query(`update app.quotation set valid_until = current_date - 3 where id = $1::uuid`, [
      overdueQ.id,
    ]);
    await db.query('commit');
    return {
      parent,
      code: {
        draft: draftQ.code,
        sent: sentQ.code,
        overdue: overdueQ.code,
        rejected: rejectedQ.code,
        converted: convertedQ.code,
      },
      orderCode: order.rows[0]?.code ?? '',
      students,
    };
  } catch (error) {
    await db.query('rollback');
    throw error;
  } finally {
    await db.end();
  }
}
