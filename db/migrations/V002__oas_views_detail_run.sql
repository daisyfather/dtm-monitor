/* =====================================================================
   VIEW CHO OAS - BẢN 2 (thay DS05, DS06)
   Mục đích: dataset OAS chỉ còn "SELECT * FROM view", không còn biểu
   thức, subquery hay LISTAGG trong câu SQL của dataset.

   Thay đổi so với DS05/DS06 cũ:
   - Mỗi view chỉ giữ 1 cột DATE là SNAPSHOT_DATE. Các cột thời gian khác
     (EVENT_TIME, START_TS, END_TS) chuyển thành chuỗi để OAS không tự
     sinh cấp thời gian (năm/quý/tháng) cho từng cột.
   - Mọi cột chuỗi được CAST về độ dài cố định.
   - LISTAGG dùng ON OVERFLOW TRUNCATE, không lỗi ORA-01489 khi dài.

   Chạy bằng công cụ đã cấu hình UTF-8 (xem hướng dẫn trong chat).
   ===================================================================== */


/* =====================================================================
   VW_OAS_MON_DETAIL - Chi tiết object vi phạm, ngày gần nhất
   Grain: 1 dòng = 1 object / grant / phụ thuộc vi phạm
   ===================================================================== */
CREATE OR REPLACE VIEW bi_dtm.vw_oas_mon_detail AS
SELECT d.snapshot_date,
       CAST(c.check_group AS VARCHAR2(30))                             AS check_group,
       CAST(d.check_code  AS VARCHAR2(50))                             AS check_code,
       CAST(c.check_name  AS VARCHAR2(200 CHAR))                       AS check_name,
       c.display_order,
       CAST(d.schema_name AS VARCHAR2(128))                            AS schema_name,
       CAST(CASE d.schema_name
                WHEN '_ALL_' THEN TO_CHAR(UNISTR('To\00E0n h\1EC7 th\1ED1ng'))
                ELSE s.business_domain
            END AS VARCHAR2(200 CHAR))                                 AS schema_desc,
       CAST(d.object_type      AS VARCHAR2(30))                        AS object_type,
       CAST(d.object_name      AS VARCHAR2(128))                       AS object_name,
       CAST(d.sub_object_name  AS VARCHAR2(128))                       AS sub_object_name,
       CAST(d.grantee          AS VARCHAR2(128))                       AS grantee,
       CAST(d.privilege_name   AS VARCHAR2(100))                       AS privilege_name,
       CAST(d.ref_schema       AS VARCHAR2(128))                       AS ref_schema,
       CAST(d.ref_object_name  AS VARCHAR2(128))                       AS ref_object_name,
       CAST(d.ref_object_type  AS VARCHAR2(30))                        AS ref_object_type,
       d.num_value,
       CAST(TO_CHAR(d.event_time, 'YYYY-MM-DD HH24:MI:SS') AS VARCHAR2(19)) AS event_time_txt,
       CAST(d.detail_msg AS VARCHAR2(1000 CHAR))                       AS detail_msg,
       CAST(SUBSTR(
           CASE
               WHEN d.ref_schema IS NOT NULL
                    THEN d.schema_name || '.' || d.object_name || ' -> ' || d.ref_schema || '.' || d.ref_object_name
               WHEN d.grantee IS NOT NULL AND d.object_name IS NOT NULL
                    THEN d.privilege_name || ' ON ' || d.schema_name || '.' || d.object_name || ' TO ' || d.grantee
               WHEN d.grantee IS NOT NULL
                    THEN d.grantee || ': ' || d.privilege_name
               WHEN d.sub_object_name IS NOT NULL
                    THEN d.schema_name || '.' || d.object_name || ' (' || d.sub_object_name || ')'
               ELSE d.schema_name || '.' || d.object_name
           END, 1, 1000) AS VARCHAR2(1000 CHAR))                       AS issue_text,
       d.run_id
FROM   bi_dtm.mon_check_detail d
JOIN   bi_dtm.mon_check_def    c ON c.check_code  = d.check_code
LEFT JOIN bi_dtm.mon_schema_def s ON s.schema_name = d.schema_name
WHERE  d.snapshot_date = (SELECT MAX(x.snapshot_date) FROM bi_dtm.mon_check_detail x);

-- (comment cua view duoc ghi trong fix_vietnamese_final.sql)


/* =====================================================================
   VW_OAS_MON_RUN - Nhật ký chạy 60 ngày
   Grain: 1 dòng = 1 lần chạy
   ===================================================================== */
CREATE OR REPLACE VIEW bi_dtm.vw_oas_mon_run AS
WITH err AS (
    SELECT r.run_id,
           LISTAGG(r.check_code || ': ' || SUBSTR(r.error_msg, 1, 200), ' | '
                   ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
               WITHIN GROUP (ORDER BY r.check_code)                    AS error_checks
    FROM   bi_dtm.mon_check_result r
    WHERE  r.check_status = 'ERROR'
    GROUP BY r.run_id
)
SELECT g.run_id,
       g.snapshot_date,
       CAST(TO_CHAR(g.start_ts, 'YYYY-MM-DD HH24:MI:SS') AS VARCHAR2(19)) AS start_time_txt,
       CAST(TO_CHAR(g.end_ts,   'YYYY-MM-DD HH24:MI:SS') AS VARCHAR2(19)) AS end_time_txt,
       ROUND((CAST(g.end_ts AS DATE) - CAST(g.start_ts AS DATE)) * 86400) AS elapsed_sec,
       CAST(g.run_status AS VARCHAR2(20))                              AS run_status,
       CASE g.run_status
            WHEN 'FAILED'  THEN 1
            WHEN 'PARTIAL' THEN 2
            WHEN 'RUNNING' THEN 3
            ELSE 4
       END                                                             AS run_status_sort,
       g.checks_total,
       g.checks_ok,
       g.checks_warn,
       g.checks_fail,
       g.checks_error,
       CAST(g.triggered_by AS VARCHAR2(30))                            AS triggered_by,
       CAST(SUBSTR(g.error_msg, 1, 1000) AS VARCHAR2(1000 CHAR))       AS run_error_msg,
       CAST(SUBSTR(e.error_checks, 1, 2000) AS VARCHAR2(2000 CHAR))    AS error_checks
FROM   bi_dtm.mon_run_log g
LEFT JOIN err e ON e.run_id = g.run_id
WHERE  g.snapshot_date >= TRUNC(SYSDATE) - 60;

-- (comment cua view duoc ghi trong fix_vietnamese_final.sql)


/* =====================================================================
   QUYỀN
   ===================================================================== */
GRANT SELECT ON bi_dtm.vw_oas_mon_detail TO bi_dtm_mon_read;
GRANT SELECT ON bi_dtm.vw_oas_mon_run    TO bi_dtm_mon_read;


/* =====================================================================
   KIỂM TRA
   ===================================================================== */
-- SELECT * FROM bi_dtm.vw_oas_mon_detail WHERE ROWNUM <= 20;
-- SELECT * FROM bi_dtm.vw_oas_mon_run ORDER BY run_id DESC;

-- Dataset OAS mới (dán vào Enter SQL, không có dấu chấm phẩy):
--   DS05: SELECT * FROM bi_dtm.vw_oas_mon_detail
--   DS06: SELECT * FROM bi_dtm.vw_oas_mon_run
