# Nhật ký Claude Code (cập nhật 18/10/2026, 17:00)

(Claude Code viết đè file này cuối mỗi phiên; tối đa một trang.)

## Đang làm
- Vừa gộp #41 đến #58 (#58: DB trang Lead, migration 035). PR P3c-2b (giao diện trang Lead, #57) chờ anh thử trên bản xem trước rồi OK. Việc kế: PR sửa nhóm đăng nhập; P3c-3 (TS-11 Lịch hẹn, kèm Mở lại lịch hẹn); P5 thay thân `opportunity_sales_documents`.

## Đã chốt (chưa vào repo)
- Anh OK 18/10: PR 5 theo đề xuất (giữ trang đặt mật khẩu mới nhưng không dẫn tới; sửa bản đồ CHUNG-04, 05, 08 cho khớp thiết kế); bốn câu P3b2 như em đề xuất (không chặn tạo cơ hội theo C4C; sửa học sinh ở cơ hội = sửa hồ sơ học sinh; phụ huynh khớp SĐT khác tên: dùng hồ sơ cũ không ghi đè tên; học sinh trùng tên khác năm sinh = hai hồ sơ); **bảng quyền phiên bản 4** (17 ô Phụ huynh, Học sinh): nạp trong P3b2a.
- Mục chờ anh quyết, chưa thành luật (ghi chú ở `docs/spec/04` mục 13): R-GD-07, R-GD-13 (một phiếu tái tục mỗi ghi danh), ticket chọn nhiều ghi danh, R-GIO-03/04, spec 02 mục 3, 6, 7, chặn môn theo khối khi tạo lớp.
- Thứ tự: PR 5 (5a, 5b, 5c), PR 5a (Trang chủ), P3b2a (Cơ hội, kèm ma trận v4), P3b2b (Phiếu), P3b3, P3c đến P3f.

## PR 5a (18/10, đã gộp #41)
- Dựng khung đăng nhập hai cột (cột giới thiệu + thẻ), CHUNG-01/06, hai bước (CHUNG-02), thiết lập 2 bước (CHUNG-03) theo P1 v4. Chữ lỗi lấy theo thiết kế ở giao diện; Edge Function giữ nguyên.
- Thêm ngoài đề xuất: hàm công khai `public.login_branch_names()` (migration 027, chỉ mã và tên cơ sở dạy học đang hoạt động) cho cột giới thiệu.
- Nền động chưa làm (5c); robot đứng yên.

## PR 5b (18/10)
- CHUNG-04 chỉ còn hướng dẫn liên hệ quản trị viên, không gửi email (anh OK 18/10). CHUNG-05 giữ trang, không dẫn tới. CHUNG-07, 08, 09, 25 theo P1 v4.
- Hết phiên (DN09): số thời gian lấy từ tham số có sẵn `staff_idle_logout_minutes` (60), `teacher_idle_logout_minutes`, `student_idle_logout_minutes` (10080), theo `idleGroup`; hiện phút, giờ hoặc ngày. Số phút lưu cùng lúc bị đăng xuất (`sessionEnd.ts`), không tạo tham số mới.
- Sửa lỗi của 5a: nền cam cột giới thiệu không hiện (khai báo `background-image` lẫn màu nên trình duyệt bỏ cả dòng); có bài kiểm tái hiện.

## PR Trang chủ theo vai trò (18/10)
- `src/pages/home/`: `CrmHome` (khung K09b), `homeBlocks` (khối khai báo theo module, quyền, công tắc tính năng; thêm phân hệ mới = thêm một dòng), `useAppointmentsToday` (hai lần gọi: `list_appointments` và `appointment_overdue_count`, không thêm migration).
- "Hôm nay" tính theo Asia/Ho_Chi_Minh (`src/lib/vnDay.ts`), không theo múi giờ trình duyệt. Thẻ QUÁ HẠN dùng mốc đầu ngày hôm nay; hàm đó chỉ có tham số "của tôi", nên thẻ này không theo ô chọn cơ sở.
- Xem thử vai trò: chỉ người có quyền Quản trị; đổi khối nào hiện, số liệu vẫn theo quyền thật.
- Ngoài ra: bỏ đuôi `?ly-do=tam-chan`; bài so sánh ảnh mặc định không ghi đè `docs/so-sanh` (đặt `SO_SANH_GHI_VAO_REPO=1` mới ghi).

## PR P3b2a Cơ hội (18/10)
- Migration `20261018000028` (bảng cơ hội, lịch hẹn gắn cơ hội, hàm tạo, sửa, đổi giai đoạn, danh sách, Kanban; tìm hoặc tạo phụ huynh, học sinh). Migration `029` (ma trận v4) CHƯA viết vào repo, chờ OK riêng.
- Điểm nối với phiếu: `opportunity_test_state`, `opportunity_l5_substage` (thân tạm); P3b2b thay thân. Hoãn: R-CRM-16 (chặn tạo đơn), 17, 18.
- Phát hiện khi đo: CTE dùng hai lần bị Postgres cho "materialized" làm danh sách quét cả bảng; đã sửa `list_leads`, `list_appointments`, `list_opportunities` bằng `not materialized`.

## PR Ma trận quyền phiên bản 4 (18/10)
- Migration `20261018000029`: 17 ô Phụ huynh, Học sinh (bỏ Tạo 8, bỏ Xuất Trưởng cơ sở 2, Xem toàn hệ thống 6, Kế toán Xem Phụ huynh 1). Bài pgTAP 021; chỉnh 017 (phụ huynh cơ sở khác nay đọc được), 018 (đếm quyền, số phiên bản).

## PR P3b2b Phiếu kiểm tra (18/10)
- Migration `20261018000030`: bảng `student_test`, lịch hẹn gắn phiếu (`student_test_id`, `is_auto_reminder`, `auto_scheduled_at`), hàm tạo, đổi lịch, sửa, bắt đầu, nộp bài, nhập kết quả, hoàn thành, lùi bước, huỷ, mở lại; danh sách, Kanban; thay thân `opportunity_test_state`, `opportunity_l5_substage`.
- Quyền theo phạm vi của phiếu (`test_scope_ok`): toàn hệ thống, cơ sở của cơ hội, được phân công (giáo viên chấm, người phụ trách). Lỗi bắt được nhờ bài kiểm: so với null cho null chứ không false, nên giáo viên chưa phân công lọt qua kiểm quyền.
- Kiểm bản vẽ TS15: Khối chọn được (không khoá). Đã sửa bản đồ TS-15 và dòng tương ứng ở `dac-ta/P3-tuyen-sinh.md`.

## R-CRM-36 đối chiếu (18/10)
- R-CRM-36 (cơ hội mới luôn bắt đầu ở L1) đã vào spec. `create_opportunity` (migration 028) khớp: câu `insert` ghi cứng `stage_code = 'L1'`, `substage_code` trống; `p_data` không có đường nào đặt giai đoạn (chỉ đọc nhu cầu, học sinh, người phụ trách, người hỗ trợ). Thêm bài pgTAP: truyền giai đoạn, nhóm con, lý do bỏ qua trong `p_data` vẫn ra L1.
- **Màn tạo cơ hội:** chưa dựng (P3d); bản vẽ TS-06 chỉ có hộp cảnh báo "lead đã có cơ hội", không có ô giai đoạn. Khi dựng màn tạo, không đặt ô chọn giai đoạn.

## PR P3b3a Gộp trùng (18/10)
- Migration `20261018000031`: bốn hàm gộp, xem trước, bản đã gộp chỉ đọc, ghi chú chuyển chỉ trong hàm gộp (cờ `hmt.merge` trong giao dịch), ghi chú hệ thống trên cả hai bản, lịch nhắc tự đóng khi phiếu sang Đang test.
- Chỉnh theo anh 18/10: `merge_parents` không chặn báo giá, đơn; `merge_opportunities` giữ nguyên giai đoạn bản giữ lại, cảnh báo nếu bản bị gộp ở giai đoạn cao hơn; lịch nhắc đóng bằng Huỷ.
- Việc kế: P3b3b nhập lô lead.

## PR P3b3b Nhập lô lead (19/10)
- Migration `20261019000032`: `import_leads` (xem trước = nhập thật rồi hoàn tác), `import_one_lead`, `lead_import_log`. Mỗi hàng đi qua `create_lead` nên không có luật lặp. Đo 500 dòng: 1 đến 3 giây ở máy em.

## PR P3c-1a Dữ liệu màn Lead (19/10)
- Migration `20261019000033`: `lead_board`, `lead_group_counts`, `list_assignable_staff`, `export_leads`, bộ lọc và cột mới của `list_leads`, tham số `export_max_rows`. Tách hai PR theo anh: 1a là DB, 1b là giao diện.
- Điều kiện lọc lặp ở bốn hàm (cùng khuôn) nên có bài kiểm tổng khớp giữa chúng. Thanh màu Kanban tính trên cả cột, "hôm nay" theo giờ Việt Nam trong DB.
- Bài kiểm C4/C4D (anh dặn): kéo sang C4 không tự gắn C4D.
- Sửa bài 017: danh sách cột của `list_leads` thêm bốn cột mới.

## PR P3c-1b Giao diện Lead (19/10)
- Màn `/crm/lead` (`src/pages/lead/`): K1 và K2 nối `list_leads`, `lead_board`, `lead_group_counts`, `export_leads`; hộp Giao ở `src/features/assign/`. Khuôn chung sửa: bảng có nhóm tải dòng khi mở, dòng mờ, "Xem thêm"; Kanban nhận tổng và số đếm thanh màu từ máy chủ, ẩn thanh khi cột chưa có lịch hẹn (P0 v5 số 12), có thể giới hạn cột có dấu "+".
- Phát hiện khi dựng: bản 033 nối các mốc Lịch hẹn bằng VÀ nên không chọn được "Quá hạn" cùng "Hôm nay" (trái R-CRM-07). Migration `034` thêm bộ lọc dạng danh sách `appointment[]`, `mine_roles[]` cho bốn hàm, mốc "hôm nay" tính trong DB.
- Ghi chú vênh bản vẽ và quyết định nằm trong mô tả PR.

## PR P3c-2a DB trang Lead (19/10)
- Migration `20261019000035` (`get_lead`, `reschedule_appointment` mở rộng) tách khỏi PR giao diện: DB thử nghiệm chỉ áp migration sau khi gộp nên bản xem trước của #57 (cần `get_lead`) báo lỗi khi anh thử. Quy trình ghi ở `quy-trinh-phoi-hop.md` mục 4. R-CRM-38 vào spec 04.

## PR P3c-3a DB Lịch hẹn (19/10)
- Migration `20261019000037`: `list_appointments` thêm bộ lọc `q` và `owner_id` (màn TS-11). Bài kiểm 029. EXPLAIN trên seed lớn (120.000 lịch hẹn, 50.000 lead): tìm khó chọn lọc 68 ms, chọn lọc 28 ms.

## PR P3c-2b Giao diện trang Lead (19/10)
- Giao diện: `src/pages/lead/LeadRecordPage.tsx` (K3), `src/features/appointments/` (hộp lịch hẹn, Hoạt động sắp tới), `src/layout/CrumbTail.ts` (chữ cuối của đường dẫn). Theo anh 19/10: Tỉnh/Thành phố trên Phường/Xã, ô bắt buộc trống viền cam nền cam nhạt (trạng thái `requiredEmpty` của ô dùng chung), thanh giai đoạn chiếm hết chiều ngang, bấm cả dòng mở lead.
- **Lỗi đã sửa kèm (phát hiện khi viết bài kiểm Tạo lead):** màn Lead P3c-1b (#56) và hộp Giao bắt lỗi bằng `toHmtError(e)` cho lỗi đã qua `rpc` (HmtError, không có `hint`), nên mọi lỗi nghiệp vụ hiện câu chung "Có lỗi xảy ra". Thêm `errorOf` (giữ mã và câu của hàm DB), có bài Vitest tái hiện và bài Playwright hộp trùng SĐT.
- Khuôn: `RecordDetail` thêm `readOnly`; `DuplicateDialog` thêm danh sách nhóm (TS-14); `RecordChatter` nhận nút nghiệp vụ, khối Hoạt động sắp tới; `Table` thêm `onRowClick`.
- R-CRM-39 (lead mới luôn ở C1) vào spec 04 theo lời anh "OK ĐƯA VÀO LUẬT" 19/10. `create_lead` đã khớp (câu `insert` ghi cứng C1), thêm bài 027.
- Bài học quy trình: bản xem trước nối DB thử nghiệm chỉ có migration đã gộp; PR có migration mới tách PR DB gộp trước (đã ghi `quy-trinh-phoi-hop.md`).

## PR Quản lý trực tiếp (19/10)
- Migration `20261019000036`: cột `manager_id` (chỉ mục từng phần), trigger toàn vẹn (chỉ qua `set_manager`, không tự quản, không vòng, không học sinh), `set_manager`, `approval_route`, `can_approve_as_manager` (đơn khác phiếu thu ở chỗ Admin duyệt thay). Bài kiểm 028 (38 bài). Màn QT-01 chưa dựng nên trường giao diện hoãn.

## PR P1-sửa Nhóm đăng nhập (19/10)
- Nguyên nhân: màn đăng nhập (P1) dựng và so sánh theo gói cũ `design/hmt-platform/screens/CHUNG-xx`, gói hiện hành là `design/hmt-p0-p2` (DN01 đến DN10). Đã so từng màn máy tính và điện thoại, sửa mọi chỗ lệch; ảnh `docs/so-sanh/DN*.jpg` (kịch bản `e2e/so-sanh-dang-nhap.spec.ts`). Các ảnh `CHUNG-01..09, 25` của gói cũ đã xoá.
- Khuôn: ô nhập và nút cỡ lớn (`size="lg"` của TextField, PasswordInput; `xl` của Button), nút con mắt thay chữ "Hiện", `authParts.tsx` (thông báo, dòng chú, liên kết, biểu tượng tròn), hộp hết phiên `SessionEndDialog`.
- Bài kiểm giữ các nét chính của bản vẽ: `e2e/dang-nhap-thiet-ke.spec.ts` (cao 44px, không `*`, con mắt, lỗi nằm trên ô, liên kết căn giữa không gạch chân, "Chào em", hộp hết phiên không nút đóng).

## PR 5c Nền động đăng nhập (19/10)
- CSS động của `.auth-*` (chép từ DN01), tắt khi `prefers-reduced-motion`; bài Playwright `e2e/nen-dong.spec.ts` (bình thường: có chuyển động, `?` đổi thành `5`; giảm chuyển động: `animation-name: none`).

## PR P3c-3b Màn Lịch hẹn (19/10)
- `src/pages/lich-hen/*`: danh sách, Kanban, Lịch trên khuôn K1, K2, K5; lọc, tìm, phân trang ở máy chủ (`list_appointments`, migration 037); Kanban mỗi cột một lần gọi; Lịch tải từng trang (tối đa 5) rồi báo nếu còn thừa. Thao tác dùng chung hộp Dời, Huỷ của trang Lead; thêm hộp Mở lại (`reopen_appointment`).
- Khuôn: `ListScreen` thêm `groupsOpenByDefault` (nhóm do màn tự dựng từ dòng đã tải) và `belowToolbar` (dải thông báo); `AppointmentDialog` nhận `targetPicker` (ô chọn lead, `LeadPicker`).
- Luật thể hiện: Quá hạn = Chưa làm và trước đầu ngày hôm nay giờ Việt Nam; Hoàn thành ⇄ Huỷ không kéo thả (chỉ qua Mở lại); không đổi giai đoạn, không tạo việc, không báo ai.
- Bài kiểm: Vitest `appointmentFilters.test.ts` (bộ lọc), Playwright `e2e/lich-hen.spec.ts` (máy tính và điện thoại; có chờ chọn chip, mở ô chọn lại khi hộp đang hiện hiệu ứng), ảnh so sánh bản vẽ `e2e/so-sanh-lich-hen.spec.ts`.

## PR P3d-1 DB Cơ hội (20/10)
- Migration `20261019000038`: `get_opportunity`, `list_opportunities` và `opportunity_board` mở rộng bộ lọc như Lead, `opportunity_group_counts`, `export_opportunities`. Bài kiểm 030 (59 bài). EXPLAIN trên seed lớn trong mô tả PR.

## PR P3d-2 Giao diện Cơ hội (20/10)
- `src/pages/co-hoi/*`: danh sách + Kanban (khuôn K1, K2; lọc dùng chung `buildLeadFilters` với Lead), trang bản ghi (K3), hộp chuyển giai đoạn `StageDialog` + `StageMoveHost` (tải cơ hội để chọn đúng dạng khi kéo thẻ), `CreateOpportunityDialog` (TS-06). Luật chọn hộp nằm ở `oppStage.ts` (hàm thuần, có kiểm thử); DB kiểm lại mọi luật.
- Khuôn: `StageBar` tự cuộn bước hiện tại vào tầm nhìn; `SmartItem.unavailable` (nút liên kết chưa có màn đích: mờ, kèm chú thích); `OptionalSelect` tách ra `src/ui`; `useLeafRows`, `buildLeadGroupTree` thành hàm chung theo kiểu dòng; ô "Gắn với" của Lịch hẹn thành `RecordPicker` (lead và cơ hội).
- Bài kiểm: Vitest `oppStage.test.ts`, `oppRecord.test.ts`; Playwright `e2e/co-hoi.spec.ts` (máy tính và điện thoại, 10 bài: danh sách, Kanban, bản ghi, đủ năm dạng hộp, Sửa, lịch hẹn, tạo từ lead); ảnh so sánh `e2e/so-sanh-co-hoi.spec.ts`.
- Bài học: bước giai đoạn `aria-disabled` không bấm được bằng `click()` thường của Playwright (chờ "enabled" mãi), dùng `force`; truy vấn của hộp cảnh báo phải `gcTime: 0` để không dùng bản nhớ của lần mở trước.

## PR nợ nhỏ P3c, P3d (20/10)
- **Gốc lỗi bài kiểm chập chờn (anh yêu cầu sửa gốc):** `AppointmentDialog` chốt loại hoạt động mặc định bằng `useState(activityOptions[0])` lúc mở hộp. Danh mục tải bất đồng bộ, nên mở hộp trước khi danh mục về thì ô Loại hoạt động rỗng mãi và nút Tạo không bao giờ sáng. Bài kiểm bấm nhanh sau khi vào trang nên trượt ngẫu nhiên (chủ yếu khi máy dồn nhiều trình duyệt); người dùng thật gặp khi mạng chậm. Sửa: mặc định lấy theo danh mục đang có (`pickActivity`, có Vitest); bài Playwright làm chậm danh mục 3 giây để tái hiện (không sửa thì trượt, sửa thì qua).
- Playwright: chờ kết quả tối đa 10 giây (trước 5) vì đăng nhập, tải dữ liệu chậm khi chạy song song; các bước bấm chọn nhanh có chờ trạng thái chọn (`pickChip`, `pickOption` trong `e2e/helpers.ts`). Chạy dồn bốn bộ test cùng tài khoản năm lần liên tiếp: 69 bài xanh cả năm lần (trước đó gần như mỗi lần trượt 1 đến 3 bài).
- Seed lớn đã đủ 50.000 lead, 20.000 cơ hội (số đếm 25.000 lead, 10.000 cơ hội trong các số đo trước là phần Trưởng cơ sở CS1 thấy, vì lọc theo cơ sở); không cần tăng thêm.
- Hoàn tác sau Hoàn thành, Huỷ: `useUndoAppointment` dùng chung (Lead, Cơ hội, Lịch hẹn).

## PR P3e-1 DB Phiếu kiểm tra (23/10)
- Migration `20261023000039`: `get_student_test`, `list_student_tests` và `student_test_board` thay thân (lọc nhiều lựa chọn HOẶC), `student_test_group_counts`, `export_student_tests`, `list_test_graders`, `list_test_rooms`. Bài kiểm 031 (76 bài). EXPLAIN trên seed lớn trong mô tả PR.

## PR P3e-2 Giao diện Phiếu kiểm tra (23/10)
- `src/pages/phieu/*`: danh sách, Kanban (thanh đầu cột đếm cả cột, thẻ có nút Bắt đầu test / Nộp bài, kéo thả bị chặn), Lịch; trang phiếu (thanh trạng thái chỉ đọc, nút theo trạng thái, menu Hành động); `CreateTestDialog` (TS-15), `TestDialogs` (kết quả, lý do, đổi lịch). Luật hiển thị ở `testLogic.ts` (giờ nhắc mặc định khớp `app.test_reminder_time`).
- Khuôn: `StageBar`/`RecordDetail` thêm `showCode`/`stageShowCode` (phiếu không hiện mã kỹ thuật DRAFT, TESTING); `Chips.tsx` tách khỏi `AppointmentDialog`.
- Mở khoá: mã phiếu ở trang Cơ hội và màn Lịch hẹn (lọc `?phieu=`), nút Mở phiếu ở hộp chặn L7, "Tạo lịch Test" ở L5+.
- Bài kiểm: Vitest `testLogic`, `testFilters`, `testHistory`; Playwright `e2e/phieu.spec.ts` (9 bài, máy tính và điện thoại).

## PR P3f-1 DB Gộp trùng gợi ý, xem trước (23/10)
- Migration `20261023000040`: `merge_candidates` (gợi ý bản trùng, chỉ trong phạm vi xem của người gọi), `merge_preview` thêm `sides`, `items`; tham số `merge_preview_max_items`. Bài kiểm 032 (50 bài: đúng và bị chặn theo từng vai trò, cơ sở khác không lộ, HMT_GOP_KHAC_CO_SO bằng quyền Xem tạm trong giao dịch). Bài học: trigger chuẩn hoá `created_at` nên bài kiểm không dựa vào thứ tự ghi chú tạo cùng giao dịch.

## PR P3f-2 Giao diện Gộp trùng và Nhập file (23/10)
- `src/features/merge/*`: hộp TS-10 (`FormDialog`): gợi ý bản trùng (`merge_candidates`) hoặc tìm tay ở máy chủ, chọn bản giữ lại, `merge_preview` (so sánh hai bên, danh sách lịch hẹn, ghi chú chuyển, điều kiện chặn, cảnh báo), xác nhận "không hoàn tác", gọi `merge_leads` hoặc `merge_opportunities`. Mở từ Hành động → Gộp trùng ở trang Lead và Cơ hội (quyền Duyệt).
- `src/pages/lead/ImportLeadsDialog.tsx` (`StepDialog` 3 bước), `importCsv.ts` (đọc CSV: BOM, dấu "," hoặc ";", ngoặc kép), `importMapping.ts` (đoán và ghép cột, đổi tên nguồn, kênh sang mã). Nút Nhập ở màn Lead cho ai có quyền Lead · Tạo.
- Bài kiểm: Vitest `importCsv`, `importMapping`, `mergeLogic`; Playwright `gop-trung.spec.ts` (3 bài) và `nhap-lead.spec.ts` (4 bài), cả máy tính và điện thoại; sửa hai bài cũ (`lead.spec`, `lead-ban-ghi.spec`) vì Nhập, Gộp trùng nay có.
- Đăng nhập dùng lại trong Playwright: `enterAs` (e2e/helpers.ts) đăng nhập thật một lần cho mỗi tài khoản (mỗi tiến trình chạy bài, mỗi loại trình duyệt), các bài sau nạp lại phiên đã lưu (khoá `sb-…` trong localStorage), phiên hỏng thì tự đăng nhập lại. Mười một file bài tính năng đổi sang `enterAs`; bài kiểm chính luồng đăng nhập (auth, dang-nhap-thiet-ke, so-sanh-*) vẫn đi qua màn đăng nhập. Lý do: Supabase local giới hạn 30 lần đăng nhập mỗi 5 phút mỗi địa chỉ; lỗi hiện là đứng ở trang đăng nhập, không phải lỗi mã. Cả bộ chạy ở máy từ 6,4 phút xuống 4,2 phút.
- Ảnh TS10c dựng bằng Admin giả (có thiết lập hai bước cho admin.cs1; chạy xong chạy lại `npm run db:seed-users`) và một lead cùng SĐT ở CS1 dựng bằng tài khoản Tuyển sinh CS1.

## Đang chờ ai
- **Anh Trường:** ngưỡng dung lượng gói tải (đo: trang đầu CRM 235 KB nén, CI chỉ báo số); hạn xử lý ticket chăm sóc tháng (khi có màn Cấu hình).
- **Claude Chat:** viết đè `docs/nhat-ky/chat.md` (luật 04d–04g đã vào spec).
- **Claude Design:** cụm Lớp trên canvas gốc P5b (xem `docs/nhat-ky/design.md`).

## File và link mới
- Đã gộp: #47, #46, #45, #44, #43, #42, #41 (PR 5a), #34 (P3a), #35 (P3b1), #36 (tách gói tải), #37 (nguồn canvas Design), #38 (nền tảng phối hợp), #39 (luật 17/10), #40 (bàn giao 17/10).
- Còn việc nhỏ: kiểm lại TS18, TS19 của P4 (bản chép cũ trong `design/nguon-canvas/p4-hmt-platform/`).
- `scripts/bundle-size.ts` (`npm run size`); bộ seed lớn `supabase/seed-lon.sql` (`npm run db:seed-lon`).
- `main` chưa bắt buộc PR (GitHub Free không cho bật); chỉ do em tuân thủ CLAUDE.md.
