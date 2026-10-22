/* =====================================================================
   BI_DTM.PKG_DTM_MONITOR
   Thu thập chỉ tiêu giám sát các schema DTM, ghi vào MON_* để OAS đọc.
   Phiên bản: 1.2 - 2026-10-22 (tiêu chí chỉ áp dụng cho MART không ghi 0 cho vùng khác)

   Cách chạy hằng ngày (Airflow / DBMS_SCHEDULER):
       BEGIN bi_dtm.pkg_dtm_monitor.run_daily; END;

   Chạy lại 1 tiêu chí để debug:
       BEGIN bi_dtm.pkg_dtm_monitor.run_check('INVALID_OBJ'); END;

   Nguyên tắc:
   - Mỗi tiêu chí chạy độc lập, COMMIT riêng. Tiêu chí lỗi -> ghi ERROR,
     các tiêu chí khác vẫn chạy tiếp. Run log = PARTIAL.
   - Run log ghi bằng autonomous transaction, không mất khi rollback.
   - Chạy lại cùng ngày: xóa dữ liệu của SNAPSHOT_DATE rồi ghi lại.
   - Chỉ raise lỗi ra ngoài (để Airflow báo fail) khi cả package dừng
     giữa chừng (FAILED). PARTIAL không raise.
   ===================================================================== */

CREATE OR REPLACE PACKAGE bi_dtm.pkg_dtm_monitor AS

    c_all_schema CONSTANT VARCHAR2(10) := '_ALL_';

    -- Chạy toàn bộ tiêu chí đang active cho một ngày
    PROCEDURE run_daily (
        p_snapshot_date IN DATE     DEFAULT TRUNC(SYSDATE),
        p_triggered_by  IN VARCHAR2 DEFAULT 'AIRFLOW'
    );

    -- Chạy lại một tiêu chí (debug, bổ sung)
    PROCEDURE run_check (
        p_check_code    IN VARCHAR2,
        p_snapshot_date IN DATE     DEFAULT TRUNC(SYSDATE),
        p_triggered_by  IN VARCHAR2 DEFAULT 'MANUAL'
    );

    -- Xóa lịch sử cũ
    PROCEDURE purge_history (
        p_keep_result_months IN PLS_INTEGER DEFAULT 24,
        p_keep_detail_months IN PLS_INTEGER DEFAULT 3
    );

END pkg_dtm_monitor;
/


CREATE OR REPLACE PACKAGE BODY bi_dtm.pkg_dtm_monitor AS

    g_date        DATE;
    g_run_id      NUMBER;
    g_check_start TIMESTAMP;

    c_module CONSTANT VARCHAR2(48) := 'PKG_DTM_MONITOR';

    /* -----------------------------------------------------------------
       Tiện ích
       ----------------------------------------------------------------- */
    FUNCTION elapsed_sec (p_from IN TIMESTAMP) RETURN NUMBER IS
        l_iv INTERVAL DAY(9) TO SECOND(6) := SYSTIMESTAMP - p_from;
    BEGIN
        RETURN EXTRACT(DAY    FROM l_iv) * 86400
             + EXTRACT(HOUR   FROM l_iv) * 3600
             + EXTRACT(MINUTE FROM l_iv) * 60
             + EXTRACT(SECOND FROM l_iv);
    END elapsed_sec;

    FUNCTION cut (p_text IN VARCHAR2, p_bytes IN PLS_INTEGER DEFAULT 4000) RETURN VARCHAR2 IS
    BEGIN
        RETURN SUBSTRB(p_text, 1, p_bytes);
    END cut;

    /* -----------------------------------------------------------------
       Run log (autonomous)
       ----------------------------------------------------------------- */
    FUNCTION log_start (p_triggered_by IN VARCHAR2) RETURN NUMBER IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_run_id NUMBER;
    BEGIN
        INSERT INTO mon_run_log (snapshot_date, start_ts, run_status, triggered_by)
        VALUES (g_date, SYSTIMESTAMP, 'RUNNING', p_triggered_by)
        RETURNING run_id INTO l_run_id;
        COMMIT;
        RETURN l_run_id;
    END log_start;

    PROCEDURE log_finish (p_status IN VARCHAR2, p_error IN VARCHAR2 DEFAULT NULL) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_total NUMBER; l_ok NUMBER; l_warn NUMBER; l_fail NUMBER; l_err NUMBER;
        l_msg   VARCHAR2(4000) := cut(p_error);
    BEGIN
        -- Mỗi tiêu chí lấy trạng thái xấu nhất trên các schema
        SELECT COUNT(*),
               NVL(SUM(CASE WHEN w IN (4, 5) THEN 1 END), 0),
               NVL(SUM(CASE WHEN w = 3      THEN 1 END), 0),
               NVL(SUM(CASE WHEN w = 2      THEN 1 END), 0),
               NVL(SUM(CASE WHEN w = 1      THEN 1 END), 0)
        INTO   l_total, l_ok, l_warn, l_fail, l_err
        FROM  (SELECT check_code,
                      MIN(CASE check_status
                              WHEN 'ERROR' THEN 1
                              WHEN 'FAIL'  THEN 2
                              WHEN 'WARN'  THEN 3
                              WHEN 'OK'    THEN 4
                              ELSE 5
                          END) AS w
               FROM   mon_check_result
               WHERE  snapshot_date = g_date
               AND    run_id        = g_run_id
               GROUP BY check_code);

        UPDATE mon_run_log
        SET    end_ts       = SYSTIMESTAMP,
               run_status   = CASE
                                  WHEN p_status = 'FAILED' THEN 'FAILED'
                                  WHEN l_err > 0           THEN 'PARTIAL'
                                  ELSE 'SUCCESS'
                              END,
               checks_total = l_total,
               checks_ok    = l_ok,
               checks_warn  = l_warn,
               checks_fail  = l_fail,
               checks_error = l_err,
               error_msg    = l_msg
        WHERE  run_id = g_run_id;
        COMMIT;
    END log_finish;

    /* -----------------------------------------------------------------
       Ghi kết quả
       ----------------------------------------------------------------- */
    PROCEDURE save_result (p_check IN VARCHAR2, p_schema IN VARCHAR2, p_value IN NUMBER) IS
        l_warn   NUMBER;
        l_fail   NUMBER;
        l_prev    NUMBER;
        l_status  VARCHAR2(10);
        l_elapsed NUMBER := elapsed_sec(g_check_start);
    BEGIN
        SELECT warn_threshold, fail_threshold
        INTO   l_warn, l_fail
        FROM   mon_check_def
        WHERE  check_code = p_check;

        BEGIN
            SELECT metric_value
            INTO   l_prev
            FROM  (SELECT metric_value
                   FROM   mon_check_result
                   WHERE  check_code    = p_check
                   AND    schema_name   = p_schema
                   AND    snapshot_date < g_date
                   AND    check_status <> 'ERROR'
                   ORDER BY snapshot_date DESC)
            WHERE  ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN l_prev := NULL;
        END;

        l_status := CASE
                        WHEN l_warn IS NULL AND l_fail IS NULL       THEN 'INFO'
                        WHEN l_fail IS NOT NULL AND p_value >= l_fail THEN 'FAIL'
                        WHEN l_warn IS NOT NULL AND p_value >= l_warn THEN 'WARN'
                        ELSE 'OK'
                    END;

        INSERT INTO mon_check_result (
            snapshot_date, check_code, schema_name, run_id,
            metric_value, warn_threshold, fail_threshold, check_status,
            prev_value, delta_value, elapsed_sec)
        VALUES (
            g_date, p_check, p_schema, g_run_id,
            p_value, l_warn, l_fail, l_status,
            l_prev, p_value - l_prev, l_elapsed);
    END save_result;

    -- Kết quả theo từng schema = số dòng chi tiết; schema không vi phạm = 0
    -- p_zone: chỉ ghi kết quả cho schema thuộc vùng này (NULL = mọi vùng).
    -- Schema ngoài vùng không có dòng kết quả -> hiển thị trống (không áp dụng),
    -- tránh hiện 0 / OK cho tiêu chí không được kiểm tra.
    PROCEDURE save_schema_counts (p_check IN VARCHAR2, p_zone IN VARCHAR2 DEFAULT NULL) IS
    BEGIN
        FOR r IN (SELECT s.schema_name, COUNT(d.check_code) AS cnt
                  FROM   mon_schema_def s
                  LEFT JOIN mon_check_detail d
                         ON  d.schema_name   = s.schema_name
                         AND d.check_code    = p_check
                         AND d.snapshot_date = g_date
                  WHERE  s.is_active = 'Y'
                  AND   (p_zone IS NULL OR s.zone_type = p_zone)
                  GROUP BY s.schema_name)
        LOOP
            save_result(p_check, r.schema_name, r.cnt);
        END LOOP;
    END save_schema_counts;

    -- Kết quả cấp database (_ALL_)
    PROCEDURE save_all_count (p_check IN VARCHAR2) IS
        l_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO l_cnt
        FROM   mon_check_detail
        WHERE  snapshot_date = g_date AND check_code = p_check;
        save_result(p_check, c_all_schema, l_cnt);
    END save_all_count;

    PROCEDURE clear_check (p_check IN VARCHAR2) IS
    BEGIN
        DELETE FROM mon_check_detail WHERE snapshot_date = g_date AND check_code = p_check;
        DELETE FROM mon_check_result WHERE snapshot_date = g_date AND check_code = p_check;
        IF p_check = 'SCHEMA_SIZE' THEN
            DELETE FROM mon_schema_size_daily WHERE snapshot_date = g_date;
        END IF;
    END clear_check;

    PROCEDURE save_error (p_check IN VARCHAR2, p_error IN VARCHAR2) IS
        l_elapsed NUMBER         := elapsed_sec(g_check_start);
        l_msg     VARCHAR2(4000) := cut(p_error);
    BEGIN
        clear_check(p_check);
        INSERT INTO mon_check_result (
            snapshot_date, check_code, schema_name, run_id,
            metric_value, check_status, elapsed_sec, error_msg)
        VALUES (
            g_date, p_check, c_all_schema, g_run_id,
            NULL, 'ERROR', l_elapsed, l_msg);
    END save_error;

    /* =================================================================
       CÁC TIÊU CHÍ
       ================================================================= */

    -- SCHEMA_SIZE: dung lượng theo schema / tablespace / nhóm segment
    PROCEDURE chk_schema_size IS
    BEGIN
        INSERT INTO mon_schema_size_daily (
            snapshot_date, schema_name, tablespace_name, segment_group,
            size_mb, segment_count, run_id)
        SELECT g_date,
               g.owner,
               g.tablespace_name,
               g.segment_group,
               ROUND(SUM(g.bytes) / 1048576, 2),
               COUNT(*),
               g_run_id
        FROM  (SELECT sg.owner,
                      sg.tablespace_name,
                      sg.bytes,
                      CASE
                          WHEN sg.segment_type LIKE 'TABLE%' THEN 'TABLE'
                          WHEN sg.segment_type LIKE 'INDEX%' THEN 'INDEX'
                          WHEN sg.segment_type LIKE 'LOB%'   THEN 'LOB'
                          ELSE 'OTHER'
                      END AS segment_group
               FROM   dba_segments   sg
               JOIN   mon_schema_def s
                      ON s.schema_name = sg.owner AND s.is_active = 'Y') g
        GROUP BY g.owner, g.tablespace_name, g.segment_group;

        FOR r IN (SELECT s.schema_name, NVL(SUM(z.size_mb), 0) AS size_mb
                  FROM   mon_schema_def s
                  LEFT JOIN mon_schema_size_daily z
                         ON  z.schema_name   = s.schema_name
                         AND z.snapshot_date = g_date
                  WHERE  s.is_active = 'Y'
                  GROUP BY s.schema_name)
        LOOP
            save_result('SCHEMA_SIZE', r.schema_name, r.size_mb);
        END LOOP;
    END chk_schema_size;

    -- TS_USAGE_PCT: tablespace đang chứa dữ liệu các DTM
    PROCEDURE chk_ts_usage IS
        l_max NUMBER;
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, num_value, detail_msg)
        SELECT g_date, 'TS_USAGE_PCT', c_all_schema, g_run_id,
               ROW_NUMBER() OVER (ORDER BY m.used_percent DESC),
               'TABLESPACE', m.tablespace_name,
               ROUND(m.used_percent, 2),
               TO_CHAR(UNISTR('\0110\00E3 d\00F9ng ')) || TO_CHAR(ROUND(m.used_percent, 2)) || '%'
        FROM   dba_tablespace_usage_metrics m
        WHERE  m.tablespace_name IN (
                   SELECT DISTINCT sg.tablespace_name
                   FROM   dba_segments   sg
                   JOIN   mon_schema_def s
                          ON s.schema_name = sg.owner AND s.is_active = 'Y');

        SELECT NVL(MAX(num_value), 0) INTO l_max
        FROM   mon_check_detail
        WHERE  snapshot_date = g_date AND check_code = 'TS_USAGE_PCT';

        save_result('TS_USAGE_PCT', c_all_schema, l_max);
    END chk_ts_usage;

    -- INVALID_OBJ
    PROCEDURE chk_invalid_obj IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, event_time, detail_msg)
        SELECT g_date, 'INVALID_OBJ', o.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY o.owner ORDER BY o.object_type, o.object_name),
               o.object_type, o.object_name, o.last_ddl_time,
               'STATUS = INVALID'
        FROM   dba_objects    o
        JOIN   mon_schema_def s ON s.schema_name = o.owner AND s.is_active = 'Y'
        WHERE  o.status = 'INVALID';

        save_schema_counts('INVALID_OBJ');
    END chk_invalid_obj;

    -- UNUSABLE_INDEX: index và partition index
    PROCEDURE chk_unusable_index IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, sub_object_name, ref_object_name, detail_msg)
        SELECT g_date, 'UNUSABLE_INDEX', u.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY u.owner ORDER BY u.index_name, u.partition_name),
               u.obj_type, u.index_name, u.partition_name, u.table_name,
               'STATUS = UNUSABLE'
        FROM  (SELECT i.owner, i.index_name, CAST(NULL AS VARCHAR2(128)) AS partition_name,
                      i.table_name, 'INDEX' AS obj_type
               FROM   dba_indexes i
               WHERE  i.status = 'UNUSABLE'
               UNION ALL
               SELECT p.index_owner, p.index_name, p.partition_name,
                      i.table_name, 'INDEX PARTITION'
               FROM   dba_ind_partitions p
               JOIN   dba_indexes i
                      ON i.owner = p.index_owner AND i.index_name = p.index_name
               WHERE  p.status = 'UNUSABLE') u
        JOIN   mon_schema_def s ON s.schema_name = u.owner AND s.is_active = 'Y';

        save_schema_counts('UNUSABLE_INDEX');
    END chk_unusable_index;

    -- STALE_STATS: bảng và partition (bỏ subpartition để giảm nhiễu)
    PROCEDURE chk_stale_stats IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, sub_object_name, event_time, detail_msg)
        SELECT g_date, 'STALE_STATS', t.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY t.owner ORDER BY t.table_name, t.partition_name),
               t.object_type, t.table_name, t.partition_name, t.last_analyzed,
               CASE WHEN t.last_analyzed IS NULL THEN TO_CHAR(UNISTR('Ch\01B0a c\00F3 stats')) ELSE TO_CHAR(UNISTR('Stats c\0169 (STALE)')) END
        FROM   dba_tab_statistics t
        JOIN   mon_schema_def s ON s.schema_name = t.owner AND s.is_active = 'Y'
        WHERE  t.object_type IN ('TABLE', 'PARTITION')
        AND    t.table_name NOT LIKE 'BIN$%'
        AND   (t.stale_stats = 'YES' OR t.last_analyzed IS NULL);

        save_schema_counts('STALE_STATS');
    END chk_stale_stats;

    -- DIRECT_GRANT_USER: quyền object cấp thẳng cho user hoặc PUBLIC
    -- Ngoại lệ: grantee là chính các schema được giám sát (owner mart cần
    -- grant trực tiếp từ STG_DTM để tạo view) và BI_DTM.
    PROCEDURE chk_direct_grant IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, grantee, privilege_name, detail_msg)
        SELECT g_date, 'DIRECT_GRANT_USER', p.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY p.owner ORDER BY p.grantee, p.table_name, p.privilege),
               p.type, p.table_name, p.grantee, p.privilege,
               CASE WHEN p.grantee = 'PUBLIC' THEN TO_CHAR(UNISTR('C\1EA5p cho PUBLIC')) ELSE TO_CHAR(UNISTR('C\1EA5p th\1EB3ng cho user')) END
        FROM   dba_tab_privs  p
        JOIN   mon_schema_def s ON s.schema_name = p.owner AND s.is_active = 'Y'
        WHERE (p.grantee = 'PUBLIC'
               OR p.grantee IN (SELECT u.username FROM dba_users u))
        AND    p.grantee <> 'BI_DTM'
        AND    p.grantee NOT IN (SELECT schema_name FROM mon_schema_def);

        save_schema_counts('DIRECT_GRANT_USER');
    END chk_direct_grant;

    -- INTERNAL_OBJ_GRANTED: bảng STG_/TWT_/TMP_ của mart bị cấp ra ngoài
    -- Hợp lệ: BI_DTM và role <OWNER>_WRITE của chính mart.
    PROCEDURE chk_internal_grant IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, grantee, privilege_name, detail_msg)
        SELECT g_date, 'INTERNAL_OBJ_GRANTED', p.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY p.owner ORDER BY p.table_name, p.grantee, p.privilege),
               p.type, p.table_name, p.grantee, p.privilege,
               TO_CHAR(UNISTR('B\1EA3ng n\1ED9i b\1ED9 b\1ECB c\1EA5p quy\1EC1n ra ngo\00E0i'))
        FROM   dba_tab_privs  p
        JOIN   mon_schema_def s
               ON s.schema_name = p.owner AND s.is_active = 'Y' AND s.zone_type = 'MART'
        WHERE  REGEXP_LIKE(p.table_name, '^(STG|TWT|TMP)_')
        AND    p.grantee <> 'BI_DTM'
        AND    p.grantee <> p.owner || '_WRITE';

        save_schema_counts('INTERNAL_OBJ_GRANTED', 'MART');
    END chk_internal_grant;

    -- ANY_PRIV_HOLDER: quyền ANY của user/role liên quan DTM (trừ BI_DTM)
    PROCEDURE chk_any_priv IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, grantee, privilege_name, detail_msg)
        SELECT g_date, 'ANY_PRIV_HOLDER', c_all_schema, g_run_id,
               ROW_NUMBER() OVER (ORDER BY sp.grantee, sp.privilege),
               CASE WHEN sp.grantee IN (SELECT u.username FROM dba_users u) THEN 'USER' ELSE 'ROLE' END,
               sp.grantee, sp.privilege,
               CASE WHEN sp.admin_option = 'YES' THEN TO_CHAR(UNISTR('C\00F3 ADMIN OPTION')) END
        FROM   dba_sys_privs sp
        WHERE  sp.privilege LIKE '% ANY %'
        AND   (sp.grantee LIKE '%DTM%' OR sp.grantee LIKE 'ETL\_%' ESCAPE '\')
        AND    sp.grantee <> 'BI_DTM';

        save_all_count('ANY_PRIV_HOLDER');
    END chk_any_priv;

    -- USER_PWD_EXPIRY: BI_DTM, schema owner, tài khoản ETL_*
    -- Schema owner bị LOCKED có chủ đích nên chỉ báo LOCKED(TIMED) và EXPIRED.
    PROCEDURE chk_user_expiry IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, num_value, event_time, detail_msg)
        SELECT g_date, 'USER_PWD_EXPIRY', c_all_schema, g_run_id,
               ROW_NUMBER() OVER (ORDER BY u.expiry_date NULLS LAST, u.username),
               'USER', u.username,
               ROUND(u.expiry_date - g_date),
               u.expiry_date,
               u.account_status
        FROM   dba_users u
        WHERE (u.username = 'BI_DTM'
               OR u.username IN (SELECT schema_name FROM mon_schema_def WHERE is_active = 'Y')
               OR u.username LIKE 'ETL\_%' ESCAPE '\')
        AND   (u.account_status LIKE '%EXPIRED%'
               OR u.account_status LIKE '%TIMED%'
               OR (u.account_status = 'OPEN'
                   AND u.expiry_date IS NOT NULL
                   AND u.expiry_date < g_date + 14));

        save_all_count('USER_PWD_EXPIRY');
    END chk_user_expiry;

    -- DDL_CHANGE_1D: object tạo mới hoặc đổi DDL từ D-1
    -- Lưu ý: TRUNCATE, GRANT cũng cập nhật LAST_DDL_TIME -> chỉ là INFO.
    PROCEDURE chk_ddl_change IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, event_time, detail_msg)
        SELECT g_date, 'DDL_CHANGE_1D', o.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY o.owner ORDER BY o.last_ddl_time DESC),
               o.object_type, o.object_name, o.last_ddl_time,
               CASE WHEN o.created >= g_date - 1 THEN TO_CHAR(UNISTR('T\1EA1o m\1EDBi')) ELSE TO_CHAR(UNISTR('\0110\1ED5i DDL')) END
        FROM   dba_objects    o
        JOIN   mon_schema_def s ON s.schema_name = o.owner AND s.is_active = 'Y'
        WHERE  o.last_ddl_time >= g_date - 1
        AND    o.last_ddl_time <  g_date + 1
        AND    o.object_type NOT LIKE '%PARTITION%'
        AND    o.object_name NOT LIKE 'BIN$%';

        save_schema_counts('DDL_CHANGE_1D');
    END chk_ddl_change;

    -- CROSS_MART_DEP: mart tham chiếu schema khác không phải zone SOURCE
    PROCEDURE chk_cross_mart_dep IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, ref_schema, ref_object_name, ref_object_type, detail_msg)
        SELECT g_date, 'CROSS_MART_DEP', d.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY d.owner ORDER BY d.name, d.referenced_owner, d.referenced_name),
               d.type, d.name, d.referenced_owner, d.referenced_name, d.referenced_type,
               TO_CHAR(UNISTR('Mart \0111\1ECDc ch\00E9o ')) || d.referenced_owner
        FROM   dba_dependencies d
        JOIN   mon_schema_def   s1
               ON s1.schema_name = d.owner AND s1.is_active = 'Y' AND s1.zone_type = 'MART'
        JOIN   mon_schema_def   s2
               ON s2.schema_name = d.referenced_owner AND s2.zone_type <> 'SOURCE'
        WHERE  d.owner <> d.referenced_owner;

        save_schema_counts('CROSS_MART_DEP', 'MART');
    END chk_cross_mart_dep;

    -- MISSING_COMMENT: bảng FCT_/DIM_/AGG_ chưa có comment
    PROCEDURE chk_missing_comment IS
    BEGIN
        INSERT INTO mon_check_detail (
            snapshot_date, check_code, schema_name, run_id, detail_seq,
            object_type, object_name, detail_msg)
        SELECT g_date, 'MISSING_COMMENT', t.owner, g_run_id,
               ROW_NUMBER() OVER (PARTITION BY t.owner ORDER BY t.table_name),
               'TABLE', t.table_name,
               TO_CHAR(UNISTR('Thi\1EBFu COMMENT ON TABLE'))
        FROM   dba_tables     t
        JOIN   mon_schema_def s ON s.schema_name = t.owner AND s.is_active = 'Y'
        LEFT JOIN dba_tab_comments c
               ON c.owner = t.owner AND c.table_name = t.table_name
        WHERE  REGEXP_LIKE(t.table_name, '^(FCT|DIM|AGG)_')
        AND    c.comments IS NULL;

        save_schema_counts('MISSING_COMMENT');
    END chk_missing_comment;

    /* -----------------------------------------------------------------
       Điều phối một tiêu chí: lỗi được nuốt và ghi ERROR
       ----------------------------------------------------------------- */
    PROCEDURE exec_check (p_check IN VARCHAR2) IS
        l_err VARCHAR2(32767);
    BEGIN
        g_check_start := SYSTIMESTAMP;
        DBMS_APPLICATION_INFO.set_module(c_module, p_check);

        clear_check(p_check);

        CASE p_check
            WHEN 'SCHEMA_SIZE'          THEN chk_schema_size;
            WHEN 'TS_USAGE_PCT'         THEN chk_ts_usage;
            WHEN 'INVALID_OBJ'          THEN chk_invalid_obj;
            WHEN 'UNUSABLE_INDEX'       THEN chk_unusable_index;
            WHEN 'STALE_STATS'          THEN chk_stale_stats;
            WHEN 'DIRECT_GRANT_USER'    THEN chk_direct_grant;
            WHEN 'INTERNAL_OBJ_GRANTED' THEN chk_internal_grant;
            WHEN 'ANY_PRIV_HOLDER'      THEN chk_any_priv;
            WHEN 'USER_PWD_EXPIRY'      THEN chk_user_expiry;
            WHEN 'DDL_CHANGE_1D'        THEN chk_ddl_change;
            WHEN 'CROSS_MART_DEP'       THEN chk_cross_mart_dep;
            WHEN 'MISSING_COMMENT'      THEN chk_missing_comment;
            ELSE
                RAISE_APPLICATION_ERROR(-20001,
                    TO_CHAR(UNISTR('Ch\01B0a c\00F3 procedure cho ti\00EAu ch\00ED ')) || p_check);
        END CASE;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            l_err := SQLERRM || ' | ' || DBMS_UTILITY.format_error_backtrace;
            ROLLBACK;
            save_error(p_check, l_err);
            COMMIT;
    END exec_check;

    /* =================================================================
       PUBLIC
       ================================================================= */
    PROCEDURE run_daily (
        p_snapshot_date IN DATE     DEFAULT TRUNC(SYSDATE),
        p_triggered_by  IN VARCHAR2 DEFAULT 'AIRFLOW'
    ) IS
        l_err VARCHAR2(32767);
    BEGIN
        g_date   := TRUNC(p_snapshot_date);
        g_run_id := log_start(p_triggered_by);
        DBMS_APPLICATION_INFO.set_module(c_module, 'RUN_DAILY');

        -- Idempotent: xóa toàn bộ dữ liệu của ngày trước khi ghi lại
        DELETE FROM mon_check_detail      WHERE snapshot_date = g_date;
        DELETE FROM mon_check_result      WHERE snapshot_date = g_date;
        DELETE FROM mon_schema_size_daily WHERE snapshot_date = g_date;
        COMMIT;

        FOR c IN (SELECT check_code
                  FROM   mon_check_def
                  WHERE  is_active = 'Y'
                  ORDER BY display_order, check_code)
        LOOP
            exec_check(c.check_code);
        END LOOP;

        log_finish('DONE');
        DBMS_APPLICATION_INFO.set_module(NULL, NULL);
    EXCEPTION
        WHEN OTHERS THEN
            l_err := SQLERRM || ' | ' || DBMS_UTILITY.format_error_backtrace;
            ROLLBACK;
            IF g_run_id IS NOT NULL THEN
                log_finish('FAILED', l_err);
            END IF;
            DBMS_APPLICATION_INFO.set_module(NULL, NULL);
            RAISE;
    END run_daily;

    PROCEDURE run_check (
        p_check_code    IN VARCHAR2,
        p_snapshot_date IN DATE     DEFAULT TRUNC(SYSDATE),
        p_triggered_by  IN VARCHAR2 DEFAULT 'MANUAL'
    ) IS
        l_err VARCHAR2(32767);
    BEGIN
        g_date   := TRUNC(p_snapshot_date);
        g_run_id := log_start(p_triggered_by);

        exec_check(UPPER(p_check_code));

        log_finish('DONE');
        DBMS_APPLICATION_INFO.set_module(NULL, NULL);
    EXCEPTION
        WHEN OTHERS THEN
            l_err := SQLERRM || ' | ' || DBMS_UTILITY.format_error_backtrace;
            ROLLBACK;
            IF g_run_id IS NOT NULL THEN
                log_finish('FAILED', l_err);
            END IF;
            DBMS_APPLICATION_INFO.set_module(NULL, NULL);
            RAISE;
    END run_check;

    PROCEDURE purge_history (
        p_keep_result_months IN PLS_INTEGER DEFAULT 24,
        p_keep_detail_months IN PLS_INTEGER DEFAULT 3
    ) IS
        l_result_cut DATE := ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -p_keep_result_months);
        l_detail_cut DATE := ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -p_keep_detail_months);
    BEGIN
        DELETE FROM mon_check_detail      WHERE snapshot_date < l_detail_cut;
        DELETE FROM mon_check_result      WHERE snapshot_date < l_result_cut;
        DELETE FROM mon_schema_size_daily WHERE snapshot_date < l_result_cut;
        DELETE FROM mon_run_log r
        WHERE  r.snapshot_date < l_result_cut
        AND    NOT EXISTS (SELECT 1 FROM mon_check_result x WHERE x.run_id = r.run_id)
        AND    NOT EXISTS (SELECT 1 FROM mon_check_detail d WHERE d.run_id = r.run_id)
        AND    NOT EXISTS (SELECT 1 FROM mon_schema_size_daily z WHERE z.run_id = r.run_id);
        COMMIT;
    END purge_history;

END pkg_dtm_monitor;
/


/* =====================================================================
   KIỂM TRA SAU KHI COMPILE
   ===================================================================== */

-- 1. Package compile sạch chưa
-- SELECT name, type, line, position, text
-- FROM   user_errors
-- WHERE  name = 'PKG_DTM_MONITOR'
-- ORDER BY type, sequence;

-- 2. Chạy thử 1 tiêu chí
-- BEGIN bi_dtm.pkg_dtm_monitor.run_check('INVALID_OBJ'); END;
-- /

-- 3. Chạy toàn bộ
-- BEGIN bi_dtm.pkg_dtm_monitor.run_daily(p_triggered_by => 'MANUAL'); END;
-- /

-- 4. Xem kết quả
-- SELECT * FROM bi_dtm.vw_mon_run    ORDER BY run_id DESC FETCH FIRST 5 ROWS ONLY;
-- SELECT * FROM bi_dtm.vw_mon_latest ORDER BY status_sort, display_order, schema_name;
-- SELECT check_code, error_msg FROM bi_dtm.mon_check_result
-- WHERE  check_status = 'ERROR' AND snapshot_date = TRUNC(SYSDATE);
