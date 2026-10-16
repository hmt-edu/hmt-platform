# Quy trình phối hợp: anh Trường, Claude Chat, Claude Design, Claude Code

Cập nhật 14/10/2026. File này nằm trong repo (`docs/quy-trinh-phoi-hop.md`) và trong Project "HMT - CRM HOÀ MA TOÁN" trên Claude.

## 1. Ai làm gì
| | Vai | Việc chính | Đọc từ đâu |
|---|---|---|---|
| Anh Trường | Chủ sản phẩm | Quyết nghiệp vụ; thử trên staging; bình luận "OK" trên PR; cập nhật bản chạy thật qua `hmt-deploy` | |
| Claude Chat (tài khoản truongcx.work, Project "HMT - CRM HOÀ MA TOÁN") | Phân tích nghiệp vụ, kiến trúc, kiểm soát | Cùng anh chốt luật; viết đặc tả; soạn prompt cho Design và Code; soát kết quả trước khi anh OK | Project, nội dung anh dán vào |
| Claude Design (một tài khoản Pro khác) | Thiết kế giao diện | Vẽ, sửa màn theo bản đồ màn hình và luật; giữ hệ thống thiết kế "HMT Platform" | File anh đính kèm |
| Claude Code (VS Code, đổi qua lại 3 tài khoản Pro) | Lập trình | Code, kiểm thử, mở PR, báo chỗ luật vênh với code | Repo: `CLAUDE.md`, `docs/`, `design/` |

## 2. Ba kho lưu
1. **Repo `hmt-vanhanh/hmt-platform`: nguồn sự thật.** Quyết định nào chưa nằm trong `docs/` thì coi như chưa có.
2. **Project trên Claude Chat:** bản sao tài liệu chính, để mở chat mới không phải dán lại.
3. **Đoạn chat và hệ thống thiết kế bên Claude Design:** thành phần, khuôn, màn đã vẽ.

Tài liệu chính trong repo:

| File | Nội dung |
|---|---|
| `docs/spec/04-luat-nghiep-vu.md` | Luật nghiệp vụ, mã R-* |
| `docs/spec/02-chuan-ma-va-danh-muc.md` | Chuẩn mã, danh mục gốc |
| `docs/spec/06-danh-muc-va-tham-so.md` | 32 danh mục, tham số Cài đặt |
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
4. **Repo → Design.** Mỗi lần nhờ Design vẽ hay sửa, anh đính kèm bản mới nhất của: luật 04, bản đồ màn hình, danh mục và tham số, và file ngữ cảnh `ngu-canh-cho-claude-design.md`. Lấy trên GitHub (mở file, bấm Download), hoặc nhờ Chat gửi.

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
- **Claude Chat:** mở chat mới trong Project "HMT - CRM HOÀ MA TOÁN", nói ngắn đang làm gì, gửi link PR hoặc dán `docs/TIEN-DO.md` nếu cần.
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
