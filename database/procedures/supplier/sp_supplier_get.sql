-- sp_supplier_get
-- Purpose : One supplier.
-- Params  : p_id
-- Results : (1) supplier row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_supplier_get(IN p_id INT)
BEGIN
  DECLARE v_shop_state CHAR(2);

  IF NOT EXISTS (SELECT 1 FROM suppliers WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Supplier not found';
  END IF;

  SELECT MAX(state_code) INTO v_shop_state FROM shop_settings WHERE id = 1;

  SELECT s.id, s.supplier_code AS code, s.supplier_name AS name, IFNULL(s.contact_person, '') AS contact_person,
         s.mobile, IFNULL(s.email, '') AS email, IFNULL(s.address, '') AS address,
         st.state_name AS state, s.state_code, IFNULL(s.gstin, '') AS gstin,
         s.opening_balance, s.payment_terms_days, s.current_balance,
         IF(s.state_code <> v_shop_state, 1, 0) AS is_inter_state,
         IF(s.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         s.created_at, IFNULL(s.updated_at, s.created_at) AS updated_at
    FROM suppliers s
    JOIN states st ON st.state_code = s.state_code
   WHERE s.id = p_id;
END
