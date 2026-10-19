# Luật nghiệp vụ

Tổng hợp các luật nghiệp vụ đã chốt với anh Trường (cập nhật 12/10/2026: thêm các quyết định trong lúc thiết kế giao diện P5, đánh dấu **(12/10)**; cập nhật 16/10/2026: bổ sung cơ hội, phiếu kiểm tra đầu vào, L8, tạo đơn và báo giá, đánh dấu **(16/10)**; bổ sung tối 16/10: phiếu kiểm tra, lịch hẹn, gộp trùng, đánh dấu **(16/10 tối)**; bổ sung 17/10: ai được gộp trùng, quyền Huỷ, Giao việc, Duyệt, mỗi lớp một dòng đơn, một ghi danh, một quỹ giờ, hồ sơ phụ huynh, học sinh dùng chung, lớp Toán Đại + Hình xen kẽ, nhóm lớp, đánh dấu **(17/10)**), lấy từ các vòng làm việc trên hệ thống Apps Script cũ và các buổi đặc tả hệ thống mới. Đây là nguồn luật cho mọi giai đoạn từ 1 trở đi.

**Cách dùng file này**
- Mỗi luật có mã `R-<NHÓM>-<số>`. Hàm SQL và bài kiểm thử ghi mã luật trong chú thích (ví dụ `-- Luật R-GIO-03`).
- **[CHỐT]** = đã chốt, làm đúng như ghi. **[CẦN CHỐT]** = chưa có quyết định: hỏi anh Trường trước khi code phần đó, không tự đoán "cách hợp lý".
- Con số trong luật là **giá trị mặc định của tham số Cài đặt** (ghi tên tham số trong ngoặc), không viết cứng trong code.
- Chỗ nào khác hệ thống cũ được ghi rõ "**Khác bản cũ**", vì tài liệu, code cũ có thể còn ghi theo luật cũ.

---

## 1. CRM: lead, cơ hội, kiểm tra đầu vào

| Mã | Luật | |
|---|---|---|
| R-CRM-01 | Một lead có thể sinh nhiều cơ hội. Lead đã có cơ hội mà tạo thêm thì cảnh báo kèm mã cơ hội cũ; người dùng xác nhận lần hai để tạo thêm, hoặc chọn gộp. | [CHỐT] |
| R-CRM-02 | Giai đoạn cơ hội chỉ đi tới, không lùi. Chặn ở cơ sở dữ liệu, không chỉ ẩn nút. | [CHỐT] |
| R-CRM-03 | Cơ hội từ L5 trở lên bắt buộc có tên và năm sinh học sinh. **(16/10)** Bắt buộc cho mọi bước từ L5 trở lên, kể cả khi bấm thẳng L7, L8. Hộp chặn trên giao diện nói rõ thiếu ô nào. | [CHỐT] |
| R-CRM-04 | **(16/10 tối)** Lịch hẹn (hoạt động) là bản ghi riêng; một bản ghi có nhiều lịch hẹn song song. "Lịch hẹn kế tiếp" trên lead, cơ hội do hệ thống tự tính. Trạng thái lịch hẹn: Chưa làm · Hoàn thành · Huỷ. **Hoàn thành:** bấm một lần. **Huỷ:** bắt buộc chọn lý do từ danh mục 34 "Lý do huỷ lịch hẹn" ("Khác" bắt ghi chú). **Mở lại:** lịch hẹn Hoàn thành hoặc Huỷ mở lại được về Chưa làm, không giới hạn thời gian, có xác nhận, ghi lịch sử. Hoàn thành ⇄ Huỷ không chuyển thẳng, phải Mở lại trước. Hoàn thành, Huỷ, Mở lại **không đổi giai đoạn, không tạo việc, không gửi thông báo**. Lịch hẹn luôn gắn với một hồ sơ (lead, cơ hội, phiếu test…), không có lịch hẹn mồ côi. | [CHỐT] |
| R-CRM-05 | **(16/10 tối)** Phiếu kiểm tra đầu vào tạo từ cơ hội, **chỉ khi cơ hội đang ở L5 trở đi (L5–L8)**. Chặn trong hàm tạo phiếu (có mã lỗi, câu tiếng Việt); nút trên giao diện mờ ở L1–L4 chỉ là gợi ý. **Một cơ hội có thể có nhiều phiếu.** Khi tạo **bắt buộc** có ngày và giờ test; phòng và giáo viên chấm chọn sau trên phiếu. Có ngày giờ test thì tự sinh lịch hẹn nhắc. Phiếu tạo khi cơ hội đã ở L6 trở đi không làm đổi giai đoạn cơ hội (R-CRM-02). | [CHỐT] |
| R-CRM-06 | **(16/10 tối)** Phiếu kiểm tra **chỉ có một nhánh kết thúc không thành là Huỷ** (bỏ nhánh "Từ chối"). Huỷ bắt buộc chọn lý do từ danh mục 13 "Lý do huỷ test"; mỗi lý do nối một nhóm con L5 (L5C–L5Q), **trừ** lý do "Tạo phiếu sai" không nối nhóm con nào. Ai cũng huỷ được, kể cả khi học sinh đã làm bài (như R-CRM-14). | [CHỐT] |
| R-CRM-07 | Bộ lọc nhanh: nhóm "của tôi" (tôi là sale, tôi là giáo viên chấm) và nhóm thời gian (quá hạn, hôm nay, sắp tới, chưa có lịch). Trong cùng nhóm là HOẶC, khác nhóm là VÀ. | [CHỐT] |
| R-CRM-08 | Bảng đối chiếu mã giai đoạn cũ → mới khi chuyển dữ liệu: L3H cũ → L3G, L3I cũ → L3H. | [CHỐT] |
| R-CRM-09 | **(12/10)** Giai đoạn **lead** (C1–C4 và nhóm con) đổi tự do cả hai chiều; mọi lần đổi ghi lịch sử. Riêng nhóm con C4D "Tạo cơ hội thành công" do hệ thống tự gắn khi tạo cơ hội, người dùng không chọn được. Chỉ cơ hội mới chặn lùi (R-CRM-02). | [CHỐT] |
| R-CRM-10 | **(12/10)** Phiếu kiểm tra đầu vào: hình thức test (danh mục: Offline, Online), cấp độ đề (danh mục: Cơ bản, Nâng cao). Kết quả gồm điểm **0–10** (một chữ số thập phân), nhận xét, trình độ đề xuất S/A/B/C, phân loại đề xuất CB/NC, lớp đề xuất (không bắt buộc), đính kèm đề, bài làm, phiếu đánh giá (**(16/10 tối)** đính kèm file làm ở giai đoạn 4, chưa có ở giai đoạn 1). Phiếu bị huỷ đưa về Nháp được, bắt buộc lý do **(16/10 tối)** (bỏ chữ "từ chối": phiếu không còn nhánh Từ chối, R-CRM-06). | [CHỐT] |
| R-CRM-11 | **(16/10 tối)** Giáo viên chấm kiểm tra đầu vào trong **cổng giáo viên** (bản tối giản chỉ gồm mục chấm test, làm sau). **Trong lúc chưa có cổng này, người phụ trách phiếu nhập kết quả thay trong CRM; lịch sử ghi rõ "nhập thay" và người nhập.** Giữ chiến dịch marketing và nhập lead từ file như bản cũ. | [CHỐT] |
| R-CRM-12 | **(16/10)** Phiếu test dang dở là phiếu ở trạng thái Nháp, Đang test hoặc Chờ giáo viên chấm. Cơ hội còn ít nhất một phiếu dang dở thì không bấm tay được L7, L8. Chặn trong hàm cơ sở dữ liệu, có mã lỗi và câu tiếng Việt, kèm tên phiếu còn dang dở. Phiếu Huỷ, Hoàn thành không tính là dang dở. **(16/10 tối)** Bỏ chữ "Từ chối". | [CHỐT] |
| R-CRM-13 | **(16/10)** Phiếu test Hoàn thành thì cơ hội tự lên L6, nhóm con L6A, chỉ khi cơ hội đang ở L5 trở xuống. Cơ hội đã ở L7, L8 thì không đổi (R-CRM-02). L6 chỉ do hệ thống chuyển, người dùng không bấm tay được. | [CHỐT] |
| R-CRM-14 | **(16/10)** Bỏ qua test: cơ hội không có phiếu, hoặc mọi phiếu đều Huỷ, thì bấm tay L7, L8 được nhưng bắt buộc chọn "lý do bỏ qua test" (danh mục 33) và ghi lịch sử. Phiếu Huỷ vẫn bắt chọn lý do huỷ như R-CRM-06. Không giới hạn vai trò huỷ phiếu, kể cả khi học sinh đã làm bài (anh Trường chấp nhận). **(16/10 tối)** Bỏ chữ "Từ chối" và câu "Phiếu Từ chối đối xử như Huỷ". | [CHỐT] |
| R-CRM-15 | **(16/10 tối)** Nhóm con L5 do hệ thống tự gắn theo các phiếu của cơ hội, **chỉ khi cơ hội đang ở L5**. Xét tất cả phiếu của cơ hội, theo thứ tự ưu tiên: (1) còn phiếu Chờ giáo viên chấm → **L5P**; (2) nếu không, còn phiếu Nháp hoặc Đang test (luôn có lịch, R-CRM-05) → **L5B**; (3) nếu không, mọi phiếu đều Huỷ → nhóm con nối với lý do huỷ của **phiếu huỷ gần nhất**, bỏ qua các phiếu huỷ vì "Tạo phiếu sai"; (4) không còn phiếu nào tính được (chưa có phiếu, hoặc chỉ có phiếu "Tạo phiếu sai") → **L5A**. Phiếu Hoàn thành thì theo R-CRM-13 (lên L6). | [CHỐT] |
| R-CRM-16 | **(16/10)** L8 do nhân viên bấm sau khi phụ huynh đã thanh toán thật (thu tiền làm trước, ghi đơn trên hệ thống làm sau). Khi bấm bắt buộc chọn nhóm con L8A, L8B hoặc L8C (L8C khi phụ huynh đóng đủ 100% ngay lần đầu), có câu xác nhận, không có Hoàn tác (cơ hội chỉ đi tới). Chưa ở L8 thì không tạo được đơn hàng từ cơ hội: chặn trong hàm tạo đơn và hàm chuyển báo giá thành đơn, nút mờ trên giao diện chỉ là gợi ý. Luật này chỉ nói về đơn tạo từ cơ hội. Đơn sinh từ phiếu tái tục, chuyển phí: anh Trường làm màn tái tục riêng và tính sau, chưa quy định ở đây. | [CHỐT] |
| R-CRM-17 | **(16/10)** Cơ hội đang L8A hoặc L8B tự nâng lên L8C khi tất cả đơn đã duyệt của cơ hội đều thu đủ (xét từng đơn, không cộng gộp; chỉ tính phiếu thu đã duyệt). Xét lại mỗi lần kế toán duyệt phiếu thu, trong cùng giao dịch. Chỉ đi tới: đã L8C thì không lùi dù có đơn mới chưa thu hoặc hoàn tiền sau đó. Ghi lịch sử "Hệ thống chuyển L8C". L8A và L8B nhân viên chọn tay, hệ thống không tự đổi giữa hai nhóm này. | [CHỐT] |
| R-CRM-18 | **(16/10)** Đối chiếu: cơ hội ghi L8C do nhân viên chọn tay, đã có phiếu thu được duyệt mà chưa đơn nào thu đủ → cảnh báo "lệch" cho Trưởng cơ sở và kế toán. Hệ thống không tự sửa. Đơn thứ hai chưa thu không gây cảnh báo. | [CHỐT] |
| R-CRM-19 | **(16/10)** Tạo đơn hàng, tạo báo giá: bấm "Tạo" chỉ mở form trắng, chưa có bản ghi, chưa cấp mã. Bấm Lưu mới tạo bản ghi (Nháp) và cấp mã (không nhảy số, spec 02); bấm Huỷ thì bỏ hết. Đã Lưu mà không dùng nữa thì đổi trạng thái Huỷ, không xoá cứng. Nút Tạo nằm trên bản ghi cơ hội; danh sách đơn, danh sách báo giá không có nút Tạo (R-TIEN-02). | [CHỐT] |
| R-CRM-20 | **(16/10)** Tạo báo giá bấm được ở mọi giai đoạn cơ hội. | [CHỐT] |
| R-CRM-21 | **(16/10 tối)** **Lùi trạng thái phiếu test:** đưa phiếu đã **Hoàn thành về Nháp** thì bắt buộc nhập lý do. Các bước lùi khác chỉ ghi lịch sử, không hỏi lý do. Đổi người phụ trách phiếu, sửa phiếu sau khi Hoàn thành: được, mỗi lần sửa ghi lịch sử (ai, lúc nào, ô nào). Phiếu đưa về Nháp không kéo cơ hội lùi giai đoạn (R-CRM-02). | [CHỐT] |
| R-CRM-22 | **(17/10)** **Gộp trùng lead, cơ hội** (bổ sung R-CRM-01): **Tuyển sinh, CSKH, Trưởng cơ sở** được gộp **trong cơ sở của mình**; **Admin** gộp ở mọi cơ sở. Hai hồ sơ thuộc **hai cơ sở khác nhau** thì chỉ Admin gộp được. Quyền gộp dùng hành động **Duyệt** trên phân hệ Lead và Cơ hội (các phân hệ này chưa có luồng duyệt nào khác, nên Duyệt ở đó nghĩa là gộp trùng; ma trận quyền ghi chú rõ). Chọn bản giữ lại; lịch hẹn, ghi chú, phiếu test của bản bị gộp chuyển sang bản giữ lại. Bản bị gộp đổi trạng thái **"Đã gộp"**: chỉ đọc, ghi "Đã gộp vào <mã>", ẩn khỏi danh sách mặc định, vẫn tìm được bằng mã; không xoá cứng. **Không hoàn tác**, hộp gộp có câu xác nhận. **Chặn gộp cơ hội** nếu bản bị gộp đã có báo giá hoặc đơn hàng (nêu rõ mã). Ghi lịch sử ở cả hai bản, kèm người gộp. | [CHỐT] |
| R-CRM-23 | **(16/10 tối)** **Giai đoạn 1: mỗi cơ hội một học sinh.** Một cơ hội nhiều học sinh (phụ huynh có hai con) để sau, phân tích riêng vì ảnh hưởng báo giá, đơn, ghi danh, phiếu test. Giai đoạn 1 muốn tư vấn em thứ hai thì tạo cơ hội thứ hai (R-CRM-01). | [CHỐT] |
| R-CRM-25 | **(17/10)** **Gộp phụ huynh, học sinh trùng** (màn KH-07): cùng nguyên tắc R-CRM-22. Tuyển sinh, CSKH, Trưởng cơ sở gộp trong cơ sở mình; hai hồ sơ khác cơ sở chỉ Admin. Quyền gộp dùng hành động **Duyệt** trên phân hệ Phụ huynh và Học sinh. Hồ sơ giữ lại nhận lead, cơ hội, đơn, ghi danh, ghi chú của hồ sơ bị gộp; hồ sơ bị gộp thành "Đã gộp", chỉ đọc, vẫn tìm được bằng mã; không hoàn tác; ghi lịch sử cả hai bản kèm người gộp. Điều kiện chặn chi tiết (ví dụ học sinh cùng đang học hai lớp trùng giờ) **[CHỜ]**: chốt khi làm phân hệ Ghi danh và Lớp học; ở giai đoạn 1 chặn khi hai hồ sơ có báo giá hoặc đơn xung đột (nêu rõ mã). | [CHỐT] phần quyền và nguyên tắc; [CHỜ] điều kiện chặn chi tiết |
| R-CRM-26 | **(17/10)** **Hồ sơ phụ huynh (PH), học sinh (HS) dùng chung toàn hệ thống**, một người một hồ sơ, không tách theo cơ sở. Mã giữ theo spec 02. | [CHỐT] |
| R-CRM-27 | **(17/10)** **Không có thao tác Tạo tay** PH, HS. Hồ sơ **sinh tự động trong hàm nghiệp vụ**: PH sinh khi tạo cơ hội, khớp theo **SĐT đã chuẩn hoá**; HS sinh khi tạo phiếu kiểm tra đầu vào hoặc khi duyệt đơn, khớp theo **PH + tên đã chuẩn hoá + năm sinh**. Khớp thì dùng hồ sơ có sẵn, không khớp thì tạo mới. Người dùng chỉ **Sửa** và **Gộp** (R-CRM-25). Nhập dữ liệu cũ từ Sheet đi qua hàm riêng của đợt đồng bộ, không qua giao diện. | [CHỐT] |
| R-CRM-28 | **(17/10)** **Cơ sở tiếp nhận** của PH, HS: cố định theo cơ sở của cơ hội đầu tiên sinh ra hồ sơ, **chỉ Admin sửa**; doanh thu ban đầu ghi theo cơ sở này. **Đang học tại**: tự tính từ các lớp đang học (có thể nhiều cơ sở), không ai sửa tay. Đổi cơ sở tiếp nhận hoặc chuyển học sang cơ sở khác chỉ qua **ticket đề nghị "Chuyển cơ sở"** đã duyệt (R-CS-02, R-CS-03). | [CHỐT] |
| R-CRM-29 | **(17/10)** **Xuất file** danh sách, hồ sơ PH, HS: **chỉ Admin**. Trưởng cơ sở và các vai trò khác không có Xuất trên hai phân hệ này. | [CHỐT] |
| R-CRM-30 | **(17/10)** **Chăm sóc hàng tháng:** mỗi HS đang học mỗi tháng có **một ticket chăm sóc**, hệ thống tự sinh bằng pg_cron, giao CSKH của **cơ sở có lớp chính** của HS. Tháng đã có ticket thì không sinh thêm. Hạn xử lý là tham số cấu hình. Nhật ký liên hệ xem ở dòng thời gian (lọc "Liên hệ"), không có bảng riêng. | [CHỐT]; hạn xử lý là **tham số cấu hình** (khai báo bằng migration kèm giá trị mặc định tạm; anh cài giá trị thật sau trong màn Cấu hình) |
| R-CRM-31 | **(17/10)** **Mục tiêu học tập** của HS là **một ô chữ tự do** (không có bảng mục tiêu, mốc ngày). Điểm bài kiểm tra tháng do giáo viên nhập trong App Giáo viên. Nhận xét từng buổi nằm ở App Giáo viên; hồ sơ HS chỉ có đường dẫn tới nhận xét đó, không lặp lại. | [CHỐT] |
| R-CRM-32 | **(17/10)** **Tài khoản app học sinh** (giai đoạn sau): hồ sơ có ba thao tác Cấp tài khoản, Đặt lại mật khẩu, Khoá tài khoản (quyền như QT-13). **Mật khẩu không bao giờ hiển thị**, chỉ đặt lại để tạo mật khẩu mới. Giai đoạn 1: nút mờ, chưa làm. | [CHỐT]; làm ở giai đoạn 4 |
| R-CRM-33 | **(17/10)** **Mã học sinh cũ.** Hồ sơ học sinh (KH-05) hiện ô **"Mã cũ (Sheet)"** cạnh mã HS, tìm được ở KH-04; cùng cách dùng như R-LOP-15. **Phụ huynh không có mã cũ** (anh Trường xác nhận 17/10: hệ thống Sheet hiện tại không có mã phụ huynh); KH-01, KH-02 không có ô mã cũ. | [CHỐT] |
| R-CRM-34 | **(18/10)** **Nhóm con L6.** Cơ hội vào L6 là do hệ thống chuyển, nhóm con L6A "Có kết quả, cần phân loại" (R-CRM-13). Sau đó người dùng tự chọn L6B, L6C, L6D, L6E hoặc L6F (xuất sắc đến yếu), mỗi lần chọn ghi lịch sử. Người dùng không chọn lại được L6A. | [CHỐT] |
| R-CRM-35 | **(18/10)** Đổi nhóm con trong cùng một giai đoạn được phép, kể cả lùi (ví dụ L7C về L7B), có ghi lịch sử. Ba ngoại lệ: (1) cơ hội đã ở L8C không đổi sang nhóm con khác (R-CRM-17); (2) nhóm con của L5 do hệ thống gắn, người dùng không đổi tay (R-CRM-15); (3) L6A do hệ thống gắn, người dùng không chọn lại (R-CRM-34). L8A và L8B do người dùng chọn tay, đổi qua lại giữa hai nhóm được. Luật này không làm thay R-CRM-02: giai đoạn vẫn chỉ đi tới. | [CHỐT] |
| R-CRM-36 | **(18/10)** **Giai đoạn khởi đầu:** cơ hội mới tạo luôn bắt đầu ở giai đoạn L1, người dùng không chọn giai đoạn lúc tạo. Giai đoạn chỉ tiến lên theo R-CRM-02 và các luật chuyển giai đoạn khác. | [CHỐT] |
| R-CRM-37 | **(18/10)** **Điều kiện gộp theo hồ sơ cha:** (a) Gộp cơ hội chỉ khi hai bên cùng phụ huynh và học sinh không khác nhau; một bên chưa có học sinh thì lấy học sinh của bên kia; khác phụ huynh thì gộp phụ huynh trước; khác học sinh thì gộp học sinh trước. (b) Gộp học sinh chỉ khi cùng phụ huynh; khác phụ huynh thì gộp phụ huynh trước. (c) Gộp phụ huynh không tự gộp học sinh; sau khi gộp, nếu có hai học sinh trùng tên và năm sinh dưới cùng phụ huynh thì hệ thống báo để người dùng gộp học sinh. | [CHỐT] |
| R-CRM-38 | **(19/10)** **Dời lịch hẹn:** chỉ lịch hẹn Chưa làm dời được. Khi dời có thể đổi người phụ trách lịch hẹn (cần quyền Giao việc theo ma trận quyền; không có quyền thì không đổi được người phụ trách) và ghi chú. Mọi thay đổi ghi lịch sử. | [CHỐT] |

## 2. Bán hàng và tiền

### 2.1 Bốn tầng
| Mã | Luật | |
|---|---|---|
| R-TIEN-01 | Bốn tầng tách biệt: **Báo giá** (không bắt buộc) → **Đơn hàng** (cam kết bán, quản lý cơ sở duyệt) → **Phiếu thu** (chứng từ, kế toán duyệt từng phiếu) → **Khoản tiền vào** (hệ thống tự sinh khi phiếu thu được duyệt, không ai tạo tay) → **Ghi danh** (quyền học). | [CHỐT] |
| R-TIEN-02 | Đơn hàng, phiếu thu, báo giá, phiếu tái tục, ghi danh **không có nút tạo mới tay**: chỉ sinh ra từ luồng nghiệp vụ (cơ hội → báo giá/đơn; đơn → phiếu thu; phiếu thu duyệt → khoản tiền → ghi danh; quỹ giờ → phiếu tái tục). | [CHỐT] |
| R-TIEN-03 | Đơn hàng tự khoá khi được duyệt. Khoá không phải là một giai đoạn. Sửa sau khi khoá đi qua nghiệp vụ khác (xếp lớp, chuyển lớp trên ghi danh), không mở khoá đơn. | [CHỐT] |
| R-TIEN-04 | Một đơn có nhiều phiếu thu (đặt cọc, trả nhiều đợt) mà không cần luồng riêng. | [CHỐT] |
| R-TIEN-05 | Báo giá có hạn hiệu lực (`quotation_validity_days`, mặc định 14 ngày). **(12/10)** Báo giá hết hạn tạo lại được từ chính nó. | [CHỐT] |
| R-TIEN-06 | **(12/10)** Đơn hàng, phiếu thu bị từ chối thì **về Nháp**, người lập sửa rồi trình lại; lịch sử giữ lần từ chối và lý do. Trình bị chặn thì báo đúng dòng, đúng ô còn thiếu. | [CHỐT] |
| R-TIEN-07 | **(12/10)** **Điều khoản thanh toán** (cấu hình có hiệu lực: số đợt, % hoặc số tiền mỗi đợt, số ngày đến hạn) chọn trên đơn để sinh **lịch đóng tiền từng đợt**. Lịch này dùng để theo dõi công nợ, nhắc sắp đến hạn và quá hạn; **không chặn học** (bỏ tham số chặn học khi nợ của bản cũ; học trước khi đóng tiền đi theo R-GD-12). | [CHỐT] |
| R-TIEN-08 | **(12/10)** Có bản in: báo giá, biên nhận phiếu thu, phiếu chi. | [CHỐT] |

### 2.2 Giá
| Mã | Luật | |
|---|---|---|
| R-TIEN-10 | Giá tính theo giờ. Mỗi gói có giá offline và giá online; giá trống nghĩa là gói không bán hình thức đó. Giá nằm ở bảng giá có ngày hiệu lực. | [CHỐT] |
| R-TIEN-11 | Giá online đang dùng: lớp chung mọi môn, mọi khối 120.000 đ/giờ; VIP 1:1 và 1:2 môn Toán 500.000 đ/giờ, môn khác 400.000 đ/giờ; VIP nhóm nhỏ và kèm riêng chỉ bán offline. (Dữ liệu bảng giá, không phải luật trong code.) | [CHỐT] |
| R-TIEN-12 | Không có giá OMO. Lớp OMO nhận cả học sinh online và offline; **hình thức học thuộc về ghi danh**, mỗi em trả giá theo hình thức của mình. Hình thức chọn trên dòng báo giá/đơn, chép sang ghi danh. | [CHỐT] |
| R-TIEN-13 | Cơ sở dữ liệu tự tính lại giá và thành tiền; không tin con số giao diện gửi lên. | [CHỐT] |
| R-TIEN-14 | Đơn hàng chụp lại đơn giá, chiết khấu, số giờ tại lúc tạo. Đổi bảng giá sau đó không làm đổi đơn cũ. | [CHỐT] |
| R-TIEN-15 | **(12/10)** Loại gói (danh mục khoá): `LC` lớp chung, `VIP` VIP 1:1 và 1:2 (chung giá), `VNN` VIP nhóm nhỏ, `KR` kèm riêng, `DV` dịch vụ (tính theo tháng), `TL` tài liệu (tính theo bộ). **Một gói có hai giá** (offline, online); hình thức chọn trên dòng đơn (R-TIEN-12). Gói có thể áp cho một khối hoặc một nhóm khối. `DV`, `TL` không có giá online, không có quỹ giờ, không sinh ghi danh. | [CHỐT] |

### 2.3 Đóng tiền từng phần, cấp giờ
| Mã | Luật | |
|---|---|---|
| R-TIEN-20 | Ghi danh được tạo khi tổng tiền đã vào của đơn ≥ tiền cọc tối thiểu (`deposit_min_amount`, mặc định 1.000.000 đ). | [CHỐT] |
| R-TIEN-21 | Giờ học cấp **theo tỉ lệ tiền đã thu**, không cấp trọn gói khi mới đặt cọc. Giờ của một dòng = số giờ dòng × tiền đã chia cho dòng ÷ thành tiền dòng. | [CHỐT] |
| R-TIEN-22 | Tiền của đơn nhiều dòng chia về các dòng theo tỉ lệ thành tiền từng dòng. | [CHỐT] |
| R-TIEN-23 | "Cấn vào dòng": phiếu thu có thể chọn một dòng của đơn. Tiền phiếu đó dồn vào dòng được chọn trước, tối đa bằng thành tiền dòng; phần thừa chia tỉ lệ cho các dòng khác. Để trống = chia tỉ lệ. Khoá lựa chọn khi phiếu rời trạng thái nháp. | [CHỐT] |
| R-TIEN-24 | Giờ tặng chỉ cấp khi đơn đã thu đủ. | [CHỐT] |
| R-TIEN-25 | Một em học hai lớp và hai anh em cùng một đơn xử lý giống nhau (mỗi dòng một ghi danh). | [CHỐT] |
| R-TIEN-26 | Đảo một khoản tiền: giữ nguyên khoản gốc, thêm một khoản âm trỏ về khoản gốc (**(12/10)** cùng dãy mã `KTV`, ghi "Đảo của …"). Không sửa, không xoá khoản gốc. Chặn đảo hai lần. Giờ đã cấp được tính lại theo tiền còn lại. **(12/10)** Bắt buộc chọn lý do đảo (danh mục). | [CHỐT] |
| R-TIEN-27 | Phiếu thu duyệt sau ngày vào lớp: giữ nguyên ngày vào lớp, cảnh báo kế toán "đã qua N buổi" (em không bị trừ các buổi đã qua vì không có tên trong danh sách các buổi đó). | [CHỐT] |
| R-TIEN-28 | **Hoàn phí** (chỉ qua ticket đề nghị đã duyệt, mục 9): tính lại số giờ đã học theo **giá gốc, bỏ chiết khấu lộ trình**; tiền hoàn = tiền đã đóng − giờ đã học × giá gốc − phí xử lý (`refund_processing_fee_percent`, mặc định 10% số tiền còn lại). Giờ tặng không hoàn. Kế toán lập phiếu chi (PC). Ví dụ: mua 48 giờ × 220.000 đ, chiết khấu 10%, đóng 9.504.000 đ, học 20 giờ → còn 9.504.000 − 4.400.000 = 5.104.000 đ → trừ 10% → hoàn 4.593.600 đ. | [CHỐT] |
| R-TIEN-29 | Chiết khấu theo % hoặc theo giờ tặng; mỗi chính sách có hiệu lực từ/đến, mức tối đa, có cần duyệt không. Nhiều chiết khấu trên một dòng thì **cộng dồn** (5% + 10% = 15%), tổng không quá `discount_total_cap_percent` (mặc định 20%); vượt trần phải quản lý cơ sở duyệt. **(12/10)** **Giờ tặng tính vào trần**, quy ra % = giờ tặng ÷ giờ mua (ví dụ giảm 15% + tặng 4/48 giờ ≈ 8,3% → tổng 23,3%, vượt trần, cần duyệt). Không có giới hạn chiết khấu riêng theo vai trò. | [CHỐT] |
| R-TIEN-30 | **(12/10)** **Quà tặng** tài liệu, dịch vụ (dòng `DV`/`TL` giá 0 đ) là chính sách quà tặng riêng, **không tính vào trần** R-TIEN-29; mỗi chính sách quà tặng có hiệu lực, mức tối đa, có cần duyệt không. | [CHỐT] |
| R-TIEN-31 | **(12/10)** **Hoàn một phần**: tiền hoàn = giờ hoàn × giá sau chiết khấu − phí xử lý (`refund_processing_fee_percent`). **Hoàn toàn bộ** (dừng hẳn) tính theo R-TIEN-28. | [CHỐT] |
| R-TIEN-32 | **(12/10)** **Chuyển phí**: giá trị chuyển = giờ còn lại × giá sau chiết khấu, **không trừ phí** (tiền vẫn ở HMT). Sang đơn mới thiếu thì đóng thêm; dư thì hoàn (R-TIEN-31) hoặc giữ thành số dư (R-TIEN-33). Giờ tặng còn lại không quy ra tiền. | [CHỐT] |
| R-TIEN-33 | **(12/10)** **Số dư khách hàng** (của phụ huynh): sinh từ chuyển phí, dừng học; không hết hạn; dùng cho đơn sau bằng thao tác "Dùng số dư" (ghi như một khoản tiền vào của đơn mới). Sổ số dư chỉ thêm dòng, không sửa, không xoá. | [CHỐT] |
| R-TIEN-34 | **(12/10)** Phiếu chi: Kế toán lập; một Kế toán được vừa lập vừa duyệt (ticket hoàn tiền đã qua quản lý cơ sở và kế toán duyệt); mọi thao tác ghi nhật ký. Phiếu chi ghi theo cơ sở của học sinh, không ghi CS3. | [CHỐT] |

## 3. Ghi danh, xếp lớp, quỹ giờ

| Mã | Luật | |
|---|---|---|
| R-GD-01 | **(17/10)** Mỗi dòng đơn sinh **một ghi danh, một quỹ giờ**, và **mỗi dòng đơn chỉ chọn một lớp**. Loại hình cũ "LC+HR" vẫn tách thành hai ghi danh. | [CHỐT] |
| R-GD-02 | **(17/10)** Ghi danh có các **dòng xếp lớp** (lớp, ngày vào, ngày rời, tình trạng). Bình thường một ghi danh có **một lớp đang học**; khi chuyển lớp thì đóng dòng cũ, mở dòng mới, **giờ còn lại đi theo ghi danh**. **Buổi Done chỉ trừ vào quỹ của ghi danh của lớp đó.** Sĩ số, danh sách lớp, điểm danh đọc từ dòng xếp lớp. Chi tiết: spec 02 mục "Luật ghi danh và xếp lớp". | [CHỐT] |
| R-GD-03 | **(17/10)** Quỹ giờ gắn với **ghi danh** (một ghi danh một lớp), không gom theo học sinh + môn + loại quỹ như bản cũ; kết thúc ghi danh này không thu hồi giờ của ghi danh khác. | [CHỐT] |
| R-GD-04 | Số dư quỹ giờ luôn tính từ sổ giờ. Sổ giờ chỉ thêm dòng, không sửa, không xoá; điều chỉnh bằng dòng ngược dấu kèm lý do. | [CHỐT] |
| R-GD-05 | Tình trạng ghi danh: Chờ xếp lớp, **Đã xếp lớp (12/10)**, Đang học, Bảo lưu, Hoàn thành, Chuyển lớp, Dừng, Hoàn phí (spec 02). Chờ xếp lớp = chưa có dòng xếp lớp đang mở; Đã xếp lớp = có lớp nhưng chưa có buổi Done; chuyển sang Đang học khi có buổi Done đầu tiên. Hàng chờ xếp lớp chỉ gồm ghi danh Chờ xếp lớp. | [CHỐT] |
| R-GD-06 | Ngày vào lớp: không bao giờ mặc định theo ngày duyệt phiếu thu. Chọn trên dòng đơn khi đã chọn lớp (bắt buộc có ngày nếu có lớp, chặn khi trình duyệt đơn); lớp đã có buổi thì chọn từ danh sách buổi sắp tới, chưa có buổi thì chọn ngày, kiểm ngày đúng thứ có lịch và không trước ngày khai giảng. Không chọn lớp thì ghi danh ở Chờ xếp lớp, vận hành xếp sau. | [CHỐT] |
| R-GD-07 | Thời hạn gói (`package_default_validity_months`, mặc định 6 tháng, tính từ ngày vào lớp) **chỉ để dự báo và báo cáo, không chặn gì**: quá hạn mà còn giờ thì em vẫn học tiếp bình thường, không mất giờ, không cần gia hạn. *[CHỜ anh quyết 17/10: một ghi danh một lớp nên mỗi lớp có ngày hết hạn riêng; chưa đổi chữ.]* | [CHỐT] |
| R-GD-08 | Đơn chỉ chọn được lớp đã duyệt (Approved), còn chỗ (sĩ số tối đa; 0 = không giới hạn), đúng môn, khối, cơ sở. | [CHỐT] |
| R-GD-09 | Bảo lưu (chỉ qua ticket đề nghị đã duyệt): giữ nguyên giờ còn lại; một lần không quá `reservation_max_months` (mặc định 6 tháng). Trong thời gian bảo lưu em không vào danh sách buổi. | [CHỐT] |
| R-GD-10 | Chuyển lớp, chuyển cơ sở (chỉ qua ticket đề nghị đã duyệt): đóng dòng xếp lớp cũ, mở dòng mới; giờ còn lại đi theo ghi danh. Giá các cơ sở như nhau nên chuyển cơ sở giữ nguyên số giờ. Doanh thu ghi cho cơ sở nơi buổi học Done. Chuyển lớp khác môn là chuyển phí (mục 9). | [CHỐT] |
| R-GD-11 | Học thử: miễn phí, không trừ giờ. Học thử là tư cách của học sinh trong một buổi, không phải loại buổi. | [CHỐT] |
| R-GD-12 | **Cho học trước, đóng tiền sau:** quản lý cơ sở bật trên đơn đã duyệt chưa thu tiền → ghi danh tạo sớm, quỹ được phép âm, tối đa `max_sessions_ahead` buổi chưa đóng tiền (mặc định 2). Vượt hạn mức thì em bị loại khỏi danh sách các buổi sau, kèm cảnh báo cho vận hành và sale. Khi thu tiền: các buổi đã học vẫn tính là đã học và trừ vào giờ được cấp. | [CHỐT] |
| R-GD-13 | Phiếu tái tục sinh tự động khi chạm một trong hai ngưỡng, ngưỡng nào trước tính ngưỡng đó: giờ còn ≤ `upsale_hours_left_threshold` (10 giờ), hoặc ngày hết giờ dự kiến còn ≤ `upsale_days_left_threshold` (30 ngày). Ngày hết giờ dự kiến tính từ lịch các buổi đã xếp của mọi lớp đang xếp (đã trừ nghỉ lễ, dời buổi). Vắng ≥ `absence_risk_sessions` (3) buổi **trong `absence_risk_window_days` (30) ngày gần nhất (12/10)** thì gắn cờ rủi ro trên phiếu tái tục. **(12/10)** Vòng đời phiếu tái tục: L1 Chờ tái tục (L1A hệ thống sinh, L1B tạo tay) · L2 Đã liên hệ · L3 Đang tư vấn · L4 Đang cân nhắc · **L5 Không tái tục** (kết thúc, bắt buộc lý do từ danh mục) · L6 Đồng ý tái tục · L7 Dự thu (L7A đã gửi báo giá, L7B đã có đơn chờ đóng tiền) · L8 Hoàn thành tái tục. *[CHỜ anh quyết 17/10: tính theo ghi danh, một phiếu tái tục cho mỗi ghi danh; học sinh Đại + Hình có thể có hai phiếu. Chưa áp dụng.]* | [CHỐT] |
| R-GD-14 | **(17/10)** Toán khối 7+ học cả Đại và Hình thì **hai dòng đơn riêng** (một lớp DAI, một lớp HINH), thành **hai ghi danh riêng**, mỗi ghi danh một quỹ giờ riêng. Khi lập đơn, hệ thống **nhắc (không chặn)** nếu học sinh mới có một trong hai. Thay cho bản 12/10 "một dòng đơn, hai lớp, chung quỹ giờ". | [CHỐT] |
| R-GD-15 | **(17/10)** Xếp lớp **chặn** nếu có **buổi trùng giờ** (cùng ngày, cùng giờ, tính cả buổi sắp sinh theo lịch) với lớp em đang học, kể cả lớp của ghi danh khác. Lớp trùng vẫn hiện nhưng không chọn được, kèm lý do. Hai lớp luân phiên (không có buổi nào trùng ngày giờ) không bị chặn. | [CHỐT] |
| R-GD-16 | **(12/10)** **Dừng học** chỉ qua ticket đề nghị nhóm "Dừng học" đã duyệt. Giờ còn lại chọn một trong hai: hoàn tiền (R-TIEN-28) hoặc giữ thành số dư khách hàng (giờ còn lại × giá sau chiết khấu, không trừ phí, R-TIEN-33). Giờ tặng còn lại bị huỷ. Không có lựa chọn "giữ nguyên giờ": nghỉ tạm thì dùng Bảo lưu. | [CHỐT] |
| R-GD-17 | **(12/10)** Học thử: tối đa `trial_sessions_max_per_opportunity` (2) buổi cho mỗi cơ hội, vượt thì chặn. Không tính vào sĩ số lớp, không tính vào chỗ còn trống khi bán; có tính vào số em của buổi (hiện "Sĩ số 12/15 · học thử 1"), vượt sĩ số tối đa chỉ cảnh báo. Cơ hội khác khối với lớp chỉ cảnh báo, không chặn. | [CHỐT] |
| R-GD-18 | **(17/10)** **Hết giờ theo ghi danh (theo lớp).** Ghi danh nào hết giờ thì **hết phí ở lớp đó**; học sinh **không được điểm danh có trừ giờ** vào lớp ấy khi quỹ bằng 0: **chặn, không cho âm** (lỗi có mã, câu tiếng Việt). Ngoại lệ duy nhất: "cho học trước, đóng tiền sau" (R-GD-12), quỹ được âm trong hạn mức. Muốn chuyển giờ từ ghi danh (lớp) này sang ghi danh khác: **bắt buộc qua phân hệ ticket, Đề nghị nhóm "Chuyển phí" đã duyệt** (R-CS-02); không sửa tay. Duyệt xong ghi hai dòng ngược dấu vào sổ giờ (trừ nguồn, cộng đích) kèm mã ticket. | [CHỐT] |

## 4. Lớp học

| Mã | Luật | |
|---|---|---|
| R-LOP-01 | Lớp đi qua các bước duyệt: Nháp → Đã trình → Đã xác nhận → Đã duyệt → Đã đóng; nhánh Từ chối (quay về Nháp được) và Huỷ. Đường đi: Nháp→[Đã trình, Huỷ]; Đã trình→[Đã xác nhận, Từ chối, Huỷ]; Đã xác nhận→[Đã duyệt, Từ chối, Huỷ]; Đã duyệt→[Đã đóng]; Từ chối→[Nháp, Huỷ]. | [CHỐT] |
| R-LOP-02 | Vận hành soạn và trình; quản lý cơ sở duyệt cả bước xác nhận và bước duyệt. Chỉ sửa thông tin lớp ở Nháp hoặc Từ chối. | [CHỐT] |
| R-LOP-03 | Duyệt lớp bắt buộc có thời khoá biểu. Duyệt xong thì **tự sinh buổi học** từ thời khoá biểu. **Khác bản cũ** (bản cũ sinh buổi bằng nút bấm tay). | [CHỐT] |
| R-LOP-04 | Đóng lớp bị chặn nếu còn học sinh còn giờ (liệt kê tên). Huỷ lớp bị chặn nếu đã có buổi Done. | [CHỐT] |
| R-LOP-05 | Tình trạng duyệt và tình trạng vận hành của lớp là hai trường riêng. | [CHỐT] |
| R-LOP-06 | Nhân sự chỉ mở lớp ở cơ sở mình; Admin mọi cơ sở. | [CHỐT] |
| R-LOP-07 | Khung chương trình bắt buộc với lớp chung, tuỳ chọn với lớp riêng. Lớp có "bài bắt đầu" (lớp mở giữa chừng khung). | [CHỐT] |
| R-LOP-08 | **(17/10)** Thời khoá biểu: mỗi thứ có thể nhiều khung giờ; mỗi khung có giờ, giáo viên, trợ giảng, phòng riêng, **cách lặp** (R-LOP-13). Trùng phòng thì cảnh báo, không chặn; **kiểm trùng ở cấp buổi thật** (cùng ngày, cùng giờ), không kiểm ở cấp khung, nên hai lớp luân phiên cùng khung giờ không bị coi là trùng. | [CHỐT] |
| R-LOP-09 | **(17/10)** Ngày kết thúc dự kiến: chạy lịch từ ngày bắt đầu, lấy các thứ trong thời khoá biểu **theo cách lặp của từng khung**, bỏ ngày nghỉ lễ (bảng ngày nghỉ), đếm đủ số buổi. | [CHỐT] |
| R-LOP-10 | Bình thường một lớp một giáo viên; đổi giáo viên = sửa lớp và sinh lại các buổi chưa diễn ra. Giáo viên ghi theo từng khung giờ, từng buổi. | [CHỐT] |
| R-LOP-11 | **(12/10)** Đổi lịch cố định của lớp đã duyệt (ca, phòng, thứ): xem trước các buổi chưa diễn ra bị đổi, rồi sinh lại. Đổi giáo viên **một buổi** (dạy thay) sửa trên buổi đó; giờ dạy tính cho người dạy thật. | [CHỐT] |
| R-LOP-12 | **(12/10)** Ngày nghỉ lễ áp dụng cho mọi cơ sở hoặc từng cơ sở (mặc định mọi cơ sở). Thêm ngày nghỉ sau khi đã sinh buổi thì xem trước các buổi bị ảnh hưởng rồi dời. | [CHỐT] |
| R-LOP-13 | **(17/10)** **Cách lặp của khung giờ.** Mỗi khung giờ có **"lặp mỗi N tuần"** (N là số nguyên từ 1 đến `class_slot_repeat_weeks_max`, mặc định 1 = hàng tuần) và **"buổi đầu tiên vào ngày …"** (đúng thứ của khung, không trước ngày khai giảng). Luân phiên Đại, Hình: hai lớp cùng thứ, giờ, phòng, cùng lặp mỗi 2 tuần, ngày buổi đầu cách nhau 1 tuần. Duyệt lớp tự sinh buổi theo cách lặp (R-LOP-03). Đổi cách lặp của lớp đã duyệt đi qua luồng đổi lịch cố định (R-LOP-11): xem trước các buổi chưa diễn ra bị đổi rồi sinh lại. | [CHỐT]; tham số `class_slot_repeat_weeks_max` khai báo bằng migration (mặc định 4, khoảng 1–8) |
| R-LOP-14 | **(17/10)** **Nhóm lớp.** Hai lớp Toán `DAI` và `HINH` cùng khối, cùng cơ sở được **gắn vào một nhóm lớp** (nhóm có tối đa một lớp mỗi môn, một lớp không thuộc quá một nhóm). Nhóm **không có mã riêng**; mã mỗi lớp giữ đúng quy định spec 02 (`CS-Năm-Môn-Khối-Phânloại-Trìnhđộ-STT`, số thứ tự cấp riêng cho từng lớp). **Tên chung** của nhóm (ví dụ tên cũ 9M1) là **tham chiếu tự do, tuỳ chọn**, không thay mã, hiện nhỏ dưới mã lớp. Mỗi lớp trong nhóm **vẫn độc lập**: giáo viên, lịch, khung chương trình, sĩ số, bước duyệt riêng. Nhóm dùng để: (1) tạo hai lớp một lần ("Tạo lớp còn lại cho nhóm này"); (2) xếp lớp một lần cho học sinh: chọn nhóm thì hệ thống xếp ghi danh Đại vào lớp DAI, ghi danh Hình vào lớp HINH, học sinh chỉ có một ghi danh thì chỉ xếp lớp tương ứng; (3) hiển thị chung trên lịch và danh sách. Chuyển lớp, đóng lớp, huỷ lớp tính từng lớp, không kéo theo lớp kia. | [CHỐT]; kiểm môn theo khối khi tạo lớp **[CHỜ anh quyết]** (khối từ `algebra_geometry_split_grade` trở lên không tạo lớp chung `TOAN`, khối dưới không tạo `DAI`, `HINH`, trừ lớp riêng; đề xuất chặn trong hàm tạo lớp, lỗi có mã; chưa áp dụng) |
| R-LOP-15 | **(17/10)** **Mã lớp cũ.** Theo luật chung về mã cũ ở spec 02 (cột `legacy_ref`, tìm kiếm được, hiện nhỏ dưới mã mới), màn chi tiết lớp (LOP-02) hiện rõ ô **"Mã cũ (Sheet)"** cạnh mã lớp; ô tìm của danh sách lớp (LOP-01) gõ mã cũ ra đúng lớp. Người dùng thường không sửa; **đợt chuyển dữ liệu từ Google Sheet điền**, Admin sửa được khi điền sai (ghi nhật ký). Mã mới vẫn là mã chính. Khác với "tên chung của nhóm" (R-LOP-14). | [CHỐT] |

## 5. Buổi học, danh sách, trừ giờ

### 5.1 Loại buổi và tình trạng buổi
| Mã | Luật | |
|---|---|---|
| R-BUOI-01 | Bốn loại buổi: **Chính** và **Củng cố** (trừ giờ); **Học bù** và **Học bổ trợ** (không trừ giờ). | [CHỐT] |
| R-BUOI-02 | Tình trạng buổi: Nháp → Đã chốt (chốt danh sách, sinh dòng điểm danh) → Done (trừ giờ); hai nhánh huỷ: **Huỷ có tính phí** và **Huỷ không tính phí**. | [CHỐT] |
| R-BUOI-03 | Học bù: CSKH hoặc sale tạo yêu cầu, quản lý cơ sở duyệt → sinh buổi loại Học bù. Không trừ giờ, kể cả khi buổi bù bị huỷ có tính phí. Không gắn với buổi gốc, có lý do, chưa giới hạn số buổi. | [CHỐT] |
| R-BUOI-04 | Củng cố: yêu cầu riêng (vì tính tiền như buổi thường), phải được duyệt; duyệt thì chèn buổi và dời nhãn bài các buổi sau. | [CHỐT] |
| R-BUOI-05 | Học bổ trợ: kèm thêm cho em yếu, tạo từ lớp, quản lý cơ sở duyệt, không trừ giờ, vẫn tính vào giờ dạy của giáo viên (căn cứ lương). Thay cho loại "bổ trợ", "bù nền" cũ. Bỏ hẳn quỹ giờ bổ trợ và quỹ bù nền. | [CHỐT] |
| R-BUOI-06 | Trung tâm huỷ buổi (cả lớp nghỉ, ký hiệu N cũ) → Huỷ không tính phí, tự thêm một buổi vào cuối lịch và dời bài theo. | [CHỐT] |
| R-BUOI-07 | Học sinh huỷ buổi lớp riêng: **người huỷ tự chọn** "Huỷ có tính phí" (không bù) hoặc "Huỷ không tính phí" (xếp buổi bù), bắt buộc ghi lý do. Không áp mốc giờ cố định. | [CHỐT] |
| R-BUOI-08 | Buổi học không có mã cho người đọc; hiển thị "tên lớp · Buổi N · ngày". | [CHỐT] |
| R-BUOI-09 | **(12/10)** Huỷ buổi được tới khi buổi Done, kể cả sau khi đã chốt danh sách. Người huỷ: CSKH, quản lý cơ sở; giáo viên không được huỷ. Huỷ thì các dòng điểm danh đã sinh bị vô hiệu. Buổi Done không huỷ được; sai thì sửa theo R-GIO-07. | [CHỐT] |
| R-BUOI-10 | **(12/10)** Yêu cầu củng cố (trừ giờ) phải ghi nhận **phụ huynh đã đồng ý**: kênh xác nhận, ngày, người xác nhận; chưa có thì không gửi duyệt được. Sau đó quản lý cơ sở duyệt như R-BUOI-04. | [CHỐT] |

### 5.2 Danh sách buổi và trừ giờ
| Mã | Luật | |
|---|---|---|
| R-GIO-01 | **Có tên trong danh sách + buổi Done → trừ giờ**, dù em có mặt, đi muộn hay vắng. **Khác bản cũ** (bản cũ: vắng không trừ). Chốt 03/10/2026, xác nhận lại 09/10/2026. | [CHỐT] |
| R-GIO-02 | Danh sách chốt khi buổi chuyển sang Đã chốt. Ghi danh sinh **sau** ngày buổi không lọt vào danh sách buổi đó. | [CHỐT] |
| R-GIO-03 | Không vào danh sách: chưa tới ngày vào lớp, đang bảo lưu, đã kết thúc/dừng, số dư không đủ giờ buổi (trừ khi đang trong hạn mức "cho học trước", R-GD-12). | [CHỐT] |
| R-GIO-04 | Một em một dòng điểm danh mỗi buổi, kể cả khi có hai ghi danh cùng xếp vào lớp đó; trừ giờ đúng một lần, vào ghi danh có **hạn sử dụng sớm nhất** (hết giờ thì sang ghi danh kế tiếp). | [CHỐT] |
| R-GIO-05 | Tự chốt buổi: định kỳ mỗi `session_autoclose_before_minutes` (30 phút), chốt các buổi bắt đầu trong `session_autoclose_scan_hours` (2 giờ) tới. | [CHỐT] |
| R-GIO-06 | Tự Done: buổi đã kết thúc và giáo viên đã hoàn tất điểm danh + nhận xét + **trạng thái BTVN** của mọi em có mặt (R-GV-11; buổi trước không giao BTVN thì bỏ qua phần này) → Done. Chưa đủ thì giữ Đã chốt và ghi lý do chưa Done. | [CHỐT] |
| R-GIO-07 | **(12/10)** Sửa điểm danh sau khi buổi Done: chỉ quản lý cơ sở (hoặc Admin), bắt buộc lý do. Đổi giữa các trạng thái đi học không đổi giờ (vẫn trừ theo R-GIO-01). Thêm hoặc bớt em khỏi danh sách thì thêm dòng điều chỉnh sổ giờ (R-GD-04). | [CHỐT] |

## 6. Điểm danh

| Mã | Luật | |
|---|---|---|
| R-DD-01 | Trạng thái: Có mặt, Đi muộn, Vắng có phép, Vắng không phép; trống = chưa điểm danh. | [CHỐT] |
| R-DD-02 | Điểm danh hai phía: vận hành và giáo viên ghi riêng; **ô của giáo viên quyết định trạng thái chính thức**. | [CHỐT] |
| R-DD-03 | Vận hành ghi kèm lý do liên hệ (danh mục: Không nghe máy, Đã nhắc vào lớp, Đã vào lớp, Xin nghỉ học…). | [CHỐT] |

## 7. Cổng giáo viên

| Mã | Luật | |
|---|---|---|
| R-GV-01 | Tiêu chí chấm: A. Thái độ **3** tiêu chí (Tập trung, Chủ động, Tinh thần học tập); B. Kiến thức 3 tiêu chí (Nắm kiến thức, Hiểu bản chất, Ghi nhớ); C. Vận dụng: mỗi nội dung buổi là một mục chấm; D. BTVN. Thang 1–5, mô tả mức trong danh mục rubric, có thể riêng theo môn. **Khác tài liệu cũ** (Thái độ 4). | [CHỐT] |
| R-GV-02 | Điểm trống khác điểm 0 ("chưa chấm" ≠ "chấm 0"). | [CHỐT] |
| R-GV-03 | Điểm trung bình vận dụng do cơ sở dữ liệu tính, không nhận từ giao diện. | [CHỐT] |
| R-GV-04 | Chấm xong một buổi: mọi em có trạng thái đi học; em có mặt có đủ 6 điểm tiêu chí và lời nhắn phụ huynh; em vắng không phải chấm. | [CHỐT] |
| R-GV-05 | Hạn hoàn tất buổi: `teacher_session_complete_hours` (8 giờ) sau khi buổi kết thúc. Đóng dấu một lần khi chấm xong em cuối: Đúng hạn hoặc Trễ hạn, ghi số giờ trễ. | [CHỐT] |
| R-GV-06 | Trễ hạn: giai đoạn đầu hệ thống chỉ ghi và **báo cáo hằng tháng** số buổi trễ, tổng giờ trễ từng giáo viên; mức xử lý do HMT quyết theo nội quy, chưa tự tính vi phạm. | [CHỐT] |
| R-GV-07 | Nội dung buổi là danh sách dòng riêng (mỗi dòng thành một mục chấm vận dụng). | [CHỐT] |
| R-GV-08 | Giáo viên KHÔNG được: tạo dòng điểm danh, đổi tình trạng buổi, ghi sổ giờ. Chỉ ghi điểm danh, điểm, nhận xét, nội dung buổi, BTVN giao mới. Chỉ thấy buổi của mình. | [CHỐT] |
| R-GV-09 | Trợ giảng có quyền như giáo viên trong các lớp được phân công. | [CHỐT] |
| R-GV-10 | Hạn chấm BTVN: BTVN giao ở buổi N được chấm ở buổi N+1, trong hạn hoàn tất của buổi N+1 (`teacher_session_complete_hours`). Khi có LMS (giai đoạn 4) học sinh nộp trên app thì xét lại hạn riêng. | [CHỐT] |
| R-GV-11 | Mỗi em mỗi bài BTVN có đúng một trạng thái: **Đã chấm** (điểm 1–5) · **Làm chưa xong** (vẫn có điểm) · **Không làm** · **Nộp sau** (chờ cập nhật ở buổi sau, sửa được điểm mà không mở lại buổi cũ) · **Không áp dụng** (vắng buổi giao bài, hoặc giáo viên miễn). Danh sách trạng thái là danh mục hệ thống (đổi tên được, không thêm bớt). Điểm BTVN theo **thang 1–5** (12/10: nhắc lại vì bản vẽ từng dùng thang 10). | [CHỐT] |
| R-GV-12 | Báo cáo BTVN tách **hai chỉ số**, không gộp "không làm" thành điểm 0: **Tỉ lệ làm bài** = (Đã chấm + Làm chưa xong) ÷ số bài phải làm (không tính Không áp dụng; Nộp sau chưa tính tới khi cập nhật). **Điểm BTVN trung bình** = trung bình điểm các bài Đã chấm và Làm chưa xong. | [CHỐT] |
| R-GV-13 | **(12/10)** Giáo viên, trợ giảng chỉ dùng **cổng Giáo viên** (không vào CRM), chỉ thấy lớp, buổi, học sinh được phân công. Cổng có hai bố cục: điện thoại (từng bước, từng em) và laptop (bảng chấm nhanh cả lớp). | [CHỐT] |
| R-GV-14 | **(12/10)** **Giờ dạy tính lương**: buổi Done, mọi loại buổi thực dạy (Chính, Củng cố, Học bù, Học bổ trợ), theo thời lượng buổi, tính cho người dạy thật, cả giáo viên và trợ giảng. Buổi huỷ (kể cả huỷ có tính phí) không tính. Kế toán hoặc Admin **chốt tháng**; tháng đã chốt giữ nguyên, sửa buổi sau đó thì chênh lệch đưa vào tháng sau. | [CHỐT] |

## 8. Tham số Cài đặt dùng trong file này

Tên tham số là tên đã đặt trong repo (GĐ0 bước 2, bước 3). Tham số đánh dấu **(12/10)** là mới, chưa khai báo trong cơ sở dữ liệu. Khoảng cho phép và cột "ghi đè theo cơ sở": xem `docs/spec/06-danh-muc-va-tham-so.md` mục 2. Nguyên tắc **(12/10)**: tham số về tiền, giá, chiết khấu, đăng nhập dùng một giá trị chung; chỉ một số tham số vận hành được ghi đè theo cơ sở.

| Tham số | Mặc định | Luật |
|---|---|---|
| `max_sessions_ahead` | 2 buổi | R-GD-12 |
| `session_autoclose_before_minutes` | 30 phút | R-GIO-05 |
| `session_autoclose_scan_hours` | 2 giờ | R-GIO-05 |
| `teacher_session_complete_hours` | 8 giờ | R-GV-05 |
| `algebra_geometry_split_grade` | 7 | spec 02 |
| `class_slot_repeat_weeks_max` **(17/10)** | 4 tuần (khoảng 1–8) | R-LOP-13 |
| `package_default_validity_months` | 6 tháng | R-GD-07 |
| `upsale_hours_left_threshold` | 10 giờ | R-GD-13 |
| `upsale_days_left_threshold` | 30 ngày | R-GD-13 |
| `absence_risk_sessions` | 3 buổi | R-GD-13 |
| `absence_risk_window_days` **(12/10)** | 30 ngày | R-GD-13 |
| `trial_sessions_max_per_opportunity` **(12/10)** | 2 buổi mỗi cơ hội | R-GD-17 |
| `quotation_validity_days` | 14 ngày | R-TIEN-05 |
| `deposit_min_amount` | 1.000.000 đ | R-TIEN-20 |
| `reservation_max_months` | 6 tháng | R-GD-09 |
| `refund_processing_fee_percent` | 10% | R-TIEN-28, R-TIEN-31 |
| `discount_total_cap_percent` | 20% | R-TIEN-29 |
| `sla_complaint_response_hours` / `sla_complaint_resolve_days` | 24 giờ / 3 ngày | R-CS-08 |
| `sla_complaint_critical_response_hours` / `sla_complaint_critical_resolve_days` | 2 giờ / 1 ngày | R-CS-08 |
| `sla_request_response_hours` / `sla_request_resolve_days` | 24 giờ / 2 ngày | R-CS-08 |
| `sla_refund_resolve_days` | 7 ngày | R-CS-08 |
| `complaint_reopen_max_days` | 7 ngày | R-CS-06 |
| `complaint_parent_confirm_days` **(12/10)** | 3 ngày | R-CS-14 |
| `login_lock_after_failures`, `login_lock_minutes` | 10 lần, 15 phút | R-HT-03 |
| `staff_idle_logout_minutes`, `teacher_idle_logout_minutes`, `student_idle_logout_minutes` | 60 phút, 7 ngày, 7 ngày (lưu bằng phút: 10.080) | R-HT-03 |

### Đối chiếu tên tham số: tài liệu gốc → repo

Tài liệu gốc của anh Trường (bản 12/10) dùng tên tiếng Việt; repo giữ tên đã đặt từ bước 2, bước 3. Khi chép luật mới từ tài liệu gốc thì đổi tên theo bảng này.

| Tên trong tài liệu gốc | Tên trong repo | Ghi chú |
|---|---|---|
| `cho_hoc_truoc_toi_da` | `max_sessions_ahead` | |
| `tu_chot_truoc_phut` | `session_autoclose_before_minutes` | Nghĩa đúng là **chu kỳ quét** (R-GIO-05); tên và mô tả trong repo đang ghi "trước giờ học", xem mục Mâu thuẫn của PR 12/10 |
| `tu_chot_quet_gio` | `session_autoclose_scan_hours` | |
| `han_gv_hoan_tat_gio` | `teacher_session_complete_hours` | |
| `khoi_tach_dai_hinh` | `algebra_geometry_split_grade` | |
| `thoi_han_goi_mac_dinh` | `package_default_validity_months` | |
| `nguong_tai_tuc_gio` | `upsale_hours_left_threshold` | |
| `nguong_tai_tuc_ngay` | `upsale_days_left_threshold` | |
| `so_buoi_vang_rui_ro` | `absence_risk_sessions` | |
| `so_ngay_dem_vang` | `absence_risk_window_days` | Mới (12/10), chưa có trong cơ sở dữ liệu |
| `hoc_thu_toi_da` | `trial_sessions_max_per_opportunity` | Mới (12/10), chưa có trong cơ sở dữ liệu |
| `han_hieu_luc_bao_gia` | `quotation_validity_days` | |
| `tien_coc_toi_thieu` | `deposit_min_amount` | |
| `bao_luu_toi_da` | `reservation_max_months` | |
| `phi_xu_ly_hoan_phi` | `refund_processing_fee_percent` | |
| `tran_chiet_khau_tong` | `discount_total_cap_percent` | |
| `sla_*` | `sla_complaint_response_hours`, `sla_complaint_resolve_days`, `sla_complaint_critical_response_hours`, `sla_complaint_critical_resolve_days`, `sla_request_response_hours`, `sla_request_resolve_days`, `sla_refund_resolve_days` | |
| `cs_mo_lai_toi_da_ngay` | `complaint_reopen_max_days` | |
| `cs_han_ph_xac_nhan_ngay` | `complaint_parent_confirm_days` | Mới (12/10), chưa có trong cơ sở dữ liệu |
| `so_lan_sai_tam_khoa` | `login_lock_after_failures` | Đã có từ bước 3 |
| `thoi_gian_tam_khoa_phut` | `login_lock_minutes` | Đã có từ bước 3 |
| `tu_dang_xuat_nhan_vien_phut` | `staff_idle_logout_minutes` | Đã có từ bước 3 |
| `tu_dang_xuat_gv_ngay` | `teacher_idle_logout_minutes` | Đã có từ bước 3; repo lưu bằng **phút** (7 ngày = 10.080) |
| `tu_dang_xuat_hs_ngay` | `student_idle_logout_minutes` | Đã có từ bước 3; repo lưu bằng **phút** |

## 9. Chăm sóc khách hàng (ticket đề nghị, khiếu nại)

Lộ trình: ticket **đề nghị** làm ở giai đoạn 2 (cùng chuyển lớp, bảo lưu, hoàn phí); **khiếu nại** ở giai đoạn 2 hoặc 3; phụ huynh tự gửi từ app ở giai đoạn 4.

| Mã | Luật | |
|---|---|---|
| R-CS-01 | Hai loại ticket: **Đề nghị** và **Khiếu nại** (không có loại góp ý/khen ngợi). Mã: `DN-<CS>-<YYMM>-<STT>`, `KN-<CS>-<YYMM>-<STT>`, cấp như chứng từ (liên tục theo cơ sở, theo tháng). | [CHỐT] |
| R-CS-02 | **Bắt buộc qua ticket đề nghị đã duyệt** mới được: chuyển lớp, chuyển cơ sở, bảo lưu, chuyển phí, hoàn tiền, dừng học (12/10). Thao tác thật chạy bằng hàm nghiệp vụ và gắn ngược mã ticket; cơ sở dữ liệu chặn nếu không có ticket hợp lệ. | [CHỐT] |
| R-CS-03 | Nhóm và nhóm con đề nghị (dữ liệu nạp sẵn): **Chuyển lớp** (cùng môn: đổi giờ học · đổi trình độ · đổi giáo viên; khác môn) · **Chuyển cơ sở** · **Bảo lưu** (bảo lưu mới · gia hạn bảo lưu · quay lại học sớm) · **Chuyển phí** (sang môn khác · sang anh/chị/em · sang gói khác) · **Hoàn tiền** (toàn bộ · một phần) · **Đổi lịch học** (dời một buổi · đổi ca cố định · xin học bù) · **Dừng học (12/10)**. Chuyển lớp khác môn xử lý như chuyển phí: dừng ghi danh môn cũ, quy tiền còn lại sang đơn môn mới (thiếu đóng thêm, dư hoàn hoặc giữ). | [CHỐT] |
| R-CS-04 | Nhóm và nhóm con khiếu nại (dữ liệu nạp sẵn): **Chương trình học** (nội dung khó/dễ · tiến độ · không bám chương trình trên trường · tài liệu) · **Giáo viên** (thái độ · chuyên môn · đi muộn, nghỉ dạy · thay giáo viên nhiều · nhận xét, chấm bài) · **Phương pháp giảng dạy** (cách giảng khó hiểu · BTVN nhiều/ít · kiểm tra đánh giá · quản lý lớp) · **Tư vấn tuyển sinh** (không đúng cam kết · thái độ · chậm phản hồi · xếp lớp sai trình độ) · **Vận hành** (đổi lịch đột xuất · phòng học, cơ sở vật chất · sĩ số · đưa đón, an toàn · thông báo chậm) · **Chăm sóc** (không phản hồi · thái độ · không gửi nhận xét, báo cáo) · **Khác**. Khiếu nại có mức độ: Thấp, Trung bình, Cao, Nghiêm trọng; Nghiêm trọng báo Ban giám đốc ngay. | [CHỐT] |
| R-CS-05 | Các bước **đề nghị**: Mới → Đang xử lý → Chờ duyệt → Đã duyệt → Đang thực hiện → Hoàn thành; nhánh Từ chối (bắt buộc lý do), Khách huỷ. | [CHỐT] |
| R-CS-06 | Các bước **khiếu nại**: Mới → Đã tiếp nhận → Đang xác minh → Có phương án → Chờ phụ huynh xác nhận → Đóng – hài lòng / Đóng – không hài lòng; nhánh Mở lại (trong `complaint_reopen_max_days` ngày sau khi đóng), Nâng cấp (quá hạn hoặc nghiêm trọng: lên quản lý cơ sở, rồi Ban giám đốc). | [CHỐT] |
| R-CS-07 | Ai duyệt theo nhóm con (mặc định, sửa được trong cấu hình): chuyển lớp cùng môn, bảo lưu, đổi lịch → quản lý cơ sở; chuyển lớp khác môn, chuyển phí, hoàn tiền, dừng học (12/10) → quản lý cơ sở rồi kế toán; chuyển cơ sở → quản lý **cả hai** cơ sở. | [CHỐT] |
| R-CS-08 | Hạn xử lý (SLA) mặc định: khiếu nại thường phản hồi 24 giờ, xử lý xong 3 ngày; khiếu nại nghiêm trọng phản hồi 2 giờ, xong 1 ngày; đề nghị phản hồi 24 giờ, xong 2 ngày (hoàn tiền 7 ngày). Quá hạn thì cảnh báo người phụ trách, rồi tự nâng cấp lên quản lý cơ sở. | [CHỐT] |
| R-CS-09 | Ticket gắn: học sinh, phụ huynh, ghi danh, lớp; khiếu nại gắn thêm người bị khiếu nại (giáo viên, sale, CSKH) để vào báo cáo của người đó. Thông tin: kênh tiếp nhận, mức độ, người phụ trách, hạn phản hồi, hạn xử lý, mô tả, đính kèm, phương án, kết quả, mức hài lòng của phụ huynh; ghi chú trao đổi và lịch sử như mọi bản ghi. | [CHỐT] |
| R-CS-10 | Ai tạo ticket: CSKH, sale, quản lý cơ sở, **giáo viên** (từ cổng giáo viên; chỉ tạo, không duyệt, không xem ticket của người khác ngoài lớp mình). | [CHỐT] |
| R-CS-11 | **Cấu hình, không viết cứng:** nhóm, nhóm con, mức độ, kênh tiếp nhận là danh mục (nhóm con kéo theo nghiệp vụ của R-CS-02 là danh mục khoá: đổi tên được, không ngừng được); SLA từng loại và mức độ, số ngày được mở lại là tham số Cài đặt; ai duyệt từng nhóm con là cấu hình có hiệu lực (như ma trận quyền). Các bước xử lý (R-CS-05, R-CS-06) là luật lõi trong code, tên hiển thị đổi được. | [CHỐT] |
| R-CS-12 | Báo cáo: số ticket theo loại, nhóm, cơ sở; tỉ lệ đúng hạn; thời gian xử lý trung bình; khiếu nại theo từng giáo viên, sale, CSKH; lý do chuyển lớp, bảo lưu, chuyển phí, hoàn tiền. | [CHỐT] |
| R-CS-13 | **(12/10)** Khi phụ huynh chưa có tài khoản: màn "Nhận xét chờ gửi phụ huynh" cho CSKH lấy lời nhắn sau buổi đã chấm xong (sao chép hoặc xuất ảnh để gửi Zalo tay) và đánh dấu đã gửi. | [CHỐT] |
| R-CS-14 | **(12/10)** Phụ huynh chấm hài lòng 5 mức: 4–5 đóng "hài lòng", 1–3 đóng "không hài lòng". "Chưa đồng ý phương án" đưa ticket về Đang xác minh. Hạn phụ huynh xác nhận `complaint_parent_confirm_days` (3 ngày); quá hạn thì nhắc CSKH gọi xác nhận, **không tự đóng**. | [CHỐT] |

## 10. Báo cáo (12/10)

| Mã | Luật | |
|---|---|---|
| R-BC-01 | Báo cáo tổng hợp làm trên **Looker Studio** (nối view chỉ đọc). Trong app chỉ có: tổng quan Ban giám đốc, báo cáo giáo viên trễ hạn (R-GV-06), giờ dạy giáo viên (R-GV-14), và các danh sách theo dõi vận hành. | [CHỐT] |
| R-BC-02 | **Học sinh đang học** = số em có ít nhất một ghi danh Đang học tại ngày cuối của khoảng đang xem. Em đang bảo lưu hiện thành con số riêng, không cộng vào. | [CHỐT] |
| R-BC-03 | **Tỉ lệ tái tục** = số phiếu L8 ÷ (L8 + L5), chỉ tính phiếu kết thúc trong khoảng đang xem. | [CHỐT] |
| R-BC-04 | **Doanh thu ghi nhận** của một buổi Done = giờ trừ × đơn giá ghi nhận; đơn giá ghi nhận = tiền dòng đơn ÷ (giờ mua + giờ tặng), chia đều mọi giờ. Buổi huỷ có tính phí vẫn ghi nhận. Học bù, học bổ trợ ghi nhận 0 đ. Doanh thu tính cho cơ sở nơi buổi Done (R-GD-10). | [CHỐT] |
| R-BC-05 | **Quỹ giờ còn quy ra tiền** = tổng (giờ còn của từng ghi danh × đơn giá ghi nhận của ghi danh đó, R-BC-04). Giờ đã dạy cộng giờ còn phải dạy, quy ra tiền, bằng đúng tiền đã thu. | [CHỐT] |

## 11. Học tập (LMS) (12/10)

| Mã | Luật | |
|---|---|---|
| R-LMS-01 | Giáo viên giao bài cho cả lớp hoặc từng em; hạn mặc định là giờ vào buổi sau; có công tắc "Cho nộp lại" và "Nhận bài muộn". Giai đoạn 4 bản đầu soạn đề mỗi lần, chưa có kho đề. | [CHỐT] |
| R-LMS-02 | Nộp sau hạn nhưng trước khi giáo viên chấm: chấm bình thường, kèm **nhãn** "Nộp muộn" (không phải trạng thái). Tới lúc chấm chưa nộp: giáo viên chọn "Nộp sau" hoặc "Không làm" (R-GV-11). Tắt "Nhận bài muộn" thì quá hạn không nộp được. | [CHỐT] |
| R-LMS-03 | Nộp lại không giới hạn số lần trước khi chấm; chấm rồi thì khoá, trừ khi giáo viên mở lại. | [CHỐT] |
| R-LMS-04 | Tệp nộp tối đa 10 MB mỗi tệp, 20 trang mỗi bài. Ảnh tự nén trên máy trước khi tải (cạnh dài khoảng 2.000px). | [CHỐT] |
| R-LMS-05 | Phần thưởng: sao và chuỗi bài nộp đúng hạn; không điểm thưởng, không xếp hạng; bật tắt theo cơ sở bằng công tắc tính năng. | [CHỐT] |

## 12. Quyền và hệ thống (12/10)

| Mã | Luật | |
|---|---|---|
| R-HT-01 | Admin làm được mọi màn, mọi việc **không dính tiền** ở mọi cơ sở, kể cả làm thay khi người phụ trách vắng: duyệt yêu cầu buổi, đơn hàng, lớp, ticket; lịch sử ghi "Admin duyệt thay". **Việc tiền** (duyệt phiếu thu, đảo khoản, phiếu chi) Admin **không duyệt trực tiếp** (giữ chốt 10/10): kế toán vắng thì Admin gán tạm vai trò Kế toán cho người làm thay, có nhật ký, **có thời hạn**. (Chốt lại chiều 12/10; bản 12/10 đầu ghi Admin duyệt cả phiếu thu, đảo khoản.) | [CHỐT] |
| R-HT-02 | Ô chọn cơ sở khi xem dữ liệu nghiệp vụ không có CS3 Hội sở; riêng màn người dùng có CS3 (nhân viên Hội sở thuộc CS3). Công tắc tính năng không có cột CS3. | [CHỐT] |
| R-HT-03 | Đăng nhập sai `login_lock_after_failures` (10) lần thì tạm khoá `login_lock_minutes` (15) phút; đăng nhập học sinh cũng dùng Turnstile. Thời gian tự đăng xuất là tham số theo nhóm người dùng. | [CHỐT] |
| R-HT-04 | Danh mục lý do luôn có "Khác"; chọn "Khác" thì bắt buộc ghi chú. Danh mục "Lý do từ chối" có trường "Áp dụng cho" (báo giá, đơn, phiếu thu, lớp, ticket, yêu cầu buổi). Có danh mục riêng "Lý do đảo khoản", "Lý do khoá tài khoản", "Lý do không tái tục", "Lý do điều chỉnh giờ". Danh sách đầy đủ: `docs/spec/06-danh-muc-va-tham-so.md` mục 1. | [CHỐT] |
| R-HT-05 | CRM ưu tiên máy tính; các màn duyệt (hàng chờ duyệt, duyệt đơn, duyệt yêu cầu buổi, duyệt ticket) và điểm danh vận hành có bố cục điện thoại. | [CHỐT] |
| R-CRM-24 | **(16/10 tối)** **Vai trò ADMIN luôn giữ đủ quyền phân hệ Quản trị** (7 hành động, toàn hệ thống); lần lưu ma trận nào bỏ hoặc thu hẹp quyền này thì báo lỗi `HMT_ADMIN_GIU_QUYEN_QUAN_TRI` và hoàn tác cả lần lưu. Đã làm ở PR 6e (#33). | [CHỐT] |

## 13. Còn mở

Luật mới phát sinh thì thêm vào đúng mục, đánh dấu [CẦN CHỐT] cho tới khi anh Trường quyết. Các mục đang chờ anh quyết nằm ngay dưới.

**Chờ anh quyết, chưa đưa vào luật (17/10):**
- R-GD-07 (thời hạn gói): một ghi danh một lớp nên mỗi lớp có ngày hết hạn riêng; chưa đổi chữ.
- R-GD-13 (tái tục): tính theo ghi danh, một phiếu tái tục cho mỗi ghi danh (học sinh Đại + Hình có thể có hai phiếu, CSKH gộp khi báo giá).
- R-GD-09, R-GD-16 và spec 02 mục 5: bảo lưu, dừng học vẫn ở cấp ghi danh; một ticket đề nghị cho chọn nhiều ghi danh.
- R-GIO-03, R-GIO-04: "số dư" là quỹ của ghi danh; chỉ khi hai ghi danh cùng xếp vào một lớp mới xét hạn sử dụng sớm nhất.
- Spec 02 mục 3 (gợi ý Đại + Hình chuyển lên bước lập đơn, khi xếp lớp chỉ nhắc nếu thiếu lớp còn lại), mục 6, 7 (quỹ và dự báo hết giờ theo từng ghi danh).
- Kiểm môn theo khối khi tạo lớp (R-LOP-14).
- **Phát hiện khi đưa luật vào, chưa ai quyết:** spec 02 mục "Toán tách Đại số và Hình học" còn ghi "Phụ huynh mua tổng giờ Toán; gói và ghi danh chỉ có môn `TOAN`; không có giờ Đại, giờ Hình", vênh R-GD-14 mới (hai ghi danh riêng, mỗi ghi danh một quỹ giờ riêng) và mục 8 ("gói `TOAN` → lớp `TOAN`, `DAI`, `HINH`").
