/* =====================================================================
   OAS ANALYSIS : DS06_MON_RUN_ANALYSIS   (trang 6. Nhat ky chay)
   Kieu         : Direct Database Request
   Grain        : 1 dong = 1 lan chay package

   VIEWS:
     Title     : NHẬT KÝ CHẠY JOB GIÁM SÁT / Số liệu trên dashboard có đầy đủ và đáng tin không
     Narrative (HTML, Rows=1):
       <div style="font-size:13px;color:#495057;padding:4px 0 8px">
       <b>Ngày giám sát gần nhất:</b> @15 &nbsp;|&nbsp; <b>Số ngày có dữ liệu:</b> @16
       &nbsp;|&nbsp; <b>Số lần chạy thành công:</b> @17 / @18
       </div>
     Table: an RUN_ID, LAST_DATE, SO_NGAY, SO_LAN_OK, SO_LAN
       Thu tu: Ngày giám sát, Bắt đầu, Kết thúc, Thời gian chạy (giây), Trạng thái,
               Số tiêu chí, FAIL, WARN, OK, ERROR, Người chạy, Tiêu chí lỗi, Lỗi package
       Value Suppression = Repeat cho cot chu ; so: 0 chu so thap phan
       Conditional Format RUN_STATUS: FAILED #F8D7DA/#842029 bold, PARTIAL #E2D9F3/#4B2C83 bold,
                                      RUNNING #FFF3CD/#664D03, SUCCESS #D1E7DD/#0F5132
       ERROR_CHECKS, RUN_ERROR_MSG: W300 Wrap
   Neu gap "Edge has duplicate layer": xoa han view Table (khong chi go khoi
   layout) roi tao lai, hoac tao analysis moi va Save As ghi de.
   ===================================================================== */
SELECT r.run_id,
       r.snapshot_date,
       r.start_time_txt,
       r.end_time_txt,
       r.elapsed_sec,
       r.run_status,
       r.checks_total,
       r.checks_fail,
       r.checks_warn,
       r.checks_ok,
       r.checks_error,
       r.triggered_by,
       r.error_checks,
       r.run_error_msg,
       MAX(r.snapshot_date) OVER ()                                       AS last_date,
       COUNT(DISTINCT r.snapshot_date) OVER ()                            AS so_ngay,
       SUM(CASE WHEN r.run_status = 'SUCCESS' THEN 1 ELSE 0 END) OVER ()  AS so_lan_ok,
       COUNT(*) OVER ()                                                   AS so_lan
FROM   bi_dtm.vw_oas_mon_run r
ORDER BY r.run_id DESC
