-- sp_settings_save
-- Purpose : Updates the shop profile. p_state accepts a state name or a 2-digit GST state code.
-- Params  : p_shop_name, p_address, p_state, p_gstin, p_phone, p_email, p_logo_url, p_upi_id,
--           p_receipt_footer, p_cashier_max_discount_pct, p_allow_negative_stock,
--           p_financial_year_start_month, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 validation
CREATE PROCEDURE sp_settings_save(
  IN p_shop_name                  VARCHAR(100),
  IN p_address                    VARCHAR(255),
  IN p_state                      VARCHAR(60),
  IN p_gstin                      VARCHAR(15),
  IN p_phone                      VARCHAR(20),
  IN p_email                      VARCHAR(100),
  IN p_logo_url                   VARCHAR(255),
  IN p_upi_id                     VARCHAR(60),
  IN p_receipt_footer             VARCHAR(255),
  IN p_cashier_max_discount_pct   DECIMAL(5,2),
  IN p_allow_negative_stock       TINYINT,
  IN p_financial_year_start_month TINYINT,
  IN p_user_id                    INT
)
BEGIN
  DECLARE v_state CHAR(2) DEFAULT NULL;

  IF TRIM(IFNULL(p_shop_name, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'shopName::Shop name is required';
  END IF;

  SELECT MAX(state_code) INTO v_state FROM states WHERE state_code = p_state OR state_name = p_state;
  IF v_state IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'state::Select a valid state';
  END IF;

  IF IFNULL(p_cashier_max_discount_pct, 0) < 0 OR IFNULL(p_cashier_max_discount_pct, 0) > 100 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cashierMaxDiscountPct::Cashier discount limit must be between 0 and 100';
  END IF;

  IF IFNULL(p_financial_year_start_month, 4) NOT BETWEEN 1 AND 12 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'financialYearStartMonth::Financial year start month must be 1-12';
  END IF;

  UPDATE shop_settings
     SET shop_name = TRIM(p_shop_name),
         address = p_address,
         state_code = v_state,
         gstin = NULLIF(TRIM(p_gstin), ''),
         phone = p_phone,
         email = p_email,
         logo_url = p_logo_url,
         upi_id = p_upi_id,
         receipt_footer = p_receipt_footer,
         cashier_max_discount_pct = IFNULL(p_cashier_max_discount_pct, 10),
         allow_negative_stock = IFNULL(p_allow_negative_stock, 1),
         financial_year_start_month = IFNULL(p_financial_year_start_month, 4),
         updated_by = p_user_id,
         updated_at = NOW()
   WHERE id = 1;

  SELECT 1 AS id, 'Settings saved successfully' AS message;
END
