/* =====================================================================
   SUA LOI TIENG VIET - BAN DUT DIEM (khong phu thuoc NLS_LANG cua client)
   Toan bo chuoi tieng Viet viet duoi dang UNISTR('\XXXX') nen file chi
   chua ky tu ASCII. Chay bang Toad / SQL Developer / sqlplus deu dung.

   Thu tu chay:
     1. pkg_dtm_monitor.sql      (chuoi trong package da doi UNISTR)
     2. oas_views_v2.sql         (tao 2 view cho OAS, da doi UNISTR)
     3. File nay, phan 1 va 2    (ghi lai danh muc + comment bang/view)
     4. BEGIN bi_dtm.pkg_dtm_monitor.run_daily(p_triggered_by => 'MANUAL'); END;
     5. Phan 3 KIEM TRA cuoi file nay
   ===================================================================== */


/* =====================================================================
   1. GHI LAI DU LIEU DANH MUC
   ===================================================================== */
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('Ph\00E1i sinh T-1 c\1EE7a SB_DWH, ngu\1ED3n conformed dimension')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'STG_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Enterprise', updated_ts = SYSTIMESTAMP WHERE schema_name = 'ENT_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('Kh\00E1ch h\00E0ng c\00E1 nh\00E2n')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'RETAIL_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('Ph\00E1p ch\1EBF, tu\00E2n th\1EE7')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'CNL_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('R\1EE7i ro')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'RISK_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('V\1EADn h\00E0nh')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'OPS_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('Ph\00EA duy\1EC7t t\00EDn d\1EE5ng')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'CAP_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = TO_CHAR(UNISTR('T\00E0i ch\00EDnh, k\1EBF to\00E1n')), updated_ts = SYSTIMESTAMP WHERE schema_name = 'FIN_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Sandbox', updated_ts = SYSTIMESTAMP WHERE schema_name = 'SND_DTM';
UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('Dung l\01B0\1EE3ng schema')),
       description  = TO_CHAR(UNISTR('T\1ED5ng dung l\01B0\1EE3ng segment c\1EE7a schema, chi ti\1EBFt \1EDF MON_SCHEMA_SIZE_DAILY')),
       action_guide = TO_CHAR(UNISTR('Theo d\00F5i t\1ED1c \0111\1ED9 t\0103ng; t\0103ng \0111\1ED9t bi\1EBFn th\00EC ki\1EC3m tra retention v\00E0 load tr\00F9ng'))
WHERE  check_code = 'SCHEMA_SIZE';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('T\1EF7 l\1EC7 s\1EED d\1EE5ng tablespace')),
       description  = TO_CHAR(UNISTR('T\1EF7 l\1EC7 % \0111\00E3 d\00F9ng c\1EE7a tablespace ch\1EE9a d\1EEF li\1EC7u c\00E1c DTM (SCHEMA_NAME = _ALL_)')),
       action_guide = TO_CHAR(UNISTR('B\00E1o DBA th\00EAm datafile ho\1EB7c d\1ECDn partition c\0169'))
WHERE  check_code = 'TS_USAGE_PCT';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Object INVALID',
       description  = TO_CHAR(UNISTR('S\1ED1 object c\00F3 STATUS = INVALID')),
       action_guide = TO_CHAR(UNISTR('Recompile; n\1EBFu v\1EABn l\1ED7i th\00EC ki\1EC3m tra thay \0111\1ED5i DDL g\1EA7n nh\1EA5t c\1EE7a object \0111\01B0\1EE3c tham chi\1EBFu'))
WHERE  check_code = 'INVALID_OBJ';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Index / partition index UNUSABLE',
       description  = TO_CHAR(UNISTR('S\1ED1 index ho\1EB7c partition index \1EDF tr\1EA1ng th\00E1i UNUSABLE')),
       action_guide = TO_CHAR(UNISTR('Rebuild index; ki\1EC3m tra job c\00F3 truncate/exchange partition m\00E0 kh\00F4ng UPDATE INDEXES'))
WHERE  check_code = 'UNUSABLE_INDEX';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('B\1EA3ng / partition c\00F3 stats c\0169 ho\1EB7c ch\01B0a c\00F3')),
       description  = TO_CHAR(UNISTR('S\1ED1 b\1EA3ng/partition c\00F3 STALE_STATS = YES ho\1EB7c LAST_ANALYZED IS NULL')),
       action_guide = TO_CHAR(UNISTR('B\1ED5 sung b\01B0\1EDBc gather stats sau load cho b\1EA3ng li\00EAn quan'))
WHERE  check_code = 'STALE_STATS';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('Quy\1EC1n object c\1EA5p th\1EB3ng cho user')),
       description  = TO_CHAR(UNISTR('S\1ED1 quy\1EC1n tr\00EAn object c\1EE7a schema c\1EA5p th\1EB3ng cho user (kh\00F4ng qua role)')),
       action_guide = TO_CHAR(UNISTR('Chuy\1EC3n sang role <DTM>_READ / _WRITE r\1ED3i thu h\1ED3i b\1EA3n c\1EA5p th\1EB3ng; ngo\1EA1i l\1EC7 h\1EE3p l\1EC7: grant cho schema owner mart \0111\1ECDc STG_DTM'))
WHERE  check_code = 'DIRECT_GRANT_USER';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('B\1EA3ng n\1ED9i b\1ED9 b\1ECB c\1EA5p quy\1EC1n ra ngo\00E0i')),
       description  = TO_CHAR(UNISTR('S\1ED1 quy\1EC1n tr\00EAn b\1EA3ng STG_/TWT_/TMP_ c\1EA5p cho user ho\1EB7c role ngo\00E0i ETL c\1EE7a ch\00EDnh mart')),
       action_guide = TO_CHAR(UNISTR('Thu h\1ED3i; n\1EBFu team kh\00E1c c\1EA7n d\1EEF li\1EC7u th\00EC t\1EA1o VW_ c\00F4ng b\1ED1'))
WHERE  check_code = 'INTERNAL_OBJ_GRANTED';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('T\00E0i kho\1EA3n gi\1EEF quy\1EC1n ANY')),
       description  = TO_CHAR(UNISTR('S\1ED1 quy\1EC1n h\1EC7 th\1ED1ng d\1EA1ng % ANY % \0111ang c\1EA5p cho user/role li\00EAn quan DTM (SCHEMA_NAME = _ALL_)')),
       action_guide = TO_CHAR(UNISTR('R\00E0 so\00E1t, thu g\1ECDn v\1EC1 m\1EE9c t\1ED1i thi\1EC3u; BI_DTM ghi nh\1EADn l\00E0m ngo\1EA1i l\1EC7 c\00F3 duy\1EC7t'))
WHERE  check_code = 'ANY_PRIV_HOLDER';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('T\00E0i kho\1EA3n s\1EAFp h\1EBFt h\1EA1n m\1EADt kh\1EA9u / b\1ECB kh\00F3a')),
       description  = TO_CHAR(UNISTR('S\1ED1 t\00E0i kho\1EA3n schema/ETL h\1EBFt h\1EA1n m\1EADt kh\1EA9u trong 14 ng\00E0y t\1EDBi, ho\1EB7c \0111ang EXPIRED / LOCKED ngo\00E0i d\1EF1 ki\1EBFn')),
       action_guide = TO_CHAR(UNISTR('\0110\1ED5i m\1EADt kh\1EA9u v\00E0 c\1EADp nh\1EADt connection Airflow/ODI tr\01B0\1EDBc ng\00E0y h\1EBFt h\1EA1n'))
WHERE  check_code = 'USER_PWD_EXPIRY';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('Object thay \0111\1ED5i DDL trong ng\00E0y')),
       description  = TO_CHAR(UNISTR('S\1ED1 object c\00F3 LAST_DDL_TIME trong 24 gi\1EDD qua')),
       action_guide = TO_CHAR(UNISTR('\0110\1ED1i chi\1EBFu v\1EDBi danh s\00E1ch deploy \0111\00E3 duy\1EC7t; DDL ngo\00E0i quy tr\00ECnh th\00EC truy v\1EBFt qua audit'))
WHERE  check_code = 'DDL_CHANGE_1D';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('Ph\1EE5 thu\1ED9c ch\00E9o gi\1EEFa c\00E1c mart')),
       description  = TO_CHAR(UNISTR('S\1ED1 ph\1EE5 thu\1ED9c t\1EEB object c\1EE7a mart n\00E0y sang mart kh\00E1c (tham chi\1EBFu t\1EDBi zone SOURCE l\00E0 h\1EE3p l\1EC7)')),
       action_guide = TO_CHAR(UNISTR('Vi ph\1EA1m bounded context: chuy\1EC3n d\1EEF li\1EC7u d\00F9ng chung v\1EC1 STG_DTM ho\1EB7c xin duy\1EC7t ngo\1EA1i l\1EC7 qua VW_'))
WHERE  check_code = 'CROSS_MART_DEP';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = TO_CHAR(UNISTR('B\1EA3ng c\00F4ng b\1ED1 thi\1EBFu comment')),
       description  = TO_CHAR(UNISTR('S\1ED1 b\1EA3ng FCT_/DIM_/AGG_ ch\01B0a c\00F3 COMMENT ON TABLE')),
       action_guide = TO_CHAR(UNISTR('B\1ED5 sung comment ghi grain, ngu\1ED3n, t\1EA7n su\1EA5t load'))
WHERE  check_code = 'MISSING_COMMENT';

COMMIT;


/* =====================================================================
   2. GHI LAI COMMENT CUA BANG / COT / VIEW TRONG BI_DTM
      COMMENT ON chi nhan literal, nen dung EXECUTE IMMEDIATE.
      Chay SAU khi da chay oas_views_v2.sql neu view chua ton tai,
      hoac chay lai khoi nay mot lan nua sau buoc 3.
   ===================================================================== */
BEGIN
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.mon_schema_def IS ''' || REPLACE(TO_CHAR(UNISTR('Danh m\1EE5c schema \0111\01B0\1EE3c gi\00E1m s\00E1t. Grain: 1 d\00F2ng = 1 schema.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_schema_def.zone_type IS ''' || REPLACE(TO_CHAR(UNISTR('SOURCE = v\00F9ng ngu\1ED3n chung (STG_DTM); MART = bounded context; SANDBOX = v\00F9ng th\1EED nghi\1EC7m')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_schema_def.business_domain IS ''' || REPLACE(TO_CHAR(UNISTR('L\0129nh v\1EF1c nghi\1EC7p v\1EE5 c\1EE7a schema')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_schema_def.is_active IS ''' || REPLACE(TO_CHAR(UNISTR('Y = \0111ang gi\00E1m s\00E1t')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.mon_check_def IS ''' || REPLACE(TO_CHAR(UNISTR('Danh m\1EE5c ti\00EAu ch\00ED gi\00E1m s\00E1t v\00E0 ng\01B0\1EE1ng. Grain: 1 d\00F2ng = 1 ti\00EAu ch\00ED.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_def.check_group IS ''' || REPLACE(TO_CHAR(UNISTR('Nh\00F3m ti\00EAu ch\00ED, d\00F9ng \0111\1EC3 nh\00F3m tr\00EAn dashboard OAS')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_def.metric_unit IS ''' || REPLACE(TO_CHAR(UNISTR('\0110\01A1n v\1ECB c\1EE7a METRIC_VALUE: COUNT, MB, PCT...')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_def.warn_threshold IS ''' || REPLACE(TO_CHAR(UNISTR('METRIC_VALUE >= ng\01B0\1EE1ng n\00E0y -> WARN. NULL c\00F9ng FAIL_THRESHOLD -> INFO')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_def.fail_threshold IS ''' || REPLACE(TO_CHAR(UNISTR('METRIC_VALUE >= ng\01B0\1EE1ng n\00E0y -> FAIL')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_def.has_detail IS ''' || REPLACE(TO_CHAR(UNISTR('Y = c\00F3 ghi chi ti\1EBFt object v\00E0o MON_CHECK_DETAIL')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_def.action_guide IS ''' || REPLACE(TO_CHAR(UNISTR('H\01B0\1EDBng x\1EED l\00FD khi ti\00EAu ch\00ED WARN/FAIL')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.mon_run_log IS ''' || REPLACE(TO_CHAR(UNISTR('Nh\1EADt k\00FD ch\1EA1y package gi\00E1m s\00E1t. Grain: 1 d\00F2ng = 1 l\1EA7n ch\1EA1y.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_run_log.run_status IS ''' || REPLACE(TO_CHAR(UNISTR('SUCCESS = m\1ECDi ti\00EAu ch\00ED ch\1EA1y \0111\01B0\1EE3c; PARTIAL = c\00F3 ti\00EAu ch\00ED ERROR; FAILED = package d\1EEBng gi\1EEFa ch\1EEBng')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_run_log.checks_error IS ''' || REPLACE(TO_CHAR(UNISTR('S\1ED1 ti\00EAu ch\00ED m\00E0 c\00E2u ki\1EC3m tra b\1ECB l\1ED7i (kh\00F4ng ph\1EA3i s\1ED1 vi ph\1EA1m)')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_run_log.triggered_by IS ''AIRFLOW / SCHEDULER / MANUAL''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.mon_check_result IS ''' || REPLACE(TO_CHAR(UNISTR('K\1EBFt qu\1EA3 gi\00E1m s\00E1t h\1EB1ng ng\00E0y. Grain: 1 d\00F2ng = 1 ng\00E0y / 1 ti\00EAu ch\00ED / 1 schema. Ngu\1ED3n ch\00EDnh cho dashboard OAS.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.schema_name IS ''' || REPLACE(TO_CHAR(UNISTR('Schema \0111\01B0\1EE3c gi\00E1m s\00E1t; _ALL_ cho ti\00EAu ch\00ED c\1EA5p database')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.metric_value IS ''' || REPLACE(TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o, \0111\01A1n v\1ECB theo MON_CHECK_DEF.METRIC_UNIT')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.warn_threshold IS ''' || REPLACE(TO_CHAR(UNISTR('Ng\01B0\1EE1ng t\1EA1i th\1EDDi \0111i\1EC3m ch\1EA1y (l\01B0u l\1EA1i \0111\1EC3 l\1ECBch s\1EED kh\00F4ng \0111\1ED5i khi s\1EEDa ng\01B0\1EE1ng)')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.prev_value IS ''' || REPLACE(TO_CHAR(UNISTR('METRIC_VALUE c\1EE7a l\1EA7n ch\1EA1y th\00E0nh c\00F4ng g\1EA7n nh\1EA5t tr\01B0\1EDBc \0111\00F3')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.delta_value IS ''METRIC_VALUE - PREV_VALUE''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.check_status IS ''' || REPLACE(TO_CHAR(UNISTR('OK / WARN / FAIL / INFO / ERROR (ERROR = c\00E2u ki\1EC3m tra l\1ED7i)')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_result.error_msg IS ''SQLERRM khi CHECK_STATUS = ERROR''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.mon_check_detail IS ''' || REPLACE(TO_CHAR(UNISTR('Chi ti\1EBFt object vi ph\1EA1m. Grain: 1 d\00F2ng = 1 ng\00E0y / 1 ti\00EAu ch\00ED / 1 object (ho\1EB7c 1 grant, 1 ph\1EE5 thu\1ED9c).')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_detail.detail_seq IS ''' || REPLACE(TO_CHAR(UNISTR('S\1ED1 th\1EE9 t\1EF1 d\00F2ng trong c\00F9ng ng\00E0y / ti\00EAu ch\00ED / schema')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_detail.sub_object_name IS ''' || REPLACE(TO_CHAR(UNISTR('Partition, subpartition ho\1EB7c c\1ED9t t\00F9y ti\00EAu ch\00ED')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_detail.grantee IS ''' || REPLACE(TO_CHAR(UNISTR('Ng\01B0\1EDDi/role nh\1EADn quy\1EC1n (ti\00EAu ch\00ED SECURITY)')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_detail.ref_schema IS ''' || REPLACE(TO_CHAR(UNISTR('Schema \0111\01B0\1EE3c tham chi\1EBFu (ti\00EAu ch\00ED CROSS_MART_DEP)')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_detail.num_value IS ''' || REPLACE(TO_CHAR(UNISTR('Gi\00E1 tr\1ECB s\1ED1 c\1EE7a object (MB, s\1ED1 ng\00E0y, % ...)')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_check_detail.event_time IS ''' || REPLACE(TO_CHAR(UNISTR('Th\1EDDi \0111i\1EC3m li\00EAn quan: LAST_DDL_TIME, LAST_ANALYZED, EXPIRY_DATE...')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.mon_schema_size_daily IS ''' || REPLACE(TO_CHAR(UNISTR('Dung l\01B0\1EE3ng theo ng\00E0y. Grain: 1 d\00F2ng = 1 ng\00E0y / 1 schema / 1 tablespace / 1 nh\00F3m segment.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_schema_size_daily.segment_group IS ''' || REPLACE(TO_CHAR(UNISTR('TABLE (g\1ED3m TABLE PARTITION/SUBPARTITION), INDEX (g\1ED3m partition), LOB, OTHER')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON COLUMN bi_dtm.mon_schema_size_daily.size_mb IS ''' || REPLACE(TO_CHAR(UNISTR('SUM(BYTES)/1024/1024 t\1EEB DBA_SEGMENTS')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_mon_result IS ''' || REPLACE(TO_CHAR(UNISTR('View c\00F4ng b\1ED1 cho OAS: k\1EBFt qu\1EA3 gi\00E1m s\00E1t theo ng\00E0y, k\00E8m t\00EAn ti\00EAu ch\00ED v\00E0 nghi\1EC7p v\1EE5 schema.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_mon_latest IS ''' || REPLACE(TO_CHAR(UNISTR('View c\00F4ng b\1ED1 cho OAS: k\1EBFt qu\1EA3 c\1EE7a ng\00E0y gi\00E1m s\00E1t g\1EA7n nh\1EA5t.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_mon_detail IS ''' || REPLACE(TO_CHAR(UNISTR('View c\00F4ng b\1ED1 cho OAS: chi ti\1EBFt object vi ph\1EA1m \0111\1EC3 drill-down.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_mon_size IS ''' || REPLACE(TO_CHAR(UNISTR('View c\00F4ng b\1ED1 cho OAS: dung l\01B0\1EE3ng theo ng\00E0y / schema / tablespace.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_mon_run IS ''' || REPLACE(TO_CHAR(UNISTR('View c\00F4ng b\1ED1 cho OAS: nh\1EADt k\00FD ch\1EA1y package gi\00E1m s\00E1t.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_oas_mon_detail IS ''' || REPLACE(TO_CHAR(UNISTR('View cho OAS: chi ti\1EBFt object vi ph\1EA1m c\1EE7a ng\00E0y gi\00E1m s\00E1t g\1EA7n nh\1EA5t.')), '''', '''''') || '''';
    EXECUTE IMMEDIATE 'COMMENT ON TABLE bi_dtm.vw_oas_mon_run IS ''' || REPLACE(TO_CHAR(UNISTR('View cho OAS: nh\1EADt k\00FD ch\1EA1y package gi\00E1m s\00E1t 60 ng\00E0y g\1EA7n nh\1EA5t.')), '''', '''''') || '''';
END;
/


/* =====================================================================
   3. KIEM TRA (chay sau run_daily)
   ===================================================================== */

-- 3.1 Byte UTF-8 chu co dau phai la c3/c4/c6/e1..., khong con 3f
SELECT check_code, check_name, DUMP(check_name, 1016) AS raw_bytes
FROM   bi_dtm.mon_check_def
WHERE  check_code IN ('SCHEMA_SIZE', 'DDL_CHANGE_1D');

-- 3.2 Quet tat ca noi con dau '?' (ket qua mong doi: 0 dong)
SELECT 'MON_CHECK_DEF' AS src, check_code AS k, check_name AS txt FROM bi_dtm.mon_check_def
WHERE  INSTR(check_name || description || action_guide, '?') > 0
UNION ALL
SELECT 'MON_SCHEMA_DEF', schema_name, business_domain FROM bi_dtm.mon_schema_def
WHERE  INSTR(business_domain, '?') > 0
UNION ALL
SELECT 'MON_CHECK_DETAIL', check_code, MAX(detail_msg) FROM bi_dtm.mon_check_detail
WHERE  snapshot_date = TRUNC(SYSDATE) AND INSTR(detail_msg, '?') > 0
GROUP BY check_code
UNION ALL
SELECT 'COMMENT', table_name, comments FROM user_tab_comments
WHERE  table_name LIKE '%MON%' AND INSTR(comments, '?') > 0
UNION ALL
SELECT 'COL_COMMENT', table_name || '.' || column_name, comments FROM user_col_comments
WHERE  table_name LIKE '%MON%' AND INSTR(comments, '?') > 0;
