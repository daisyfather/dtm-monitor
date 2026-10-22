/* =====================================================================
   OAS ANALYSIS : DS00_MON_GLOSSARY_ANALYSIS   (trang 0. Huong dan)
   Kieu         : Direct Database Request
   Nguon        : BI_DTM.VW_OAS_MON_GLOSSARY

   VIEWS (Compound Layout tu tren xuong):
     1. Title       : HƯỚNG DẪN ĐỌC DASHBOARD / Đọc trang này trước khi xem các trang khác
     2. Static Text : xem oas/analyses/DS00_static_text.html (tick Contains HTML Markup)
     3. Table       : Sections = NHOM; an TERM_CODE, DISPLAY_ORDER
                      TERM_NAME  -> "Thuật ngữ"       W230  Data Format: Treat Text As HTML
                      DEFINITION -> "Ý nghĩa"         W400  Wrap
                      HOW_TO_READ-> "Cách đọc / xử lý" W400 Wrap
                      EXAMPLE    -> "Ví dụ"           W260  Wrap
                      Value Suppression = Repeat cho moi cot
                      Section NHOM (Format Values): Bold 13, chu #FFFFFF, nen #1F2430, padding 6/10
                      Format Headings: Bold, chu #343A40, nen #E9ECEF
                      Table Properties > Style: alternating rows #F8F9FA
   ===================================================================== */
SELECT g.group_order || '. ' || g.term_group  AS nhom,
       CASE g.term_code
            WHEN 'FAIL'        THEN '<span style="background:#F8D7DA;color:#842029;padding:2px 8px;font-weight:bold">'
            WHEN 'ERROR'       THEN '<span style="background:#E2D9F3;color:#4B2C83;padding:2px 8px;font-weight:bold">'
            WHEN 'WARN'        THEN '<span style="background:#FFF3CD;color:#664D03;padding:2px 8px;font-weight:bold">'
            WHEN 'OK'          THEN '<span style="background:#D1E7DD;color:#0F5132;padding:2px 8px;font-weight:bold">'
            WHEN 'INFO'        THEN '<span style="background:#E9ECEF;color:#495057;padding:2px 8px;font-weight:bold">'
            WHEN 'RUN_SUCCESS' THEN '<span style="background:#D1E7DD;color:#0F5132;padding:2px 8px;font-weight:bold">'
            WHEN 'RUN_PARTIAL' THEN '<span style="background:#E2D9F3;color:#4B2C83;padding:2px 8px;font-weight:bold">'
            WHEN 'RUN_FAILED'  THEN '<span style="background:#F8D7DA;color:#842029;padding:2px 8px;font-weight:bold">'
            ELSE                    '<span style="font-weight:bold;color:#1F2430">'
       END || g.term_name || '</span>'   AS term_name,
       g.definition,
       g.how_to_read,
       g.example,
       g.term_code,
       g.display_order
FROM   bi_dtm.vw_oas_mon_glossary g
ORDER BY g.group_order, g.display_order
