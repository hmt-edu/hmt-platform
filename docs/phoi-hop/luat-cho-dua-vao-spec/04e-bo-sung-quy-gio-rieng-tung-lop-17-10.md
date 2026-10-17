# Bổ sung luật 17/10/2026: mỗi lớp một dòng đơn, một ghi danh, một quỹ giờ riêng

Anh Trường đã nói "OK ĐƯA VÀO LUẬT" ngày 17/10/2026 (14:22 và 15:44). **Bản này thay bản 04e gửi lúc 15:40**: bỏ "phân bổ giờ, chia đều"; thay bằng **mỗi lớp một dòng đơn** (anh chốt 15:44). File **bổ sung sau** `04d`. Khi Code đưa vào repo: sửa R-GD-01, R-GD-02, R-GD-03, R-GD-14 trong `docs/spec/04-luat-nghiep-vu.md` (ghi "(17/10)"), thêm R-GD-18, sửa mục "Luật ghi danh và xếp lớp" ở `docs/spec/02` (mục 1, 3, 5, 6, 7); không giữ file riêng. Repo là bản đúng. (Số R-GD-10 đến R-GD-17 đã có trong spec 04, nên luật mới bắt đầu từ R-GD-18.)

## 1. Sửa luật đã có

| Mã | Sửa thành | |
|---|---|---|
| R-GD-01 | **(17/10)** Mỗi dòng đơn sinh **một ghi danh, một quỹ giờ**, và **mỗi dòng đơn chỉ chọn một lớp**. Loại hình cũ "LC+HR" vẫn tách thành hai ghi danh. | [CHỐT] |
| R-GD-14 | **(17/10)** Toán khối 7+ học cả Đại và Hình thì **hai dòng đơn riêng** (một lớp DAI, một lớp HINH), thành **hai ghi danh riêng**, mỗi ghi danh một quỹ giờ riêng. Khi lập đơn, hệ thống **nhắc (không chặn)** nếu học sinh mới có một trong hai. Thay cho bản 12/10 "một dòng đơn, hai lớp, chung quỹ giờ". | [CHỐT] |
| R-GD-02 | **(17/10)** Ghi danh có các **dòng xếp lớp** (lớp, ngày vào, ngày rời, tình trạng). Bình thường một ghi danh có **một lớp đang học**; khi chuyển lớp thì đóng dòng cũ, mở dòng mới, **giờ còn lại đi theo ghi danh**. **Buổi Done chỉ trừ vào quỹ của ghi danh của lớp đó.** Sĩ số, danh sách lớp, điểm danh đọc từ dòng xếp lớp. | [CHỐT] |
| R-GD-03 | **(17/10)** Quỹ giờ gắn với **ghi danh** (một ghi danh một lớp), không gom theo học sinh + môn + loại quỹ như bản cũ; kết thúc ghi danh này không thu hồi giờ của ghi danh khác. | [CHỐT] |

## 2. Luật mới

| Mã | Luật | |
|---|---|---|
| R-GD-18 | **(17/10)** **Hết giờ theo ghi danh (theo lớp).** Ghi danh nào hết giờ thì **hết phí ở lớp đó**; học sinh **không được điểm danh có trừ giờ** vào lớp ấy khi quỹ bằng 0: **chặn, không cho âm** (lỗi có mã, câu tiếng Việt). Ngoại lệ duy nhất: "cho học trước, đóng tiền sau" (R-GD-12), quỹ được âm trong hạn mức. Muốn chuyển giờ từ ghi danh (lớp) này sang ghi danh khác: **bắt buộc qua phân hệ ticket, Đề nghị nhóm "Chuyển phí" đã duyệt** (R-CS-02); không sửa tay. Duyệt xong ghi hai dòng ngược dấu vào sổ giờ (trừ nguồn, cộng đích) kèm mã ticket. | [CHỐT] |

## 3. Luật đang có phải rà theo (đề xuất, **[CHỜ]** anh duyệt từng dòng)

| Luật hiện có | Đề xuất |
|---|---|
| R-GD-07 (thời hạn gói, chỉ dự báo) | Tự rõ: một ghi danh một lớp nên mỗi lớp có End Date riêng (như HS-02). Không cần sửa chữ. |
| R-GD-13 (tái tục) | Tính theo ghi danh = theo lớp; **một phiếu cho mỗi ghi danh**. Học sinh Đại + Hình có thể có hai phiếu; CSKH gộp khi báo giá. |
| R-GD-16 (dừng học), bảo lưu R-GD-09, spec 02 mục 5 ("thao tác ở cấp ghi danh, áp cho mọi lớp đang xếp") | Vẫn ở cấp ghi danh; vì một học sinh có thể có hai ghi danh, **một ticket đề nghị cho chọn nhiều ghi danh**. |
| R-GIO-03, R-GIO-04 | "Số dư" là quỹ của ghi danh; trừ giờ vào ghi danh của lớp đó; chỉ khi hai ghi danh cùng xếp vào một lớp mới xét hạn sử dụng sớm nhất. |
| spec 02 mục 3 (gợi ý Đại + Hình khi xếp lớp) | Gợi ý chuyển lên bước lập đơn (nhắc mềm, R-GD-14); khi xếp lớp (GD-03) chỉ xếp một lớp cho một ghi danh, chỉ nhắc nếu học sinh chưa có lớp còn lại. |
| spec 02 mục 6, 7 ("cùng một quỹ", "cộng lịch mọi lớp") | Sửa: quỹ và dự báo hết giờ theo từng ghi danh. |

## 4. Việc cho giai đoạn code
- Ghi danh (giai đoạn 2): sổ giờ (R-GD-04) khoá theo ghi danh như cũ; không cần cột "giờ phân bổ".
- Hàm tạo, duyệt đơn: chặn dòng đơn có nhiều lớp (R-GD-01); nhắc mềm khi Toán khối 7+ mới có một trong Đại, Hình. Hàm điểm danh trừ giờ: chặn khi quỹ ghi danh bằng 0 trừ ngoại lệ R-GD-12.
- Ticket: một đề nghị chọn được nhiều ghi danh (bảo lưu, dừng học, chuyển cơ sở).
- Giao diện: HS-02 giữ nguyên (mỗi lớp một dòng); dòng đơn BH-05 chỉ một lớp mỗi dòng; không có cột "giờ phân bổ".
