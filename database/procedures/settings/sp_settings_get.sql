-- sp_settings_get
-- Purpose : Shop profile and billing rules (single row).
-- Params  : none
-- Results : (1) settings row
-- Errors  : none
CREATE PROCEDURE sp_settings_get()
BEGIN
  SELECT s.shop_name,
         s.address,
         st.state_name AS state,
         s.state_code,
         s.gstin,
         s.phone,
         s.email,
         s.logo_url AS logo,
         s.upi_id,
         s.receipt_footer,
         s.cashier_max_discount_pct,
         s.allow_negative_stock,
         s.financial_year_start_month,
         s.updated_at
    FROM shop_settings s
    LEFT JOIN states st ON st.state_code = s.state_code
   WHERE s.id = 1;
END
