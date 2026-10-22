# DS05_MON_DETAIL_PROMPT

Dashboard prompt dùng chung cho trang **3. Chi tiết vi phạm** và **4. Xu hướng**.
Hai prompt đều là **Variable Prompt** gán presentation variable (analysis dùng Direct Database Request nên không lọc theo cột).

| Prompt | Biến | Kiểu | Giá trị | Mặc định | Chọn nhiều |
|---|---|---|---|---|---|
| Tiêu chí | `pv_check` | Choice List, Custom Values | mã tiêu chí (bên dưới) | `INVALID_OBJ` | Không |
| Schema | `pv_schema` | Choice List, Custom Values | `%` + danh sách schema | `%` | Không |

Dùng **mã ASCII** thay vì tên tiếng Việt vì giá trị được ghép thẳng vào SQL gửi xuống database.

**pv_check:** INVALID_OBJ, UNUSABLE_INDEX, STALE_STATS, CROSS_MART_DEP, DIRECT_GRANT_USER,
INTERNAL_OBJ_GRANTED, ANY_PRIV_HOLDER, MISSING_COMMENT, USER_PWD_EXPIRY, TS_USAGE_PCT, DDL_CHANGE_1D
(`SCHEMA_SIZE` không có chi tiết nên không đưa vào).

**pv_schema:** %, STG_DTM, COMMON_DTM, ENT_DTM, RETAIL_DTM, CNL_DTM, RISK_DTM, OPS_DTM, CAP_DTM,
FIN_DTM, TREAS_DTM, XLN_DTM, WSP_DTM, ML_DTM, DG_DTM, SND_DTM, BI_DTM, _ALL_

Bố cục: tick **New Column** ở prompt Schema để 2 ô nằm ngang; bật Apply / Reset.
Khi thêm tiêu chí hoặc schema mới phải cập nhật danh sách Custom Values ở đây.
