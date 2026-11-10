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
- Số 108 bỏ, không dùng lại.
- Dải số: Code 1 dùng 111, 113, 114, 115. Code 2 dùng 109, 110, 112, 116, 117, 118.
- Không dùng số ngoài dải của mình. Cần thêm số thì báo Chat.

## 6. Tự lấy việc và báo cáo

- Xong việc nào thì tự lấy việc kế tiếp trong hàng đợi của `docs/ke-hoach/ke-hoach-17-11.md`, không chờ tin Chat.
- Chỉ dừng khi cần anh Trường quyết: đổi luật, đổi số migration, đụng dữ liệu thật, đụng production.
- Câu hỏi nhỏ: tự chọn phương án ít thay đổi nhất, ghi lý do vào báo cáo. Chat sửa nếu lệch.
- Báo cáo ngắn. Mỗi lần xong một PR ghi: mã commit, kết quả CI, file kiểm, danh sách màn "chưa có khung / lệch luật". Kết thúc bằng dòng `ĐANG CHẠY: ...`.
