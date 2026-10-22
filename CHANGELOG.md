# Changelog

Ghi lại mọi thay đổi **định nghĩa metric**, cấu trúc bảng và package.
Mỗi mục ghi rõ thay đổi đó làm số liệu trên dashboard tăng / giảm thế nào.

## [Chưa phát hành]

### Repo
- Chuyển bản đang chạy (v1.2) vào `legacy/v1/` kèm README ngữ cảnh, script job scheduler, script chẩn đoán tiếng Việt.
- Thêm `docs/decisions.md` (nhật ký quyết định D01–D14).

### Đã phát hiện, sẽ sửa
- `CROSS_MART_DEP`: zone `ADMIN` (BI_DTM) đang bị tính là vi phạm khi mart gọi package của BI_DTM.
- `DDL_CHANGE_1D`: khoảng thời gian là `g_date - 1` đến `g_date + 1` (~33 giờ), đếm trùng giữa 2 lần chạy liên tiếp.
- `UNUSABLE_INDEX`: khoảng 97% là index tự động (`AUTO = YES`, tên `SYS_AI_*`); chưa đọc `DBA_IND_SUBPARTITIONS`.
- `STALE_STATS`: chưa flush `DBA_TAB_MODIFICATIONS`; đang tính cả bảng khóa stats, GTT, partition rỗng.
- `DIRECT_GRANT_USER`, `INTERNAL_OBJ_GRANTED`: đếm từng quyền thay vì cặp người nhận × object; chưa miễn tài khoản dịch vụ;
  `INTERNAL_OBJ_GRANTED` chỉ bắt tiền tố, bỏ sót hậu tố (`*_STG_TMP`).
- `ANY_PRIV_HOLDER`: không duyệt cây role; sẽ đưa ra khỏi bộ của owner.
- `USER_PWD_EXPIRY`: báo động giả với schema owner khóa có chủ đích; sẽ chỉ xét tài khoản dịch vụ.

Chi tiết và kế hoạch: `docs/metrics-catalog.md`.

## [1.2] - 2026-10-22
### Thay đổi
- Job `BI_DTM.JOB_MONITOR_DTM_DAILY` (DBMS_SCHEDULER) chạy 09:00 / 12:30 / 17:30, `triggered_by = SCHEDULER`.
- Package 1.2: `save_schema_counts` nhận tham số `p_zone`. `INTERNAL_OBJ_GRANTED` và `CROSS_MART_DEP`
  chỉ ghi kết quả cho schema zone `MART`; schema khác hiển thị trống thay vì `0 / OK`.
- `V005`: thêm 7 schema (`BI_DTM`, `COMMON_DTM`, `DG_DTM`, `ML_DTM`, `TREAS_DTM`, `WSP_DTM`, `XLN_DTM`)
  và zone `ADMIN`. Các số tổng trên dashboard tăng do phạm vi rộng hơn, không phải hệ thống xấu đi.
- `V004`: bảng thuật ngữ `MON_GLOSSARY` và view `VW_OAS_MON_GLOSSARY`.

## [1.1] - 2026-10-21
### Sửa lỗi
- PLS-00231: hàm private (`cut`, `elapsed_sec`) không được gọi trong câu SQL, gán vào biến trước.
- Tiếng Việt thành `?`: mọi chuỗi trong package và seed đổi sang `UNISTR` (`V003`).
- `V002`: view `VW_OAS_MON_DETAIL`, `VW_OAS_MON_RUN` cho OAS.

## [1.0] - 2026-10-21
### Khởi tạo
- `V001`: 6 bảng `MON_*`, 5 view `VW_MON_*`, 12 tiêu chí, role `BI_DTM_MON_READ`.
- Package `PKG_DTM_MONITOR`: `run_daily`, `run_check`, `purge_history`.
