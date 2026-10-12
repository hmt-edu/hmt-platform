Kanban (K04): cột theo giai đoạn có số thẻ; thẻ gồm mã, tên, thông tin chính, người phụ trách, hạn; kéo thả hoặc menu "Chuyển sang" (thay cho kéo thả với bàn phím).

- `canMove` trả `{ ok:false, reason }` khi luật chặn (chỉ đi tới, thiếu dữ liệu) → BlockingDialog nêu lý do; thẻ không đổi cột.
- Cột đang được thả vào có viền nét đứt `hmt-focus`.
- Không dùng Kanban trên điện thoại (dùng danh sách có lọc giai đoạn).
