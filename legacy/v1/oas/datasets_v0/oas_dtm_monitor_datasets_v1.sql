/* =====================================================================
   OAS - DATASET GIÁM SÁT DTM
   Nguồn  : BI_DTM.VW_MON_* (chỉ đọc qua view, không đọc bảng)
   Dùng cho: OAS Data Visualization -> Create Dataset -> Connection Oracle
             -> Enter SQL, dán từng câu bên dưới thành 1 dataset riêng.

   Chuẩn bị:
   - User connection của OAS phải có role BI_DTM_MON_READ và role này là
     DEFAULT ROLE:
         GRANT bi_dtm_mon_read TO <oas_user>;
         ALTER USER <oas_user> DEFAULT ROLE ALL;
   - KHÔNG để dấu chấm phẩy cuối câu khi dán vào OAS.
   - Data Access của dataset: chọn "Live" (dữ liệu nhỏ) hoặc "Automatic
     Caching" + reload sau giờ job chạy xong.

   Danh sách dataset
   ---------------------------------------------------------------------
   DS01_MON_OVERVIEW   Tổng quan ngày gần nhất, 1 dòng / tiêu chí    -> KPI tile, bảng tổng quan
   DS02_MON_MATRIX     Ngày gần nhất, tiêu chí x schema              -> Heatmap / pivot màu
   DS03_MON_TREND      Lịch sử 90 ngày, tiêu chí x schema x ngày     -> Line chart xu hướng
   DS04_MON_SIZE       Dung lượng 180 ngày theo schema, kèm tăng trưởng -> Line / bar dung lượng
   DS05_MON_DETAIL     Chi tiết object vi phạm ngày gần nhất         -> Bảng drill-down
   DS06_MON_RUN        Nhật ký chạy 60 ngày + lỗi kiểm tra           -> Bảng sức khỏe job
   ===================================================================== */


/* =====================================================================
   DS01_MON_OVERVIEW - Tổng quan ngày gần nhất
   Grain: 1 dòng = 1 tiêu chí (gộp các schema, lấy trạng thái xấu nhất)
   ===================================================================== */
SELECT r.snapshot_date,
       r.check_group,
       r.check_code,
       r.check_name,
       r.metric_unit,
       r.display_order,
       MIN(r.status_sort)                                              AS worst_status_sort,
       CASE MIN(r.status_sort)
            WHEN 1 THEN 'FAIL'
            WHEN 2 THEN 'ERROR'
            WHEN 3 THEN 'WARN'
            WHEN 4 THEN 'OK'
            ELSE 'INFO'
       END                                                             AS worst_status,
       SUM(r.metric_value)                                             AS total_value,
       SUM(r.delta_value)                                              AS total_delta,
       COUNT(CASE WHEN r.check_status = 'FAIL'  THEN 1 END)            AS schema_fail,
       COUNT(CASE WHEN r.check_status = 'WARN'  THEN 1 END)            AS schema_warn,
       COUNT(CASE WHEN r.check_status = 'ERROR' THEN 1 END)            AS schema_error,
       COUNT(*)                                                        AS schema_checked,
       LISTAGG(CASE WHEN r.check_status IN ('FAIL','WARN') THEN r.schema_name END, ', ')
           WITHIN GROUP (ORDER BY r.status_sort, r.schema_name)         AS schema_issue_list,
       MAX(r.action_guide)                                             AS action_guide
FROM   bi_dtm.vw_mon_latest r
GROUP BY r.snapshot_date, r.check_group, r.check_code, r.check_name,
         r.metric_unit, r.display_order


/* =====================================================================
   DS02_MON_MATRIX - Ma trận tiêu chí x schema, ngày gần nhất
   Grain: 1 dòng = 1 tiêu chí / 1 schema
   Gợi ý: Pivot/Heatmap, hàng = CHECK_NAME, cột = SCHEMA_NAME,
          giá trị = METRIC_VALUE, màu theo STATUS_SORT
   ===================================================================== */
SELECT r.snapshot_date,
       r.check_group,
       r.check_code,
       r.check_name,
       r.display_order,
       r.schema_name,
       CASE r.schema_name WHEN '_ALL_' THEN TO_CHAR(UNISTR('To\00E0n h\1EC7 th\1ED1ng'))
                          ELSE r.business_domain END                   AS schema_desc,
       NVL(r.zone_type, 'DATABASE')                                    AS zone_type,
       r.metric_unit,
       r.metric_value,
       r.prev_value,
       r.delta_value,
       r.warn_threshold,
       r.fail_threshold,
       r.check_status,
       r.status_sort,
       r.error_msg
FROM   bi_dtm.vw_mon_latest r


/* =====================================================================
   DS03_MON_TREND - Xu hướng 90 ngày
   Grain: 1 dòng = 1 ngày / 1 tiêu chí / 1 schema
   Gợi ý: Line chart, trục X = SNAPSHOT_DATE, Y = METRIC_VALUE,
          màu = SCHEMA_NAME, filter CHECK_NAME (chọn 1 tiêu chí)
   Bỏ dòng ERROR vì METRIC_VALUE NULL làm đứt đường.
   ===================================================================== */
SELECT r.snapshot_date,
       TO_CHAR(r.snapshot_date, 'YYYY-MM')                             AS snapshot_month,
       r.check_group,
       r.check_code,
       r.check_name,
       r.display_order,
       r.schema_name,
       NVL(r.zone_type, 'DATABASE')                                    AS zone_type,
       r.metric_unit,
       r.metric_value,
       r.delta_value,
       r.warn_threshold,
       r.fail_threshold,
       r.check_status,
       r.status_sort
FROM   bi_dtm.vw_mon_result r
WHERE  r.snapshot_date >= TRUNC(SYSDATE) - 90
AND    r.check_status  <> 'ERROR'


/* =====================================================================
   DS04_MON_SIZE - Dung lượng 180 ngày theo schema
   Grain: 1 dòng = 1 ngày / 1 schema
   Tăng trưởng so với lần đo trước, 7 ngày và 30 ngày trước (theo lần đo).
   Gợi ý: Line SIZE_GB theo ngày, màu = SCHEMA_NAME;
          bảng xếp hạng GROWTH_30D_GB giảm dần.
   ===================================================================== */
WITH d AS (
    SELECT s.snapshot_date,
           s.schema_name,
           MAX(s.zone_type)                                            AS zone_type,
           MAX(s.business_domain)                                      AS business_domain,
           SUM(CASE WHEN s.segment_group = 'TABLE' THEN s.size_mb END) AS table_mb,
           SUM(CASE WHEN s.segment_group = 'INDEX' THEN s.size_mb END) AS index_mb,
           SUM(CASE WHEN s.segment_group = 'LOB'   THEN s.size_mb END) AS lob_mb,
           SUM(s.size_mb)                                              AS total_mb,
           SUM(s.segment_count)                                        AS segment_count
    FROM   bi_dtm.vw_mon_size s
    WHERE  s.snapshot_date >= TRUNC(SYSDATE) - 210
    GROUP BY s.snapshot_date, s.schema_name
), g AS (
SELECT snapshot_date,
       schema_name,
       zone_type,
       business_domain,
       ROUND(NVL(table_mb, 0) / 1024, 2)                               AS table_gb,
       ROUND(NVL(index_mb, 0) / 1024, 2)                               AS index_gb,
       ROUND(NVL(lob_mb,   0) / 1024, 2)                               AS lob_gb,
       ROUND(total_mb / 1024, 2)                                       AS size_gb,
       segment_count,
       ROUND((total_mb - LAG(total_mb, 1)  OVER (PARTITION BY schema_name ORDER BY snapshot_date)) / 1024, 2) AS growth_1d_gb,
       ROUND((total_mb - LAG(total_mb, 7)  OVER (PARTITION BY schema_name ORDER BY snapshot_date)) / 1024, 2) AS growth_7d_gb,
       ROUND((total_mb - LAG(total_mb, 30) OVER (PARTITION BY schema_name ORDER BY snapshot_date)) / 1024, 2) AS growth_30d_gb,
       CASE WHEN snapshot_date = MAX(snapshot_date) OVER () THEN 'Y' ELSE 'N' END AS is_latest
FROM   d
)
SELECT *
FROM   g
WHERE  snapshot_date >= TRUNC(SYSDATE) - 180
-- Lấy 210 ngày để LAG 30 có dữ liệu, rồi mới cắt còn 180 ngày
-- Nếu OAS báo lỗi với WITH, bọc toàn bộ câu trong SELECT * FROM (...)


/* =====================================================================
   DS05_MON_DETAIL - Chi tiết object vi phạm, ngày gần nhất
   Grain: 1 dòng = 1 object / grant / phụ thuộc vi phạm
   Gợi ý: Table, filter CHECK_NAME + SCHEMA_NAME;
          dùng làm đích drill (Data Action) từ DS02.
   ===================================================================== */
SELECT d.snapshot_date,
       d.check_group,
       d.check_code,
       d.check_name,
       d.schema_name,
       d.business_domain,
       d.object_type,
       d.object_name,
       d.sub_object_name,
       d.grantee,
       d.privilege_name,
       d.ref_schema,
       d.ref_object_name,
       d.ref_object_type,
       d.num_value,
       d.event_time,
       d.detail_msg,
       CASE
           WHEN d.ref_schema IS NOT NULL
                THEN d.schema_name || '.' || d.object_name || ' -> ' || d.ref_schema || '.' || d.ref_object_name
           WHEN d.grantee IS NOT NULL
                THEN d.privilege_name || ' ON ' || d.schema_name || '.' || d.object_name || ' TO ' || d.grantee
           WHEN d.sub_object_name IS NOT NULL
                THEN d.schema_name || '.' || d.object_name || ' (' || d.sub_object_name || ')'
           WHEN d.object_name IS NOT NULL
                THEN d.schema_name || '.' || d.object_name
           ELSE d.grantee
       END                                                             AS issue_text
FROM   bi_dtm.vw_mon_detail d
WHERE  d.snapshot_date = (SELECT MAX(x.snapshot_date) FROM bi_dtm.vw_mon_detail x)


/* =====================================================================
   DS06_MON_RUN - Nhật ký chạy 60 ngày
   Grain: 1 dòng = 1 lần chạy
   ERROR_CHECKS: các tiêu chí bị lỗi trong lần chạy đó (lỗi câu kiểm tra,
   không phải vi phạm dữ liệu).
   Gợi ý: Table, tô màu RUN_STATUS; KPI "ngày gần nhất chạy lúc mấy giờ".
   ===================================================================== */
SELECT g.run_id,
       g.snapshot_date,
       g.start_ts,
       g.end_ts,
       g.elapsed_sec,
       g.run_status,
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
       g.triggered_by,
       g.error_msg,
       (SELECT LISTAGG(e.check_code || ': ' || SUBSTR(e.error_msg, 1, 200), CHR(10))
                   WITHIN GROUP (ORDER BY e.check_code)
        FROM   bi_dtm.vw_mon_result e
        WHERE  e.run_id = g.run_id
        AND    e.check_status = 'ERROR')                               AS error_checks
FROM   bi_dtm.vw_mon_run g
WHERE  g.snapshot_date >= TRUNC(SYSDATE) - 60
