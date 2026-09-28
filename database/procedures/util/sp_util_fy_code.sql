-- sp_util_fy_code
-- Purpose : Financial-year code for a date, e.g. 2026-09-26 -> '2627' (April-March by default,
--           start month taken from shop_settings.financial_year_start_month).
-- Params  : p_date DATE (NULL = today), OUT p_fy CHAR(4)
-- Results : none (OUT parameter only)
-- Errors  : none
CREATE PROCEDURE sp_util_fy_code(IN p_date DATE, OUT p_fy CHAR(4))
BEGIN
  DECLARE v_date  DATE DEFAULT IFNULL(p_date, CURDATE());
  DECLARE v_start INT DEFAULT 4;
  DECLARE v_year  INT;

  SELECT IFNULL(MAX(financial_year_start_month), 4) INTO v_start FROM shop_settings WHERE id = 1;
  SET v_year = IF(MONTH(v_date) >= v_start, YEAR(v_date), YEAR(v_date) - 1);
  SET p_fy = CONCAT(LPAD(MOD(v_year, 100), 2, '0'), LPAD(MOD(v_year + 1, 100), 2, '0'));
END
