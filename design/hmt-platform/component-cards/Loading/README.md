Trạng thái chờ: Skeleton cho nội dung có cấu trúc (bảng, danh sách, thẻ), Spinner có chữ cho chờ ngắn, Button `loading` cho thao tác.

- Chỉ hiện sau 300ms; quá 10s hiện giải thích + nút huỷ. Vùng đang tải có `aria-busy`.
- Hiệu ứng shimmer tắt khi `prefers-reduced-motion`.
- Không dùng spinner toàn màn hình chặn thao tác khi chỉ một khối đang tải.
