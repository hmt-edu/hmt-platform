# QT-07: nối nhóm con của «Lý do huỷ test» (migration 594)

Quyết định: anh Trường duyệt 20/11/2026 (Design đợt 2). Luật: R-CRM-06, R-V2-02, spec 06 dòng 13.

## Hàm (schema `app`)
| Hàm | Ai gọi | Làm gì |
|---|---|---|
| `catalog_add_item(..., p_no_link)` | Admin (`assert_config_writer`) | Thêm mục vào danh mục mở. Riêng `TEST_CANCEL_REASON`: bắt buộc chọn nhóm con (`p_linked_item_id`) hoặc «Không nối nhóm con» (`p_no_link = true`). Lỗi: `HMT_THIEU_NOI_NHOM_CON` (chưa chọn gì), `HMT_NOI_NHOM_CON_MAU_THUAN` (chọn cả hai), `HMT_NOI_NHOM_CON_SAI` (nhóm con của giai đoạn cơ hội nhưng ngoài L5C–L5O hoặc đã Ngừng); mục thuộc danh mục khác vẫn do trigger cũ báo `HMT_MUC_NOI_SAI`. |
| `list_test_cancel_link_options()` | Admin xem | Mảng `{id, code, name}` các nhóm con L5C–L5O đang dùng, cho ô chọn. |
| `is_test_cancel_link_allowed(id)` | nội bộ | Dùng chung cho ô chọn và kiểm ở `catalog_add_item`. |
| `get_catalog_tree` | Admin xem | Trả thêm `linked_item_id`, `linked_code`, `linked_name` cho cột «Nối nhóm con». |
| trigger `test_cancel_link_immutable` | tự động | Chặn đổi hoặc bỏ nối của mục `TEST_CANCEL_REASON` sau khi tạo (`HMT_NOI_NHOM_CON_KHONG_SUA`), trừ migration. Đổi tên vẫn được. |

Nối sai thì Ngừng mục và tạo mục mới; cơ hội đã huỷ giữ nhóm con cũ. Không bảng mới, không chỉ mục mới (danh mục vài chục dòng).
Kiểm thử: `supabase/tests/database/594_qt07_noi_nhom_con_ly_do_huy_test.test.sql`; e2e `e2e/danh-muc.spec.ts`.

## Sửa spec cùng PR
- `R-CRM-06` (spec 04): L5Q → L5M (theo spec 06 04/11, mới hơn); thêm luật bắt buộc nối và không sửa nối.
- Spec 06 dòng 13: ghi quyết định nối bắt buộc.
