import sys
src,dst=sys.argv[1],sys.argv[2]
s=open(src,encoding='utf-8').read()
def rep(old,new,count=1):
    global s
    n=s.count(old); assert n==count,(old[:70],n); s=s.replace(old,new)
rep("Bản v3 gồm hai đợt bổ sung: bốn khung mở ra của K1 và lịch sử phiên bản Ma trận quyền (mục 6); ô tìm kiếm toàn hệ thống và chuông thông báo ở thanh trên (mục 7).",
"""**Bản v4 (16/10/2026)** sửa P1 và P2 theo các quyết định anh Trường đã chốt, thêm 2 token còn nợ. Gói gồm **70 artboard** (P0 38, P1 28, P2 4). Đọc bảng "Đổi gì so với v3" ngay dưới đây trước. Các đợt bổ sung cũ vẫn giữ ở mục 6 (K1 bốn khung, lịch sử phiên bản Ma trận quyền) và mục 7 (ô tìm toàn hệ thống, chuông). Mục 8 là chỗ chưa chắc của đợt v4.

## Đổi gì so với v3

| # | Màn / tệp | v3 | v4 | Lý do |
|---|---|---|---|---|
| 1 | DN03 · Xác thực hai bước | 8 artboard: mã từ ứng dụng + mã dự phòng (`*_backup`, `*_backup_err`) | **Còn 4**: `DN03_pc_code`, `DN03_pc_code_err`, `DN03_mb_code`, `DN03_mb_code_err`. Bỏ 4 artboard mã dự phòng | Bỏ mã dự phòng |
| 2 | DN03 · dòng dưới nút | Liên kết "Mất điện thoại? Dùng mã dự phòng" | Chữ thường (không phải liên kết): "Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước" | Bỏ mã dự phòng |
| 3 | DN04 · Thiết lập 2FA | 3 bước (bước 3 lưu mã dự phòng) | **2 bước**. Bỏ `DN04_pc_s3`, `DN04_mb_s3`. Thanh bước còn 2 khúc; nhãn "BƯỚC 1/2 · QUÉT MÃ", "BƯỚC 2/2 · NHẬP MÃ". Nút chính bước 2 đổi "Xác nhận" → **"Hoàn tất"** (vẫn có "Quay lại") | Bỏ mã dự phòng |
| 4 | DN05 · Quên mật khẩu | Ô nhập email, Turnstile, nút "Gửi link đặt lại", câu học sinh nhờ CSKH; biến thể "đã gửi" (`*_sent`) | Chỉ còn câu "Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm." và nút chính **"Quay lại đăng nhập"**. Bỏ `DN05_pc_sent`, `DN05_mb_sent`. Giữ tên `DN05_pc_form`, `DN05_mb_form` | Quên mật khẩu chỉ liên hệ quản trị viên |
| 5 | DN06 · Đặt mật khẩu mới (link email) | Trong gói (4 artboard) | **Hoãn.** Giữ artboard trên canvas, gắn nhãn "HOÃN", **không đưa vào gói** | Không còn luồng đặt lại qua email |
| 6 | DN08 · Tài khoản bị khoá | 4 artboard: tạm khoá 15 phút, khoá hẳn (`*_temp`, `*_perm`) | **Gộp 1 màn mỗi thiết bị**: `DN08_pc_lock`, `DN08_mb_lock`. Tiêu đề "Không thể đăng nhập", một câu chung: "Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm." Không nói thời gian khoá, không nói lý do. Một nút "Quay lại đăng nhập" | Luật S03-18: không để lộ tài khoản có tồn tại hay không |
| 7 | CauHinh · tab Tham số nghiệp vụ | Dòng đang sửa có ô "Có hiệu lực từ" (ngày); câu cuối "Sửa một tham số thì có hiệu lực từ ngày chọn, bản cũ vẫn giữ trong lịch sử." | Bỏ ô "Có hiệu lực từ". Câu cuối: "Sửa một tham số thì có hiệu lực ngay; giá trị cũ vẫn giữ trong lịch sử thay đổi." | Tham số có hiệu lực ngay |
| 8 | Token mới (`tokens.json` v4, `hmt-tokens.css`) | Chưa có | `--success-border` #BAD9C4, `--warning-border` #F2DE9D, `--danger-border` #ECBBC2 (cùng cách pha với `--info-border` có sẵn); `--table-head-height` 32px, `--table-row-height` 36px | Hai token còn nợ |
| 9 | `bundle.css` | `.hmt-table th` cao 32px, `td` cao 36px viết thẳng | Dùng `var(--table-head-height)` và `var(--table-row-height)`. Giá trị không đổi, ảnh chụp mọi màn giống v3 | Dùng token thay giá trị viết thẳng |
| 10 | K2 Kanban | Thanh màu trên đầu cột chưa có giải thích | Ghi nghĩa ở mục 4 (không đổi bản vẽ) | Anh Trường yêu cầu |

Tổng số artboard: v3 84 → v4 70 (bỏ 4 DN03, 2 DN04, 2 DN05, 4 DN06 hoãn; DN08 4 → 2). P0 và các màn P1, P2 khác **không đổi**.""")
rep("artboards/*.dc.html                84 artboard (P0 38, P1 42, P2 4)","artboards/*.dc.html                70 artboard (P0 38, P1 28, P2 4)")
rep("### P1 · Đăng nhập & xác thực (10 màn, 42 artboard: máy tính + điện thoại)","### P1 · Đăng nhập & xác thực (9 màn trong gói, 28 artboard: máy tính + điện thoại; DN06 hoãn)")
rep("| DN03 | CHUNG-02 | Xác thực hai bước (nhập mã) | pc_code, pc_code_err, pc_backup, pc_backup_err, mb_code, mb_code_err, mb_backup, mb_backup_err |","| DN03 | CHUNG-02 | Xác thực hai bước (nhập mã, không có mã dự phòng) | pc_code, pc_code_err, mb_code, mb_code_err |")
rep("| DN04 | CHUNG-03 | Thiết lập 2FA lần đầu (3 bước) | pc_s1, pc_s2, pc_s3, mb_s1, mb_s2, mb_s3 |","| DN04 | CHUNG-03 | Thiết lập 2FA lần đầu (2 bước) | pc_s1, pc_s2, mb_s1, mb_s2 |")
rep("| DN05 | CHUNG-04 | Quên mật khẩu | pc_form, pc_sent, mb_form, mb_sent |","| DN05 | CHUNG-04 | Quên mật khẩu (chỉ hướng dẫn liên hệ quản trị viên) | pc_form, mb_form |")
rep("| DN06 | CHUNG-05 | Đặt mật khẩu mới (link từ email) | pc_new, pc_ok, mb_new, mb_ok |","| ~~DN06~~ | CHUNG-05 | Đặt mật khẩu mới (link từ email): **HOÃN, không có trong gói** | — |")
rep("| DN08 | CHUNG-08 | Tài khoản bị khoá (tạm 15 phút / khoá hẳn) | pc_temp, pc_perm, mb_temp, mb_perm |","| DN08 | CHUNG-08 | Không thể đăng nhập (một câu chung, gộp tạm khoá và khoá hẳn) | pc_lock, mb_lock |")
rep("Mỗi artboard P1 đi theo khuôn đăng nhập; DN04 và DN10 có phần bố cục riêng (3 bước; hai thẻ cổng).","Mỗi artboard P1 đi theo khuôn đăng nhập; DN04 và DN10 có phần bố cục riêng (2 bước; hai thẻ cổng).")
# section 3 P1 blocks
a=s.index("- `DN03_pc_backup` — Máy tính · Mã dự phòng"); b=s.index("- `DN03_mb_code` — Điện thoại · Mã từ ứng dụng")
s=s[:a]+s[b:]
a=s.index("- `DN03_mb_backup` — Điện thoại · Mã dự phòng"); b=s.index("#### DN04 · CHUNG-03")
s=s[:a]+s[b:]
s=s.replace("#### DN03 · CHUNG-02 — Xác thực hai bước (nhập mã)\n","#### DN03 · CHUNG-02 — Xác thực hai bước (nhập mã)\nDưới nút của cả 4 artboard có dòng chữ thường: “Mất điện thoại? Liên hệ quản trị viên để đặt lại xác thực hai bước” và “Bắt buộc với tài khoản Admin và Kế toán.”\n",1)
a=s.index("#### DN04 · CHUNG-03"); b=s.index("#### DN07 · CHUNG-07")
s=s[:a]+"""#### DN04 · CHUNG-03 — Thiết lập 2FA lần đầu (2 bước)
- `DN04_pc_s1` — Máy tính · Bước 1/2 · Quét mã
  - **Nút:** “Tiếp”
- `DN04_pc_s2` — Máy tính · Bước 2/2 · Nhập mã (bước cuối)
  - **Nút:** “Quay lại” · “Hoàn tất”
- `DN04_mb_s1` — Điện thoại · Bước 1/2 · Quét mã
  - **Nút:** “Tiếp”
- `DN04_mb_s2` — Điện thoại · Bước 2/2 · Nhập mã (bước cuối)
  - **Nút:** “Quay lại” · “Hoàn tất”
#### DN05 · CHUNG-04 — Quên mật khẩu
- `DN05_pc_form` — Máy tính · Liên hệ quản trị viên
  - **Nút:** “Quay lại đăng nhập”
  - **Chữ:** “Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.”
- `DN05_mb_form` — Điện thoại · Liên hệ quản trị viên
  - **Nút:** “Quay lại đăng nhập”
  - **Chữ:** “Để đặt lại mật khẩu, vui lòng liên hệ quản trị viên của trung tâm.”
#### DN06 · CHUNG-05 — Đặt mật khẩu mới (link từ email)
- **HOÃN.** Không có trong gói v4. Artboard vẫn trên canvas, gắn nhãn “HOÃN”.
"""+s[b:]
a=s.index("#### DN08 · CHUNG-08"); b=s.index("#### DN09 · CHUNG-09")
s=s[:a]+"""#### DN08 · CHUNG-08 — Không thể đăng nhập (một câu chung)
- `DN08_pc_lock` — Máy tính
  - **Nút:** “Quay lại đăng nhập”
  - **Thông báo:** tiêu đề “Không thể đăng nhập”; câu “Không thể đăng nhập lúc này. Vui lòng thử lại sau hoặc liên hệ quản trị viên của trung tâm.”
- `DN08_mb_lock` — Điện thoại
  - **Nút:** “Quay lại đăng nhập”
  - **Thông báo:** như bản máy tính.
- Dùng chung cho mọi trường hợp không cho đăng nhập (tạm khoá do sai nhiều lần, tài khoản bị khoá). Không nói thời gian khoá, không nói lý do (luật S03-18).
"""+s[b:]
rep("  - **Nút:** “Lịch sử thay đổi” · “Danh mục” · “Tham số nghiệp vụ”","  - **Tham số (v4):** không còn ô “Có hiệu lực từ”; câu cuối tab Tham số: “Sửa một tham số thì có hiệu lực ngay; giá trị cũ vẫn giữ trong lịch sử thay đổi.”\n  - **Nút:** “Lịch sử thay đổi” · “Danh mục” · “Tham số nghiệp vụ”")
rep("- **Bộ lọc nhanh của K1**: cùng nhóm là HOẶC, khác nhóm là VÀ. Group By tối đa 2 cấp.","""- **Bộ lọc nhanh của K1**: cùng nhóm là HOẶC, khác nhóm là VÀ. Group By tối đa 2 cấp.
- **Thanh màu trên đầu cột Kanban (K2)** (`.hmt-kbar`, ghi thêm v4): chia khúc theo tình trạng lịch hẹn của các thẻ trong cột. **Xanh** (`.ok`, `--success-solid`) = lịch hẹn còn hạn; **vàng** (`.warn`, `--warning-solid`) = lịch hẹn hôm nay; **đỏ** (`.bad`, `--danger-solid`) = quá hạn; **xám** (phần nền còn lại, `--divider`) = chưa có lịch. Độ dài mỗi khúc theo tỉ lệ số thẻ. **Bấm một khúc màu thì lọc cột theo nhóm đó** (bản vẽ chưa thể hiện trạng thái đang lọc).
- **Tham số nghiệp vụ** (v4): có hiệu lực ngay khi lưu, không hẹn ngày; giá trị cũ giữ trong lịch sử thay đổi.
- **Đăng nhập** (v4): không có mã dự phòng; quên mật khẩu chỉ liên hệ quản trị viên; mọi trường hợp bị chặn đăng nhập dùng một câu chung (DN08).""")
rep("2. **Chữ lỗi OTP** (DN03: “Sai mã”, “Sai hoặc đã dùng”, hết hạn mã) chưa được duyệt từng câu.","2. **Chữ lỗi OTP** (DN03: “Sai mã”, hết hạn mã) chưa được duyệt từng câu. (v4 đã bỏ lỗi mã dự phòng.)")
rep("| Cấu hình (CauHinh) | CauHinh | Màn Cấu hình vẫn còn ô “Có hiệu lực từ” cho tham số nghiệp vụ. Luật 10/10 chỉ nói về ma trận quyền nên em không sửa, cần anh xác nhận có áp dụng cho tham số không. |","| Cấu hình (CauHinh) | CauHinh | **Đã xử lý ở v4**: anh xác nhận tham số có hiệu lực ngay, đã bỏ ô “Có hiệu lực từ”. |")
s=s.rstrip()+"""


## 8. Đợt v4: chỗ còn chưa chắc

| Khung | Artboard | Chưa chắc |
|---|---|---|
| DN03 dòng "Mất điện thoại?" | DN03_* | Em để là chữ thường, không phải liên kết, vì không có nơi để bấm tới. Nếu anh muốn liên kết mở thông tin liên hệ quản trị viên thì cần nêu đích. |
| DN05 tên artboard | DN05_pc_form, DN05_mb_form | Giữ tên `_form` cho khỏi đổi mã, dù màn không còn biểu mẫu. Câu “Học sinh quên mật khẩu thì nhờ chăm sóc khách hàng cấp lại.” đã bỏ theo yêu cầu “chỉ có câu … và nút”. Học sinh vẫn có câu riêng ở DN02. |
| DN08 tên và nội dung | DN08_pc_lock, DN08_mb_lock | Tên `_lock` là em đặt cho màn gộp. Tiêu đề “Không thể đăng nhập” em lấy từ câu anh đưa (cần có tiêu đề theo khuôn). Biểu tượng ổ khoá giữ từ bản cũ; nếu sợ gợi ý “tài khoản bị khoá” thì có thể đổi sang biểu tượng thông tin. Bỏ nút “Quên mật khẩu?” của bản tạm khoá cũ (màn gộp lấy theo bản khoá hẳn, một nút). |
| DN09 hết phiên | DN09_* | Không đổi; chưa đối chiếu lại với quyết định đăng nhập mới. |
| Token viền trạng thái | tokens.json, hmt-tokens.css | Ba màu viền mới em pha 21% màu đậm vào màu nền, cùng cách với `--info-border` có sẵn. **Chưa gắn vào `.hmt-alert` / `.hmt-toast`** để khỏi đổi các màn đã duyệt; dùng khi dựng thành phần mới hoặc khi anh duyệt thêm viền cho thông báo. |
| Chiều cao hàng bảng | bundle.css | Chỉ đưa hàng tiêu đề (32) và hàng dữ liệu (36) của `.hmt-table` vào token. Hàng nhóm `.ghead` (34) và `.grp` (28) cùng các bảng tự dựng bằng lưới (CauHinh 40–44, MaTranQuyen) vẫn viết thẳng; hai kiểu hàng nhóm cao khác nhau, cần anh chốt một số. |
| Thanh màu K2 | K2 | Bản vẽ chưa có trạng thái “đang lọc theo khúc màu” và chưa có chú thích màu trên màn. |
"""
open(dst,'w',encoding='utf-8').write(s); print(len(s))
