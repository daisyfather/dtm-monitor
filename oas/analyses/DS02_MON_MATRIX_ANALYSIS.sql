/* =====================================================================
   OAS ANALYSIS : DS02_MON_MATRIX_ANALYSIS   (trang 2. Ma tran)
   Kieu         : Direct Database Request
   Grain        : 1 dong = 1 tieu chi, 1 cot = 1 schema

   Ky thuat: mau cua o duoc tinh SAN trong SQL (HTML), KHONG dung Pivot +
   Conditional Format theo measure khac (gay loi Assertion failure
   FormatManagerExpressionBuilder tren DDR).

   VIEWS:
     Title     : MA TRẬN TIÊU CHÍ × SCHEMA / Vấn đề đang nằm ở schema nào
     Narrative (HTML, Rows=1): xem DS02_narrative.html  (@1 = SNAPSHOT_DATE)
     Table (KHONG dung Pivot):
       An: SNAPSHOT_DATE, CHECK_GROUP, CHECK_CODE, DISPLAY_ORDER
       CHECK_NAME -> "Tiêu chí" W260 Wrap ; METRIC_UNIT -> "Đơn vị"
       17 cot schema: Data Format > Treat Text As = HTML ; Width ~80
       ALL_DB -> "Toàn hệ thống"

   LUU Y BAO TRI: danh sach schema ghi cung trong PIVOT. Them schema vao
   MON_SCHEMA_DEF thi phai them 1 dong o day + bat HTML cho cot moi.
   ===================================================================== */
WITH c AS (
    SELECT r.snapshot_date,
           r.check_group,
           r.check_code,
           r.check_name,
           r.display_order,
           CASE WHEN r.check_code = 'SCHEMA_SIZE' THEN 'GB' ELSE r.metric_unit END AS metric_unit,
           r.schema_name,
           '<div style="padding:4px 8px;text-align:right;white-space:nowrap;'
           || CASE r.status_sort
                  WHEN 1 THEN 'background:#F8D7DA;color:#842029;font-weight:bold'
                  WHEN 2 THEN 'background:#E2D9F3;color:#4B2C83;font-weight:bold'
                  WHEN 3 THEN 'background:#FFF3CD;color:#664D03'
                  WHEN 4 THEN 'background:#D1E7DD;color:#0F5132'
                  ELSE        'background:#E9ECEF;color:#495057'
              END
           || '">'
           || CASE WHEN r.check_status = 'ERROR' THEN 'ERROR'
                   ELSE TO_CHAR(CASE WHEN r.check_code = 'SCHEMA_SIZE'
                                     THEN ROUND(r.metric_value / 1024)
                                     ELSE r.metric_value END,
                                'FM999G999G999G990')
              END
           || '</div>' AS cell
    FROM   bi_dtm.vw_mon_latest r
)
SELECT *
FROM   c
PIVOT (MAX(cell) FOR schema_name IN (
          'STG_DTM'    AS stg_dtm,
          'COMMON_DTM' AS common_dtm,
          'ENT_DTM'    AS ent_dtm,
          'RETAIL_DTM' AS retail_dtm,
          'CNL_DTM'    AS cnl_dtm,
          'RISK_DTM'   AS risk_dtm,
          'OPS_DTM'    AS ops_dtm,
          'CAP_DTM'    AS cap_dtm,
          'FIN_DTM'    AS fin_dtm,
          'TREAS_DTM'  AS treas_dtm,
          'XLN_DTM'    AS xln_dtm,
          'WSP_DTM'    AS wsp_dtm,
          'ML_DTM'     AS ml_dtm,
          'DG_DTM'     AS dg_dtm,
          'SND_DTM'    AS snd_dtm,
          'BI_DTM'     AS bi_dtm,
          '_ALL_'      AS all_db))
ORDER BY display_order
