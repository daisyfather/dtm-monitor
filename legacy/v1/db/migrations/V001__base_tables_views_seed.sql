-- ascii-check: skip  (ban goc da deploy ngay 2026-10-21; chuoi tieng Viet duoc ghi lai bang UNISTR o V003)
/* =====================================================================
   BI_DTM MONITOR - DDL
   Mục đích : Lưu kết quả giám sát hằng ngày các schema DTM để kéo lên OAS
   Schema   : BI_DTM
   Phiên bản: 1.0 - 2026-10-21
   Oracle   : 19c (dùng identity column, interval partitioning)

   Mô hình dữ liệu
   ---------------------------------------------------------------------
   MON_SCHEMA_DEF        Danh mục schema được giám sát (không hardcode LIKE '%_DTM')
   MON_CHECK_DEF         Danh mục tiêu chí giám sát + ngưỡng cảnh báo
   MON_RUN_LOG           1 dòng / 1 lần chạy package
   MON_CHECK_RESULT      1 dòng / ngày / tiêu chí / schema  -> KPI, xu hướng trên OAS
   MON_CHECK_DETAIL      1 dòng / object vi phạm             -> drill-down trên OAS
   MON_SCHEMA_SIZE_DAILY Dung lượng theo ngày / schema / loại segment / tablespace

   Quy ước
   ---------------------------------------------------------------------
   - SNAPSHOT_DATE = ngày chạy giám sát (TRUNC(SYSDATE)), là khóa partition.
   - Chạy lại cùng ngày: package xóa dữ liệu của SNAPSHOT_DATE đó rồi ghi lại
     (idempotent), RUN_ID mới.
   - STATUS của một tiêu chí: OK / WARN / FAIL / INFO / ERROR
       ERROR = bản thân câu kiểm tra bị lỗi, KHÔNG phải dữ liệu có vấn đề.
       Lỗi của một tiêu chí không làm dừng các tiêu chí khác.
   - Ngưỡng: METRIC_VALUE >= FAIL_THRESHOLD -> FAIL,
             METRIC_VALUE >= WARN_THRESHOLD -> WARN, còn lại OK.
             Không có ngưỡng -> INFO.
   ===================================================================== */


/* =====================================================================
   0. QUYỀN CẦN CẤP CHO BI_DTM (DBA chạy, cấp TRỰC TIẾP, không qua role)
      Package definer rights không dùng được quyền nhận qua role,
      nên SELECT_CATALOG_ROLE là không đủ.
   ===================================================================== */
-- GRANT SELECT ANY DICTIONARY TO bi_dtm;
-- Hoặc tối thiểu từng view:
-- GRANT SELECT ON sys.dba_objects                   TO bi_dtm;
-- GRANT SELECT ON sys.dba_segments                  TO bi_dtm;
-- GRANT SELECT ON sys.dba_tab_privs                 TO bi_dtm;
-- GRANT SELECT ON sys.dba_sys_privs                 TO bi_dtm;
-- GRANT SELECT ON sys.dba_users                     TO bi_dtm;
-- GRANT SELECT ON sys.dba_tables                    TO bi_dtm;
-- GRANT SELECT ON sys.dba_tab_comments              TO bi_dtm;
-- GRANT SELECT ON sys.dba_tab_statistics            TO bi_dtm;
-- GRANT SELECT ON sys.dba_dependencies              TO bi_dtm;
-- GRANT SELECT ON sys.dba_indexes                   TO bi_dtm;
-- GRANT SELECT ON sys.dba_ind_partitions            TO bi_dtm;
-- GRANT SELECT ON sys.dba_tablespace_usage_metrics  TO bi_dtm;


/* =====================================================================
   1. MON_SCHEMA_DEF - Danh mục schema được giám sát
   ===================================================================== */
CREATE TABLE bi_dtm.mon_schema_def (
    schema_name      VARCHAR2(128)       NOT NULL,
    zone_type        VARCHAR2(20)        NOT NULL,
    business_domain  VARCHAR2(200 CHAR),
    owner_team       VARCHAR2(200 CHAR),
    is_active        CHAR(1)   DEFAULT 'Y' NOT NULL,
    created_ts       TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    updated_ts       TIMESTAMP,
    CONSTRAINT pk_mon_schema_def PRIMARY KEY (schema_name),
    CONSTRAINT ck_mon_schema_def_zone   CHECK (zone_type IN ('SOURCE','MART','SANDBOX')),
    CONSTRAINT ck_mon_schema_def_active CHECK (is_active IN ('Y','N'))
);

COMMENT ON TABLE  bi_dtm.mon_schema_def IS 'Danh mục schema được giám sát. Grain: 1 dòng = 1 schema.';
COMMENT ON COLUMN bi_dtm.mon_schema_def.zone_type IS 'SOURCE = vùng nguồn chung (STG_DTM); MART = bounded context; SANDBOX = vùng thử nghiệm';
COMMENT ON COLUMN bi_dtm.mon_schema_def.business_domain IS 'Lĩnh vực nghiệp vụ của schema';
COMMENT ON COLUMN bi_dtm.mon_schema_def.is_active IS 'Y = đang giám sát';


/* =====================================================================
   2. MON_CHECK_DEF - Danh mục tiêu chí giám sát
   ===================================================================== */
CREATE TABLE bi_dtm.mon_check_def (
    check_code       VARCHAR2(50)        NOT NULL,
    check_name       VARCHAR2(200 CHAR)  NOT NULL,
    check_group      VARCHAR2(30)        NOT NULL,
    metric_unit      VARCHAR2(30)        NOT NULL,
    warn_threshold   NUMBER,
    fail_threshold   NUMBER,
    has_detail       CHAR(1)   DEFAULT 'Y' NOT NULL,
    is_active        CHAR(1)   DEFAULT 'Y' NOT NULL,
    display_order    NUMBER(5),
    description      VARCHAR2(1000 CHAR),
    action_guide     VARCHAR2(1000 CHAR),
    created_ts       TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    updated_ts       TIMESTAMP,
    CONSTRAINT pk_mon_check_def PRIMARY KEY (check_code),
    CONSTRAINT ck_mon_check_def_group  CHECK (check_group IN
        ('STORAGE','OBJECT','SECURITY','CHANGE','PERFORMANCE','ARCHITECTURE','METADATA')),
    CONSTRAINT ck_mon_check_def_detail CHECK (has_detail IN ('Y','N')),
    CONSTRAINT ck_mon_check_def_active CHECK (is_active  IN ('Y','N')),
    CONSTRAINT ck_mon_check_def_thres  CHECK (
        warn_threshold IS NULL OR fail_threshold IS NULL OR warn_threshold <= fail_threshold)
);

COMMENT ON TABLE  bi_dtm.mon_check_def IS 'Danh mục tiêu chí giám sát và ngưỡng. Grain: 1 dòng = 1 tiêu chí.';
COMMENT ON COLUMN bi_dtm.mon_check_def.check_group IS 'Nhóm tiêu chí, dùng để nhóm trên dashboard OAS';
COMMENT ON COLUMN bi_dtm.mon_check_def.metric_unit IS 'Đơn vị của METRIC_VALUE: COUNT, MB, PCT...';
COMMENT ON COLUMN bi_dtm.mon_check_def.warn_threshold IS 'METRIC_VALUE >= ngưỡng này -> WARN. NULL cùng FAIL_THRESHOLD -> INFO';
COMMENT ON COLUMN bi_dtm.mon_check_def.fail_threshold IS 'METRIC_VALUE >= ngưỡng này -> FAIL';
COMMENT ON COLUMN bi_dtm.mon_check_def.has_detail IS 'Y = có ghi chi tiết object vào MON_CHECK_DETAIL';
COMMENT ON COLUMN bi_dtm.mon_check_def.action_guide IS 'Hướng xử lý khi tiêu chí WARN/FAIL';


/* =====================================================================
   3. MON_RUN_LOG - Nhật ký mỗi lần chạy package
   ===================================================================== */
CREATE TABLE bi_dtm.mon_run_log (
    run_id           NUMBER GENERATED ALWAYS AS IDENTITY,
    snapshot_date    DATE                NOT NULL,
    start_ts         TIMESTAMP           NOT NULL,
    end_ts           TIMESTAMP,
    run_status       VARCHAR2(20)        NOT NULL,
    checks_total     NUMBER(5),
    checks_ok        NUMBER(5),
    checks_warn      NUMBER(5),
    checks_fail      NUMBER(5),
    checks_error     NUMBER(5),
    triggered_by     VARCHAR2(30)  DEFAULT 'AIRFLOW' NOT NULL,
    db_user          VARCHAR2(128) DEFAULT SYS_CONTEXT('USERENV','SESSION_USER') NOT NULL,
    error_msg        VARCHAR2(4000 CHAR),
    CONSTRAINT pk_mon_run_log PRIMARY KEY (run_id),
    CONSTRAINT ck_mon_run_log_status CHECK (run_status IN ('RUNNING','SUCCESS','PARTIAL','FAILED'))
);

CREATE INDEX bi_dtm.ix_mon_run_log_date ON bi_dtm.mon_run_log (snapshot_date);

COMMENT ON TABLE  bi_dtm.mon_run_log IS 'Nhật ký chạy package giám sát. Grain: 1 dòng = 1 lần chạy.';
COMMENT ON COLUMN bi_dtm.mon_run_log.run_status IS 'SUCCESS = mọi tiêu chí chạy được; PARTIAL = có tiêu chí ERROR; FAILED = package dừng giữa chừng';
COMMENT ON COLUMN bi_dtm.mon_run_log.checks_error IS 'Số tiêu chí mà câu kiểm tra bị lỗi (không phải số vi phạm)';
COMMENT ON COLUMN bi_dtm.mon_run_log.triggered_by IS 'AIRFLOW / SCHEDULER / MANUAL';


/* =====================================================================
   4. MON_CHECK_RESULT - Kết quả tổng hợp
      Grain: 1 ngày / 1 tiêu chí / 1 schema
      Tiêu chí cấp database (vd tablespace) dùng SCHEMA_NAME = '_ALL_'
   ===================================================================== */
CREATE TABLE bi_dtm.mon_check_result (
    snapshot_date    DATE                NOT NULL,
    check_code       VARCHAR2(50)        NOT NULL,
    schema_name      VARCHAR2(128)       NOT NULL,
    run_id           NUMBER              NOT NULL,
    metric_value     NUMBER,
    warn_threshold   NUMBER,
    fail_threshold   NUMBER,
    check_status     VARCHAR2(10)        NOT NULL,
    prev_value       NUMBER,
    delta_value      NUMBER,
    elapsed_sec      NUMBER(10,3),
    error_msg        VARCHAR2(4000 CHAR),
    load_ts          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT ck_mon_check_result_status CHECK (check_status IN ('OK','WARN','FAIL','INFO','ERROR')),
    CONSTRAINT fk_mon_check_result_check  FOREIGN KEY (check_code) REFERENCES bi_dtm.mon_check_def (check_code),
    CONSTRAINT fk_mon_check_result_run    FOREIGN KEY (run_id)     REFERENCES bi_dtm.mon_run_log (run_id)
)
PARTITION BY RANGE (snapshot_date) INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION p_init VALUES LESS THAN (DATE '2026-10-01')
);

CREATE UNIQUE INDEX bi_dtm.ux_mon_check_result
    ON bi_dtm.mon_check_result (snapshot_date, check_code, schema_name) LOCAL;

ALTER TABLE bi_dtm.mon_check_result
    ADD CONSTRAINT pk_mon_check_result PRIMARY KEY (snapshot_date, check_code, schema_name)
    USING INDEX bi_dtm.ux_mon_check_result;

COMMENT ON TABLE  bi_dtm.mon_check_result IS 'Kết quả giám sát hằng ngày. Grain: 1 dòng = 1 ngày / 1 tiêu chí / 1 schema. Nguồn chính cho dashboard OAS.';
COMMENT ON COLUMN bi_dtm.mon_check_result.schema_name IS 'Schema được giám sát; _ALL_ cho tiêu chí cấp database';
COMMENT ON COLUMN bi_dtm.mon_check_result.metric_value IS 'Giá trị đo, đơn vị theo MON_CHECK_DEF.METRIC_UNIT';
COMMENT ON COLUMN bi_dtm.mon_check_result.warn_threshold IS 'Ngưỡng tại thời điểm chạy (lưu lại để lịch sử không đổi khi sửa ngưỡng)';
COMMENT ON COLUMN bi_dtm.mon_check_result.prev_value IS 'METRIC_VALUE của lần chạy thành công gần nhất trước đó';
COMMENT ON COLUMN bi_dtm.mon_check_result.delta_value IS 'METRIC_VALUE - PREV_VALUE';
COMMENT ON COLUMN bi_dtm.mon_check_result.check_status IS 'OK / WARN / FAIL / INFO / ERROR (ERROR = câu kiểm tra lỗi)';
COMMENT ON COLUMN bi_dtm.mon_check_result.error_msg IS 'SQLERRM khi CHECK_STATUS = ERROR';


/* =====================================================================
   5. MON_CHECK_DETAIL - Chi tiết object vi phạm (drill-down)
      Cột dùng chung cho mọi tiêu chí; cột nào không áp dụng để NULL.
   ===================================================================== */
CREATE TABLE bi_dtm.mon_check_detail (
    snapshot_date    DATE                NOT NULL,
    check_code       VARCHAR2(50)        NOT NULL,
    schema_name      VARCHAR2(128)       NOT NULL,
    run_id           NUMBER              NOT NULL,
    detail_seq       NUMBER              NOT NULL,
    object_type      VARCHAR2(30),
    object_name      VARCHAR2(128),
    sub_object_name  VARCHAR2(128),
    grantee          VARCHAR2(128),
    privilege_name   VARCHAR2(100),
    ref_schema       VARCHAR2(128),
    ref_object_name  VARCHAR2(128),
    ref_object_type  VARCHAR2(30),
    num_value        NUMBER,
    event_time       DATE,
    detail_msg       VARCHAR2(1000 CHAR),
    load_ts          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT fk_mon_check_detail_check FOREIGN KEY (check_code) REFERENCES bi_dtm.mon_check_def (check_code),
    CONSTRAINT fk_mon_check_detail_run   FOREIGN KEY (run_id)     REFERENCES bi_dtm.mon_run_log (run_id)
)
PARTITION BY RANGE (snapshot_date) INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION p_init VALUES LESS THAN (DATE '2026-10-01')
);

CREATE INDEX bi_dtm.ix_mon_check_detail
    ON bi_dtm.mon_check_detail (snapshot_date, check_code, schema_name) LOCAL;

COMMENT ON TABLE  bi_dtm.mon_check_detail IS 'Chi tiết object vi phạm. Grain: 1 dòng = 1 ngày / 1 tiêu chí / 1 object (hoặc 1 grant, 1 phụ thuộc).';
COMMENT ON COLUMN bi_dtm.mon_check_detail.detail_seq IS 'Số thứ tự dòng trong cùng ngày / tiêu chí / schema';
COMMENT ON COLUMN bi_dtm.mon_check_detail.sub_object_name IS 'Partition, subpartition hoặc cột tùy tiêu chí';
COMMENT ON COLUMN bi_dtm.mon_check_detail.grantee IS 'Người/role nhận quyền (tiêu chí SECURITY)';
COMMENT ON COLUMN bi_dtm.mon_check_detail.ref_schema IS 'Schema được tham chiếu (tiêu chí CROSS_MART_DEP)';
COMMENT ON COLUMN bi_dtm.mon_check_detail.num_value IS 'Giá trị số của object (MB, số ngày, % ...)';
COMMENT ON COLUMN bi_dtm.mon_check_detail.event_time IS 'Thời điểm liên quan: LAST_DDL_TIME, LAST_ANALYZED, EXPIRY_DATE...';


/* =====================================================================
   6. MON_SCHEMA_SIZE_DAILY - Dung lượng theo ngày (xu hướng tăng trưởng)
   ===================================================================== */
CREATE TABLE bi_dtm.mon_schema_size_daily (
    snapshot_date    DATE                NOT NULL,
    schema_name      VARCHAR2(128)       NOT NULL,
    tablespace_name  VARCHAR2(30)        NOT NULL,
    segment_group    VARCHAR2(20)        NOT NULL,
    size_mb          NUMBER(18,2)        NOT NULL,
    segment_count    NUMBER(10)          NOT NULL,
    run_id           NUMBER              NOT NULL,
    load_ts          TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT ck_mon_size_group CHECK (segment_group IN ('TABLE','INDEX','LOB','OTHER')),
    CONSTRAINT fk_mon_size_run   FOREIGN KEY (run_id) REFERENCES bi_dtm.mon_run_log (run_id)
)
PARTITION BY RANGE (snapshot_date) INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(
    PARTITION p_init VALUES LESS THAN (DATE '2026-10-01')
);

CREATE UNIQUE INDEX bi_dtm.ux_mon_schema_size_daily
    ON bi_dtm.mon_schema_size_daily (snapshot_date, schema_name, tablespace_name, segment_group) LOCAL;

COMMENT ON TABLE  bi_dtm.mon_schema_size_daily IS 'Dung lượng theo ngày. Grain: 1 dòng = 1 ngày / 1 schema / 1 tablespace / 1 nhóm segment.';
COMMENT ON COLUMN bi_dtm.mon_schema_size_daily.segment_group IS 'TABLE (gồm TABLE PARTITION/SUBPARTITION), INDEX (gồm partition), LOB, OTHER';
COMMENT ON COLUMN bi_dtm.mon_schema_size_daily.size_mb IS 'SUM(BYTES)/1024/1024 từ DBA_SEGMENTS';


/* =====================================================================
   7. VIEW CHO OAS
      OAS chỉ đọc qua các view này, không đọc bảng trực tiếp.
   ===================================================================== */

-- 7.1 Kết quả đầy đủ kèm tên tiêu chí, nghiệp vụ schema
CREATE OR REPLACE VIEW bi_dtm.vw_mon_result AS
SELECT r.snapshot_date,
       r.check_code,
       c.check_name,
       c.check_group,
       c.metric_unit,
       c.display_order,
       r.schema_name,
       s.zone_type,
       s.business_domain,
       r.metric_value,
       r.prev_value,
       r.delta_value,
       r.warn_threshold,
       r.fail_threshold,
       r.check_status,
       CASE r.check_status
            WHEN 'FAIL'  THEN 1
            WHEN 'ERROR' THEN 2
            WHEN 'WARN'  THEN 3
            WHEN 'OK'    THEN 4
            ELSE 5
       END                       AS status_sort,
       c.action_guide,
       r.error_msg,
       r.run_id,
       r.load_ts
FROM   bi_dtm.mon_check_result r
JOIN   bi_dtm.mon_check_def    c ON c.check_code  = r.check_code
LEFT JOIN bi_dtm.mon_schema_def s ON s.schema_name = r.schema_name;

COMMENT ON TABLE bi_dtm.vw_mon_result IS 'View công bố cho OAS: kết quả giám sát theo ngày, kèm tên tiêu chí và nghiệp vụ schema.';

-- 7.2 Trạng thái mới nhất (trang tổng quan)
CREATE OR REPLACE VIEW bi_dtm.vw_mon_latest AS
SELECT v.*
FROM   bi_dtm.vw_mon_result v
WHERE  v.snapshot_date = (SELECT MAX(snapshot_date) FROM bi_dtm.mon_check_result);

COMMENT ON TABLE bi_dtm.vw_mon_latest IS 'View công bố cho OAS: kết quả của ngày giám sát gần nhất.';

-- 7.3 Chi tiết vi phạm
CREATE OR REPLACE VIEW bi_dtm.vw_mon_detail AS
SELECT d.snapshot_date,
       d.check_code,
       c.check_name,
       c.check_group,
       d.schema_name,
       s.business_domain,
       d.object_type,
       d.object_name,
       d.sub_object_name,
       d.grantee,
       d.privilege_name,
       d.ref_schema,
       d.ref_object_name,
       d.ref_object_type,
       d.num_value,
       d.event_time,
       d.detail_msg,
       d.run_id
FROM   bi_dtm.mon_check_detail d
JOIN   bi_dtm.mon_check_def    c ON c.check_code  = d.check_code
LEFT JOIN bi_dtm.mon_schema_def s ON s.schema_name = d.schema_name;

COMMENT ON TABLE bi_dtm.vw_mon_detail IS 'View công bố cho OAS: chi tiết object vi phạm để drill-down.';

-- 7.4 Dung lượng
CREATE OR REPLACE VIEW bi_dtm.vw_mon_size AS
SELECT z.snapshot_date,
       z.schema_name,
       s.zone_type,
       s.business_domain,
       z.tablespace_name,
       z.segment_group,
       z.size_mb,
       ROUND(z.size_mb / 1024, 2) AS size_gb,
       z.segment_count
FROM   bi_dtm.mon_schema_size_daily z
LEFT JOIN bi_dtm.mon_schema_def s ON s.schema_name = z.schema_name;

COMMENT ON TABLE bi_dtm.vw_mon_size IS 'View công bố cho OAS: dung lượng theo ngày / schema / tablespace.';

-- 7.5 Nhật ký chạy
CREATE OR REPLACE VIEW bi_dtm.vw_mon_run AS
SELECT run_id,
       snapshot_date,
       start_ts,
       end_ts,
       ROUND((CAST(end_ts AS DATE) - CAST(start_ts AS DATE)) * 86400) AS elapsed_sec,
       run_status,
       checks_total,
       checks_ok,
       checks_warn,
       checks_fail,
       checks_error,
       triggered_by,
       error_msg
FROM   bi_dtm.mon_run_log;

COMMENT ON TABLE bi_dtm.vw_mon_run IS 'View công bố cho OAS: nhật ký chạy package giám sát.';


/* =====================================================================
   8. DỮ LIỆU KHỞI TẠO
   ===================================================================== */

-- 8.1 Schema được giám sát (BI_DTM không nằm trong danh sách)
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('STG_DTM',    'SOURCE',  'Phái sinh T-1 của SB_DWH, nguồn conformed dimension');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('ENT_DTM',    'MART',    'Enterprise');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('RETAIL_DTM', 'MART',    'Khách hàng cá nhân');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('CNL_DTM',    'MART',    'Pháp chế, tuân thủ');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('RISK_DTM',   'MART',    'Rủi ro');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('OPS_DTM',    'MART',    'Vận hành');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('CAP_DTM',    'MART',    'Phê duyệt tín dụng');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('FIN_DTM',    'MART',    'Tài chính, kế toán');
INSERT INTO bi_dtm.mon_schema_def (schema_name, zone_type, business_domain) VALUES ('SND_DTM',    'SANDBOX', 'Sandbox');

-- 8.2 Tiêu chí giám sát (ngưỡng là đề xuất ban đầu, chỉnh sau 2-4 tuần chạy thực tế)
INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('SCHEMA_SIZE', 'Dung lượng schema', 'STORAGE', 'MB', NULL, NULL, 'N', 10,
        'Tổng dung lượng segment của schema, chi tiết ở MON_SCHEMA_SIZE_DAILY',
        'Theo dõi tốc độ tăng; tăng đột biến thì kiểm tra retention và load trùng');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('TS_USAGE_PCT', 'Tỷ lệ sử dụng tablespace', 'STORAGE', 'PCT', 85, 95, 'Y', 20,
        'Tỷ lệ % đã dùng của tablespace chứa dữ liệu các DTM (SCHEMA_NAME = _ALL_)',
        'Báo DBA thêm datafile hoặc dọn partition cũ');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('INVALID_OBJ', 'Object INVALID', 'OBJECT', 'COUNT', 1, 5, 'Y', 30,
        'Số object có STATUS = INVALID',
        'Recompile; nếu vẫn lỗi thì kiểm tra thay đổi DDL gần nhất của object được tham chiếu');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('UNUSABLE_INDEX', 'Index / partition index UNUSABLE', 'OBJECT', 'COUNT', NULL, 1, 'Y', 40,
        'Số index hoặc partition index ở trạng thái UNUSABLE',
        'Rebuild index; kiểm tra job có truncate/exchange partition mà không UPDATE INDEXES');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('STALE_STATS', 'Bảng / partition có stats cũ hoặc chưa có', 'PERFORMANCE', 'COUNT', 10, 50, 'Y', 50,
        'Số bảng/partition có STALE_STATS = YES hoặc LAST_ANALYZED IS NULL',
        'Bổ sung bước gather stats sau load cho bảng liên quan');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('DIRECT_GRANT_USER', 'Quyền object cấp thẳng cho user', 'SECURITY', 'COUNT', 1, NULL, 'Y', 60,
        'Số quyền trên object của schema cấp thẳng cho user (không qua role)',
        'Chuyển sang role <DTM>_READ / _WRITE rồi thu hồi bản cấp thẳng; ngoại lệ hợp lệ: grant cho schema owner mart đọc STG_DTM');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('INTERNAL_OBJ_GRANTED', 'Bảng nội bộ bị cấp quyền ra ngoài', 'SECURITY', 'COUNT', 1, NULL, 'Y', 70,
        'Số quyền trên bảng STG_/TWT_/TMP_ cấp cho user hoặc role ngoài ETL của chính mart',
        'Thu hồi; nếu team khác cần dữ liệu thì tạo VW_ công bố');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('ANY_PRIV_HOLDER', 'Tài khoản giữ quyền ANY', 'SECURITY', 'COUNT', 1, NULL, 'Y', 80,
        'Số quyền hệ thống dạng % ANY % đang cấp cho user/role liên quan DTM (SCHEMA_NAME = _ALL_)',
        'Rà soát, thu gọn về mức tối thiểu; BI_DTM ghi nhận làm ngoại lệ có duyệt');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('USER_PWD_EXPIRY', 'Tài khoản sắp hết hạn mật khẩu / bị khóa', 'SECURITY', 'COUNT', 1, NULL, 'Y', 90,
        'Số tài khoản schema/ETL hết hạn mật khẩu trong 14 ngày tới, hoặc đang EXPIRED / LOCKED ngoài dự kiến',
        'Đổi mật khẩu và cập nhật connection Airflow/ODI trước ngày hết hạn');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('DDL_CHANGE_1D', 'Object thay đổi DDL trong ngày', 'CHANGE', 'COUNT', NULL, NULL, 'Y', 100,
        'Số object có LAST_DDL_TIME trong 24 giờ qua',
        'Đối chiếu với danh sách deploy đã duyệt; DDL ngoài quy trình thì truy vết qua audit');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('CROSS_MART_DEP', 'Phụ thuộc chéo giữa các mart', 'ARCHITECTURE', 'COUNT', NULL, 1, 'Y', 110,
        'Số phụ thuộc từ object của mart này sang mart khác (tham chiếu tới zone SOURCE là hợp lệ)',
        'Vi phạm bounded context: chuyển dữ liệu dùng chung về STG_DTM hoặc xin duyệt ngoại lệ qua VW_');

INSERT INTO bi_dtm.mon_check_def (check_code, check_name, check_group, metric_unit, warn_threshold, fail_threshold, has_detail, display_order, description, action_guide)
VALUES ('MISSING_COMMENT', 'Bảng công bố thiếu comment', 'METADATA', 'COUNT', 1, NULL, 'Y', 120,
        'Số bảng FCT_/DIM_/AGG_ chưa có COMMENT ON TABLE',
        'Bổ sung comment ghi grain, nguồn, tần suất load');

COMMIT;


/* =====================================================================
   9. QUYỀN ĐỌC CHO OAS
   ===================================================================== */
CREATE ROLE bi_dtm_mon_read;

GRANT SELECT ON bi_dtm.vw_mon_result TO bi_dtm_mon_read;
GRANT SELECT ON bi_dtm.vw_mon_latest TO bi_dtm_mon_read;
GRANT SELECT ON bi_dtm.vw_mon_detail TO bi_dtm_mon_read;
GRANT SELECT ON bi_dtm.vw_mon_size   TO bi_dtm_mon_read;
GRANT SELECT ON bi_dtm.vw_mon_run    TO bi_dtm_mon_read;

-- GRANT bi_dtm_mon_read TO <oas_connection_user>;


/* =====================================================================
   10. RETENTION (gợi ý, chạy trong package hoặc job hằng tháng)
       MON_CHECK_RESULT, MON_SCHEMA_SIZE_DAILY : giữ 24 tháng
       MON_CHECK_DETAIL                        : giữ 3 tháng
       -> ALTER TABLE ... DROP PARTITION FOR (DATE 'yyyy-mm-01') UPDATE INDEXES;
   ===================================================================== */
