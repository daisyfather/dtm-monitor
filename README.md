# dtm-monitor

Bộ giám sát hằng ngày cho các schema datamart (`*_DTM`) trên Oracle, kèm dashboard OAS.

Góc nhìn của bộ giám sát là **owner schema / Data Engineer**, không phải DBA:
dữ liệu có về đúng hạn không, mart có giữ đúng ranh giới kiến trúc không, object có hỏng không,
ai đang dùng dữ liệu, dữ liệu chiếm bao nhiêu và tăng nhanh cỡ nào. Các vấn đề nền tảng
(tablespace, tài khoản dịch vụ) chỉ được theo dõi ở mức cảnh báo sớm để báo DBA.

Danh mục metric và lý do chọn: [`docs/metrics-catalog.md`](docs/metrics-catalog.md).

## Kiến trúc

```
Dictionary Oracle (DBA_*)                 BI_DTM.MON_*                    OAS
  DBA_OBJECTS, DBA_SEGMENTS,   ──►  PKG_DTM_MONITOR.run_daily  ──►  VW_MON_* / VW_OAS_MON_*  ──►  Dashboard
  DBA_TAB_PRIVS, ...                (chạy 1 lần/ngày, sau ETL)       (OAS chỉ đọc view)          DATAMART MONITOR DAILY
```

| Bảng | Grain | Vai trò |
|---|---|---|
| `MON_SCHEMA_DEF` | 1 schema | Danh mục schema được giám sát, zone `SOURCE` / `MART` / `SANDBOX` / `ADMIN` |
| `MON_CHECK_DEF` | 1 tiêu chí | Danh mục tiêu chí, ngưỡng WARN / FAIL, hướng xử lý |
| `MON_RUN_LOG` | 1 lần chạy | Nhật ký chạy package |
| `MON_CHECK_RESULT` | ngày × tiêu chí × schema | Kết quả, nguồn chính cho dashboard |
| `MON_CHECK_DETAIL` | ngày × tiêu chí × object | Danh sách vi phạm để drill-down |
| `MON_SCHEMA_SIZE_DAILY` | ngày × schema × tablespace × loại segment | Dung lượng |
| `MON_GLOSSARY` | 1 thuật ngữ | Trang hướng dẫn của dashboard |

Trạng thái một tiêu chí: `OK` / `WARN` / `FAIL` / `INFO` / `ERROR`.
`ERROR` là lỗi của chính câu kiểm tra (thiếu quyền, lỗi SQL), **không phải** dữ liệu có vấn đề.
Một tiêu chí lỗi không làm dừng các tiêu chí khác; lần chạy đó ghi `PARTIAL`.

## Phiên bản

| Phiên bản | Trạng thái | Vị trí |
|---|---|---|
| **v1.2** | **Đang chạy** trên production (job scheduler 09:00 / 12:30 / 17:30) | [`legacy/v1/`](legacy/v1/README.md) — nguyên trạng, ngữ cảnh, bài học, giới hạn |
| v2 | Đang xây dựng theo [`docs/metrics-catalog.md`](docs/metrics-catalog.md) | thư mục gốc (`db/`, `oas/`) |

Đọc trước: [`legacy/v1/README.md`](legacy/v1/README.md) để hiểu bản đang chạy, và
[`docs/decisions.md`](docs/decisions.md) để hiểu vì sao hệ thống được dựng như vậy.

## Cấu trúc repo

```
legacy/v1/              Bản đang chạy: db (migrations, package, job), oas (analyses, prompts, portal)
db/                     v2 (đang xây)
oas/                    v2 (đang xây)
tools/                  unistr_conv.py, check_ascii.py
docs/metrics-catalog.md Danh mục metric v2, nguyên tắc chọn, lộ trình
docs/decisions.md       Nhật ký quyết định
```

## Deploy v1 (tham khảo)

Chạy bằng user `BI_DTM`: `legacy/v1/db/migrations/V001` → `V005`, rồi `legacy/v1/db/packages/pkg_dtm_monitor.sql`,
rồi `legacy/v1/db/jobs/job_monitor_dtm_daily.sql`. Kiểm tra `user_errors` phải 0 dòng.

Quyền dictionary phải cấp **trực tiếp** cho `BI_DTM` (package definer rights không dùng quyền nhận qua role).

## Quy tắc bắt buộc

**1. Không có tiếng Việt có dấu trong phần code SQL.** Oracle client của team không dùng UTF-8,
chuỗi tiếng Việt bị đổi thành `?` khi gửi xuống database. Viết bằng `TO_CHAR(UNISTR('...'))`:

```bash
python3 tools/unistr_conv.py input.sql output.sql   # tự đổi literal tiếng Việt sang UNISTR
python3 tools/check_ascii.py                        # chạy trước mỗi commit
```

Comment (`--`, `/* */`) được phép có tiếng Việt. `COMMENT ON` không nhận hàm, phải ghi qua
`EXECUTE IMMEDIATE` (xem `legacy/v1/db/migrations/V003`). Tên hiển thị trên OAS gõ trực tiếp trong trình duyệt thì không bị lỗi.

**2. OAS chỉ đọc qua view**, không đọc thẳng bảng `MON_*`. Quyền đọc qua role `BI_DTM_MON_READ`.

**3. Mọi thay đổi định nghĩa metric ghi vào `CHANGELOG.md`**, để số liệu đổi do định nghĩa
không bị hiểu nhầm là hệ thống tốt lên hay xấu đi.

## Dashboard OAS

7 trang: 0. Hướng dẫn · 1. Tổng quan · 2. Ma trận · 3. Chi tiết vi phạm · 4. Xu hướng · 5. Dung lượng · 6. Nhật ký chạy.
Mọi analysis dùng **Direct Database Request**; SQL và cách định dạng view của bản đang chạy nằm trong `legacy/v1/oas/analyses/`.
Một số giới hạn của OAS đã gặp và cách xử lý được ghi ngay trong comment đầu mỗi file.
