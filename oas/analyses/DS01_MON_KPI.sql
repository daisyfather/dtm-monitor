/* =====================================================================
   OAS ANALYSIS : DS01_MON_KPI   (trang 1. Tong quan - phan dau trang)
   Kieu         : Direct Database Request, tra ve DUNG 1 DONG
   Ly do tach rieng: Performance Tile tren DDR khong chinh duoc aggregation
   rule, nen KPI lay tu 1 dong da tinh san.

   VIEWS:
     Title     : TỔNG QUAN GIÁM SÁT DATAMART / Kết quả kiểm tra kỹ thuật hằng ngày các schema DTM
     Narrative (HTML, Rows=1):
       <div style="font-size:13px;color:#495057;padding:4px 0 8px">
       <b>Ngày giám sát:</b> @1 &nbsp;&nbsp;|&nbsp;&nbsp;
       <b>Lần chạy gần nhất:</b> @8, kết thúc lúc @9 &nbsp;&nbsp;|&nbsp;&nbsp;
       <b>Số tiêu chí kiểm tra:</b> @7
       </div>
     5 Performance Tile, thu tu FAIL -> WARN -> ERROR -> OK -> INFO:
       FAIL_CNT  nen #F8D7DA chu #842029 "Tiêu chí vi phạm nghiêm trọng"
       WARN_CNT  nen #FFF3CD chu #664D03 "Tiêu chí cần theo dõi"
       ERROR_CNT nen #E2D9F3 chu #4B2C83 "Tiêu chí không đo được"
       OK_CNT    nen #D1E7DD chu #0F5132 "Tiêu chí đạt"
       INFO_CNT  nen #E9ECEF chu #495057 "Chỉ để theo dõi"
     SNAPSHOT_DATE: Data Format Custom dd/MM/yyyy
   ===================================================================== */
SELECT k.snapshot_date,
       k.fail_cnt,
       k.warn_cnt,
       k.error_cnt,
       k.ok_cnt,
       k.info_cnt,
       k.total_cnt,
       r.run_status,
       r.end_time_txt
FROM  (SELECT MAX(snapshot_date)                AS snapshot_date,
              COUNT(CASE WHEN w = 1 THEN 1 END) AS fail_cnt,
              COUNT(CASE WHEN w = 3 THEN 1 END) AS warn_cnt,
              COUNT(CASE WHEN w = 2 THEN 1 END) AS error_cnt,
              COUNT(CASE WHEN w = 4 THEN 1 END) AS ok_cnt,
              COUNT(CASE WHEN w = 5 THEN 1 END) AS info_cnt,
              COUNT(*)                          AS total_cnt
       FROM  (SELECT check_code,
                     MAX(snapshot_date) AS snapshot_date,
                     MIN(status_sort)   AS w
              FROM   bi_dtm.vw_mon_latest
              GROUP BY check_code)) k
CROSS JOIN
      (SELECT run_status, end_time_txt
       FROM   bi_dtm.vw_oas_mon_run
       ORDER BY run_id DESC
       FETCH FIRST 1 ROW ONLY) r
