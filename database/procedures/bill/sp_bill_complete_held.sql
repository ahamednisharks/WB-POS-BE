-- sp_bill_complete_held
-- Purpose : Completes a HELD bill with the (possibly edited) cart and payments. Same rules as sp_bill_save.
-- Params  : p_id, p_client_ref, p_device_id, p_customer_mobile, p_customer_name, p_discount_type, p_discount_value,
--           p_items JSON, p_payments JSON, p_user_id, p_role
-- Results : the completed bill (as sp_bill_get)
-- Errors  : 45000 not HELD / validation, 45403, 45404
CREATE PROCEDURE sp_bill_complete_held(
  IN p_id              INT,
  IN p_client_ref      VARCHAR(36),
  IN p_device_id       VARCHAR(50),
  IN p_customer_mobile VARCHAR(10),
  IN p_customer_name   VARCHAR(80),
  IN p_discount_type   VARCHAR(10),
  IN p_discount_value  DECIMAL(12,2),
  IN p_items           JSON,
  IN p_payments        JSON,
  IN p_user_id         INT,
  IN p_role            VARCHAR(10)
)
BEGIN
  DECLARE v_status  VARCHAR(10) DEFAULT NULL;
  DECLARE v_cashier INT;

  SELECT bill_status, cashier_id INTO v_status, v_cashier FROM bills WHERE id = p_id AND is_deleted = 0;
  IF v_status IS NULL OR (p_role = 'CASHIER' AND v_cashier <> p_user_id) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Bill not found';
  END IF;
  IF v_status <> 'HELD' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only held bills can be completed';
  END IF;

  CALL sp_bill_save(p_id, p_client_ref, p_device_id, 'COMPLETED', p_customer_mobile, p_customer_name,
                    p_discount_type, p_discount_value, p_items, p_payments, p_user_id, p_role);
END
