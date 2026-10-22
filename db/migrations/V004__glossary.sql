/* =====================================================================
   BI_DTM - BANG THUAT NGU CHO DASHBOARD GIAM SAT DTM
   Phien ban: 1.0 - 2026-10-22

   File chi chua ky tu ASCII (tieng Viet viet bang UNISTR), chay bang
   Toad / SQL Developer / sqlplus deu ra dung dau.

   Thanh phan:
   1. MON_GLOSSARY          Bang thuat ngu viet tay (cach doc, trang thai,
                            vung, cot, thuat ngu Oracle)
   2. Seed du lieu          Chay lai duoc: xoa roi ghi lai
   3. VW_OAS_MON_GLOSSARY   Gop 3 nguon:
                              - MON_GLOSSARY
                              - MON_CHECK_DEF  (tieu chi + nguong, tu cap nhat)
                              - MON_SCHEMA_DEF (schema, tu cap nhat)
   4. Quyen cho OAS

   Dataset OAS:  SELECT * FROM bi_dtm.vw_oas_mon_glossary
   ===================================================================== */


/* =====================================================================
   1. BANG MON_GLOSSARY (chi chay lan dau)
   ===================================================================== */
CREATE TABLE bi_dtm.mon_glossary (
    term_code      VARCHAR2(50)         NOT NULL,
    term_group     VARCHAR2(100 CHAR)   NOT NULL,
    group_order    NUMBER(3)            NOT NULL,
    term_name      VARCHAR2(200 CHAR)   NOT NULL,
    definition     VARCHAR2(1000 CHAR)  NOT NULL,
    how_to_read    VARCHAR2(1000 CHAR),
    example        VARCHAR2(1000 CHAR),
    display_order  NUMBER(5)            NOT NULL,
    is_active      CHAR(1)   DEFAULT 'Y' NOT NULL,
    updated_ts     TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_mon_glossary PRIMARY KEY (term_code),
    CONSTRAINT ck_mon_glossary_active CHECK (is_active IN ('Y','N'))
);

COMMENT ON TABLE  bi_dtm.mon_glossary IS 'Glossary for DTM monitor dashboard. Grain: 1 row = 1 term.';
COMMENT ON COLUMN bi_dtm.mon_glossary.group_order   IS 'Order of term group on dashboard';
COMMENT ON COLUMN bi_dtm.mon_glossary.display_order IS 'Order of term inside the glossary';


/* =====================================================================
   2. SEED DU LIEU (chay lai duoc bat cu luc nao)
   ===================================================================== */
DELETE FROM bi_dtm.mon_glossary;

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('DASHBOARD_PURPOSE', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Dashboard n\00E0y d\00F9ng \0111\1EC3 l\00E0m g\00EC')),
        TO_CHAR(UNISTR('Theo d\00F5i h\1EB1ng ng\00E0y s\1EE9c kh\1ECFe k\1EF9 thu\1EADt c\1EE7a c\00E1c schema datamart: dung l\01B0\1EE3ng, object l\1ED7i, ph\00E2n quy\1EC1n, thay \0111\1ED5i c\1EA5u tr\00FAc v\00E0 vi\1EC7c tu\00E2n th\1EE7 ki\1EBFn tr\00FAc. Dashboard kh\00F4ng \0111o s\1ED1 li\1EC7u nghi\1EC7p v\1EE5 (d\01B0 n\1EE3, giao d\1ECBch...).')),
        TO_CHAR(UNISTR('M\1EDF trang T\1ED5ng quan tr\01B0\1EDBc. N\1EBFu kh\00F4ng c\00F3 ti\00EAu ch\00ED FAIL, WARN ho\1EB7c ERROR th\00EC h\1EC7 th\1ED1ng \1ED5n trong ng\00E0y.')),
        NULL,
        10);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('DATA_FRESHNESS', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('D\1EEF li\1EC7u c\1EADp nh\1EADt khi n\00E0o')),
        TO_CHAR(UNISTR('Package BI_DTM.PKG_DTM_MONITOR ch\1EA1y 1 l\1EA7n m\1ED7i ng\00E0y v\00E0 ch\1EE5p l\1EA1i hi\1EC7n tr\1EA1ng t\1EA1i th\1EDDi \0111i\1EC3m ch\1EA1y. C\00E1c trang m\1EB7c \0111\1ECBnh hi\1EC3n th\1ECB ng\00E0y gi\00E1m s\00E1t g\1EA7n nh\1EA5t, ri\00EAng trang Xu h\01B0\1EDBng v\00E0 Dung l\01B0\1EE3ng hi\1EC3n th\1ECB l\1ECBch s\1EED.')),
        TO_CHAR(UNISTR('Ki\1EC3m tra trang Nh\1EADt k\00FD ch\1EA1y: l\1EA7n ch\1EA1y m\1EDBi nh\1EA5t ph\1EA3i c\00F3 tr\1EA1ng th\00E1i SUCCESS v\00E0 ng\00E0y gi\00E1m s\00E1t l\00E0 h\00F4m nay.')),
        NULL,
        20);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('READ_ORDER', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Th\1EE9 t\1EF1 \0111\1ECDc khuy\1EBFn ngh\1ECB')),
        TO_CHAR(UNISTR('\0110\1ECDc t\1EEB t\1ED5ng qu\00E1t \0111\1EBFn chi ti\1EBFt: T\1ED5ng quan (ti\00EAu ch\00ED n\00E0o c\00F3 v\1EA5n \0111\1EC1) -> Ma tr\1EADn (\1EDF schema n\00E0o) -> Chi ti\1EBFt vi ph\1EA1m (object c\1EE5 th\1EC3 v\00E0 h\01B0\1EDBng x\1EED l\00FD) -> Xu h\01B0\1EDBng (v\1EA5n \0111\1EC1 \0111ang t\0103ng hay gi\1EA3m).')),
        TO_CHAR(UNISTR('M\1ED7i v\1EA5n \0111\1EC1 c\1EA7n tr\1EA3 l\1EDDi \0111\01B0\1EE3c ba c\00E2u: c\00E1i g\00EC, \1EDF \0111\00E2u, x\1EED l\00FD th\1EBF n\00E0o.')),
        NULL,
        30);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PAGE_OVERVIEW', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Trang T\1ED5ng quan')),
        TO_CHAR(UNISTR('M\1ED7i d\00F2ng l\00E0 m\1ED9t ti\00EAu ch\00ED gi\00E1m s\00E1t, g\1ED9p tr\00EAn t\1EA5t c\1EA3 schema v\00E0 l\1EA5y tr\1EA1ng th\00E1i x\1EA5u nh\1EA5t.')),
        TO_CHAR(UNISTR('C\1ED9t WORST_STATUS cho bi\1EBFt m\1EE9c nghi\00EAm tr\1ECDng; SCHEMA_ISSUE_LIST li\1EC7t k\00EA schema \0111ang FAIL ho\1EB7c WARN; ACTION_GUIDE l\00E0 h\01B0\1EDBng x\1EED l\00FD.')),
        NULL,
        40);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PAGE_MATRIX', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Trang Ma tr\1EADn ti\00EAu ch\00ED x schema')),
        TO_CHAR(UNISTR('B\1EA3ng m\00E0u: h\00E0ng l\00E0 ti\00EAu ch\00ED, c\1ED9t l\00E0 schema, m\1ED7i \00F4 l\00E0 gi\00E1 tr\1ECB \0111o v\00E0 m\00E0u theo tr\1EA1ng th\00E1i.')),
        TO_CHAR(UNISTR('\00D4 \0111\1ECF l\00E0 ch\1ED7 c\1EA7n x\1EED l\00FD tr\01B0\1EDBc. C\1ED9t To\00E0n h\1EC7 th\1ED1ng ch\1EE9a c\00E1c ti\00EAu ch\00ED c\1EA5p database, kh\00F4ng thu\1ED9c ri\00EAng schema n\00E0o.')),
        NULL,
        50);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PAGE_DETAIL', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Trang Chi ti\1EBFt vi ph\1EA1m')),
        TO_CHAR(UNISTR('Danh s\00E1ch t\1EEBng object, quy\1EC1n ho\1EB7c ph\1EE5 thu\1ED9c \0111ang vi ph\1EA1m c\1EE7a ng\00E0y gi\00E1m s\00E1t g\1EA7n nh\1EA5t.')),
        TO_CHAR(UNISTR('L\1ECDc theo ti\00EAu ch\00ED v\00E0 schema. C\1ED9t ISSUE_TEXT m\00F4 t\1EA3 vi ph\1EA1m trong m\1ED9t d\00F2ng \0111\1EC3 chuy\1EC3n cho ng\01B0\1EDDi x\1EED l\00FD.')),
        NULL,
        60);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PAGE_TREND', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Trang Xu h\01B0\1EDBng')),
        TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o c\1EE7a t\1EEBng ti\00EAu ch\00ED theo ng\00E0y trong 90 ng\00E0y g\1EA7n nh\1EA5t.')),
        TO_CHAR(UNISTR('\0110\01B0\1EDDng \0111i l\00EAn l\00E0 v\1EA5n \0111\1EC1 \0111ang t\00EDch t\1EE5, \0111i xu\1ED1ng l\00E0 \0111ang \0111\01B0\1EE3c x\1EED l\00FD. C\1EA7n \00EDt nh\1EA5t 1 \0111\1EBFn 2 tu\1EA7n d\1EEF li\1EC7u m\1EDBi \0111\1ECDc \0111\01B0\1EE3c xu h\01B0\1EDBng.')),
        NULL,
        70);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PAGE_SIZE', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Trang Dung l\01B0\1EE3ng')),
        TO_CHAR(UNISTR('Dung l\01B0\1EE3ng l\01B0u tr\1EEF theo schema v\00E0 theo ng\00E0y, k\00E8m m\1EE9c t\0103ng sau 1, 7 v\00E0 30 l\1EA7n \0111o.')),
        TO_CHAR(UNISTR('Theo d\00F5i schema chi\1EBFm t\1EF7 tr\1ECDng l\1EDBn v\00E0 schema t\0103ng nhanh b\1EA5t th\01B0\1EDDng \0111\1EC3 l\00EAn k\1EBF ho\1EA1ch d\1ECDn d\1EB9p ho\1EB7c xin th\00EAm dung l\01B0\1EE3ng.')),
        NULL,
        80);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PAGE_RUN', TO_CHAR(UNISTR('C\00E1ch \0111\1ECDc dashboard')), 1, TO_CHAR(UNISTR('Trang Nh\1EADt k\00FD ch\1EA1y')),
        TO_CHAR(UNISTR('M\1ED7i d\00F2ng l\00E0 m\1ED9t l\1EA7n ch\1EA1y package gi\00E1m s\00E1t, k\00E8m s\1ED1 ti\00EAu ch\00ED theo t\1EEBng tr\1EA1ng th\00E1i.')),
        TO_CHAR(UNISTR('N\1EBFu l\1EA7n ch\1EA1y g\1EA7n nh\1EA5t kh\00F4ng ph\1EA3i SUCCESS th\00EC s\1ED1 li\1EC7u tr\00EAn c\00E1c trang kh\00E1c c\00F3 th\1EC3 thi\1EBFu ho\1EB7c c\0169.')),
        NULL,
        90);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('FAIL', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('FAIL - Vi ph\1EA1m nghi\00EAm tr\1ECDng')),
        TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o l\1EDBn h\01A1n ho\1EB7c b\1EB1ng ng\01B0\1EE1ng FAIL c\1EE7a ti\00EAu ch\00ED.')),
        TO_CHAR(UNISTR('M\00E0u \0111\1ECF. C\1EA7n x\1EED l\00FD trong ng\00E0y ho\1EB7c l\00EAn k\1EBF ho\1EA1ch x\1EED l\00FD c\00F3 th\1EDDi h\1EA1n.')),
        TO_CHAR(UNISTR('INVALID_OBJ = 7 v\1EDBi ng\01B0\1EE1ng FAIL = 5 ngh\0129a l\00E0 schema \0111ang c\00F3 7 object l\1ED7i bi\00EAn d\1ECBch.')),
        100);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('WARN', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('WARN - C\1EA3nh b\00E1o')),
        TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o \0111\00E3 ch\1EA1m ng\01B0\1EE1ng WARN nh\01B0ng ch\01B0a t\1EDBi ng\01B0\1EE1ng FAIL.')),
        TO_CHAR(UNISTR('M\00E0u v\00E0ng. Ch\01B0a g\00E2y s\1EF1 c\1ED1 nh\01B0ng c\1EA7n theo d\00F5i, kh\00F4ng \0111\1EC3 k\00E9o d\00E0i.')),
        NULL,
        110);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('OK', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('OK - \0110\1EA1t')),
        TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o n\1EB1m d\01B0\1EDBi ng\01B0\1EE1ng c\1EA3nh b\00E1o.')),
        TO_CHAR(UNISTR('M\00E0u xanh. Kh\00F4ng c\1EA7n h\00E0nh \0111\1ED9ng.')),
        NULL,
        120);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('INFO', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('INFO - Ch\1EC9 \0111\1EC3 theo d\00F5i')),
        TO_CHAR(UNISTR('Ti\00EAu ch\00ED kh\00F4ng \0111\1EB7t ng\01B0\1EE1ng, ch\1EC9 ghi nh\1EADn s\1ED1 li\1EC7u.')),
        TO_CHAR(UNISTR('M\00E0u x\00E1m. Kh\00F4ng t\1EF1 k\1EBFt lu\1EADn t\1ED1t hay x\1EA5u; xem k\00E8m xu h\01B0\1EDBng ho\1EB7c \0111\1ED1i chi\1EBFu v\1EDBi k\1EBF ho\1EA1ch.')),
        TO_CHAR(UNISTR('DDL_CHANGE_1D l\00E0 INFO v\00EC \0111\1ED5i c\1EA5u tr\00FAc c\00F3 th\1EC3 l\00E0 deploy h\1EE3p l\1EC7.')),
        130);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('ERROR', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('ERROR - Kh\00F4ng \0111o \0111\01B0\1EE3c')),
        TO_CHAR(UNISTR('B\1EA3n th\00E2n c\00E2u ki\1EC3m tra b\1ECB l\1ED7i khi ch\1EA1y (thi\1EBFu quy\1EC1n, l\1ED7i SQL...). \0110\00E2y l\00E0 l\1ED7i c\1EE7a h\1EC7 th\1ED1ng gi\00E1m s\00E1t, kh\00F4ng ph\1EA3i d\1EEF li\1EC7u c\00F3 v\1EA5n \0111\1EC1.')),
        TO_CHAR(UNISTR('M\00E0u t\00EDm. S\1ED1 li\1EC7u c\1EE7a ti\00EAu ch\00ED n\00E0y trong ng\00E0y kh\00F4ng \0111\00E1ng tin; b\00E1o team BI xem c\1ED9t ERROR_MSG.')),
        NULL,
        140);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('RUN_SUCCESS', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('SUCCESS - L\1EA7n ch\1EA1y th\00E0nh c\00F4ng')),
        TO_CHAR(UNISTR('Package ch\1EA1y h\1EBFt v\00E0 m\1ECDi ti\00EAu ch\00ED \0111\1EC1u \0111o \0111\01B0\1EE3c.')),
        TO_CHAR(UNISTR('S\1ED1 li\1EC7u trong ng\00E0y \0111\1EA7y \0111\1EE7.')),
        NULL,
        150);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('RUN_PARTIAL', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('PARTIAL - Ch\1EA1y \0111\01B0\1EE3c m\1ED9t ph\1EA7n')),
        TO_CHAR(UNISTR('Package ch\1EA1y h\1EBFt nh\01B0ng c\00F3 \00EDt nh\1EA5t m\1ED9t ti\00EAu ch\00ED ERROR.')),
        TO_CHAR(UNISTR('C\00E1c ti\00EAu ch\00ED c\00F2n l\1EA1i v\1EABn d\00F9ng \0111\01B0\1EE3c; xem c\1ED9t ERROR_CHECKS \0111\1EC3 bi\1EBFt ti\00EAu ch\00ED n\00E0o thi\1EBFu.')),
        NULL,
        160);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('RUN_FAILED', TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i')), 2, TO_CHAR(UNISTR('FAILED - L\1EA7n ch\1EA1y th\1EA5t b\1EA1i')),
        TO_CHAR(UNISTR('Package d\1EEBng gi\1EEFa ch\1EEBng.')),
        TO_CHAR(UNISTR('S\1ED1 li\1EC7u c\1EE7a ng\00E0y c\00F3 th\1EC3 thi\1EBFu nhi\1EC1u ti\00EAu ch\00ED; c\1EA7n ch\1EA1y l\1EA1i.')),
        NULL,
        170);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SOURCE', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, TO_CHAR(UNISTR('SOURCE - V\00F9ng ngu\1ED3n chung')),
        TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u n\1EC1n d\00F9ng chung cho m\1ECDi mart. Hi\1EC7n l\00E0 STG_DTM, v\00F9ng ph\00E1i sinh T-1 c\1EE7a SB_DWH, ch\1EE9a c\00E1c dimension d\00F9ng chung (kh\00E1ch h\00E0ng, chi nh\00E1nh, s\1EA3n ph\1EA9m...).')),
        TO_CHAR(UNISTR('M\1ECDi mart ch\1EC9 \0111\01B0\1EE3c l\1EA5y d\1EEF li\1EC7u d\00F9ng chung t\1EEB v\00F9ng n\00E0y.')),
        NULL,
        180);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('MART', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, TO_CHAR(UNISTR('MART - V\00F9ng nghi\1EC7p v\1EE5')),
        TO_CHAR(UNISTR('Datamart c\1EE7a m\1ED9t l\0129nh v\1EF1c nghi\1EC7p v\1EE5, t\1ED5ng h\1EE3p d\1EEF li\1EC7u theo ng\1EEF ngh\0129a ri\00EAng c\1EE7a l\0129nh v\1EF1c \0111\00F3.')),
        TO_CHAR(UNISTR('M\1ED7i mart l\00E0 m\1ED9t v\00F9ng \0111\1ED9c l\1EADp, kh\00F4ng \0111\1ECDc d\1EEF li\1EC7u c\1EE7a mart kh\00E1c.')),
        TO_CHAR(UNISTR('CAP_DTM nh\00ECn kh\00E1ch h\00E0ng theo g\00F3c ph\00EA duy\1EC7t t\00EDn d\1EE5ng, CNL_DTM theo g\00F3c tu\00E2n th\1EE7.')),
        190);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SANDBOX', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, TO_CHAR(UNISTR('SANDBOX - V\00F9ng th\1EED nghi\1EC7m')),
        TO_CHAR(UNISTR('V\00F9ng \0111\1EC3 ph\00E1t tri\1EC3n v\00E0 th\1EED nghi\1EC7m (SND_DTM).')),
        TO_CHAR(UNISTR('Kh\00F4ng mart production n\00E0o \0111\01B0\1EE3c ph\1EE5 thu\1ED9c v\00E0o v\00F9ng n\00E0y.')),
        NULL,
        200);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('ALL_SCHEMA', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, TO_CHAR(UNISTR('To\00E0n h\1EC7 th\1ED1ng (_ALL_)')),
        TO_CHAR(UNISTR('D\00F2ng k\1EBFt qu\1EA3 c\1EE7a c\00E1c ti\00EAu ch\00ED \0111o \1EDF c\1EA5p database, kh\00F4ng g\1EAFn v\1EDBi ri\00EAng schema n\00E0o.')),
        TO_CHAR(UNISTR('G\1ED3m t\1EF7 l\1EC7 d\00F9ng tablespace, quy\1EC1n ANY v\00E0 t\00E0i kho\1EA3n s\1EAFp h\1EBFt h\1EA1n m\1EADt kh\1EA9u.')),
        NULL,
        210);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('BOUNDED_CONTEXT', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, 'Bounded context',
        TO_CHAR(UNISTR('Nguy\00EAn t\1EAFc ki\1EBFn tr\00FAc: m\1ED7i mart l\00E0 m\1ED9t v\00F9ng kh\00E9p k\00EDn, ch\1EC9 \0111\1ECDc t\1EEB v\00F9ng ngu\1ED3n chung v\00E0 t\1EF1 \0111\1ECBnh ngh\0129a ng\1EEF ngh\0129a c\1EE7a m\00ECnh.')),
        TO_CHAR(UNISTR('C\00F9ng t\00EAn ch\1EC9 ti\00EAu (v\00ED d\1EE5 d\01B0 n\1EE3) \1EDF hai mart c\00F3 th\1EC3 kh\00E1c \0111\1ECBnh ngh\0129a; kh\00F4ng so s\00E1nh tr\1EF1c ti\1EBFp khi ch\01B0a \0111\1ED1i chi\1EBFu \0111\1ECBnh ngh\0129a.')),
        NULL,
        220);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PUBLISHED_LAYER', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, TO_CHAR(UNISTR('L\1EDBp c\00F4ng b\1ED1')),
        TO_CHAR(UNISTR('C\00E1c b\1EA3ng v\00E0 view \0111\01B0\1EE3c ph\00E9p cho ng\01B0\1EDDi d\00F9ng v\00E0 team kh\00E1c \0111\1ECDc: ti\1EC1n t\1ED1 FCT_, DIM_, AGG_, VW_.')),
        TO_CHAR(UNISTR('B\00E1o c\00E1o v\00E0 s\1EA3n ph\1EA9m d\1EEF li\1EC7u ch\1EC9 \0111\01B0\1EE3c x\00E2y tr\00EAn l\1EDBp n\00E0y.')),
        NULL,
        230);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('INTERNAL_LAYER', TO_CHAR(UNISTR('V\00F9ng d\1EEF li\1EC7u v\00E0 ki\1EBFn tr\00FAc')), 3, TO_CHAR(UNISTR('L\1EDBp n\1ED9i b\1ED9')),
        TO_CHAR(UNISTR('B\1EA3ng trung gian ch\1EC9 d\00F9ng trong qu\00E1 tr\00ECnh x\1EED l\00FD ETL c\1EE7a mart: ti\1EC1n t\1ED1 STG_, TWT_, TMP_.')),
        TO_CHAR(UNISTR('Kh\00F4ng c\1EA5p quy\1EC1n cho ng\01B0\1EDDi ngo\00E0i; c\1EA5u tr\00FAc c\00F3 th\1EC3 \0111\1ED5i b\1EA5t c\1EE9 l\00FAc n\00E0o.')),
        NULL,
        240);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SNAPSHOT_DATE', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('SNAPSHOT_DATE - Ng\00E0y gi\00E1m s\00E1t')),
        TO_CHAR(UNISTR('Ng\00E0y package ch\1EA1y \0111o. M\1ECDi s\1ED1 li\1EC7u l\00E0 \1EA3nh ch\1EE5p t\1EA1i th\1EDDi \0111i\1EC3m ch\1EA1y c\1EE7a ng\00E0y \0111\00F3.')),
        TO_CHAR(UNISTR('Ph\1EA7n gi\1EDD (12:00:00 AM) kh\00F4ng c\00F3 \00FD ngh\0129a.')),
        NULL,
        250);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('METRIC_VALUE', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('METRIC_VALUE - Gi\00E1 tr\1ECB \0111o')),
        TO_CHAR(UNISTR('K\1EBFt qu\1EA3 \0111o c\1EE7a m\1ED9t ti\00EAu ch\00ED tr\00EAn m\1ED9t schema. \0110\01A1n v\1ECB theo c\1ED9t METRIC_UNIT.')),
        TO_CHAR(UNISTR('COUNT l\00E0 s\1ED1 l\01B0\1EE3ng, MB l\00E0 megabyte, PCT l\00E0 ph\1EA7n tr\0103m.')),
        NULL,
        260);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PREV_VALUE', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('PREV_VALUE - Gi\00E1 tr\1ECB l\1EA7n tr\01B0\1EDBc')),
        TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o c\1EE7a l\1EA7n gi\00E1m s\00E1t h\1EE3p l\1EC7 g\1EA7n nh\1EA5t tr\01B0\1EDBc \0111\00F3.')),
        TO_CHAR(UNISTR('Tr\1ED1ng n\1EBFu \0111\00E2y l\00E0 l\1EA7n \0111o \0111\1EA7u ti\00EAn.')),
        NULL,
        270);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('DELTA_VALUE', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('DELTA_VALUE - Ch\00EAnh l\1EC7ch')),
        TO_CHAR(UNISTR('Gi\00E1 tr\1ECB \0111o h\00F4m nay tr\1EEB gi\00E1 tr\1ECB l\1EA7n tr\01B0\1EDBc.')),
        TO_CHAR(UNISTR('D\01B0\01A1ng l\00E0 t\0103ng, \00E2m l\00E0 gi\1EA3m. V\1EDBi ti\00EAu ch\00ED \0111\1EBFm vi ph\1EA1m th\00EC gi\1EA3m l\00E0 t\1ED1t.')),
        NULL,
        280);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('THRESHOLD', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('WARN_THRESHOLD / FAIL_THRESHOLD - Ng\01B0\1EE1ng')),
        TO_CHAR(UNISTR('M\1EE9c gi\00E1 tr\1ECB \0111\1EC3 x\1EBFp tr\1EA1ng th\00E1i: t\1EEB ng\01B0\1EE1ng WARN tr\1EDF l\00EAn l\00E0 WARN, t\1EEB ng\01B0\1EE1ng FAIL tr\1EDF l\00EAn l\00E0 FAIL.')),
        TO_CHAR(UNISTR('Ng\01B0\1EE1ng \0111\01B0\1EE3c l\01B0u k\00E8m t\1EEBng ng\00E0y, n\00EAn s\1EEDa ng\01B0\1EE1ng kh\00F4ng l\00E0m thay \0111\1ED5i tr\1EA1ng th\00E1i c\1EE7a c\00E1c ng\00E0y c\0169.')),
        NULL,
        290);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('WORST_STATUS', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('WORST_STATUS - Tr\1EA1ng th\00E1i x\1EA5u nh\1EA5t')),
        TO_CHAR(UNISTR('Tr\1EA1ng th\00E1i nghi\00EAm tr\1ECDng nh\1EA5t c\1EE7a m\1ED9t ti\00EAu ch\00ED tr\00EAn t\1EA5t c\1EA3 schema.')),
        TO_CHAR(UNISTR('Th\1EE9 t\1EF1 nghi\00EAm tr\1ECDng: FAIL > ERROR > WARN > OK > INFO.')),
        NULL,
        300);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('TOTAL_VALUE', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('TOTAL_VALUE - T\1ED5ng gi\00E1 tr\1ECB')),
        TO_CHAR(UNISTR('T\1ED5ng gi\00E1 tr\1ECB \0111o c\1EE7a ti\00EAu ch\00ED tr\00EAn t\1EA5t c\1EA3 schema.')),
        TO_CHAR(UNISTR('V\1EDBi ti\00EAu ch\00ED ph\1EA7n tr\0103m (PCT) th\00EC t\1ED5ng kh\00F4ng c\00F3 \00FD ngh\0129a, xem t\1EEBng d\00F2ng \1EDF trang Ma tr\1EADn.')),
        NULL,
        310);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SCHEMA_COUNT', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, 'SCHEMA_FAIL / SCHEMA_WARN / SCHEMA_ERROR',
        TO_CHAR(UNISTR('S\1ED1 schema \0111ang \1EDF tr\1EA1ng th\00E1i FAIL, WARN ho\1EB7c ERROR v\1EDBi ti\00EAu ch\00ED \0111\00F3.')),
        TO_CHAR(UNISTR('SCHEMA_CHECKED l\00E0 t\1ED5ng s\1ED1 schema \0111\01B0\1EE3c \0111o.')),
        NULL,
        320);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SCHEMA_ISSUE_LIST', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('SCHEMA_ISSUE_LIST - Danh s\00E1ch schema c\00F3 v\1EA5n \0111\1EC1')),
        TO_CHAR(UNISTR('T\00EAn c\00E1c schema \0111ang FAIL ho\1EB7c WARN, schema nghi\00EAm tr\1ECDng h\01A1n \0111\1EE9ng tr\01B0\1EDBc.')),
        NULL,
        NULL,
        330);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('ACTION_GUIDE', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('ACTION_GUIDE - H\01B0\1EDBng x\1EED l\00FD')),
        TO_CHAR(UNISTR('Vi\1EC7c c\1EA7n l\00E0m khi ti\00EAu ch\00ED \1EDF tr\1EA1ng th\00E1i WARN ho\1EB7c FAIL.')),
        NULL,
        NULL,
        340);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('ISSUE_TEXT', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('ISSUE_TEXT - M\00F4 t\1EA3 vi ph\1EA1m')),
        TO_CHAR(UNISTR('M\1ED9t d\00F2ng m\00F4 t\1EA3 object ho\1EB7c quy\1EC1n \0111ang vi ph\1EA1m, v\00ED d\1EE5 d\1EA1ng SCHEMA.OBJECT ho\1EB7c QUY\1EC0N ON OBJECT TO NG\01AF\1EDCI_NH\1EACN.')),
        TO_CHAR(UNISTR('C\00F3 th\1EC3 copy nguy\00EAn d\00F2ng \0111\1EC3 g\1EEDi ng\01B0\1EDDi x\1EED l\00FD.')),
        NULL,
        350);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SIZE_GB', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('SIZE_GB - T\1ED5ng dung l\01B0\1EE3ng')),
        TO_CHAR(UNISTR('T\1ED5ng dung l\01B0\1EE3ng l\01B0u tr\1EEF c\1EE7a schema, t\00EDnh b\1EB1ng GB.')),
        TO_CHAR(UNISTR('B\1EB1ng TABLE_GB + INDEX_GB + LOB_GB + ph\1EA7n kh\00E1c; c\00F3 th\1EC3 l\1EC7ch 1 do l\00E0m tr\00F2n.')),
        NULL,
        360);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('TABLE_INDEX_LOB_GB', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, 'TABLE_GB / INDEX_GB / LOB_GB',
        TO_CHAR(UNISTR('Dung l\01B0\1EE3ng t\00E1ch theo lo\1EA1i: d\1EEF li\1EC7u b\1EA3ng, index v\00E0 c\1ED9t d\1EEF li\1EC7u l\1EDBn (LOB).')),
        TO_CHAR(UNISTR('Index chi\1EBFm t\1EF7 l\1EC7 cao b\1EA5t th\01B0\1EDDng so v\1EDBi b\1EA3ng l\00E0 d\1EA5u hi\1EC7u n\00EAn r\00E0 so\00E1t index th\1EEBa.')),
        NULL,
        370);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SEGMENT_COUNT', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('SEGMENT_COUNT - S\1ED1 segment')),
        TO_CHAR(UNISTR('S\1ED1 \0111\01A1n v\1ECB l\01B0u tr\1EEF c\1EE7a schema. M\1ED7i b\1EA3ng, index, partition c\00F3 d\1EEF li\1EC7u l\00E0 m\1ED9t segment.')),
        TO_CHAR(UNISTR('S\1ED1 l\1EDBn cho th\1EA5y b\1EA3ng \0111\01B0\1EE3c chia r\1EA5t nhi\1EC1u partition; \1EA3nh h\01B0\1EDFng t\1ED1c \0111\1ED9 gather stats v\00E0 qu\1EA3n tr\1ECB.')),
        NULL,
        380);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('GROWTH_GB', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('GROWTH_1D_GB / 7D / 30D - M\1EE9c t\0103ng')),
        TO_CHAR(UNISTR('Dung l\01B0\1EE3ng t\0103ng th\00EAm so v\1EDBi 1, 7 v\00E0 30 l\1EA7n \0111o tr\01B0\1EDBc.')),
        TO_CHAR(UNISTR('Tr\1ED1ng khi ch\01B0a \0111\1EE7 s\1ED1 ng\00E0y d\1EEF li\1EC7u. T\0103ng 30 ng\00E0y nh\00E2n 12 cho \01B0\1EDBc l\01B0\1EE3ng nhu c\1EA7u dung l\01B0\1EE3ng m\1ED9t n\0103m.')),
        NULL,
        390);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('IS_LATEST', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, TO_CHAR(UNISTR('IS_LATEST - D\00F2ng m\1EDBi nh\1EA5t')),
        TO_CHAR(UNISTR('Y l\00E0 d\00F2ng c\1EE7a ng\00E0y \0111o g\1EA7n nh\1EA5t.')),
        TO_CHAR(UNISTR('L\1ECDc IS_LATEST = Y \0111\1EC3 xem hi\1EC7n tr\1EA1ng.')),
        NULL,
        400);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('RUN_COLUMNS', TO_CHAR(UNISTR('Ch\1EC9 s\1ED1 v\00E0 c\1ED9t tr\00EAn b\00E1o c\00E1o')), 4, 'CHECKS_OK / WARN / FAIL / ERROR',
        TO_CHAR(UNISTR('S\1ED1 ti\00EAu ch\00ED theo t\1EEBng tr\1EA1ng th\00E1i trong m\1ED9t l\1EA7n ch\1EA1y, m\1ED7i ti\00EAu ch\00ED t\00EDnh theo tr\1EA1ng th\00E1i x\1EA5u nh\1EA5t.')),
        TO_CHAR(UNISTR('ERROR_CHECKS li\1EC7t k\00EA ti\00EAu ch\00ED b\1ECB l\1ED7i v\00E0 l\00FD do.')),
        NULL,
        410);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SCHEMA', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Schema',
        TO_CHAR(UNISTR('M\1ED9t kh\00F4ng gian ch\1EE9a b\1EA3ng, view, package... c\1EE7a m\1ED9t user Oracle. M\1ED7i datamart l\00E0 m\1ED9t schema, v\00ED d\1EE5 RISK_DTM.')),
        NULL,
        NULL,
        420);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('SEGMENT', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Segment',
        TO_CHAR(UNISTR('Ph\1EA7n dung l\01B0\1EE3ng \0111\0129a c\1EA5p cho m\1ED9t b\1EA3ng, index ho\1EB7c partition.')),
        NULL,
        NULL,
        430);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('TABLESPACE', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Tablespace',
        TO_CHAR(UNISTR('V\00F9ng l\01B0u tr\1EEF ch\1EE9a d\1EEF li\1EC7u c\1EE7a c\00E1c schema. Tablespace \0111\1EA7y th\00EC m\1ECDi job ghi v\00E0o \0111\00F3 s\1EBD l\1ED7i.')),
        NULL,
        NULL,
        440);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PARTITION', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Partition',
        TO_CHAR(UNISTR('M\1ED9t ph\1EA7n c\1EE7a b\1EA3ng l\1EDBn \0111\01B0\1EE3c chia theo kh\00F3a, th\01B0\1EDDng l\00E0 theo ng\00E0y d\1EEF li\1EC7u.')),
        TO_CHAR(UNISTR('Gi\00FAp load l\1EA1i m\1ED9t ng\00E0y v\00E0 x\00F3a d\1EEF li\1EC7u c\0169 nhanh m\00E0 kh\00F4ng \0111\1EE5ng ph\1EA7n c\00F2n l\1EA1i.')),
        NULL,
        450);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('INDEX', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Index',
        TO_CHAR(UNISTR('C\1EA5u tr\00FAc gi\00FAp t\00ECm d\00F2ng d\1EEF li\1EC7u nhanh, gi\1ED1ng m\1EE5c l\1EE5c c\1EE7a s\00E1ch.')),
        NULL,
        NULL,
        460);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('LOB', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'LOB',
        TO_CHAR(UNISTR('Ki\1EC3u c\1ED9t ch\1EE9a d\1EEF li\1EC7u l\1EDBn nh\01B0 v\0103n b\1EA3n d\00E0i (CLOB) ho\1EB7c file nh\1ECB ph\00E2n (BLOB).')),
        NULL,
        NULL,
        470);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('INVALID', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Object INVALID',
        TO_CHAR(UNISTR('View, package, procedure... kh\00F4ng bi\00EAn d\1ECBch \0111\01B0\1EE3c, th\01B0\1EDDng do object n\00F3 tham chi\1EBFu b\1ECB \0111\1ED5i ho\1EB7c b\1ECB x\00F3a.')),
        TO_CHAR(UNISTR('B\00E1o c\00E1o ho\1EB7c job g\1ECDi t\1EDBi object INVALID s\1EBD l\1ED7i.')),
        NULL,
        480);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('UNUSABLE', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Index UNUSABLE',
        TO_CHAR(UNISTR('Index ho\1EB7c partition index b\1ECB v\00F4 hi\1EC7u, th\01B0\1EDDng sau khi ETL truncate ho\1EB7c exchange partition m\00E0 kh\00F4ng rebuild.')),
        TO_CHAR(UNISTR('Oracle b\1ECF qua index n\00E0y m\00E0 kh\00F4ng b\00E1o l\1ED7i, n\00EAn truy v\1EA5n ch\1EADm \0111i m\00E0 ng\01B0\1EDDi d\00F9ng kh\00F4ng bi\1EBFt l\00FD do.')),
        NULL,
        490);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('STATS', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Statistics (stats)',
        TO_CHAR(UNISTR('Th\00F4ng tin th\1ED1ng k\00EA v\1EC1 s\1ED1 d\00F2ng, ph\00E2n b\1ED1 d\1EEF li\1EC7u m\00E0 Oracle d\00F9ng \0111\1EC3 ch\1ECDn c\00E1ch ch\1EA1y truy v\1EA5n.')),
        TO_CHAR(UNISTR('Stats c\0169 (STALE) ho\1EB7c ch\01B0a c\00F3 l\00E0m Oracle ch\1ECDn sai c\00E1ch ch\1EA1y, b\00E1o c\00E1o ch\1EADm \0111\1ED9t ng\1ED9t.')),
        NULL,
        500);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('GRANT_ROLE', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Grant / Role',
        TO_CHAR(UNISTR('Grant l\00E0 vi\1EC7c c\1EA5p quy\1EC1n. Role l\00E0 nh\00F3m quy\1EC1n, \0111\01B0\1EE3c c\1EA5p cho nhi\1EC1u ng\01B0\1EDDi c\00F9ng l\00FAc.')),
        TO_CHAR(UNISTR('Nguy\00EAn t\1EAFc: c\1EA5p quy\1EC1n qua role, kh\00F4ng c\1EA5p th\1EB3ng cho t\1EEBng c\00E1 nh\00E2n.')),
        NULL,
        510);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('ANY_PRIV', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, TO_CHAR(UNISTR('Quy\1EC1n ANY')),
        TO_CHAR(UNISTR('Quy\1EC1n h\1EC7 th\1ED1ng t\00E1c \0111\1ED9ng l\00EAn m\1ECDi schema, v\00ED d\1EE5 SELECT ANY TABLE, DROP ANY TABLE.')),
        TO_CHAR(UNISTR('R\1EE7i ro cao v\00EC v\01B0\1EE3t qua m\1ECDi ranh gi\1EDBi gi\1EEFa c\00E1c mart.')),
        NULL,
        520);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('PUBLIC', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'PUBLIC',
        TO_CHAR(UNISTR('Nh\00F3m \0111\1EB7c bi\1EC7t \0111\1EA1i di\1EC7n cho m\1ECDi user trong database.')),
        TO_CHAR(UNISTR('C\1EA5p quy\1EC1n cho PUBLIC ngh\0129a l\00E0 ai c\0169ng \0111\1ECDc \0111\01B0\1EE3c.')),
        NULL,
        530);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('DDL', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'DDL',
        TO_CHAR(UNISTR('C\00E2u l\1EC7nh thay \0111\1ED5i c\1EA5u tr\00FAc: CREATE, ALTER, DROP, TRUNCATE, GRANT...')),
        TO_CHAR(UNISTR('DDL tr\00EAn production ph\1EA3i \0111i qua quy tr\00ECnh review v\00E0 deploy.')),
        NULL,
        540);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('DEPENDENCY', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, TO_CHAR(UNISTR('Ph\1EE5 thu\1ED9c (dependency)')),
        TO_CHAR(UNISTR('Quan h\1EC7 m\1ED9t object d\00F9ng object kh\00E1c, v\00ED d\1EE5 view \0111\1ECDc t\1EEB b\1EA3ng.')),
        TO_CHAR(UNISTR('Ph\1EE5 thu\1ED9c gi\1EEFa hai mart nghi\1EC7p v\1EE5 l\00E0 vi ph\1EA1m ki\1EBFn tr\00FAc bounded context.')),
        NULL,
        550);

INSERT INTO bi_dtm.mon_glossary (term_code, term_group, group_order, term_name, definition, how_to_read, example, display_order)
VALUES ('COMMENT', TO_CHAR(UNISTR('Thu\1EADt ng\1EEF Oracle')), 5, 'Comment',
        TO_CHAR(UNISTR('M\00F4 t\1EA3 l\01B0u ngay trong database cho b\1EA3ng v\00E0 c\1ED9t (COMMENT ON TABLE / COLUMN).')),
        TO_CHAR(UNISTR('B\1EA3ng c\00F4ng b\1ED1 ph\1EA3i c\00F3 comment ghi r\00F5 grain, ngu\1ED3n v\00E0 t\1EA7n su\1EA5t load.')),
        NULL,
        560);

COMMIT;


/* =====================================================================
   3. VIEW CHO OAS
      Tieu chi va schema lay truc tiep tu MON_CHECK_DEF, MON_SCHEMA_DEF:
      sua nguong / them tieu chi / them schema thi trang thuat ngu tu dung.
   ===================================================================== */
CREATE OR REPLACE VIEW bi_dtm.vw_oas_mon_glossary AS
SELECT CAST(g.term_group AS VARCHAR2(100 CHAR))   AS term_group,
       g.group_order,
       CAST(g.term_code  AS VARCHAR2(50))          AS term_code,
       CAST(g.term_name  AS VARCHAR2(200 CHAR))    AS term_name,
       CAST(g.definition AS VARCHAR2(1000 CHAR))   AS definition,
       CAST(g.how_to_read AS VARCHAR2(1000 CHAR))  AS how_to_read,
       CAST(g.example    AS VARCHAR2(1000 CHAR))   AS example,
       g.display_order
FROM   bi_dtm.mon_glossary g
WHERE  g.is_active = 'Y'
UNION ALL
SELECT CAST(TO_CHAR(UNISTR('Ti\00EAu ch\00ED gi\00E1m s\00E1t')) AS VARCHAR2(100 CHAR)),
       6,
       CAST(c.check_code AS VARCHAR2(50)),
       CAST(c.check_code || ' - ' || c.check_name AS VARCHAR2(200 CHAR)),
       CAST(c.description AS VARCHAR2(1000 CHAR)),
       CAST(SUBSTR(
           CASE
               WHEN c.warn_threshold IS NULL AND c.fail_threshold IS NULL
                    THEN TO_CHAR(UNISTR('Ch\1EC9 theo d\00F5i (INFO), kh\00F4ng \0111\1EB7t ng\01B0\1EE1ng.'))
               WHEN c.warn_threshold IS NULL
                    THEN TO_CHAR(UNISTR('FAIL khi gi\00E1 tr\1ECB >= ')) || TO_CHAR(c.fail_threshold) || ' ' || c.metric_unit || '.'
               WHEN c.fail_threshold IS NULL
                    THEN TO_CHAR(UNISTR('WARN khi gi\00E1 tr\1ECB >= ')) || TO_CHAR(c.warn_threshold) || ' ' || c.metric_unit || '.'
               ELSE TO_CHAR(UNISTR('WARN khi gi\00E1 tr\1ECB >= ')) || TO_CHAR(c.warn_threshold)
                    || '; FAIL khi >= ' || TO_CHAR(c.fail_threshold) || ' ' || c.metric_unit || '.'
           END || TO_CHAR(UNISTR(' X\1EED l\00FD: ')) || c.action_guide, 1, 1000) AS VARCHAR2(1000 CHAR)),
       CAST(TO_CHAR(UNISTR('Nh\00F3m: ')) || c.check_group || TO_CHAR(UNISTR('. \0110\01A1n v\1ECB: ')) || c.metric_unit AS VARCHAR2(1000 CHAR)),
       1000 + NVL(c.display_order, 999)
FROM   bi_dtm.mon_check_def c
WHERE  c.is_active = 'Y'
UNION ALL
SELECT CAST(TO_CHAR(UNISTR('Danh s\00E1ch schema')) AS VARCHAR2(100 CHAR)),
       7,
       CAST(s.schema_name AS VARCHAR2(50)),
       CAST(s.schema_name AS VARCHAR2(200 CHAR)),
       CAST(NVL(s.business_domain, s.schema_name) AS VARCHAR2(1000 CHAR)),
       CAST(CASE s.zone_type
                WHEN 'SOURCE'  THEN TO_CHAR(UNISTR('V\00F9ng ngu\1ED3n chung: c\00E1c mart ch\1EC9 l\1EA5y d\1EEF li\1EC7u d\00F9ng chung t\1EEB \0111\00E2y.'))
                WHEN 'MART'    THEN TO_CHAR(UNISTR('Mart nghi\1EC7p v\1EE5 \0111\1ED9c l\1EADp: ch\1EC9 \0111\1ECDc v\00F9ng ngu\1ED3n chung, kh\00F4ng \0111\1ECDc mart kh\00E1c.'))
                WHEN 'SANDBOX' THEN TO_CHAR(UNISTR('V\00F9ng th\1EED nghi\1EC7m: production kh\00F4ng \0111\01B0\1EE3c ph\1EE5 thu\1ED9c v\00E0o v\00F9ng n\00E0y.'))
            END AS VARCHAR2(1000 CHAR)),
       CAST(TO_CHAR(UNISTR('V\00F9ng: ')) || s.zone_type AS VARCHAR2(1000 CHAR)),
       2000 + CASE s.zone_type WHEN 'SOURCE' THEN 0 WHEN 'MART' THEN 100 ELSE 200 END
            + ROW_NUMBER() OVER (PARTITION BY s.zone_type ORDER BY s.schema_name)
FROM   bi_dtm.mon_schema_def s
WHERE  s.is_active = 'Y';

COMMENT ON TABLE bi_dtm.vw_oas_mon_glossary IS 'OAS view: glossary page (manual terms + checks + schemas).';


/* =====================================================================
   4. QUYEN CHO OAS
   ===================================================================== */
GRANT SELECT ON bi_dtm.vw_oas_mon_glossary TO bi_dtm_mon_read;


/* =====================================================================
   5. KIEM TRA
   ===================================================================== */
-- So thuat ngu theo nhom (mong doi: 5 nhom viet tay + nhom tieu chi + nhom schema)
SELECT group_order, term_group, COUNT(*) AS so_thuat_ngu
FROM   bi_dtm.vw_oas_mon_glossary
GROUP BY group_order, term_group
ORDER BY group_order;

-- Khong con dau '?' (mong doi: 0 dong)
SELECT term_code, term_name
FROM   bi_dtm.vw_oas_mon_glossary
WHERE  INSTR(term_group || term_name || definition || how_to_read || example, '?') > 0;
