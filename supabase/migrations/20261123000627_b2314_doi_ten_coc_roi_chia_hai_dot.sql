-- Code B (23/11/2026), thẻ B-23-14 (anh chốt 14:03): đổi TÊN điều khoản «Cọc rồi chia hai đợt» cho đúng số lần đóng thực tế.
-- Điều khoản COC_VA_CHIA_DOT = đợt 1 là cọc cố định, đợt 2 là phần còn lại: tổng cộng HAI lần đóng (cọc + một đợt), không phải «chia hai đợt» sau cọc.
-- Làm gì: đổi cột name của bản đang có (code, version giữ nguyên, nên đơn và lịch cũ không đổi cấu trúc). Bảng cấu hình này có trigger chặn đổi tên (tg_payment_term_fixed, «tạo bản mới»);
-- đây là sửa CHỮ HIỂN THỊ theo quyết định của anh, không đổi số tiền hay số đợt, nên tắt trigger đúng một câu lệnh rồi bật lại trong cùng giao dịch. Nhật ký thao tác (audit) vẫn ghi dòng đổi.
-- Idempotent: chỉ đổi khi tên còn là tên cũ; môi trường không có điều khoản này thì không làm gì.
alter table app.payment_term disable trigger payment_term_fixed;
update app.payment_term
   set name = 'Cọc rồi đóng phần còn lại'
 where code = 'COC_VA_CHIA_DOT' and name = 'Cọc rồi chia hai đợt';
alter table app.payment_term enable trigger payment_term_fixed;
