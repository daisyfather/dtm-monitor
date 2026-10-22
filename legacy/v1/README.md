# v1 — Bản đang chạy trên production

Thư mục này lưu **nguyên trạng** bộ giám sát DTM bản 1.x đang chạy trên database và dashboard OAS,
kèm ngữ cảnh: vì sao được dựng như vậy, chạy thế nào, đã gặp lỗi gì, và giới hạn nào sẽ được sửa ở v2.

> Không sửa file trong thư mục này để phát triển tính năng mới. v2 được xây ở thư mục gốc theo
> [`docs/metrics-catalog.md`](../../docs/metrics-catalog.md). Chỉ cập nhật ở đây khi trạng thái
> production thực tế thay đổi (ví dụ đổi lịch job).

## 1. Đang chạy thế nào

| Thành phần | Giá trị |
|---|---|
| Schema chứa | `BI_DTM` (user master / orchestration) |
| Package | `BI_DTM.PKG_DTM_MONITOR` bản **1.2** (`db/packages/pkg_dtm_monitor.sql`) |
| Lịch chạy | `DBMS_SCHEDULER` job `BI_DTM.JOB_MONITOR_DTM_DAILY`, 09:00 / 12:30 / 17:30 giờ VN (`db/jobs/`) |
| Thời gian một lần chạy | khoảng 2–5 phút (đo thực tế 145–310 giây) |
| Phạm vi | 16 schema trong `MON_SCHEMA_DEF` |
| Dashboard | OAS **DATAMART MONITOR DAILY**, 7 trang (`oas/`) |
| Quyền đọc cho OAS | role `BI_DTM_MON_READ`, chỉ qua view |

### Luồng xử lý của một lần chạy

```
run_daily(p_snapshot_date = hôm nay)
  1. Ghi MON_RUN_LOG (autonomous transaction, trạng thái RUNNING)
  2. Xóa toàn bộ dữ liệu của SNAPSHOT_DATE trong 3 bảng kết quả, COMMIT
  3. Với từng tiêu chí đang active trong MON_CHECK_DEF (theo DISPLAY_ORDER):
       exec_check → procedure chk_* tương ứng
         - ghi danh sách vi phạm vào MON_CHECK_DETAIL
         - ghi kết quả theo schema vào MON_CHECK_RESULT (so ngưỡng → OK/WARN/FAIL/INFO)
         - COMMIT riêng; nếu lỗi: ROLLBACK, ghi 1 dòng ERROR (schema _ALL_), chạy tiếp
  4. Cập nhật MON_RUN_LOG: SUCCESS / PARTIAL (có tiêu chí ERROR) / FAILED (dừng giữa chừng)
```

Hệ quả cần biết:
- **Chạy lại cùng ngày thì ghi đè.** Dashboard giữ kết quả của **lần chạy cuối trong ngày** (17:30).
- **Lần chạy giữa ngày có thể trùng lúc ETL đang chạy** và bắt trạng thái tạm (partition index UNUSABLE,
  stats chưa gather), ghi đè kết quả sạch của buổi sáng.
- Nếu một lần chạy FAILED sau bước 2, dữ liệu tốt của lần trước trong ngày đã bị xóa.
- Chỉ FAILED mới raise ra ngoài (job scheduler báo lỗi). PARTIAL không raise, phải xem trang 6.

## 2. Mô hình dữ liệu

| Bảng | Grain |
|---|---|
| `MON_SCHEMA_DEF` | 1 schema; zone `SOURCE` / `MART` / `SANDBOX` / `ADMIN` |
| `MON_CHECK_DEF` | 1 tiêu chí; ngưỡng WARN / FAIL; hướng xử lý |
| `MON_RUN_LOG` | 1 lần chạy |
| `MON_CHECK_RESULT` | ngày × tiêu chí × schema (`_ALL_` cho tiêu chí cấp database); partition theo tháng |
| `MON_CHECK_DETAIL` | ngày × tiêu chí × object vi phạm; partition theo tháng |
| `MON_SCHEMA_SIZE_DAILY` | ngày × schema × tablespace × loại segment |
| `MON_GLOSSARY` | 1 thuật ngữ (trang Hướng dẫn) |

View: `VW_MON_RESULT`, `VW_MON_LATEST`, `VW_MON_DETAIL`, `VW_MON_SIZE`, `VW_MON_RUN`,
`VW_OAS_MON_DETAIL`, `VW_OAS_MON_RUN`, `VW_OAS_MON_GLOSSARY`.

Ngưỡng được **chụp lại vào từng dòng kết quả**, nên sửa ngưỡng không làm đổi trạng thái các ngày cũ.

### Schema được giám sát

| Zone | Schema |
|---|---|
| SOURCE | STG_DTM (phái sinh T-1 của SB_DWH, nguồn conformed dimension) |
| MART | ENT, RETAIL, CNL (Pháp chế tuân thủ), RISK, OPS, CAP (Phê duyệt tín dụng), FIN, SND, COMMON, DG, ML, TREAS, WSP, XLN (_DTM) |
| ADMIN | BI_DTM |

`SND_DTM` đang để zone MART, mô tả "Sandbox" là phỏng đoán ban đầu — cần xác nhận lại.
6 schema thêm ngày 22/10 có mô tả "Chưa xác định".

## 3. 12 tiêu chí v1

| # | Mã | Nhóm v1 | Đơn vị | WARN / FAIL | Đo gì |
|---|---|---|---|---|---|
| 1 | SCHEMA_SIZE | STORAGE | MB | – / – (INFO) | Tổng dung lượng segment |
| 2 | TS_USAGE_PCT | STORAGE | PCT | 85 / 95 | % dùng của tablespace chứa DTM (`_ALL_`) |
| 3 | INVALID_OBJ | OBJECT | COUNT | 1 / 5 | Object STATUS = INVALID |
| 4 | UNUSABLE_INDEX | OBJECT | COUNT | – / 1 | Index và partition index UNUSABLE |
| 5 | STALE_STATS | PERFORMANCE | COUNT | 10 / 50 | Bảng / partition stats cũ hoặc chưa có |
| 6 | DIRECT_GRANT_USER | SECURITY | COUNT | 1 / – | Quyền object cấp thẳng cho user hoặc PUBLIC |
| 7 | INTERNAL_OBJ_GRANTED | SECURITY | COUNT | 1 / – | Bảng STG_/TWT_/TMP_ cấp ra ngoài (chỉ zone MART) |
| 8 | ANY_PRIV_HOLDER | SECURITY | COUNT | 1 / – | Quyền ANY của user/role tên có DTM hoặc ETL_ (`_ALL_`) |
| 9 | USER_PWD_EXPIRY | SECURITY | COUNT | 1 / – | Tài khoản hết hạn / khóa / sắp hết hạn 14 ngày (`_ALL_`) |
| 10 | DDL_CHANGE_1D | CHANGE | COUNT | – / – (INFO) | Object có LAST_DDL_TIME từ D-1 |
| 11 | CROSS_MART_DEP | ARCHITECTURE | COUNT | – / 1 | Mart phụ thuộc schema khác không phải SOURCE (chỉ zone MART) |
| 12 | MISSING_COMMENT | METADATA | COUNT | 1 / – | Bảng FCT_/DIM_/AGG_ thiếu comment |

## 4. Dashboard OAS

| Trang | Analysis | Ghi chú |
|---|---|---|
| 0. Hướng dẫn | DS00_MON_GLOSSARY_ANALYSIS | Static Text giới thiệu + bảng thuật ngữ chia section |
| 1. Tổng quan | DS01_MON_KPI + DS01_MON_ANALYSIS | 5 tile KPI + bảng tiêu chí |
| 2. Ma trận | DS02_MON_MATRIX_ANALYSIS | Màu ô tính sẵn bằng HTML trong SQL; danh sách schema ghi cứng trong PIVOT |
| 3. Chi tiết vi phạm | DS05_MON_DETAIL_ANALYSIS | Prompt `pv_check`, `pv_schema`; tối đa 5.000 dòng |
| 4. Xu hướng | DS03_MON_TREND_ANALYSIS | Dùng chung prompt trang 3; có đường ngưỡng WARN/FAIL |
| 5. Dung lượng | DS04_MON_SIZE_LATEST | 1 dòng / schema; biểu đồ stacked TABLE/INDEX/LOB |
| 6. Nhật ký chạy | DS06_MON_RUN_ANALYSIS | Trạng thái từng lần chạy |

Tất cả analysis dùng **Direct Database Request**. `oas/datasets_v0/` là bản dataset (DV) dựng đầu tiên,
đã bỏ vì lỗi "Edge has duplicate layer" trên Classic Analysis.

## 5. Lịch sử triển khai

| Ngày | Sự kiện |
|---|---|
| 21/10 | Deploy V001 (bảng, view, seed 12 tiêu chí, 9 schema) và package 1.0 |
| 21/10 | Lỗi PLS-00231: hàm private gọi trong SQL → package 1.1 gán vào biến trước |
| 21/10 | Tiếng Việt thành `?` (client NLS_LANG không phải UTF-8) → V003 ghi lại bằng UNISTR; package 1.1 đổi chuỗi sang UNISTR |
| 21/10 | V002: view cho OAS (`VW_OAS_MON_DETAIL`, `VW_OAS_MON_RUN`) |
| 22/10 | V004: bảng thuật ngữ; dựng xong 7 trang dashboard |
| 22/10 | Package 1.2: tiêu chí chỉ dành cho MART không ghi 0/OK cho zone khác |
| 22/10 | V005: thêm 7 schema và zone ADMIN; tạo job scheduler |

## 6. Bài học kỹ thuật (giữ lại cho v2)

**Oracle / PL/SQL**
- Package definer rights **không dùng quyền nhận qua role** → quyền dictionary cấp trực tiếp cho BI_DTM.
- Hàm khai báo riêng trong package body không gọi được trong câu SQL (PLS-00231) → gán vào biến.
- Client của team không gửi đúng UTF-8: **mọi chuỗi tiếng Việt trong code viết bằng `TO_CHAR(UNISTR(...))`**.
  `TO_CHAR` bọc ngoài để tránh ORA-12704 khi trộn NVARCHAR2 với VARCHAR2. `COMMENT ON` không nhận
  hàm → dùng `EXECUTE IMMEDIATE`. Kiểm tra bằng `tools/check_ascii.py`.
- Chẩn đoán lỗi dấu: `SELECT DUMP('đươ', 1016) FROM dual;` ra `64,75,6f` hoặc `3f` là client đang làm hỏng chuỗi.

**OAS (Classic Analysis trên Direct Database Request)**
- Pivot + Conditional Format dựa trên measure khác → `Assertion failure ... FormatManagerExpressionBuilder`.
  Cách làm: tính màu sẵn trong SQL thành HTML, cột đặt **Treat Text As: HTML**.
- Biểu đồ stacked dùng Vary Color By trên dữ liệu nhiều dòng / schema bị gộp sai (chỉ còn 1 loại).
  Cách làm: SQL trả 1 dòng / schema, mỗi loại là 1 measure, màu theo Style Formatting (vị trí).
- Performance Tile không chỉnh được aggregation rule → làm analysis KPI riêng trả đúng 1 dòng.
- "Edge has duplicate layer" là cấu hình view hỏng: xóa hẳn view và tạo lại, hoặc tạo analysis mới.
- Lọc bằng presentation variable trong SQL: `'@{pv_check}{INVALID_OBJ}'`; giá trị prompt dùng mã ASCII.
- Đổi tên cột ghi vào **Column Heading**, không phải Folder Heading. Retrieve Columns làm mất tên đã đặt
  → đổi tên ở bước cuối.
- Cột chữ mặc định ẩn giá trị lặp → đặt Value Suppression = Repeat cho bảng nhật ký.

## 7. Giới hạn đã biết → hướng xử lý ở v2

| Tiêu chí v1 | Vấn đề | Metric v2 |
|---|---|---|
| CROSS_MART_DEP | Zone ADMIN bị tính vi phạm; bỏ sót qua synonym; chưa chia mức công bố / nội bộ | A1 |
| DDL_CHANGE_1D | Khoảng thời gian ~33 giờ, đếm trùng; nhiễu do TRUNCATE | M3 |
| UNUSABLE_INDEX | ~97% là index tự động `SYS_AI_*`; chưa đọc subpartition; đếm theo partition | O3 |
| STALE_STATS | Chưa flush monitoring info; tính cả bảng khóa stats, GTT, partition rỗng | O4 |
| INVALID_OBJ | Lẫn object chỉ chờ compile | O1 + O2 |
| DIRECT_GRANT_USER | Đếm từng quyền; tính cả tài khoản dịch vụ; bỏ qua grant giữa các mart | S1 + S2 + S4 |
| INTERNAL_OBJ_GRANTED | Chỉ bắt tiền tố, bỏ sót `*_STG_TMP` | S3 |
| ANY_PRIV_HOLDER | Không duyệt cây role; ngoài phạm vi owner | Đưa ra khỏi bộ của owner |
| USER_PWD_EXPIRY | Báo động giả với schema owner khóa có chủ đích | P2 (chỉ tài khoản dịch vụ) |
| TS_USAGE_PCT | Chưa có TEMP / UNDO | P1 + P3 |
| MISSING_COMMENT | Chưa có view VW_; chưa đo comment cột | M1 + M2 |
| SCHEMA_SIZE | Đạt | C1 (+ C2 → C6) |
| Lịch chạy | 3 lần / ngày ghi đè; có thể trùng giờ ETL | Chạy sau ETL qua Airflow |
| Package | Một package, điều phối bằng CASE | Package lõi + package theo nhóm, gọi theo `PROC_NAME` |
