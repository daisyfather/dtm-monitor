/* =====================================================================
   OAS ANALYSIS : DS05_MON_DETAIL_ANALYSIS   (trang 3. Chi tiet vi pham)
   Kieu         : Direct Database Request, loc bang presentation variable
                  pv_check (mac dinh INVALID_OBJ), pv_schema (mac dinh %)
   Gioi han 5.000 dong: bang chi tiet co the len hang tram nghin dong.

   VIEWS:
     Title     : CHI TIẾT VI PHẠM / Object cụ thể đang vi phạm và hướng xử lý
     Narrative (HTML, Rows=1):
       <div style="font-size:13px;color:#495057;padding:4px 0 8px;line-height:1.7">
       <b>Ngày giám sát:</b> @1 &nbsp;|&nbsp; <b>Tiêu chí:</b> @2 &nbsp;|&nbsp;
       <b>Số vi phạm:</b> @9 <span style="color:#8a92a3">(hiển thị tối đa 5.000 dòng)</span><br>
       <b>Hướng xử lý:</b> @10
       </div>
     Table: an SNAPSHOT_DATE, CHECK_NAME, TOTAL_ROWS, ACTION_GUIDE
       SCHEMA_NAME Schema W110 | OBJECT_TYPE Loại object W120 | ISSUE_TEXT Vi phạm W450 Wrap
       DETAIL_MSG Ghi chú W200 Wrap | NUM_VALUE Giá trị W80 | EVENT_TIME_TXT Thời điểm W150
   Prompt: oas/prompts/DS05_MON_DETAIL_PROMPT.md
   ===================================================================== */
SELECT d.snapshot_date,
       d.check_name,
       d.schema_name,
       d.object_type,
       d.issue_text,
       d.detail_msg,
       d.num_value,
       d.event_time_txt,
       COUNT(*) OVER ()                                   AS total_rows,
       (SELECT MAX(l.action_guide)
        FROM   bi_dtm.vw_mon_latest l
        WHERE  l.check_code = d.check_code)               AS action_guide
FROM   bi_dtm.vw_oas_mon_detail d
WHERE  d.check_code  LIKE '@{pv_check}{INVALID_OBJ}'
AND    d.schema_name LIKE '@{pv_schema}{%}'
ORDER BY d.schema_name, d.object_type, d.issue_text
FETCH FIRST 5000 ROWS ONLY
