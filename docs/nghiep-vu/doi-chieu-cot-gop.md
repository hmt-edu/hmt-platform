# Rà cột bị gộp trong danh sách CRM (Code F, 19/11/2026; thẻ F40)

Cách làm: lấy tiêu đề cột (`<th>`) của khung canvas rồi so với cấu hình cột của từng màn danh sách (`ListConfig.columns`).

| Màn | Canvas | Code trước | Việc làm |
|---|---|---|---|
| TS-01 Lead | Phụ huynh, SĐT, Source type, Source, Medium, Stage, Sub-stage (7 cột riêng) | 3 cột gộp: «Phụ huynh · SĐT», «Source · Sub-source», «Stage · Sub-stage» | **Đã tách** (PR này) |
| TS-07 Cơ hội | Cơ hội, Phụ huynh, SĐT, Stage, Sub-stage, Source type, Source, Medium | cùng 3 cột gộp | **Đã tách** (PR này) |
| BH-01 Báo giá, BH-06 Đơn hàng | cột «Phụ huynh» một cột | «Phụ huynh» (tên, SĐT xếp dưới trong một cột) | khớp canvas, giữ |
| CS-01 Ticket | «Nhóm · Nhóm con» một cột | «Nhóm · Nhóm con» | khớp canvas, giữ |
| CHUNG-15 | «Học sinh · đối tượng» một cột | giống | khớp canvas, giữ |
| TT-01 Tái tục | Stage, Sub-stage riêng | riêng | đã đúng |

Ghi chú tách: «Source type» lấy theo `source_type_code` (danh mục SOURCE_TYPE), «Source» theo `source_code`, «Medium» theo `channel_code`; cột Sub-source cũ chính là Medium. Lead, cơ hội đã gộp hiện «Đã gộp vào <mã>» ở cột Stage. Lọc, nhóm, sắp xếp theo khoá cũ giữ nguyên (cột phụ huynh vẫn sắp xếp được). Ba màn khác chưa so (BH khác, TC, GD, BUOI): cột đã dựng theo canvas ở từng PR.
