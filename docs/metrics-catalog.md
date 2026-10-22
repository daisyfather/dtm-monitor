# Danh mục metric giám sát DTM

Trạng thái: **bản thảo đã thống nhất hướng** (2026-10-22). Định nghĩa chi tiết từng metric
(công thức, nguồn, ngưỡng, nhiễu, người xử lý) được bổ sung lần lượt theo nhóm.

## 1. Góc nhìn

Bộ giám sát phục vụ **owner schema / Data Engineer**. Câu hỏi trung tâm:

- Dữ liệu của tôi đã về đủ, đúng hạn chưa?
- Các mart có giữ đúng ranh giới kiến trúc (bounded context) và chuẩn không?
- Code và object của tôi có hỏng không?
- Ai đang dùng dữ liệu của tôi, bằng đường nào?
- Dữ liệu của tôi chiếm bao nhiêu, tăng nhanh cỡ nào?

Việc thuộc nền tảng (tablespace, tài khoản, cấu hình database) chỉ theo dõi ở mức **cảnh báo sớm để báo DBA**.

## 2. Nguyên tắc chọn metric

Một metric được đưa vào khi thỏa cả 5 điều kiện:

| # | Điều kiện | Câu hỏi kiểm tra |
|---|---|---|
| 1 | Trả lời một câu hỏi có người thật sự hỏi | Owner, người dùng nghiệp vụ hoặc team có hỏi câu này không? |
| 2 | Dẫn tới hành động | Khi metric xấu đi, có ai làm gì cụ thể không? |
| 3 | Thuộc phạm vi của owner | Owner có quyền và trách nhiệm xử lý không? |
| 4 | Đo tự động, ít nhiễu | Có nguồn tin cậy, ít báo động giả không? |
| 5 | Phát hiện sớm | Báo trước khi sự cố xảy ra hay chỉ ghi nhận sau? |

## 3. Hai loại metric

| Loại | Ý nghĩa | Trạng thái |
|---|---|---|
| **Kiểm soát** | Có quy tắc đúng / sai, vi phạm phải có người xử lý | OK / WARN / FAIL |
| **Theo dõi** | Số liệu để hiểu hệ thống và đọc xu hướng | INFO, có thể WARN khi **biến động bất thường** |

## 4. Danh mục theo nhóm

Cột **Hiện có** cho biết tiêu chí tương ứng trong bộ 12 tiêu chí ban đầu (nếu có).

### Nhóm 1. Giao dữ liệu — *Dữ liệu hôm nay đã về đủ, đúng hạn chưa?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| D1 | Độ tươi: bảng công bố đã có dữ liệu T-1 chưa | Đo đúng thứ người dùng thấy, bắt cả trường hợp job báo thành công mà dữ liệu không về | Kiểm soát | – |
| D2 | Job ETL lỗi trong 24 giờ theo mart | Chỉ ra nguyên nhân khi D1 lỗi | Kiểm soát | – |
| D3 | Trễ SLA: giờ load xong so với giờ cam kết | Chậm mà không lỗi vẫn ảnh hưởng người dùng | Kiểm soát | – |
| D4 | Lệch khối lượng: số dòng ngày D lệch > X% so với trung bình 7 ngày | Bắt lỗi im lặng: dữ liệu chỉ về một phần | Kiểm soát | – |

Cần: bảng cấu hình `MON_FRESHNESS_DEF` (bảng, cột ngày, độ trễ cho phép, giờ SLA) và nguồn log job ETL.

### Nhóm 2. Kiến trúc & mô hình — *Các mart có giữ đúng ranh giới và chuẩn không?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| A1 | Phụ thuộc chéo giữa mart; 2 mức: đọc lớp công bố (WARN) / đọc lớp nội bộ (FAIL) | Bảo vệ bounded context | Kiểm soát | `CROSS_MART_DEP` |
| A2 | Sai quy ước đặt tên, kể cả bảng nội bộ đặt tên như bảng công bố | Đặt tên sai làm hỏng phân lớp, kéo theo cấp quyền và đọc chéo sai | Kiểm soát | – |
| A3 | Bảng RANGE partition chưa có partition tháng tới | Thiếu partition thì job fail ngày đầu tháng | Kiểm soát | – |
| A4 | Bảng FCT lớn chưa partition | Nợ thiết kế: không load lại theo ngày, không áp được retention | Theo dõi | – |

### Nhóm 3. Sức khỏe object — *Code và object có hỏng không?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| O1 | Object hỏng thật: INVALID và có dòng trong `DBA_ERRORS` | Gọi tới là lỗi chắc chắn | Kiểm soát | `INVALID_OBJ` (tách) |
| O2 | Object chờ compile: INVALID, không có lỗi biên dịch | Tách để bớt nhiễu cho O1 | Theo dõi | `INVALID_OBJ` (tách) |
| O3 | Index do team tạo bị UNUSABLE, tính cả subpartition | Chậm mà không báo lỗi; loại index tự động | Kiểm soát | `UNUSABLE_INDEX` |
| O4 | Stats cũ / thiếu trên lớp công bố | Nguyên nhân hàng đầu của báo cáo chậm đột ngột | Kiểm soát | `STALE_STATS` |
| O5 | Synonym hỏng | Lỗi ẩn, chỉ lộ khi có người gọi | Kiểm soát | – |

### Nhóm 4. Truy cập dữ liệu — *Ai đang dùng dữ liệu, bằng đường nào?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| S1 | Quyền cấp thẳng cho cá nhân, đếm cặp người nhận × object, trừ tài khoản dịch vụ | Thực thi "cấp quyền qua role" | Kiểm soát | `DIRECT_GRANT_USER` |
| S2 | Object cấp cho PUBLIC | Mức phơi bày cao nhất | Kiểm soát | `DIRECT_GRANT_USER` (tách) |
| S3 | Bảng nội bộ bị cấp ra ngoài (tiền tố và hậu tố) | Bảng nội bộ đổi cấu trúc bất kỳ lúc nào | Kiểm soát | `INTERNAL_OBJ_GRANTED` |
| S4 | Grant giữa các mart (trừ từ STG_DTM) | Cửa mở đường cho phụ thuộc chéo A1 | Kiểm soát | – |
| S5 | Quyền cấp lan (grantor không phải owner) | Quyền lan ra ngoài tầm kiểm soát | Kiểm soát | – |
| S6 | Database link trong schema | Dữ liệu có thể ra ngoài phạm vi kiểm soát | Kiểm soát | – |

Cần: bảng `MON_SERVICE_ACCOUNT` (dùng chung với P2).

### Nhóm 5. Metadata & thay đổi — *Người dùng có hiểu bảng không? Cái gì vừa đổi?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| M1 | Bảng / view công bố thiếu comment | Thiếu comment thì hiểu sai grain, sai định nghĩa | Kiểm soát | `MISSING_COMMENT` |
| M2 | Tỷ lệ cột có comment trên lớp công bố | Đo mức hoàn thiện tài liệu | Theo dõi | – |
| M3 | Object tạo mới / đổi cấu trúc kể từ lần chạy thành công trước | Đối chiếu với danh sách deploy đã duyệt | Theo dõi | `DDL_CHANGE_1D` (sửa khoảng thời gian) |

### Nhóm 6. Dung lượng & tăng trưởng — *Dữ liệu chiếm bao nhiêu, tăng nhanh cỡ nào?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| C1 | Dung lượng schema, tách TABLE / INDEX / LOB | Số liệu nền: tỷ trọng giữa các mart | Theo dõi | `SCHEMA_SIZE` |
| C2 | Tăng trưởng 1 / 7 / 30 ngày; WARN khi 1 ngày > 3 lần trung bình 30 ngày | Phát hiện load trùng, bảng backup mới | Theo dõi | (DS04) |
| C3 | Top 10 bảng lớn mỗi schema (bảng + partition + index + LOB) | Đầu vào cho retention, nén, partition | Theo dõi | – |
| C4 | Tỷ lệ index / tổng dung lượng | Phát hiện index phình (RISK_DTM 35%) | Theo dõi | (DS04) |
| C5 | Dung lượng recycle bin; WARN khi vượt ngưỡng | Dung lượng lãng phí, dọn được ngay | Kiểm soát | – |
| C6 | Dữ liệu vượt thời hạn lưu trữ | Dọn theo chính sách | Kiểm soát | – |

Cần (C6): bảng cấu hình thời hạn lưu trữ.

### Nhóm 7. Nền tảng (báo DBA) — *Có gì sắp làm vỡ pipeline không?*

| Mã | Metric | Vì sao chọn | Loại | Hiện có |
|---|---|---|---|---|
| P1 | Tablespace chứa dữ liệu DTM (% theo MAXSIZE) | Đầy thì mọi job ghi đều fail | Kiểm soát | `TS_USAGE_PCT` |
| P2 | Tài khoản dịch vụ bị khóa / hết hạn / sắp hết hạn mật khẩu | Lỗi đăng nhập làm dừng pipeline | Kiểm soát | `USER_PWD_EXPIRY` (thu hẹp) |
| P3 | TEMP / UNDO tại thời điểm chạy | Nguyên nhân phổ biến làm job lớn fail | Theo dõi | – |

### Đưa ra khỏi bộ của owner

| Metric | Lý do |
|---|---|
| `ANY_PRIV_HOLDER` (quyền ANY toàn database) | Không thuộc phạm vi owner (điều kiện 3); thuộc DBA / bảo mật |
| Cấu hình Auto Index | Cơ chế của Oracle, DBA cấu hình |
| Audit đăng nhập, top SQL qua AWR | Cần quyền audit / license Diagnostics Pack; thuộc DBA |

## 5. Lộ trình

| Giai đoạn | Nội dung |
|---|---|
| 0. Nền móng | `MON_CHECK_DEF` thêm `CHECK_GROUP` (7 nhóm), `CHECK_TYPE`, `RESOLVER`, `PROC_NAME`; package lõi gọi tiêu chí theo `PROC_NAME`; package theo nhóm; bảng `MON_SERVICE_ACCOUNT`, `MON_FRESHNESS_DEF` |
| 1. Chuẩn hóa | Sửa 2 lỗi gấp (A1 zone ADMIN, M3 khoảng thời gian); nhóm 3, 4; thêm C3, C5; đổi nhóm trên dashboard |
| 2. Giao dữ liệu | D1 → D4, sau khi có danh sách bảng công bố + SLA + nguồn log job |
| 3. Mở rộng | A2 → A4, S4 → S6, M2, C6, P3 |
