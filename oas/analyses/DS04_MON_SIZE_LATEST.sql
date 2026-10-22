/* =====================================================================
   OAS ANALYSIS : DS04_MON_SIZE_LATEST   (trang 5. Dung luong)
   Kieu         : Direct Database Request
   Grain        : 1 dong = 1 schema, ngay giam sat moi nhat
   Ly do 1 dong / schema (TABLE/INDEX/LOB thanh 3 cot): bieu do stacked tren
   DDR voi Vary Color By bi gop sai, chi giu lai dong TABLE.

   VIEWS:
     Title     : DUNG LƯỢNG LƯU TRỮ / Schema nào chiếm nhiều dung lượng, nặng ở bảng, index hay LOB
     Narrative (HTML, Rows=1):
       <div style="font-size:13px;color:#495057;padding:4px 0 8px">
       <b>Ngày giám sát:</b> @1 &nbsp;|&nbsp; <b>Tổng dung lượng các schema giám sát:</b> @13 TB
       </div>
     Graph Bar / Stacked Horizontal:
       Measures TABLE_GB, INDEX_GB, LOB_GB ; Group By SCHEMA_NAME ;
       Vary Color By = Measure Labels ; mau theo Style Formatting (vi tri)
       TABLE #4C78A8, INDEX #F58518, LOB #9D755D ; truc gia tri "GB"
     Table: SCHEMA_NAME Schema | TOTAL_GB Tổng (GB) | SHARE_PCT Tỷ trọng (%)
       TABLE_GB Bảng | INDEX_GB Index | LOB_GB LOB | INDEX_PCT Index / tổng (%)
       GROWTH_1D/7D/30D_GB Tăng 1/7/30 ngày (GB) - 1 chu so thap phan
       An: SNAPSHOT_DATE, OTHER_GB, SYSTEM_TOTAL_TB (2 chu so thap phan)
   ===================================================================== */
WITH d AS (
    SELECT snapshot_date,
           schema_name,
           SUM(CASE WHEN segment_group = 'TABLE' THEN size_mb END) AS t_mb,
           SUM(CASE WHEN segment_group = 'INDEX' THEN size_mb END) AS i_mb,
           SUM(CASE WHEN segment_group = 'LOB'   THEN size_mb END) AS l_mb,
           SUM(size_mb)                                            AS tmb
    FROM   bi_dtm.vw_mon_size
    WHERE  snapshot_date >= TRUNC(SYSDATE) - 40
    GROUP BY snapshot_date, schema_name
),
g AS (
    SELECT d.*,
           tmb - LAG(tmb, 1)  OVER (PARTITION BY schema_name ORDER BY snapshot_date) AS g1,
           tmb - LAG(tmb, 7)  OVER (PARTITION BY schema_name ORDER BY snapshot_date) AS g7,
           tmb - LAG(tmb, 30) OVER (PARTITION BY schema_name ORDER BY snapshot_date) AS g30
    FROM   d
)
SELECT snapshot_date,
       schema_name,
       ROUND(NVL(t_mb, 0) / 1024, 1)                                   AS table_gb,
       ROUND(NVL(i_mb, 0) / 1024, 1)                                   AS index_gb,
       ROUND(NVL(l_mb, 0) / 1024, 1)                                   AS lob_gb,
       ROUND((tmb - NVL(t_mb,0) - NVL(i_mb,0) - NVL(l_mb,0)) / 1024, 1) AS other_gb,
       ROUND(tmb / 1024, 1)                                            AS total_gb,
       ROUND(100 * tmb / SUM(tmb) OVER (), 1)                          AS share_pct,
       ROUND(100 * NVL(i_mb, 0) / NULLIF(tmb, 0), 1)                   AS index_pct,
       ROUND(g1  / 1024, 1)                                            AS growth_1d_gb,
       ROUND(g7  / 1024, 1)                                            AS growth_7d_gb,
       ROUND(g30 / 1024, 1)                                            AS growth_30d_gb,
       ROUND(SUM(tmb) OVER () / 1024 / 1024, 2)                        AS system_total_tb
FROM   g
WHERE  snapshot_date = (SELECT MAX(snapshot_date) FROM bi_dtm.vw_mon_size)
ORDER BY total_gb DESC
