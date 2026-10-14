-- sp_preorder_add_payment
-- Purpose : Takes one or more further payments on a BOOKED / READY pre-order - the customer may pay any number of
--           times until the bill is generated on delivery. The total paid can never exceed the order total.
-- Params  : p_id, p_payments JSON [{ "mode": "UPI", "amount": 100, "referenceNo": "UTR123" }], p_user_id
-- Results : the pre-order, as sp_preorder_get
-- Errors  : 45000 validation / order not open, 45404 not found
CREATE PROCEDURE sp_preorder_add_payment(
  IN p_id       INT,
  IN p_payments JSON,
  IN p_user_id  INT
)
BEGIN
  DECLARE v_status VARCHAR(10) DEFAULT NULL;
  DECLARE v_count  INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;

  SELECT order_status INTO v_status FROM pre_orders WHERE id = p_id AND is_deleted = 0 FOR UPDATE;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Pre-order not found';
  END IF;
  IF v_status NOT IN ('BOOKED', 'READY') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payments can only be taken on a booked or ready pre-order';
  END IF;

  CALL sp_preorder_post_payments(p_id, p_payments, p_user_id, v_count);
  IF v_count = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'payments::Enter a payment amount greater than 0';
  END IF;

  UPDATE pre_orders SET updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;

  COMMIT;

  CALL sp_preorder_get(p_id);
END
