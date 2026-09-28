-- sp_util_next_number
-- Purpose : Next document / master number. Locks the number_series row FOR UPDATE (call it inside
--           the caller's transaction), creates the series on first use and increments it.
--           Financial-year series : BILL -> B2627-000123, PO -> PO2627-0001, PE -> PE2627-0001, TXN -> T2627-000001
--           Master series         : ITM -> ITM0001, SUP -> SUP001, EMP -> EMP001
-- Params  : p_series VARCHAR(20), OUT p_number VARCHAR(20)
-- Results : none (OUT parameter only)
-- Errors  : 45000 unknown series
CREATE PROCEDURE sp_util_next_number(IN p_series VARCHAR(20), OUT p_number VARCHAR(20))
BEGIN
  DECLARE v_fy     CHAR(4) DEFAULT NULL;
  DECLARE v_key    VARCHAR(20);
  DECLARE v_prefix VARCHAR(12);
  DECLARE v_pad    INT;
  DECLARE v_no     INT UNSIGNED;

  IF p_series IN ('BILL', 'PO', 'PE', 'TXN') THEN
    CALL sp_util_fy_code(CURDATE(), v_fy);
  END IF;

  CASE p_series
    WHEN 'BILL' THEN SET v_prefix = CONCAT('B', v_fy, '-'),  v_pad = 6;
    WHEN 'PO'   THEN SET v_prefix = CONCAT('PO', v_fy, '-'), v_pad = 4;
    WHEN 'PE'   THEN SET v_prefix = CONCAT('PE', v_fy, '-'), v_pad = 4;
    WHEN 'TXN'  THEN SET v_prefix = CONCAT('T', v_fy, '-'),  v_pad = 6;
    WHEN 'ITM'  THEN SET v_prefix = 'ITM', v_pad = 4;
    WHEN 'SUP'  THEN SET v_prefix = 'SUP', v_pad = 3;
    WHEN 'EMP'  THEN SET v_prefix = 'EMP', v_pad = 3;
    ELSE SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown number series';
  END CASE;

  SET v_key = IF(v_fy IS NULL, p_series, CONCAT(p_series, '-', v_fy));

  INSERT IGNORE INTO number_series (series_key, prefix, next_no, pad_length)
  VALUES (v_key, v_prefix, 1, v_pad);

  SELECT next_no INTO v_no FROM number_series WHERE series_key = v_key FOR UPDATE;

  UPDATE number_series SET next_no = next_no + 1, updated_at = NOW() WHERE series_key = v_key;

  SET p_number = CONCAT(v_prefix, LPAD(v_no, GREATEST(v_pad, CHAR_LENGTH(v_no)), '0'));
END
