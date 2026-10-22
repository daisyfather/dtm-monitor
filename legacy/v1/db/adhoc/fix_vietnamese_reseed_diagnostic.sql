-- ascii-check: skip  (script chan doan lan 1, da duoc thay bang V003; giu lai de tham khao)
/* =====================================================================
   SỬA LỖI TIẾNG VIỆT BỊ "?" TRONG BI_DTM.MON_*
   Chạy theo thứ tự: BƯỚC 1 chẩn đoán -> chọn hướng -> BƯỚC 2, 3, 4
   ===================================================================== */


/* =====================================================================
   BƯỚC 1. CHẨN ĐOÁN
   ===================================================================== */

-- 1.1 Character set của database
SELECT parameter, value
FROM   nls_database_parameters
WHERE  parameter IN ('NLS_CHARACTERSET', 'NLS_NCHAR_CHARACTERSET');

-- 1.2 Dữ liệu đã lưu có thật sự bị hỏng không
--     Nếu thấy byte 3f ở vị trí chữ có dấu -> đã lưu thành dấu '?', phải ghi lại.
SELECT check_code, check_name, DUMP(check_name, 1016) AS raw_bytes
FROM   bi_dtm.mon_check_def
WHERE  check_code IN ('SCHEMA_SIZE', 'DDL_CHANGE_1D');

/*  Đọc kết quả 1.1:
    - NLS_CHARACTERSET = AL32UTF8
        -> Database lưu được tiếng Việt. Lỗi do công cụ chạy script
           (SQL Developer / Toad / sqlplus) gửi sai bảng mã.
           Làm tiếp BƯỚC 2 -> 3 -> 4 trong file này.
    - NLS_CHARACTERSET khác (WE8MSWIN1252, WE8ISO8859P1, VN8MSWIN1258...)
        -> VARCHAR2 không chứa được đủ chữ tiếng Việt. DỪNG LẠI,
           không chạy tiếp file này; cần đổi hướng thiết kế.
*/


/* =====================================================================
   BƯỚC 2. CẤU HÌNH CÔNG CỤ TRƯỚC KHI CHẠY LẠI (chỉ khi AL32UTF8)

   SQL Developer:
     Tools > Preferences > Environment > Encoding = UTF-8
     Đóng file .sql rồi mở lại, kiểm tra chữ có dấu hiển thị đúng
     trong editor trước khi chạy.

   Toad:
     View > Toad Options > Editor > Open/Save: chọn UTF-8.

   sqlplus (Windows cmd):
     chcp 65001
     set NLS_LANG=AMERICAN_AMERICA.AL32UTF8
     sqlplus bi_dtm@... @fix_vietnamese_reseed.sql

   sqlplus (Linux):
     export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
   ===================================================================== */


/* =====================================================================
   BƯỚC 3. GHI LẠI DỮ LIỆU DANH MỤC
   ===================================================================== */

UPDATE bi_dtm.mon_schema_def SET business_domain = 'Phái sinh T-1 của SB_DWH, nguồn conformed dimension', updated_ts = SYSTIMESTAMP WHERE schema_name = 'STG_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Enterprise',          updated_ts = SYSTIMESTAMP WHERE schema_name = 'ENT_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Khách hàng cá nhân',  updated_ts = SYSTIMESTAMP WHERE schema_name = 'RETAIL_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Pháp chế, tuân thủ',  updated_ts = SYSTIMESTAMP WHERE schema_name = 'CNL_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Rủi ro',              updated_ts = SYSTIMESTAMP WHERE schema_name = 'RISK_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Vận hành',            updated_ts = SYSTIMESTAMP WHERE schema_name = 'OPS_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Phê duyệt tín dụng',  updated_ts = SYSTIMESTAMP WHERE schema_name = 'CAP_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Tài chính, kế toán',  updated_ts = SYSTIMESTAMP WHERE schema_name = 'FIN_DTM';
UPDATE bi_dtm.mon_schema_def SET business_domain = 'Sandbox',             updated_ts = SYSTIMESTAMP WHERE schema_name = 'SND_DTM';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Dung lượng schema',
       description  = 'Tổng dung lượng segment của schema, chi tiết ở MON_SCHEMA_SIZE_DAILY',
       action_guide = 'Theo dõi tốc độ tăng; tăng đột biến thì kiểm tra retention và load trùng'
WHERE  check_code = 'SCHEMA_SIZE';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Tỷ lệ sử dụng tablespace',
       description  = 'Tỷ lệ % đã dùng của tablespace chứa dữ liệu các DTM (SCHEMA_NAME = _ALL_)',
       action_guide = 'Báo DBA thêm datafile hoặc dọn partition cũ'
WHERE  check_code = 'TS_USAGE_PCT';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Object INVALID',
       description  = 'Số object có STATUS = INVALID',
       action_guide = 'Recompile; nếu vẫn lỗi thì kiểm tra thay đổi DDL gần nhất của object được tham chiếu'
WHERE  check_code = 'INVALID_OBJ';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Index / partition index UNUSABLE',
       description  = 'Số index hoặc partition index ở trạng thái UNUSABLE',
       action_guide = 'Rebuild index; kiểm tra job có truncate/exchange partition mà không UPDATE INDEXES'
WHERE  check_code = 'UNUSABLE_INDEX';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Bảng / partition có stats cũ hoặc chưa có',
       description  = 'Số bảng/partition có STALE_STATS = YES hoặc LAST_ANALYZED IS NULL',
       action_guide = 'Bổ sung bước gather stats sau load cho bảng liên quan'
WHERE  check_code = 'STALE_STATS';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Quyền object cấp thẳng cho user',
       description  = 'Số quyền trên object của schema cấp thẳng cho user (không qua role)',
       action_guide = 'Chuyển sang role <DTM>_READ / _WRITE rồi thu hồi bản cấp thẳng; ngoại lệ hợp lệ: grant cho schema owner mart đọc STG_DTM'
WHERE  check_code = 'DIRECT_GRANT_USER';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Bảng nội bộ bị cấp quyền ra ngoài',
       description  = 'Số quyền trên bảng STG_/TWT_/TMP_ cấp cho user hoặc role ngoài ETL của chính mart',
       action_guide = 'Thu hồi; nếu team khác cần dữ liệu thì tạo VW_ công bố'
WHERE  check_code = 'INTERNAL_OBJ_GRANTED';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Tài khoản giữ quyền ANY',
       description  = 'Số quyền hệ thống dạng % ANY % đang cấp cho user/role liên quan DTM (SCHEMA_NAME = _ALL_)',
       action_guide = 'Rà soát, thu gọn về mức tối thiểu; BI_DTM ghi nhận làm ngoại lệ có duyệt'
WHERE  check_code = 'ANY_PRIV_HOLDER';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Tài khoản sắp hết hạn mật khẩu / bị khóa',
       description  = 'Số tài khoản schema/ETL hết hạn mật khẩu trong 14 ngày tới, hoặc đang EXPIRED / LOCKED ngoài dự kiến',
       action_guide = 'Đổi mật khẩu và cập nhật connection Airflow/ODI trước ngày hết hạn'
WHERE  check_code = 'USER_PWD_EXPIRY';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Object thay đổi DDL trong ngày',
       description  = 'Số object có LAST_DDL_TIME trong 24 giờ qua',
       action_guide = 'Đối chiếu với danh sách deploy đã duyệt; DDL ngoài quy trình thì truy vết qua audit'
WHERE  check_code = 'DDL_CHANGE_1D';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Phụ thuộc chéo giữa các mart',
       description  = 'Số phụ thuộc từ object của mart này sang mart khác (tham chiếu tới zone SOURCE là hợp lệ)',
       action_guide = 'Vi phạm bounded context: chuyển dữ liệu dùng chung về STG_DTM hoặc xin duyệt ngoại lệ qua VW_'
WHERE  check_code = 'CROSS_MART_DEP';

UPDATE bi_dtm.mon_check_def SET updated_ts = SYSTIMESTAMP,
       check_name   = 'Bảng công bố thiếu comment',
       description  = 'Số bảng FCT_/DIM_/AGG_ chưa có COMMENT ON TABLE',
       action_guide = 'Bổ sung comment ghi grain, nguồn, tần suất load'
WHERE  check_code = 'MISSING_COMMENT';

COMMIT;

-- Kiểm tra lại: không còn byte 3f ở vị trí chữ có dấu
SELECT check_code, check_name, DUMP(check_name, 1016) AS raw_bytes
FROM   bi_dtm.mon_check_def
WHERE  check_code IN ('SCHEMA_SIZE', 'DDL_CHANGE_1D');


/* =====================================================================
   BƯỚC 4. COMPILE LẠI PACKAGE VÀ CHẠY LẠI JOB
   Package có chuỗi tiếng Việt ('Đã dùng', 'Chưa có stats', 'Tạo mới'...)
   nên cũng phải compile lại bằng công cụ đã cấu hình UTF-8 ở BƯỚC 2.
   Sau đó chạy lại để ghi đè dữ liệu ngày hôm nay (DETAIL_MSG bị hỏng).
   ===================================================================== */

-- @pkg_dtm_monitor.sql

-- BEGIN bi_dtm.pkg_dtm_monitor.run_daily(p_triggered_by => 'MANUAL'); END;
-- /

-- Kiểm tra chuỗi trong package đã lưu đúng
-- SELECT line, text FROM user_source
-- WHERE  name = 'PKG_DTM_MONITOR' AND type = 'PACKAGE BODY'
-- AND    text LIKE '%Tạo mới%';
