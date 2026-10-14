-- sp_preorder_next_no
-- Purpose : Number and date shown on the New Pre-Order screen before saving. Read only: the number is taken by
--           sp_util_next_number when the order is saved, so it moves on if another counter books first.
--           Format must match the PRE series in sp_util_next_number (WB-PRE-2026-0001).
-- Params  : none
-- Results : (1) order_no, order_date
-- Errors  : none
CREATE PROCEDURE sp_preorder_next_no()
BEGIN
  DECLARE v_year CHAR(4) DEFAULT YEAR(CURDATE());
  DECLARE v_no   INT UNSIGNED;

  SET v_no = IFNULL((SELECT next_no FROM number_series WHERE series_key = CONCAT('PRE-', v_year)), 1);

  SELECT CONCAT('WB-PRE-', v_year, '-', LPAD(v_no, GREATEST(4, CHAR_LENGTH(v_no)), '0')) AS order_no,
         NOW() AS order_date;
END
