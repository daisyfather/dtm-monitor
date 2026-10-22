/* =====================================================================
   BO SUNG 7 SCHEMA VAO DANH MUC GIAM SAT
   BI_DTM, COMMON_DTM, DG_DTM, ML_DTM, TREAS_DTM, WSP_DTM, XLN_DTM
   File chi chua ky tu ASCII (tieng Viet viet bang UNISTR).
   ===================================================================== */


/* ---------------------------------------------------------------------
   1. Them vung ADMIN cho BI_DTM
      BI_DTM la user master / orchestration, khong phai mart nghiep vu.
      Dat zone ADMIN de BI_DTM:
        - van duoc giam sat: dung luong, INVALID, UNUSABLE, stats,
          comment, han mat khau
        - KHONG bi cham 2 tieu chi chi danh cho MART:
          bang noi bo cap ra ngoai, phu thuoc cheo
   --------------------------------------------------------------------- */
ALTER TABLE bi_dtm.mon_schema_def DROP CONSTRAINT ck_mon_schema_def_zone;

ALTER TABLE bi_dtm.mon_schema_def ADD CONSTRAINT ck_mon_schema_def_zone
    CHECK (zone_type IN ('SOURCE','MART','SANDBOX','ADMIN'));


/* ---------------------------------------------------------------------
   2. Seed 7 schema
      BUSINESS_DOMAIN de "Chua xac dinh" cho 6 schema chua ro vai tro,
      cap nhat sau bang UPDATE.

      LUU Y COMMON_DTM:
        Neu COMMON_DTM la vung du lieu DUNG CHUNG cho nhieu mart
        (giong STG_DTM) thi doi zone_type thanh 'SOURCE' truoc khi chay.
        De 'MART' thi moi mart doc COMMON_DTM se bi tinh la phu thuoc cheo.
   --------------------------------------------------------------------- */
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('BI_DTM', 'ADMIN',
        TO_CHAR(UNISTR('Qu\1EA3n tr\1ECB: user master, orchestration, b\1EA3ng gi\00E1m s\00E1t MON_*')));

INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('COMMON_DTM', 'MART',
        TO_CHAR(UNISTR('Ch\01B0a x\00E1c \0111\1ECBnh - c\1EA7n b\1ED5 sung')));

INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('DG_DTM', 'MART',
        TO_CHAR(UNISTR('Ch\01B0a x\00E1c \0111\1ECBnh - c\1EA7n b\1ED5 sung')));

INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('ML_DTM', 'MART',
        TO_CHAR(UNISTR('Ch\01B0a x\00E1c \0111\1ECBnh - c\1EA7n b\1ED5 sung')));

INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('TREAS_DTM', 'MART',
        TO_CHAR(UNISTR('Ch\01B0a x\00E1c \0111\1ECBnh - c\1EA7n b\1ED5 sung')));

INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('WSP_DTM', 'MART',
        TO_CHAR(UNISTR('Ch\01B0a x\00E1c \0111\1ECBnh - c\1EA7n b\1ED5 sung')));

INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain)
VALUES ('XLN_DTM', 'MART',
        TO_CHAR(UNISTR('Ch\01B0a x\00E1c \0111\1ECBnh - c\1EA7n b\1ED5 sung')));

COMMIT;


/* ---------------------------------------------------------------------
   3. Kiem tra danh muc: mong doi 16 schema
   --------------------------------------------------------------------- */
SELECT zone_type, schema_name, business_domain
FROM   bi_dtm.mon_schema_def
ORDER BY DECODE(zone_type, 'SOURCE', 1, 'MART', 2, 'SANDBOX', 3, 'ADMIN', 4), schema_name;


/* ---------------------------------------------------------------------
   4. Chay lai job hom nay (ghi de toan bo du lieu ngay hien tai)
   --------------------------------------------------------------------- */
BEGIN
    bi_dtm.pkg_dtm_monitor.run_daily(p_triggered_by => 'MANUAL');
END;
/


/* ---------------------------------------------------------------------
   5. Kiem tra sau khi chay
   --------------------------------------------------------------------- */
-- 5.1 Lan chay moi nhat: mong doi SUCCESS, CHECKS_ERROR = 0
SELECT run_id, run_status, checks_total, checks_ok, checks_warn,
       checks_fail, checks_error, start_time_txt, end_time_txt
FROM   bi_dtm.vw_oas_mon_run
ORDER BY run_id DESC
FETCH FIRST 1 ROW ONLY;

-- 5.2 Moi schema moi deu co ket qua
SELECT schema_name, COUNT(*) AS so_tieu_chi
FROM   bi_dtm.mon_check_result
WHERE  snapshot_date = TRUNC(SYSDATE)
AND    schema_name IN ('BI_DTM','COMMON_DTM','DG_DTM','ML_DTM',
                       'TREAS_DTM','WSP_DTM','XLN_DTM')
GROUP BY schema_name
ORDER BY schema_name;


/* ---------------------------------------------------------------------
   6. Cap nhat vai tro nghiep vu sau khi xac nhan (vi du, chua chay)
      Tieng Viet phai viet bang UNISTR, hoac sua truc tiep tu cong cu
      da cau hinh NLS_LANG = AMERICAN_AMERICA.AL32UTF8.
   --------------------------------------------------------------------- */
-- UPDATE bi_dtm.mon_schema_def
-- SET    business_domain = 'Treasury', updated_ts = SYSTIMESTAMP
-- WHERE  schema_name = 'TREAS_DTM';
-- COMMIT;
