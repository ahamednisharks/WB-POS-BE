-- sp_supplier_dropdown
-- Purpose : Active suppliers for select boxes (with the IGST flag for purchase screens).
-- Params  : none
-- Results : (1) id, code, name, state, gstin, mobile, payment_terms_days, current_balance, is_inter_state
-- Errors  : none
CREATE PROCEDURE sp_supplier_dropdown()
BEGIN
  DECLARE v_shop_state CHAR(2);
  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT s.id, s.supplier_code AS code, s.supplier_name AS name, st.state_name AS state,
         IFNULL(s.gstin, '') AS gstin, s.mobile, s.payment_terms_days, s.current_balance,
         IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state
    FROM suppliers s
    JOIN states st ON st.state_code = s.state_code
   WHERE s.is_deleted = 0 AND s.status = 1
   ORDER BY s.supplier_name;
END
