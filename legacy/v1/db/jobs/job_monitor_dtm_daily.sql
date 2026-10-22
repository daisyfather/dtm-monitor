/* =====================================================================
   DBMS_SCHEDULER job chay PKG_DTM_MONITOR (v1)
   Tao ngay 2026-10-22, chay bang user BI_DTM (can quyen CREATE JOB).

   Lich: 09:00, 12:30, 17:30 gio Viet Nam moi ngay.
   Luu y: run_daily ghi de du lieu cua ngay -> dashboard giu ket qua cua
   LAN CHAY CUOI trong ngay (17:30). Lan chay giua ngay co the trung luc
   ETL dang chay.

   KHI CHUYEN SANG AIRFLOW: tat job nay truoc de tranh chay trung
       BEGIN DBMS_SCHEDULER.DISABLE('BI_DTM.JOB_MONITOR_DTM_DAILY'); END;

   Neu job tren database duoc tao khac file nay (vd triggered_by 'SCHEDULE'),
   cap nhat lai file cho khop thuc te.
   ===================================================================== */
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'BI_DTM.JOB_MONITOR_DTM_DAILY',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN bi_dtm.pkg_dtm_monitor.run_daily(p_triggered_by => ''SCHEDULER''); END;',
        start_date      => SYSTIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh',
        repeat_interval => 'FREQ=DAILY;BYTIME=090000,123000,173000',
        enabled         => FALSE,
        auto_drop       => FALSE,
        comments        => 'DTM monitor v1.2. Tat job nay khi chuyen sang Airflow.'
    );

    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name      => 'BI_DTM.JOB_MONITOR_DTM_DAILY',
        attribute => 'max_run_duration',
        value     => INTERVAL '30' MINUTE);

    DBMS_SCHEDULER.ENABLE('BI_DTM.JOB_MONITOR_DTM_DAILY');
END;
/

-- Kiem tra
SELECT job_name, enabled, state, next_run_date, repeat_interval, run_count, failure_count
FROM   user_scheduler_jobs
WHERE  job_name = 'JOB_MONITOR_DTM_DAILY';

SELECT log_date, status, run_duration, error#, additional_info
FROM   user_scheduler_job_run_details
WHERE  job_name = 'JOB_MONITOR_DTM_DAILY'
ORDER BY log_date DESC;
