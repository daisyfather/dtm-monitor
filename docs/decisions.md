# Nhật ký quyết định

Ghi lại các quyết định đã chốt và lý do, để người đọc sau hiểu **vì sao** hệ thống được dựng như vậy.
Quyết định mới thêm vào cuối, không sửa quyết định cũ; nếu đổi hướng thì ghi một quyết định mới thay thế.

| # | Ngày | Quyết định | Lý do | Ảnh hưởng |
|---|---|---|---|---|
| D01 | 21/10 | Mỗi mart là một **bounded context**; dữ liệu dùng chung (conformed dimension) lấy từ **STG_DTM** (phái sinh T-1 của SB_DWH); mart không đọc chéo nhau | Mỗi mart tự định nghĩa ngữ nghĩa nghiệp vụ riêng; tránh phụ thuộc chéo thành mạng nhện | Tiêu chí phụ thuộc chéo (v1: CROSS_MART_DEP, v2: A1) |
| D02 | 21/10 | **BI_DTM** là user master / orchestration, chứa bộ giám sát | Một điểm điều phối duy nhất | BI_DTM là rủi ro tập trung: vault mật khẩu, audit, không dùng ad-hoc |
| D03 | 21/10 | Kết quả giám sát ghi vào bảng lịch sử, **OAS chỉ đọc view** | View DBA_* chậm; OAS không cần quyền dictionary; có lịch sử để đọc xu hướng | Bảng `MON_*`, view `VW_MON_*`, role `BI_DTM_MON_READ` |
| D04 | 21/10 | Trạng thái `ERROR` tách khỏi `FAIL`; một tiêu chí lỗi không dừng tiêu chí khác | Lỗi của bộ đo không được che hoặc giả làm lỗi dữ liệu (bài học từ job cảnh báo LOS) | Lần chạy có `PARTIAL` |
| D05 | 21/10 | Mọi chuỗi tiếng Việt trong code SQL viết bằng `TO_CHAR(UNISTR(...))` | Oracle client của team không gửi đúng UTF-8, chữ có dấu thành `?` | `tools/unistr_conv.py`, `tools/check_ascii.py` |
| D06 | 22/10 | Dashboard OAS dùng **Direct Database Request** cho mọi analysis | Dataset (DV) trên Classic Analysis gặp lỗi "Edge has duplicate layer" | SQL của dashboard nằm trong repo, lọc bằng presentation variable |
| D07 | 22/10 | Màu trạng thái tính sẵn trong SQL thành HTML khi OAS không làm được bằng Conditional Format | Lỗi Assertion failure khi tô màu Pivot theo measure khác trên DDR | Trang Ma trận, trang Hướng dẫn |
| D08 | 22/10 | Thêm zone **ADMIN** cho BI_DTM | BI_DTM không phải mart nghiệp vụ, không chấm theo tiêu chí dành cho mart | Package 1.2 lọc theo zone; v1 còn lỗi A1 tính ADMIN là vi phạm |
| D09 | 22/10 | Góc nhìn bộ giám sát là **owner schema / Data Engineer**, không phải DBA | Owner cần biết dữ liệu, kiến trúc, object, truy cập, dung lượng của mình; việc nền tảng chỉ cảnh báo sớm để báo DBA | Danh mục 7 nhóm metric; loại quyền ANY, audit, AWR khỏi bộ của owner |
| D10 | 22/10 | Dung lượng và tăng trưởng thuộc về **owner** (nhóm 6), tách khỏi sức chứa nền tảng (nhóm 7, DBA) | Owner quyết định giữ / dọn / partition dữ liệu; DBA lo tablespace, ASM | Nhóm 6: C1 → C6 |
| D11 | 22/10 | Metric chia 2 loại: **Kiểm soát** (đúng/sai) và **Theo dõi** (INFO, cảnh báo khi biến động bất thường) | Dung lượng, tăng trưởng không có đúng/sai nhưng vẫn cần cảnh báo khi đột biến | Cột `CHECK_TYPE` ở v2 |
| D12 | 22/10 | Metric chỉ được chọn khi thỏa 5 nguyên tắc (có người hỏi, dẫn tới hành động, thuộc phạm vi owner, đo tự động ít nhiễu, phát hiện sớm) | Tránh bộ giám sát phình ra với số liệu không ai dùng | `docs/metrics-catalog.md` mục 2 |
| D13 | 22/10 | Metric đếm theo **object**; partition / từng quyền chỉ để ở phần chi tiết | Đếm theo partition và từng quyền làm số phóng đại (149 nghìn UNUSABLE, 58 nghìn grant), ngưỡng không so sánh được | Định nghĩa v2 |
| D14 | 22/10 | v1 lưu nguyên trạng ở `legacy/v1`; v2 xây ở thư mục gốc; mỗi giai đoạn qua Pull Request | Biết rõ bản đang chạy; thay đổi được review trước khi deploy | Cấu trúc repo |
