# Quy trình phối hợp: anh Trường, Claude Chat, Claude Design, Claude Code

Cập nhật 17/10/2026. File này nằm trong repo (`docs/quy-trinh-phoi-hop.md`) và trong Project "HMT - CRM HOÀ MA TOÁN" trên Claude.

## 1. Ai làm gì
| | Vai | Việc chính | Đọc từ đâu |
|---|---|---|---|
| Anh Trường | Chủ sản phẩm | Quyết nghiệp vụ; thử trên staging; bình luận "OK" trên PR; cập nhật bản chạy thật qua `hmt-deploy` | |
| Claude Chat (tài khoản truongcx.work, Project "HMT - CRM HOÀ MA TOÁN") | Phân tích nghiệp vụ, kiến trúc, kiểm soát | Cùng anh chốt luật; viết đặc tả; soạn prompt cho Design và Code; soát kết quả trước khi anh OK | Repo (kết nối GitHub, chỉ đọc), Project, canvas của Design qua link, `docs/nhat-ky/` |
| Claude Design (hiện cùng tài khoản truongcx.work) | Thiết kế giao diện | Vẽ, sửa màn theo bản đồ màn hình và luật; giữ hệ thống thiết kế "HMT Platform" | Repo (kết nối GitHub, chỉ đọc), canvas của mình, file anh đính kèm, `docs/nhat-ky/` |
| Claude Code (VS Code, đổi qua lại 3 tài khoản Pro) | Lập trình | Code, kiểm thử, mở PR, báo chỗ luật vênh với code | Repo: `CLAUDE.md`, `docs/`, `design/`, `docs/nhat-ky/` |

## 2. Ba kho lưu
1. **Repo `hmt-vanhanh/hmt-platform`: nguồn sự thật.** Quyết định nào chưa nằm trong `docs/` thì coi như chưa có.
2. **Project trên Claude Chat:** bản sao tài liệu chính, để mở chat mới không phải dán lại.
3. **Đoạn chat và hệ thống thiết kế bên Claude Design:** thành phần, khuôn, màn đã vẽ.

Tài liệu chính trong repo:

| File | Nội dung |
|---|---|
| `docs/spec/04-luat-nghiep-vu.md` | Luật nghiệp vụ, mã R-* |
| `docs/spec/02-chuan-ma-va-danh-muc.md` | Chuẩn mã, danh mục gốc |
| `docs/spec/06-danh-muc-va-tham-so.md` | 34 danh mục, tham số Cài đặt |
| `docs/design/ban-do-man-hinh.md` | 197 màn, mã màn |
| `docs/design/luat-cho-thiet-ke.md` | Luật rút gọn cho Design |
| `docs/design/ma-luat-S02-S03.md` | Định nghĩa mã luật S02-*, S03-* dùng trong bản đồ màn hình |
| `docs/lo-trinh-phan-he.md` | Danh sách phân hệ P0–P14, trạng thái, thứ tự |
| `design/hmt-platform/` | Gói thiết kế |
| `docs/TIEN-DO.md` | Đang ở đâu, việc tiếp theo |

## 3. Bốn đường chuyển (anh là người chuyển)
1. **Code/Design hỏi nghiệp vụ → Chat.** Anh dán câu hỏi cho Chat. Chat đề xuất, anh chốt. Chat trả về **khối dán sẵn** để anh gửi ngược lại. Câu hỏi thuần về cách vẽ (bố cục, màu, khoảng cách) thì anh trả lời thẳng với Design.
2. **Chat → repo.**
   - Chat xuất file. Anh chép vào thư mục `_inbox/` trong dự án (thư mục này không bao giờ commit).
   - Anh dán prompt Chat viết. Claude Code gộp vào `docs/` bằng một PR tài liệu.
   - Luật mới chỉ vào file khi anh nói "OK ĐƯA VÀO LUẬT".
3. **Design → repo.** Design xuất zip. Anh chép vào `_inbox/`. Claude Code đưa vào `design/hmt-platform/` bằng PR.
4. **Repo → Design.** Mỗi lần nhờ Design vẽ hay sửa, anh đính kèm bản mới nhất của: luật 04, bản đồ màn hình, danh mục và tham số, và file ngữ cảnh `ngu-canh-cho-claude-design.md`. Lấy trên GitHub (mở file, bấm Download), hoặc nhờ Chat gửi. **(17/10)** Design đã kết nối GitHub chỉ đọc nên tự đọc được repo; anh chỉ đính kèm khi Design báo không thấy file.

Thứ tự ưu tiên khi các nguồn vênh nhau: **luật (spec 04, 02, 06) > quyết định thiết kế 13/10 (`docs/design/quyet-dinh-thiet-ke-13-10.md`) > bản đồ màn hình > gói thiết kế**.

## 4. Vòng làm việc mỗi phân hệ
1. **Design vẽ** cả phân hệ (artboard 1440 × 1000; điện thoại 390 × 844).
2. **Anh duyệt** trên canvas.
3. **Chat viết đặc tả màn hình** (trường, nút, trạng thái, lỗi, mã luật; chỉ dẫn mã luật, không chép lại). Anh duyệt, đưa vào repo bằng PR tài liệu.
4. **Code:** gửi kế hoạch, anh OK, rồi làm từng PR. Mỗi PR có bản xem trước, mục "Anh kiểm", ảnh so với thiết kế.
5. **Anh** thử trên staging. Dán báo cáo PR cho Chat soát. Ổn thì bình luận "OK" trên PR.
6. Xong giai đoạn thì anh cập nhật bản chạy thật qua `hmt-deploy`.

## 5. Đổi tài khoản Claude Code
Trước khi đổi (nếu còn lượt):
- Việc dở phải được commit và push lên nhánh. Không gộp main, không push --force.
- Cập nhật `docs/TIEN-DO.md`.

Đổi tài khoản: gõ `/logout`, rồi `/login` bằng tài khoản khác. Mở đúng thư mục `~/Developer/hmt-platform`.

Tin nhắn đầu tiên cho tài khoản mới:
```
Em tiếp quản dự án HMT Platform từ một phiên Claude Code khác. Chưa sửa gì.
1. Đọc CLAUDE.md, docs/TIEN-DO.md, docs/quy-trinh-phoi-hop.md, docs/spec/ (01, 02, 03, 04, 06), docs/design/ban-do-man-hinh.md.
2. Xem git: nhánh hiện tại, git status, 15 commit gần nhất, nhánh chưa gộp, PR đang mở (gh pr list).
3. Báo anh tối đa 15 dòng, tiếng Việt dễ hiểu: đang ở bước nào; PR nào chờ anh OK; có việc dở hay thay đổi chưa commit không; tóm tắt luật an toàn trong CLAUDE.md.
4. Dừng, chờ anh giao việc.
```

## 6. Mở chat mới
- **Claude Chat:** mở chat mới (trong Project "HMT - CRM HOÀ MA TOÁN" nếu có), dán lời nhắn ở `docs/phoi-hop/khoi-dong-chat.md`. Chat tự đọc repo và `docs/nhat-ky/`, không cần dán `TIEN-DO.md`.
- **Claude Design:** giữ đoạn chat cũ. Mở chat mới thì đính kèm các file ở đường 4 và manifest gần nhất.

## 7. Luật an toàn (nhắc lại)
- Khoá của bản chạy thật không bao giờ nằm trên máy Mac. Không đăng nhập Supabase hay Cloudflare bằng tài khoản thật trên máy.
- Không dán khoá vào chat; che mã QR khi chụp màn hình.
- Không dùng dữ liệu học sinh thật ở môi trường thử nghiệm, máy cá nhân, kiểm thử, nhật ký.
- Chỉ gộp PR khi anh Trường bình luận "OK". Không push --force.
- Bản chạy thật chỉ do anh Trường cập nhật qua `hmt-deploy`.

## 8. Làm việc theo phân hệ và khi thiếu khuôn (14/10/2026)
- **Phân hệ** là đơn vị làm việc duy nhất (P0, P1, P2…). Danh sách và trạng thái ở `docs/lo-trinh-phan-he.md`. Không dùng các tên "đợt A/B" cũ.
- **Mỗi phân hệ đi 6 bước:** Vẽ (Design) → Anh duyệt → Đặc tả màn hình (Chat) → Code → Staging → Chạy thật.
- **Thiếu khuôn thì dừng và báo, không tự chế.**
  - Tự làm được: hộp thoại hoặc màn chỉ khác khuôn đã có ở trường và chữ (ví dụ mọi hộp thoại "bắt buộc lý do" đều dựng từ cùng một khuôn).
  - Phải dừng: cấu trúc hoặc cách tương tác chưa có khuôn nào giống (ví dụ hộp thoại có bảng sửa trực tiếp, hộp thoại hai cột so sánh).
  - Claude Code ghi vào PR và báo anh: tên màn hoặc hộp thoại, mã màn trong bản đồ, khuôn gần nhất, chỗ khuôn đó chưa đủ. Phần còn lại của PR vẫn làm tiếp.
  - Anh dán báo cáo cho Chat. Chat soạn prompt cho Design vẽ thêm khuôn vào P0. Anh duyệt, đưa gói mới vào `_inbox/`, rồi Code tiếp tục màn đó.
- Khi viết đặc tả màn hình cho một phân hệ, Chat đối chiếu từng màn, hộp thoại với các khuôn P0 và báo thiếu khuôn trước khi đến Code.

## 9. Nhật ký phối hợp (17/10/2026)
- Thư mục `docs/nhat-ky/` có ba file: `chat.md`, `design.md`, `code.md`. Mỗi file **tối đa một trang, viết đè mỗi lần** (không viết nối dài), gồm: đang làm gì; đã chốt gì; đang chờ ai; file hoặc link mới.
- Đầu mỗi phiên, cả ba bên đọc ba file này (và `docs/TIEN-DO.md`). Cuối phiên, anh nhắc "ghi nhật ký".
- **Claude Chat** không ghi lên GitHub: soạn `chat.md`, anh dán nội dung cho Claude Code (hoặc bỏ file vào `_inbox/`), Code đưa vào repo trong PR tài liệu kế tiếp (PR chỉ có tài liệu không chạy CI nên không tốn phút Actions).
- **Claude Design** được đẩy file lên **nhánh `design/<tên-ngắn>`** (xem mục 13). Không đẩy lên `main`, không ghi ngoài `design/` và `docs/nhat-ky/design.md`.
- Luật anh đã chốt nhưng Code chưa đưa vào spec để ở `docs/phoi-hop/luat-cho-dua-vao-spec/` (tạo thư mục khi có luật chờ); Code đưa vào spec rồi xoá file. Prompt cho Design lưu ở `docs/phoi-hop/prompt-design/`.

## 10. Kết nối GitHub cho Claude Chat và Claude Design
- **Chỉ kết nối repo `hmt-platform`, quyền chỉ đọc** ("Only select repositories"). **Không bao giờ kết nối `hmt-deploy`** (nơi chạy bản thật).
- Dùng tài khoản GitHub **`hmt-vanhanh`** để kết nối, không dùng `caotruong276` (chủ `hmt-deploy`). Làm trên trình duyệt; không đăng nhập `caotruong276` trên máy Mac.
- Làm cho cả ba tài khoản Claude: `truongcx.work`, `truongcx.biz`, `lead.vanhanh.hmt`, để khi một tài khoản hết giới hạn thì chuyển sang ngay.
- Không dán khoá, mật khẩu, dữ liệu thật vào chat hay file ở repo.

## 11. Đổi tài khoản Claude khi hết giới hạn
Ba tài khoản Claude Pro (`truongcx.work`, `truongcx.biz`, `lead.vanhanh.hmt`) dùng luân phiên. Trước khi đổi, anh gửi bên đang dùng đúng tin ở mục 13.
- **Claude Code:** xem mục 5.
- **Claude Chat:** đăng nhập tài khoản khác, mở chat mới, dán `docs/phoi-hop/khoi-dong-chat.md`. Project và bộ nhớ là riêng từng tài khoản, nên mọi thứ cần nhớ nằm trong repo.
- **Claude Design:** tình trạng thật nằm ở canvas và `design/`. Chia sẻ canvas quyền sửa cho tài khoản kia (anh thử một lần trước khi cần), mở chat mới, dán `docs/phoi-hop/khoi-dong-design.md`. Nếu không chia sẻ được thì dựng lại canvas từ nguồn đã đẩy lên `design/` (script dựng, `project/`, `canvas.json`, `ds/hmt`).
- Sau khi đổi, đọc ngay `docs/nhat-ky/` để biết ai đang làm gì; không dựng lại từ trí nhớ.

## 12. Bàn giao khi xong việc (17/10/2026)
Mục tiêu: anh chỉ cần chuyển **link**, không dán chat; và luôn biết bước tiếp theo của mình.
- **Claude Code**, cuối mỗi việc (PR): báo anh ngắn gọn, **luôn kèm link PR** và câu "Anh gửi link này cho Claude Chat để soát". Giữ mục "Anh kiểm" và việc còn dở như hiện nay.
- **Claude Design**, cuối mỗi cụm màn: báo anh **link canvas** (kèm số phiên bản), danh sách khung đã vẽ hoặc đã sửa, câu hỏi còn treo (đánh số, kèm đề xuất), và câu "Anh gửi link này cho Claude Chat để đối chiếu luật". Cập nhật khung "Ghi chú" cuối canvas.
- **Claude Chat**, mỗi khi anh gửi link: đọc rồi trả lời theo mẫu cố định, đúng thứ tự (anh đổi thứ tự 19/10/2026):
  1. **Kết quả:** ổn hay còn vênh luật (chỉ nêu chỗ vênh, kèm mã luật).
  2. **Việc anh quyết:** mỗi việc một dòng, kèm đề xuất để anh trả lời "OK". Không có việc thì ghi "không có việc".
  3. **Anh làm gì với Claude Code:** dán gì, thử gì trên staging, có cần bình luận "OK" không.
  4. **Anh làm gì với Claude Design:** dán đoạn nào, đính kèm file nào, có cần sửa gì trên canvas không. Ghi "không có việc" nếu không có.
  5. **Nhắc ghi nhật ký** nếu đây là cuối phiên.
  - **Khi còn việc anh quyết (mục 2), Chat chờ anh trả lời rồi mới soạn tin cho Claude Code và Claude Design** (mục 3 và 4 chỉ soạn sau khi anh đã quyết xong), để không soạn tin theo một quyết định chưa chốt.
- Việc anh luôn tự làm: quyết định, thử trên staging, bình luận "OK" trên PR từ `caotruong276`.

## 13. Bàn giao khi sắp hết giới hạn (bản 2, 17/10/2026)
Nguyên tắc: **xong cụm nào lưu cụm đó** (nhật ký + nguồn), để lúc đổi tài khoản gần như không mất gì. Khi trang Usage của tài khoản khoảng 80%, anh ngừng giao việc mới, chờ cụm đang dở xong, rồi gửi tin dưới đây. Anh chỉ cần copy, dán.

**Tin 1: gửi Claude Design**
```
BÀN GIAO. Anh sắp đổi tài khoản.
Em làm đủ 4 việc, không làm việc mới:
1. Cập nhật docs/nhat-ky/design.md (link canvas, số phiên bản, màn xong, màn dở, câu hỏi treo, ghi chú bàn giao cho chat mới).
2. Lấy main mới nhất, tạo NHÁNH MỚI tên design/luu-nguon-<ngày-giờ> (ví dụ design/luu-nguon-18-10-0930), đẩy nguồn (script, project/, nhật ký) lên đó. Không dùng lại nhánh cũ, không đẩy lên main.
3. Gửi anh: tên nhánh, link các canvas (kèm số phiên bản), danh sách màn dở.
4. KHÔNG soạn câu dán cho Claude Code. Anh đã có tin riêng.
```

**Tin 2: gửi Claude Chat**
```
BÀN GIAO. Anh sắp đổi tài khoản.
Em viết nội dung docs/nhat-ky/chat.md (việc đã xong, việc đang treo, quyết định mới, việc anh phải làm) và các luật mới chưa vào repo.
Gửi anh trong một khối để anh dán thẳng cho Claude Code. Không cần soạn câu cho Code.
```

**Tin 3: gửi Claude Code (một lần cho cả hai, dán nội dung vào luôn)**
```
Em mở PR "bàn giao <ngày>" vào main (chỉ tài liệu và thiết kế), gồm:
- Nhánh Design vừa đẩy: <tên nhánh Design gửi> (nếu có).
- docs/nhat-ky/chat.md: nội dung dưới đây.
<dán nội dung Chat gửi>
Nếu nhánh Design bị xung đột (vì commit cũ đã squash vào main), đừng ép: tạo nhánh mới từ main, lấy các file đã đổi ở nhánh Design bỏ vào.
Gộp bằng squash. Em gửi anh link PR. Anh sẽ comment OK bằng caotruong276, rồi em gộp.
```
Bên nào không có gì để đưa thì anh xoá dòng của bên đó.

**Tin 4: mở chat mới ở tài khoản mới**
- Design:
```
Đọc docs/phoi-hop/khoi-dong-design.md và docs/nhat-ky/design.md trong repo hmt-vanhanh/hmt-platform, rồi làm theo. Mở canvas gốc đã Share (link trong nhật ký) và hệ thiết kế gốc, báo anh có sửa được không. Sửa được thì làm tiếp trên bản gốc. Chỉ khi không sửa được mới dựng lại từ nguồn trong design/nguon-canvas/. Báo anh bạn đã đọc xong và cụm kế tiếp là gì.
```
- Chat:
```
Đọc docs/phoi-hop/khoi-dong-chat.md và docs/nhat-ky/chat.md trong repo hmt-vanhanh/hmt-platform, rồi làm theo. Báo anh trạng thái hiện tại và việc anh cần làm tiếp.
```
- Chat mới không đọc được repo thì anh dán thẳng nội dung file `khoi-dong-…` và `chat.md` vào chat. Chat ở tài khoản mới không thấy Project cũ, nên mọi luật phải nằm trong repo (`docs/spec/`).

**Việc anh làm một lần khi bắt đầu dùng tài khoản mới**
- Share canvas gốc và artifact hệ thiết kế cho tài khoản mới (quyền Editor), bấm nhận lời mời ở email.

**Quy tắc đẩy nhánh của Design**
- Mỗi lần bàn giao một nhánh mới `design/luu-nguon-<ngày-giờ>`, tạo từ `main` mới nhất. Không dùng lại nhánh đã gộp.
- Chỉ ghi vào `design/` và `docs/nhat-ky/design.md`; không chạm `docs/spec/`, `supabase/`, `src/`.
- Gộp vào `main` do Claude Code làm (squash), sau comment "OK" từ `caotruong276`.

**Anh nhớ ba điều**
- Ngừng giao việc cho Design hoặc Chat: dùng Tin 1 hoặc Tin 2. Không nhớ tên nhánh hay đường dẫn.
- Việc với Code luôn là Tin 3.
- Việc anh làm ở GitHub chỉ là comment OK vào PR bằng `caotruong276`.
