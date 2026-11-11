# Quy tắc cứng cho Claude Code

Cập nhật 10/11/2026. Đọc file này đầu mỗi phiên, cùng `docs/quy-trinh-phoi-hop.md` và `docs/ke-hoach/ke-hoach-17-11.md`. Quy tắc nào chưa nằm trong `docs/` thì coi như chưa có. Có chỗ mâu thuẫn giữa file này và tin mới nhất của Chat thì làm theo tin của Chat, rồi báo để Chat sửa file.

## 1. Luật và thiết kế

- Luật nghiệp vụ thắng canvas. Canvas lệch luật thì làm theo luật và ghi vào báo cáo "lệch luật".
- Luật mới chỉ vào `docs/spec/04-luat-nghiep-vu.md` khi anh Trường nói "OK ĐƯA VÀO LUẬT". Code không tự sửa file luật.
- Một thay đổi trên một màn áp dụng cho mọi màn giống nhau. Đề xuất đổi khung trước, chỉ sửa khi có OK.
- Thiếu khung canvas: làm theo khuôn và luật, ghi "chưa có khung" vào báo cáo, không chờ Design.

## 2. An toàn

- Không đưa token, mật khẩu, khoá `.age` vào chat, commit hay repo.
- Không force push.
- Code không chạy deploy production. Anh Trường tự chạy workflow trong `hmt-deploy`.
- Không dùng dữ liệu học sinh thật ở môi trường thử.
- Dừng và báo khi CI Compute gần 8 đô.

## 3. Pull request

- Mỗi PR là một cụm màn (4 đến 7 màn). Viết hết cụm liền mạch, chạy `check:all` một lần ở cuối cụm; giữa chừng chỉ chạy kiểm tra nhanh trên phần mình sửa.
- Mỗi PR một lần đẩy, một lần mở, không gắn nhãn.
- File kiểm của PR đặt trong `gui-chat/` và chép sang `~/Desktop/sang-10-11/gui-chat/CHO-CHAT-10-11/`.
- PR chỉ có tài liệu: không chạy CI nhưng phải `prettier --check .` xanh.
- Chỉ gộp khi anh Trường đã bình luận OK, OK khớp commit cuối của PR và CI xanh trên commit đó. Có commit mới sau OK thì OK mất hiệu lực, báo Chat kiểm lại.
- Gộp theo thứ tự đã dặn; gộp xong một PR thì kiểm `main` xanh rồi mới gộp PR kế.

## 4. Việc nặng

pgTAP, Playwright, `check:all`, `db:reset`, `npm ci`, `supabase start`, `supabase stop` đều phải giữ khoá `scripts/heavy-lock.sh`. Mỗi lúc chỉ một việc nặng chạy.

## 5. Migration

- Tiền tố `20261111…`.
- Số migration phải lớn hơn mọi file trên `main` và trong các PR đang mở. Kiểm bằng `git ls-tree origin/main` và `gh pr list`.
- Các số 108, 112, 115, 118, 119 bỏ, không dùng lại.
- Dải số (Chat chốt 10 đến 11/11): Code 1 dùng 120, 123 (đã dùng 111, 113, 114). Code 2 dùng 121, 122, 124 (đã dùng 109, 110, 116, 117).
- Thứ tự gộp migration theo số: 109, 110, 111, 113, 114, 116, 117, 120, 121, 122, 123, 124.
- Không dùng số ngoài dải của mình. Cần thêm số thì báo Chat.

## 6. Tự lấy việc và báo cáo

- Xong việc nào thì tự lấy việc kế tiếp trong hàng đợi của `docs/ke-hoach/ke-hoach-17-11.md`, không chờ tin Chat.
- Chỉ dừng khi cần anh Trường quyết: đổi luật, đổi số migration, đụng dữ liệu thật, đụng production.
- Câu hỏi nhỏ: tự chọn phương án ít thay đổi nhất, ghi lý do vào báo cáo. Chat sửa nếu lệch.
- Báo cáo ngắn. Mỗi lần xong một PR ghi: mã commit, kết quả CI, file kiểm, danh sách màn "chưa có khung / lệch luật". Kết thúc bằng dòng `ĐANG CHẠY: ...`.

## 8. Quy tắc hiển thị tạm (chưa vào luật)

Do Chat chốt, chỉ là cách hiển thị, chưa ghi vào `docs/spec/04`; đổi khi anh Trường chốt luật.

- BUOI-11 (vắng, chưa đến): ô giáo viên là ô quyết định. Giáo viên đã chọn Có mặt thì không hiện vắng dù vận hành ghi gì; ô vận hành chỉ dùng khi ô giáo viên trống. Chưa đến = buổi Đã chốt hôm nay đã bắt đầu mà cả hai ô trống.
- GV-05: giáo viên chỉ thấy tên lý do liên hệ do vận hành ghi ("Ghi chú vận hành (chỉ xem)"), không thấy ghi chú tự do, số điện thoại, phụ huynh.
- Nhãn lớp ở các màn buổi học và lớp: "môn + mã lớp".
- BUOI-12: nút "Nhắc GV" tạm mờ vì cổng giáo viên chưa có hộp thông báo (làm sau 17/11); hàm ghi thông báo vẫn có ở cơ sở dữ liệu.
- BH-08 Chọn lớp lưu ngay khi bấm Chọn, không hoàn tác khi Huỷ Sửa đơn (ghi vào danh sách sau 17/11).
- KH-04 tình trạng học sinh: có ghi danh Chờ xếp lớp, Đã xếp lớp hoặc Đang học thì là Đang học; không thuộc nhóm đó mà có Bảo lưu thì là Bảo lưu; có ghi danh khác thì là Dừng học; chưa có ghi danh thì là Tiềm năng. «Có con đang học» của phụ huynh dùng nhóm đầu (Đang học).
- TC-13 «Đã đóng» từng đợt: tiền vào ròng của đơn (đã trừ khoản đảo) lấp lần lượt từ đợt 1.
- GV-08 «Nộp sau» suy từ điểm danh: có mặt buổi giao bài, vắng buổi kế tiếp, chưa có dòng kết quả.
