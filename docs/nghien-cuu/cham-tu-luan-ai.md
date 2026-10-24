> Tài liệu tham khảo (10/10/2026), không phải luật, không phải đặc tả. Chưa vào docs/spec.

# HMT LMS – Chấm bài tự luận bằng AI: tổng hợp nghiên cứu

> Tổng hợp từ buổi làm việc ngày 10/10/2026 (anh Trường + Claude). Cập nhật 21h.
> Trạng thái: **đã thử cả vòng "chỉ có đề → AI soạn barem → AI chấm" trên 1 bài thật, ổn định 3/3 lần; đã thiết kế hội đồng chấm AI có cơ sở khoa học (mục 7d, chưa thử); chưa code app**. Bước tiếp theo: thử 20 bài BTVN thật (đo luôn hội đồng), sau đó viết đặc tả LMS.

---

## 1. Bối cảnh

- HMT Platform: 1 ứng dụng, 3 cổng (CRM, Giáo viên, Học tập/LMS) trên **React (Vite) + Supabase + Cloudflare Pages**, mục tiêu **0 đồng/tháng** (theo *Bản định hướng*, 09/10/2026).
- Quy mô: 4 cơ sở, khoảng 1.300 học sinh, khoảng 166 lớp, 50–60 giáo viên.
- LMS là **giai đoạn 4** (sau khi chạy thật CRM + vận hành lớp + cổng Giáo viên).
- Yêu cầu: giáo viên giao bài (trắc nghiệm + tự luận). Trắc nghiệm chọn trên app. Tự luận làm ra giấy, **chụp ảnh nộp**, rồi **AI chấm** và **AI viết nhận xét**.
- Ưu tiên chấm **BTVN** (bài tập về nhà), mỗi buổi học một bài.

### Ghi chú lệch trong *Bản định hướng*
- Sơ đồ kiến trúc vẫn ghi "Next.js trên Vercel", còn phần chữ đã chốt React (Vite) trên Cloudflare Pages.
- Sơ đồ đặt "Lưu file" trong Supabase, còn bảng chi phí ghi file bài tập để trên Cloudflare R2.
→ Cần sửa sơ đồ cho khớp phần chữ.

---

## 2. Giải pháp đã chốt (tóm tắt)

| Vai trò | Mô hình | Hạn mức miễn phí (tài khoản đang dùng) |
|---|---|---|
| **Chấm chính** | `gemini-3.5-flash-lite`, **thinkingLevel = high** | 500 lượt/ngày, 15 lượt/phút |
| **Giám khảo 2** trong hội đồng (mục 7d) | `gemma-4-31b-it` | 14.400 lượt/ngày, 30 lượt/phút, **16K token/phút** |
| Trọng tài khi hai giám khảo lệch | `gemini-3.8-flash` (dự phòng 3.7 / 3.6 / 3.5 Flash) | 20 lượt/ngày mỗi mô hình, 5 lượt/phút |
| **Viết nhận xét** HS + PH | `gemma-4-31b-it`, chỉ chữ, sau khi GV duyệt | dùng chung hạn mức Gemma |
| **Tự soạn barem từ đề** (1 lần/đề, dùng lại mãi) | `gemini-3.8-flash` (high), kiểm tra chéo `gemini-3.7-flash` | 20 + 20 lượt/ngày |

**Chi phí: 0 đồng.** Nhu cầu BTVN ước tính khoảng 370–560 bài/ngày (1.300 HS × 2–3 buổi/tuần) → đủ hạn mức.

**Luật bắt buộc rút ra từ thử nghiệm:** barem phải **tách bước, mỗi bước một ý, chỉ có đạt hoặc không đạt, không cho nửa điểm**. Barem gộp ý làm AI chấm dao động (xem mục 4).

---

## 3. Luồng xử lý

```
GV tạo bài ──► HS nộp ──► AI CHẤM ──► GV DUYỆT ──► AI NHẬN XÉT ──► Công bố HS/PH
(đề + đáp án   (chụp mọi    (Flash-Lite,   (sửa điểm,     (Gemma, đọc       (+ đổ mức BTVN vào
 + barem tách   trang theo   ảnh + barem,   bài bị đánh    điểm đã duyệt,    mục D phiếu chấm buổi)
 bước)          thứ tự,      1 lượt/bài)    dấu lên đầu)   chỉ chữ)
                + ô đáp số)
```

1. **GV tạo bài: chỉ cần tải đề lên** (ảnh/PDF/chữ) + chọn lớp. AI **tự giải và soạn barem tách bước** (chạy ngầm, 2–15 phút), mô hình thứ hai giải độc lập để so đáp số, máy tự kiểm tổng điểm. GV **duyệt nhanh** (soát đáp số + cảnh báo) rồi lưu. Barem lưu theo đề, dùng lại cho mọi lớp/khoá (xem mục 7b).
2. **HS nộp:** chụp **tất cả các trang theo thứ tự** (nộp theo bài, không theo câu), gõ **ô đáp số** nếu câu có đáp số.
3. **Hội đồng AI chấm** (mục 7d): GK1 Flash-Lite và GK2 Gemma chấm độc lập, mỗi giám khảo một lượt/bài (mọi trang + barem chữ). Thư ký (máy) so từng bước → khớp thì chốt, lệch nhỏ thì chấp nhận, lệch vừa thì trọng tài bỏ phiếu thứ 3, lệch lớn hoặc có cờ thì chuyển GV. **Máy tự cộng điểm và chặn trần.**
4. **GV duyệt:** bài bị đánh dấu được đẩy lên đầu. GV sửa điểm một chạm.
5. **AI nhận xét:** Gemma đọc **kết quả đã duyệt** + nội dung barem, rồi viết nhận xét từng câu (HS), tổng kết (HS), đoạn gửi phụ huynh. Viết sau khi duyệt nên **không bao giờ có nhận xét dựa trên điểm sai**.
6. **Công bố.** BTVN quy ra **mức 1–5** cho mục D của phiếu chấm buổi, theo quy tắc trung tâm đặt.

### Trạng thái điểm tự luận
`chưa chấm → AI đề xuất → GV đã duyệt → đã công bố` (đúng luật "chưa chấm khác chấm 0").

### Bài bị đánh dấu "cần xem" khi
- AI cho đủ điểm câu nhưng **ô đáp số sai** (hoặc ngược lại).
- Có **chỗ khó đọc**.
- Có câu **khong_thay** (không tìm thấy trên ảnh nào).
- Kiểm tra ngẫu nhiên: **Gemma lệch Flash-Lite** quá 0,25 điểm/câu.
- **Không tin** mức "chắc chắn" do AI tự báo: Flash-Lite từng chấm sai mà vẫn báo "cao".

---

## 4. Kết quả thử nghiệm (bài 1: phiếu 4 trang, bài của 1 HS lớp 9, GV chấm 8,25)

Đề suy ra từ bài làm: 1.1 phương trình chứa ẩn ở mẫu; 1.2a hệ phương trình; 1.2b hệ đặt ẩn phụ (HS **làm dở**, dừng ở b = 1); 2a, 2b hình học đồng dạng (HS làm đúng). Đáp án đúng theo barem tạm: **4,25/4,75**.

### 4.1 Không có barem, chép lại toàn bài (lần đầu)
- `gemini-3.8-flash`: đánh giá đúng cả 5 ý, chép bài gần như nguyên văn, tự bắt thêm lỗi thiếu ĐKXĐ.
- **179 giây**, khoảng 4.800 token vào, khoảng 3.400 token ra + 2.300 token suy nghĩ. Điểm từng ý lệch GV vì không có barem.

### 4.2 Có barem chữ, kết quả gọn (bản tối ưu)

| Mô hình | Câu làm dở 1.2b | Tổng | Thời gian | Token vào / ra / suy nghĩ |
|---|---|---|---|---|
| 3.8 Flash (low) | ✅ | 4,25 ✅ | 11 giây | 5.357 / 357 / 0 |
| 3.5 Flash-Lite (low) | ❌ cho đủ điểm | 4,75 | 9 giây | 5.357 / 658 / 0 |
| **3.5 Flash-Lite (high)** | ✅ | 4,25 ✅ | 21 giây | 5.403 / 395 / 5.708 |
| 3.1 Flash-Lite (high) | ❌ cho đủ điểm | 4,75 | 49 giây | 5.403 / 724 / 4.395 |
| **Gemma 4 31B** | ✅ | 4,25 ✅ | khoảng 100 giây (hay quá tải) | **2.179** / 679 / 0 |
| Gemma 4 26B | ❌ chỉ trả câu đầu | 1,0 | 17 giây | 2.179 / 82 |

→ Kiểu sai nguy hiểm nhất: **cho đủ điểm câu làm dở, kèm "chắc chắn cao"**.

### 4.3 Độ ổn định của 3.5 Flash-Lite (high)
- **Barem gộp ý** (bản 1): 3 lần chạy ra **4,25 / 3,5 / 4,0**. Lệch đúng ở hai bước gộp ý: `1.2b.1` (ĐK + đặt ẩn phụ + đưa về hệ) và `2b.2`.
- **Barem tách bước** (bản 2, 20 bước, không nửa điểm): **3/3 lần đúng 4,25**, từng câu khớp.
→ **Nguyên nhân dao động là barem mơ hồ, không phải mô hình.**

### 4.4 Nhận xét
- Viết nhận xét **trong cùng lượt chấm** (`--nhanxet`): lời văn tốt, nhưng lần đó chấm sai 2b và **nhận xét lặp lại cái sai** cho học sinh.
- **Tách riêng** (`--nhanxet-rieng`, Gemma đọc kết quả chấm): nhận xét bám sát điểm, cụ thể, không giải hộ, đoạn gửi phụ huynh đúng vai. 65 giây, khoảng 1.500 token vào. Cần chỉnh: số điểm viết kiểu Việt Nam (4/4,75); lời khen hơi na ná, sửa bằng **bộ mẫu nhận xét chuẩn HMT**.
- Thêm nhận xét **không tốn thêm lượt** (hạn mức tính theo lượt và token **vào**), chỉ thêm thời gian.

---

## 5. Hạn mức miễn phí thực tế (AI Studio, ngày 10/10/2026)

| Mô hình | RPM | TPM | RPD |
|---|---|---|---|
| Gemini 3.8 / 3.7 / 3.6 / 3.5 / 3 / 2.5 Flash | 5 | 250K | **20** mỗi mô hình |
| Gemini 3.5 Flash-Lite, 3.1 Flash-Lite | 15 | 250K | **500** mỗi mô hình |
| Gemini 2.5 Flash-Lite | 10 | 250K | 20 |
| **Gemma 4 26B / 31B** | 30 | **16K** | **14.400** mỗi mô hình |
| Gemini Pro (3.1, 2.5) | 0 | 0 | 0 (không miễn phí) |

- TPM chỉ tính **token vào**: dòng 3.8 Flash ghi 5,36K, đúng bằng số token vào của một lượt chấm.
- Các trang tổng hợp trên mạng (1.000–1.500 lượt/ngày) **sai** với tài khoản này. Phải xem trong AI Studio → Rate Limit → bật "All models".
- **Không** tạo nhiều project hay tài khoản để nhân hạn mức (lách điều khoản, dễ bị khoá).

### Giá nếu phải trả phí (bảng giá Google, 2026)
- 3.8 Flash: 0,75 / 3,75 USD cho mỗi 1 triệu token vào/ra (tăng gấp đôi từ 2027). Bản tối ưu khoảng **0,005 USD/bài**, tức khoảng 20–40 USD/tháng cho toàn bộ BTVN.
- 3.1 Flash-Lite: 0,25 / 1,50. 3.5 Flash-Lite: 0,30 / 2,50.
- Gói **Google AI Pro**: 10 USD/tháng tín dụng Google Cloud dùng được cho Gemini API (kích hoạt qua Google Developer Program, project cần bật thanh toán, nên đặt trần chi tiêu).

---

## 6. Thiết kế lời dặn và kết quả của AI chấm

### 6.1 Những gì làm giảm token mạnh nhất
1. **Đưa sẵn đề + đáp án + barem chữ**: AI không phải đoán đề và tự giải.
2. **Không chép lại cả bài**: chỉ trích dòng bị trừ điểm. Bản chép đầy đủ chỉ gọi riêng khi phúc khảo.
3. **Kết quả gọn theo mã bước barem** + khuôn JSON bắt buộc + trần token ra.
4. **Máy cộng điểm**, không để AI cộng.
5. (Chưa đo) Cắt phần đầu phiếu và viền trang trí, giảm độ phân giải ảnh, chuyển đen trắng, thử `media_resolution`.

**Không** chuyển ảnh sang chữ trước rồi mới chấm: tốn gấp đôi lượt, token ra đắt, đọc sai ở bước 1 thì bước 2 chấm sai mà không ai biết, mất hình vẽ. Chữ chỉ có ích cho phúc khảo, thống kê lỗi, tìm kiếm. Nếu chép thì dùng ký hiệu thường (x², √, ·) thay cho LaTeX.

### 6.2 Lời dặn chấm (đang dùng trong file chạy thử)
```
Chấm bài Toán viết tay theo BAREM bên dưới. Các ảnh là các trang của cùng một bài, theo thứ tự.
- Bỏ qua mọi chữ, dấu, điểm bằng mực đỏ của giáo viên. Bỏ qua phần học sinh đã gạch bỏ.
- Mỗi bước barem: cho đủ điểm nếu bài làm thể hiện đúng bước đó; 0 nếu thiếu hoặc sai.
- Cách giải khác nhưng đúng vẫn cho điểm các bước tương đương.
- Câu không làm: mọi bước 0 điểm.
- Chỉ khi có bước bị trừ: ghi "sai" (≤ 15 từ) và "trich" (dòng bị trừ, ký hiệu toán thường, không LaTeX).
- "tin": cao / tb / thap. "kho_doc": chỗ không đọc rõ.
Chỉ trả JSON theo khuôn.
```
Khuôn kết quả:
```json
{"y":[{"c":"1.2b","b":[{"id":"1.2b.1","d":0},{"id":"1.2b.2","d":0.125}],
       "sai":"dừng ở b=1","trich":"5b = 5 ⇒ b = 1","tin":"cao"}],
 "kho_doc":[]}
```
**Cần bổ sung khi làm thật** (cho bài nhiều trang, xem mục 7): `"trang":[3,4]` và `"tinh_trang":"co_lam|bo_trong|khong_thay"` cho mỗi câu; câu "bài làm có thể nối sang trang sau".

### 6.3 Mẫu barem tách bước
```
QUY TẮC CHẤM: Mỗi bước chỉ có 2 mức: đạt (đủ điểm) hoặc không đạt (0). KHÔNG cho nửa điểm bước.

CÂU 1.2b (0,75đ). Giải hệ: 2/(x+2y) + 1/(y+2x) = 3 và 4/(x+2y) − 3/(y+2x) = 1
Đáp án: x = y = 1/3
- 1.2b.1 (0,125) Nêu điều kiện: x + 2y ≠ 0 và y + 2x ≠ 0
- 1.2b.2 (0,125) Đặt ẩn phụ a, b, viết được hệ 2a + b = 3; 4a − 3b = 1
- 1.2b.3 (0,125) Tìm được b = 1
- 1.2b.4 (0,125) Tìm được a = 1
- 1.2b.5 (0,25)  Đưa về x + 2y = 1; 2x + y = 1, giải ra x = y = 1/3 và kết luận
```
App nên **nhắc GV khi soạn barem**: cảnh báo bước có chữ "và", hoặc gộp nhiều phép tính.

### 6.4 Lời dặn viết nhận xét (Gemma, chỉ chữ)
Đầu vào: kết quả chấm **đã chốt** (điểm từng bước kèm nội dung bước barem, lỗi, dòng HS viết).
Luật: **không chấm lại, không đổi điểm, không nhắc lỗi không có trong kết quả**.
Đầu ra:
- `cau[].nx`: 15–30 từ gửi HS, xưng "em". Câu đúng thì khen cụ thể. Câu sai thì chỉ bước chưa đạt và gợi hướng sửa, **không giải hộ**. Cấm câu chung chung.
- `hoc_sinh`: 2–3 câu tổng kết, nêu 1 điều cần sửa ưu tiên.
- `phu_huynh`: 60–100 từ, xưng "Trung tâm", gọi HS là "con", viết dễ hiểu, có 1 gợi ý hỗ trợ ở nhà.

**Việc tiếp:** soạn **10–15 nhận xét mẫu chuẩn giọng HMT** (đúng / sai / làm dở / bỏ trống; bản HS và bản PH) để đưa vào lời dặn. Claude Pro dùng để soạn bộ mẫu này trong chat. **Không** dùng Claude Pro để chạy nhận xét tự động: Pro không có API, và cách dùng tự động qua gói thuê bao chỉ dành cho thử nghiệm cá nhân.

---

## 7. Bài làm một câu nằm ở 1 ảnh hoặc nhiều ảnh

**Nộp theo bài, không theo câu.** HS chụp mọi trang theo thứ tự, AI chấm cả bài trong một lượt.
- Một câu trải nhiều trang: AI tự nối (đã thử: câu 2a nằm ở trang 3–4, chấm đúng). Điều kiện là **thứ tự trang đúng**: app đánh số, hiện ảnh thu nhỏ, cho kéo đổi thứ tự. Gửi AI kèm nhãn "Trang i".
- Một trang có nhiều câu: không sao.
- Mỗi câu AI trả về `trang` (để màn duyệt nhảy thẳng tới đúng ảnh) và `tinh_trang`:
  - `co_lam`: chấm bình thường.
  - `bo_trong`: 0 điểm.
  - `khong_thay`: **không tự cho 0**. Đánh dấu "thiếu bài làm". Còn hạn thì app báo HS nộp bổ sung rồi **chấm lại cả bài**.
- Giới hạn khoảng 10 trang/bài. Quy định cho HS: ghi rõ số câu, chụp thẳng, đủ sáng, đúng thứ tự.
- Nộp theo câu bị loại vì tốn 1 lượt/câu và HS dễ gắn nhầm ảnh.

**Đáp án của GV ở dạng ảnh (1 hoặc nhiều trang):** không gửi ảnh đáp án mỗi lần chấm. Lúc tạo bài, AI (3.8 Flash) đọc ảnh đáp án và **soạn nháp barem tách bước**, GV sửa và duyệt, lưu lại barem chữ. Mọi bài nộp chấm theo barem đó.

---

## 7b. GV chỉ ra đề → AI tự soạn barem (đã thử, đạt)

**Luồng:** đề → `3.8 Flash` (thinking high) tự giải + soạn barem → `3.7 Flash` giải độc lập, so đáp số theo đúng mã câu → máy kiểm (tổng bước = điểm câu, bội 0,125, bước gộp ý) → GV duyệt → lưu.

**Kết quả thử (đề bài 1, lớp 9):**
| Lần | Barem | Chấm 3 lần bằng Flash-Lite (high) |
|---|---|---|
| 1 | Đáp số đúng nhưng **gộp bước** ("đặt ẩn… giải ra u = 1 và v = 1"), cách khác chỉ là 1 dòng chung | 4 / 4,25 / 4 ❌ |
| 2 | Tách bước tốt hơn, nhưng **tên ẩn u, v ≠ a, b của HS**, câu 2b HS dùng **cách thứ 3 không có trong barem**; tổng câu 1.1 lệch 1,125 (máy bắt được) | 4,25 / 4,375 / **3,25** (2b bị 0) ❌ |
| 3 | Bước theo **biểu thức**, cách khác là **barem đầy đủ riêng** (mã `.k1…`), có liệt kê các hướng chứng minh khác | **4,25 / 4,25 / 4,25** ✅ |

**Luật soạn barem tự động (đưa vào lời dặn):**
- Mỗi bước kết thúc ở **đúng một kết quả nhìn thấy được** (một điều kiện / phương trình / giá trị / khẳng định). Có ví dụ mẫu gộp (sai) và tách (đúng), dùng đề khác.
- Mô tả **theo biểu thức**, không theo tên ẩn tự đặt ("tìm được 1/(y+2x) = 1", không viết "v = 1").
- **Cách khác** = barem đầy đủ riêng, mã `<câu>.k<số>`, tổng điểm bằng điểm câu. Câu chứng minh liệt kê thêm `cach_khac_ngan` (các hướng đúng khác).
- Mã câu theo đúng đề (1.1, 1.2a, 2b…). Mô hình kiểm tra chéo được **đưa sẵn danh sách mã câu**.
- Chọn lớp (`--lop 9`) để cách chính đúng chương trình.

**Luật chấm bổ sung:**
- AI khai `cach`: `chinh` / `khac` / **`la`** (cách đúng không có barem chi tiết). Với `la`: **không được cho 0 vì khác barem**, AI đề xuất `d_la` cho cả câu, **bắt buộc GV xem**.
- AI khai `tinh_trang`: `co_lam` / `bo_trong` / `khong_thay`.
- Máy lấy điểm cao hơn giữa cách chính và cách khác. Máy gắn cờ **"có làm mà 0 điểm"**.
- Đối chiếu theo **biểu thức**, không theo tên ẩn.

**Bài học:** barem soạn tay từ chính bài HS thì dễ ổn định. Barem soạn từ đề **không lường hết cách giải**, nhất là **câu chứng minh hình**. → Câu tính toán: tự động tốt. Câu chứng minh: cần cờ "cách lạ" + **GV bổ sung cách mới vào barem khi gặp** → barem mỗi đề tốt dần theo thời gian.

**Vận hành:** soạn barem mất 2–15 phút/đề (đã gặp quá 10 phút ở thinking high) → **chạy ngầm trong hàng chờ**, báo GV khi xong. Không chạy trực tiếp trong Edge Function (giới hạn thời gian). Có tuỳ chọn `--nghi medium` nếu quá chậm.

---

## 7c. Học sinh dùng AI giải rồi chép vào BTVN

**Sự thật:** không có cách phát hiện chắc chắn với bài viết tay. Không dùng "công cụ phát hiện AI". Chiến lược: **tín hiệu để nghi vấn → kiểm tra lại để xác nhận → thiết kế để chép không còn lợi.**

**Tín hiệu (mạnh → yếu):**
1. **BTVN cao, làm tại lớp thấp** (mạnh nhất, làm ngay được bằng dữ liệu sẵn có, không cần AI).
2. **Nhiều HS cùng lời giải lạ** (cùng cách hiếm, cùng câu chữ, cùng lỗi) → AI chấm trả thêm `dau_van_tay` ~10 từ, máy so trong lớp.
3. **Dùng kiến thức ngoài chương trình / ngoài cách dạy trên lớp** → AI chấm đánh dấu `ngoai_cach_hoc`.
4. Lời giải hoàn hảo, văn phong máy, không nháp (yếu, dễ oan). Giờ nộp (rất yếu).

**Xác nhận:** từ barem, AI tự tạo **câu tương tự (khác số)**. Đầu buổi sau, HS bị nghi vấn (hoặc cả lớp) làm 1 câu trong 5 phút. Không làm được thì GV hỏi em giải thích một bước trong bài của mình.

**Thiết kế:** giảm sức nặng điểm BTVN (mục D chấm nỗ lực/quá trình); yêu cầu làm theo cách học trên lớp; nút **"Em chưa làm được câu này"** + ô **"Em có dùng trợ giúp"** (không phạt); sau này có **trợ giảng AI của HMT** chỉ gợi ý, không giải hộ; phiếu phụ huynh hiện **chênh lệch BTVN và làm tại lớp**.

**Nguyên tắc:** mọi đánh dấu chỉ là **"nghi vấn"**, chỉ GV thấy, **không tự trừ điểm**, không hiện cho HS/PH. Làm ở giai đoạn 4b/4c.

---

## 7d. Hội đồng chấm AI (đề xuất, chưa thử)

**Kết luận:** đúng hướng, có cơ sở khoa học. **Bổ sung** cho barem chặt chứ không thay thế: barem chặt là điều kiện để hội đồng chạy được, nếu không thì trọng tài sẽ quá tải.

### Cơ sở khoa học
| Căn cứ | Nội dung | Áp vào HMT |
|---|---|---|
| Quy chế chấm thi tốt nghiệp THPT | Bài tự luận chấm **2 vòng độc lập** bởi 2 cán bộ thuộc 2 tổ khác nhau, người chấm vòng 2 không nhận lại bài mình đã chấm vòng 1; **chấm chung ≥ 10 bài** trước để thống nhất cách hiểu; thống nhất điểm, có trường hợp chấm lần 3 | Hội đồng AI là phiên bản tự động: độc lập, che tên, cùng barem, hiệu chỉnh trước, có trọng tài |
| Định lý bồi thẩm đoàn Condorcet | Giám khảo đúng p > 50% và **sai độc lập** → đa số đúng nhiều hơn. p = 90%, 3 người → **97,2%** | Lý do toán học. Điều kiện: **độc lập** |
| Verga et al. 2024, *Replacing Judges with Juries* (PoLL) | 3 mô hình nhỏ **khác hãng** > 1 GPT-4: κ với người 0,763 so với 0,627; **rẻ hơn hơn 7 lần**; ít thiên vị; mô hình đơn lẻ nhạy với lời dặn (κ 0,52–0,73) | Bằng chứng trực tiếp. Thành viên **phải khác họ mô hình** |
| Kim et al., ICML 2025, *Correlated Errors in LLMs* | Khi cùng sai, hai mô hình **chọn cùng đáp án sai khoảng 60%** (ngẫu nhiên khoảng 1/3). **Cùng hãng, cùng kiến trúc → sai giống nhau hơn**. Đa mô hình "không phải thuốc tiên", cần hiệu chỉnh bằng dữ liệu thật | ⚠️ Flash-Lite và Gemma **đều của Google** → hai bên khớp **không có nghĩa** là đúng. Bắt buộc kiểm định bằng điểm GV |
| Wang et al. 2022, *Self-Consistency* | Cùng mô hình giải nhiều lần + bỏ phiếu → chính xác hơn | Chấm lặp cùng mô hình **bắt được dao động**, **không bắt được sai hệ thống** (ví dụ dễ dãi với câu làm dở) |
| Dawid & Skene 1979 | Gộp ý kiến nhiều người gán nhãn bằng cách ước lượng tỉ lệ sai từng người → **bỏ phiếu có trọng số** | Khi đủ dữ liệu: tin giám khảo nào hơn theo từng dạng câu |
| UC Irvine 2026, chấm bài giải tích viết tay (khoảng 3.900 bài, GPT-4.1-mini) | 79,8% đúng hoàn toàn, 9,6% chấp nhận được, 10,7% sai. Lỗi: đọc sai chữ, **trừ cách giải đúng ngoài barem**, **dễ dãi** với lập luận sai. Khuyến nghị: **bài chấm lặp dao động → chuyển người chấm**; **2 barem + lấy điểm cao hơn**; nhiệt độ gần 0 | Thiết kế HMT (barem tách bước, cách khác + lấy cao hơn, chuyển GV) **khớp khuyến nghị** |

### 4 điều kiện bắt buộc
1. Thành viên **khác mô hình** (càng khác càng tốt). Chấm 2 lần cùng mô hình chỉ bắt được dao động.
2. **Độc lập + che tên**: không giám khảo nào thấy kết quả của giám khảo khác.
3. **So từng bước, bỏ phiếu đa số, không lấy trung bình từng bước.** Barem nhị phân + 3 phiếu → luôn có đa số. Trung bình 0,125 và 0 ra 0,0625 là **chắc chắn sai**. **So từng bước, không so tổng**, vì tổng có thể bù trừ (đã gặp: 3 mô hình cùng 4,25 nhưng chia bước khác nhau).
4. **Hiệu chỉnh + kiểm định bằng điểm GV**, trước và trong khi dùng.

**Không dùng nhiều tài khoản free để nhân hạn mức:** cùng mô hình không thêm độ độc lập, lách điều khoản, có nguy cơ bị khoá. Một tài khoản đã có 3 mô hình với hạn mức riêng.

### Thành phần
| Vai trò | Ai | Nhiệm vụ |
|---|---|---|
| Giám khảo 1 | Gemini 3.5 Flash-Lite (high) | Chấm độc lập |
| Giám khảo 2 | Gemma 4 31B | Chấm độc lập (khác họ mô hình) |
| Trọng tài | Gemini 3.8 Flash (dự phòng 3.7 / 3.6 / 3.5 Flash) | Phiếu thứ 3 khi lệch, chấm độc lập không xem kết quả 2 GK |
| Thư ký | Máy (Supabase) | So từng bước, cộng điểm, phân luồng, nhật ký, thống kê |
| Tổ trưởng | **Giáo viên** | Quyết định cuối, chấm hiệu chỉnh, chấm kiểm định |

### Quy trình
- **Bước 0: chấm chung (mỗi đề mới).** GV chấm 3–5 bài đầu, hội đồng chấm cùng. Lệch nhiều thì sửa barem trước khi chấm hàng loạt.
- **Bước 1: hai vòng độc lập.** GK1 và GK2 chấm song song.
- **Bước 2: phân mức** (ngưỡng ban đầu, chỉnh theo dữ liệu):

| Mức | Điều kiện | Xử lý |
|---|---|---|
| 0. Khớp | Mọi bước giống nhau | Chốt |
| 1. Lệch nhỏ | Tổng lệch ≤ 0,25đ **và** không đổi mức BTVN 1–5 | Chốt bằng **trung bình tổng**. Bước lệch gắn nhãn "chưa chắc", nhận xét không khẳng định ở bước đó |
| 2. Lệch vừa | Tổng lệch > 0,25, hoặc một câu lệch ≥ 0,5 | Trọng tài chấm độc lập → **đa số 2/3 từng bước** |
| 3. Chuyển GV | Lệch > 1đ; "cách lạ"; ô đáp số mâu thuẫn; có làm mà 0 điểm; hết lượt trọng tài | GV chấm. Bài này cũng là dữ liệu để sửa barem |

- **Bước 3: kiểm định.** Rút ngẫu nhiên **5%** bài mức 0–1 cho GV chấm lại. Quy tắc số 3: kiểm 100 bài, 0 sai → tỉ lệ sai thật < 3% (độ tin cậy 95%). Theo dõi hằng tuần: κ giữa AI và GV, tỉ lệ bài ở từng mức, **tỉ lệ AI cho cao hơn GV** (chấm dễ dãi).
- **Bước 4: học dần.** Sau vài trăm bài: ước lượng độ chính xác từng GK theo dạng câu → bỏ phiếu có trọng số (Dawid–Skene) → chỉnh ngưỡng để cân số bài chuyển GV và tỉ lệ sai lọt qua.

### Phép tính then chốt: trọng tài có đủ lượt không
Bài k = 20 bước, mỗi GK đúng p mỗi bước, sai độc lập:
| p mỗi bước | Lệch mỗi bước | Bài có ≥ 1 bước lệch | 400 bài/ngày → cần trọng tài |
|---|---|---|---|
| 99% | khoảng 2% | khoảng 33% | khoảng 130 |
| 97% | khoảng 6% | khoảng 70% | khoảng 280 |
| 90% | khoảng 18% | khoảng 98% | gần hết |
Trọng tài chỉ có khoảng 20 + 60 lượt/ngày → **mức 1 (chấp nhận lệch nhỏ) là bắt buộc**, và barem phải chặt để p cao. **Cần đo bằng dữ liệu thật.**

### Còn chưa biết (cần 20 → 100–200 bài có điểm GV)
- Tỉ lệ bài rơi vào từng mức.
- Mức tương quan sai giữa Flash-Lite và Gemma (cùng Google).
- Độ chính xác của trọng tài **trên nhóm bài khó** (thiên lệch do chọn mẫu: bài lệch là bài khó nhất).

### Nguồn
- Verga et al. (2024). *Replacing Judges with Juries: Evaluating LLM Generations with a Panel of Diverse Models.* https://arxiv.org/abs/2404.18796
- Kim et al. (2025). *Correlated Errors in Large Language Models.* ICML 2025. https://proceedings.mlr.press/v267/kim25e.html
- Wang et al. (2022). *Self-Consistency Improves Chain of Thought Reasoning in Language Models.* https://arxiv.org/abs/2203.11171
- Dawid, A. P. & Skene, A. M. (1979). *Maximum Likelihood Estimation of Observer Error Rates Using the EM Algorithm.* Applied Statistics 28(1). https://ideas.repec.org/a/bla/jorssc/v28y1979i1p20-28.html
- *Evaluating AI Grading on Real-World Handwritten College Mathematics* (UC Irvine, 2026). https://arxiv.org/abs/2603.00895
- Quy trình chấm bài tự luận thi tốt nghiệp THPT 2024 (Báo Lào Cai, VnExpress). https://baolaocai.vn/quy-trinh-cham-bai-tu-luan-thi-tot-nghiep-thpt-nam-2024-the-nao-post386084.html · https://vnexpress.net/bai-thi-tu-luan-duoc-cham-the-nao-4144967.html

---

## 8. Gắn vào kiến trúc đã chốt

| Thành phần | Công nghệ | Việc |
|---|---|---|
| Giao diện | React (Vite) trên Cloudflare Pages | Màn chụp/nộp (kiểm tra ảnh mờ, sắp thứ tự, cắt và nén trên máy), màn duyệt chia đôi cho GV |
| Dữ liệu và luật | Supabase Postgres + RLS | Đề, câu, barem, bài nộp, điểm từng bước. **Cộng điểm trong hàm của cơ sở dữ liệu** |
| File | Cloudflare R2 | Ảnh bài làm, đề PDF, ảnh đáp án. Link tải lên có chữ ký, có hạn |
| Hàng chờ | Bảng job + pg_cron mỗi phút | Lấy bài "chờ chấm", khoá dòng để không chấm trùng |
| Bộ chấm | Edge Function `cham-ai` | Gọi Gemini/Gemma, khoá API trong Supabase secrets |
| Báo cáo | Looker Studio | Tỉ lệ nộp, điểm, tỉ lệ AI khớp GV, lỗi hay gặp, hạn mức đã dùng |

### Dữ liệu chính (nháp)
- `de`, `cau_hoi` (mã câu, loại, điểm tối đa, đáp án, **đáp số**), `barem_buoc` (mã bước, điểm, nội dung).
- `giao_bai` (lớp/buổi, mở lúc, hạn nộp, thời gian làm, số lần, chế độ công bố).
- `bai_nop`, `tra_loi_tn`, `dap_so_hs`, `anh_bai_lam` (thứ tự trang, khoá R2).
- `luot_cham_ai` (trạng thái, mô hình, **phiên bản lời dặn**, số lần thử, token, số giây, JSON gốc).
- `diem_buoc` (điểm AI, điểm GV, người chốt). Tổng câu và tổng bài do cơ sở dữ liệu tính.
- `nhan_xet` (câu, HS, PH, mô hình, đã duyệt chưa).

### Vận hành bộ chấm
- **Bộ chấm thay được**: app chỉ biết "gửi bài → nhận điểm từng bước". Sau lưng có thể là Gemini miễn phí, Gemini trả phí, máy chấm tại trung tâm (Qwen-VL qua Ollama trên Mac) hoặc GV chấm tay.
- Lỗi 429/500/503 thì thử lại với thời gian chờ tăng dần (10 → 30 → 60 giây). Hết lượt trong ngày thì để bài chờ hôm sau hoặc chuyển Gemma. Chờ quá N giờ thì báo GV chấm tay.
- Mô hình không nhận `thinkingConfig` / `responseSchema` (Gemma) thì tự bỏ tham số đó, đọc JSON từ chữ.
- Có `maxOutputTokens` đủ lớn khi suy nghĩ cao (suy nghĩ ăn vào trần token ra; đã gặp lỗi bị cắt).
- BTVN không cần xong ngay, chỉ cần xong trước buổi học sau, nên có thể chấm dồn vào ban đêm.

---

## 9. Chia giai đoạn LMS

| Giai đoạn | Nội dung | AI |
|---|---|---|
| **4a** | Đề + đáp án + barem, giao bài, trắc nghiệm tự chấm, nộp ảnh + ô đáp số, GV chấm tay theo barem (màn tích bước) | Không |
| **4b** | Hàng chờ + Flash-Lite chấm gợi ý, GV duyệt 100%, Gemma viết nhận xét sau duyệt, đo tỉ lệ khớp | Có |
| **4c** | Bài không bị đánh dấu và tỉ lệ khớp đạt ngưỡng thì tự công bố, GV soát ngẫu nhiên | Có |

---

## 10. Rủi ro và lưu ý

- **Tài khoản Google đầu tiên (lead.vanhanh.hmt@gmail.com) bị khoá gói miễn phí Gemini** ("project has been denied access"), không rõ lý do. Trên diễn đàn Google, nhiều người bị cùng lỗi từ tháng 9–10/2026 và chưa được giải quyết. Tài khoản đang dùng là một gmail cá nhân khác → hệ chấm phụ thuộc vào gmail này.
- Gói miễn phí có thể bị cắt hoặc đổi hạn mức bất kỳ lúc nào (Google từng cắt 2.5 Flash từ 250 xuống 20 lượt/ngày). Dự phòng: 3.8 Flash trả phí (khoảng 20–40 USD/tháng) hoặc tín dụng AI Pro.
- **Dữ liệu học sinh:** điều khoản Gemini API gói miễn phí cho phép Google dùng dữ liệu để cải thiện sản phẩm (có người đọc), cấm ứng dụng hướng tới người dưới 18 tuổi, và dặn không gửi thông tin cá nhân. Anh đã quyết định đi tiếp. Nên giảm rủi ro: ảnh gửi đi **không có tên/mã HS** (cắt phần đầu phiếu, dùng mã bài ngẫu nhiên), ghi rõ trong điều khoản ghi danh. Gói trả phí thì Google không dùng dữ liệu để huấn luyện.
- **Khoá API đã từng dán vào chat → phải xoá và tạo khoá mới.** Khoá thật chỉ cất trong Supabase secrets.
- Mới thử trên **1 bài**. Chưa có số liệu thống kê.

---

## 11. Việc tiếp theo

1. [ ] **Thử 20 bài BTVN thật**: cùng đề (**ảnh đề gốc**), chụp **trước khi GV chấm**, có **điểm GV** để so. Barem do `tao_barem.py` tự soạn → GV duyệt → chấm cả bộ, xuất bảng so sánh + tỉ lệ khớp. Đặc biệt xem **câu chứng minh** và **cờ "cách lạ"**.
2. [x] ~~AI soạn barem từ đề~~ → đã thử, đạt trên 1 đề (mục 7b). Còn thử với **ảnh đề** (chưa thử, mới thử đề dạng chữ).
2b. [ ] Viết `hoi_dong.py`: chạy đủ hội đồng (GK1, GK2, trọng tài) trên bộ bài có điểm GV → bảng: độ chính xác từng GK, **tương quan sai GK1–GK2**, tỉ lệ bài ở từng mức, tỉ lệ sai lọt qua theo từng ngưỡng → chọn ngưỡng bằng số liệu.
3. [ ] Soạn **bộ mẫu nhận xét chuẩn HMT** (10–15 mẫu).
4. [ ] Đo **cắt và nén ảnh** (token vào giảm bao nhiêu, AI còn đọc đúng không).
5. [ ] Cập nhật lời dặn: `trang`, `tinh_trang`, câu nối trang.
6. [ ] Viết **đặc tả LMS** (bước 1 trong quy trình 5 bước) → anh duyệt → mới code.

### Câu hỏi còn mở
- HS học mấy buổi/tuần? BTVN thường mấy câu, mấy trang?
- Ai soạn barem: GV từng lớp hay tổ chuyên môn?
- Quy tắc quy điểm BTVN ra mức 1–5 (mục D phiếu chấm buổi)?
- Ngưỡng để sang 4c (ví dụ ≥ 90% câu lệch ≤ 0,25 điểm trên 200 bài)?
- HS nhỏ không có điện thoại thì phụ huynh chụp nộp hộ?
- Có dùng phiếu bài làm HMT có QR (mã đề + mã HS) không? Có QR thì ghép bài và cắt ảnh tự động dễ hơn.

---

## 12. Phụ lục: chạy thử trên Mac

**Các file:** `tao_barem.py` (đề → barem), `cham_theo_barem.py` (chấm), `de_bai1.txt` (đề bài 1 dạng chữ), `barem_bai1_v2.txt` (barem soạn tay), `thu_cham_gemini.py` (bản đầu, không barem). Chỉ dùng thư viện có sẵn của Python.

```bash
cd ~/Downloads
export GEMINI_KEY='khoá của anh'      # không dán khoá vào chat

# Đề -> barem tự động (+ kiểm tra chéo). Đề có thể là .txt, ảnh, hoặc PDF
python3 tao_barem.py --lop 9 de_bai1.txt          # ra barem_tu_dong.txt
#   tuỳ chọn: --nghi medium | --model gemini-3.6-flash | --kiem-cheo khong | --ra ten.txt

# Chấm (cấu hình đã chốt)
python3 cham_theo_barem.py --model gemini-3.5-flash-lite --nghi high barem_bai1_v2.txt a1.jpg a2.jpg a3.jpg a4.jpg

# Chấm + Gemma viết nhận xét riêng (HS + PH)
python3 cham_theo_barem.py --model gemini-3.5-flash-lite --nghi high --nhanxet-rieng barem_bai1_v2.txt a1.jpg a2.jpg a3.jpg a4.jpg

# Đo độ ổn định: chấm 3 lần
for i in 1 2 3; do python3 cham_theo_barem.py --model gemini-3.5-flash-lite --nghi high barem_bai1_v2.txt a1.jpg a2.jpg a3.jpg a4.jpg | grep -E "^(1.2b|2b|TỔNG)"; done
```
Tuỳ chọn: `--model`, `--nghi low|high`, `--nhanxet` (nhận xét trong cùng lượt, không khuyên dùng), `--phuhuynh`, `--nhanxet-rieng`, `--model-nx`.
Định dạng barem: mỗi bước một dòng `- <mã> (<điểm>) <nội dung>`. Dòng bắt đầu bằng `#` là ghi chú.

**Lỗi đã gặp:**
- `CERTIFICATE_VERIFY_FAILED`: chạy `open "/Applications/Python 3.14/Install Certificates.command"`.
- 503 "high demand": Google quá tải. File tự thử lại, hoặc đổi mô hình.
- 403 "project has been denied access": tài khoản/project bị khoá gói miễn phí.
- Mac tải file trùng tên sẽ lưu thành `... (1).py`. Xoá bản cũ, đổi tên về đúng tên gốc.
