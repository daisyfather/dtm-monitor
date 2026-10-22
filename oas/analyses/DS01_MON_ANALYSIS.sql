/* =====================================================================
   OAS ANALYSIS : DS01_MON_ANALYSIS   (trang 1. Tong quan - bang chinh)
   Kieu         : Direct Database Request
   Grain        : 1 dong = 1 tieu chi (gop moi schema, lay trang thai xau nhat)

   VIEWS:
     Table:
       An: SNAPSHOT_DATE, CHECK_CODE, DISPLAY_ORDER, WORST_STATUS_SORT,
           SCHEMA_CHECKED, IS_FAIL, IS_ERROR, IS_WARN, IS_OK, IS_INFO
       Column Heading (KHONG phai Folder Heading):
         CHECK_GROUP Nhóm | CHECK_NAME Tiêu chí | WORST_STATUS Trạng thái
         TOTAL_VALUE Giá trị | METRIC_UNIT Đơn vị | TOTAL_DELTA Thay đổi
         SCHEMA_FAIL/WARN/ERROR Số schema FAIL/WARN/ERROR
         SCHEMA_ISSUE_LIST Schema có vấn đề | ACTION_GUIDE Hướng xử lý
       Conditional Format tren WORST_STATUS (dieu kien tren CHINH cot nay):
         FAIL  #F8D7DA / #842029 bold    ERROR #E2D9F3 / #4B2C83 bold
         WARN  #FFF3CD / #664D03         OK    #D1E7DD / #0F5132
         INFO  #E9ECEF / #495057
       Width + Wrap: CHECK_NAME 180, SCHEMA_ISSUE_LIST 260, ACTION_GUIDE 320
   Thu tu dong: do ORDER BY trong SQL (khong dat sort trong OAS).
   ===================================================================== */
SELECT r.snapshot_date,
       r.check_group,
       r.check_code,
       r.check_name,
       CASE WHEN r.check_code = 'SCHEMA_SIZE' THEN 'GB' ELSE r.metric_unit END AS metric_unit,
       r.display_order,
       MIN(r.status_sort)                                              AS worst_status_sort,
       CASE MIN(r.status_sort)
            WHEN 1 THEN 'FAIL'
            WHEN 2 THEN 'ERROR'
            WHEN 3 THEN 'WARN'
            WHEN 4 THEN 'OK'
            ELSE 'INFO'
       END                                                             AS worst_status,
       CASE
            WHEN r.metric_unit = 'PCT'        THEN MAX(r.metric_value)
            WHEN r.check_code = 'SCHEMA_SIZE' THEN ROUND(SUM(r.metric_value) / 1024)
            ELSE SUM(r.metric_value)
       END                                                             AS total_value,
       CASE
            WHEN r.metric_unit = 'PCT'        THEN MAX(r.delta_value)
            WHEN r.check_code = 'SCHEMA_SIZE' THEN ROUND(SUM(r.delta_value) / 1024, 1)
            ELSE SUM(r.delta_value)
       END                                                             AS total_delta,
       COUNT(CASE WHEN r.check_status = 'FAIL'  THEN 1 END)            AS schema_fail,
       COUNT(CASE WHEN r.check_status = 'WARN'  THEN 1 END)            AS schema_warn,
       COUNT(CASE WHEN r.check_status = 'ERROR' THEN 1 END)            AS schema_error,
       COUNT(*)                                                        AS schema_checked,
       LISTAGG(CASE WHEN r.check_status IN ('FAIL','WARN') THEN r.schema_name END, ', '
               ON OVERFLOW TRUNCATE '...' WITHOUT COUNT)
           WITHIN GROUP (ORDER BY r.status_sort, r.schema_name)         AS schema_issue_list,
       MAX(r.action_guide)                                             AS action_guide,
       CASE WHEN MIN(r.status_sort) = 1 THEN 1 ELSE 0 END              AS is_fail,
       CASE WHEN MIN(r.status_sort) = 2 THEN 1 ELSE 0 END              AS is_error,
       CASE WHEN MIN(r.status_sort) = 3 THEN 1 ELSE 0 END              AS is_warn,
       CASE WHEN MIN(r.status_sort) = 4 THEN 1 ELSE 0 END              AS is_ok,
       CASE WHEN MIN(r.status_sort) = 5 THEN 1 ELSE 0 END              AS is_info
FROM   bi_dtm.vw_mon_latest r
GROUP BY r.snapshot_date, r.check_group, r.check_code, r.check_name,
         r.metric_unit, r.display_order
ORDER BY worst_status_sort, r.display_order
