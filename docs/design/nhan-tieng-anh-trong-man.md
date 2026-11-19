# Nhãn tiếng Anh trên giao diện (KHO-VIEC dòng 6, 19/11/2026)

Quét `src/` tìm nhãn (label, header, title, placeholder, aria-label) bằng tiếng Anh và đối chiếu với chữ trong các canvas `design/hmt-canvas-*`. **Kết quả: mọi nhãn tiếng Anh còn lại đều là chữ của canvas** (anh Trường chốt với Design), nên theo thứ bậc «canvas thắng» thì KHÔNG đổi.

| Nhãn | Chỗ dùng | Có trong canvas |
|---|---|---|
| Filters, Group By, Favorites, Save to Favorites | khuôn danh sách K03 (`src/list/ListScreen.tsx`) | Có, và là ngoại lệ chính thức Đ268 (CLAUDE.md) |
| Source, Source type, Medium, Sub-source | Lead, Cơ hội (danh sách, bản ghi, bộ lọc) | Có (68 khung «Source», 116 khung «Sub-source»); spec 06 mục 2 ghi «Source type, Source, Medium» |
| Stage, Sub-stage | Lead, Cơ hội, Tái tục | Có (24 và 193 khung) |
| Time Table | Lớp (LOP-02, LOP-03) | Có (38 khung); spec 04 R-LOP-02, R-LOP-10 dùng chữ này |
| Start Date | Ghi danh (bản ghi) | Có (18 khung) |
| Campaign | Phiếu tái tục | Có |
| Lead, Ticket, Email | tìm kiếm, bản ghi phụ huynh, tạo người dùng | Có |

**Không có nhãn tiếng Anh nào nằm ngoài canvas**, nên không đổi gì trong mã. Nếu anh Trường muốn Việt hoá một số nhãn dù canvas đang dùng tiếng Anh (ví dụ Source thành «Nguồn», Time Table thành «Thời khoá biểu»), cần anh chốt từng nhãn và nhờ Design cập nhật canvas trước, rồi Code đổi một lượt (chỉ chữ, không đổi mã).
