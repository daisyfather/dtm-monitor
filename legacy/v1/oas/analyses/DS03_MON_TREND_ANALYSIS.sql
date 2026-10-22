/* =====================================================================
   OAS ANALYSIS : DS03_MON_TREND_ANALYSIS   (trang 4. Xu huong)
   Kieu         : Direct Database Request, loc bang presentation variable
                  pv_check, pv_schema (dung chung prompt DS05_MON_DETAIL_PROMPT)

   Them 2 chuoi gia "Ngưỡng WARN", "Ngưỡng FAIL" vao cot SCHEMA_NAME de
   bieu do tu ve 2 duong nguong.

   VIEWS:
     Title     : XU HƯỚNG THEO NGÀY / Vấn đề đang tích tụ hay đang được xử lý
     Narrative (HTML, Rows=1):
       <div style="font-size:13px;color:#495057;padding:4px 0 8px">
       <b>Tiêu chí:</b> @2 (@4) &nbsp;|&nbsp; <b>Từ ngày:</b> @8 &nbsp;|&nbsp; <b>Số ngày có dữ liệu:</b> @9
       &nbsp;<span style="color:#8a92a3">(cần tối thiểu 7 ngày để đọc xu hướng)</span>
       </div>
     Graph Line: Measures METRIC_VALUE ("Giá trị"), Horizontal Axis SNAPSHOT_DATE,
       Vary Color By SCHEMA_NAME; truc doc "Giá trị", truc ngang "Ngày giám sát"
       Conditional Formatting: SCHEMA_NAME = Ngưỡng FAIL -> #C62828 ;
                               SCHEMA_NAME = Ngưỡng WARN -> #F9A825
     SNAPSHOT_DATE, FROM_DATE: dd/MM/yyyy
   Thu tu 9 cot co dinh - Narrative dung @2 @4 @8 @9.
   ===================================================================== */
WITH t AS (
    SELECT r.snapshot_date,
           r.check_name,
           r.schema_name,
           CASE WHEN r.check_code = 'SCHEMA_SIZE' THEN 'GB' ELSE r.metric_unit END AS metric_unit,
           CASE WHEN r.check_code = 'SCHEMA_SIZE' THEN ROUND(r.metric_value / 1024)
                ELSE r.metric_value END                                     AS metric_value,
           r.warn_threshold,
           r.fail_threshold
    FROM   bi_dtm.vw_mon_result r
    WHERE  r.check_code  LIKE '@{pv_check}{INVALID_OBJ}'
    AND    r.schema_name LIKE '@{pv_schema}{%}'
    AND    r.check_status <> 'ERROR'
    AND    r.snapshot_date >= TRUNC(SYSDATE) - 90
),
s AS (
    SELECT snapshot_date, check_name, schema_name AS series, metric_unit,
           metric_value, warn_threshold, fail_threshold, 1 AS series_order
    FROM   t
    UNION ALL
    SELECT snapshot_date, MAX(check_name), TO_CHAR(UNISTR('Ng\01B0\1EE1ng WARN')), MAX(metric_unit),
           MAX(warn_threshold), MAX(warn_threshold), MAX(fail_threshold), 2
    FROM   t
    WHERE  warn_threshold IS NOT NULL
    GROUP BY snapshot_date
    UNION ALL
    SELECT snapshot_date, MAX(check_name), TO_CHAR(UNISTR('Ng\01B0\1EE1ng FAIL')), MAX(metric_unit),
           MAX(fail_threshold), MAX(warn_threshold), MAX(fail_threshold), 3
    FROM   t
    WHERE  fail_threshold IS NOT NULL
    GROUP BY snapshot_date
)
SELECT s.snapshot_date,
       s.check_name,
       s.series                                 AS schema_name,
       s.metric_unit,
       s.metric_value,
       s.warn_threshold,
       s.fail_threshold,
       MIN(s.snapshot_date) OVER ()             AS from_date,
       COUNT(DISTINCT s.snapshot_date) OVER ()  AS so_ngay
FROM   s
ORDER BY s.snapshot_date, s.series_order, s.series
