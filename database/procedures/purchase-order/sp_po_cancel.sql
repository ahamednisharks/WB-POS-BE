-- sp_po_cancel
-- Purpose : Cancels a DRAFT or SENT purchase order (nothing received yet).
-- Params  : p_id, p_reason, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 reason missing / wrong status, 45404 not found
CREATE PROCEDURE sp_po_cancel(IN p_id INT, IN p_reason VARCHAR(200), IN p_user_id INT)
BEGIN
  DECLARE v_status VARCHAR(10) DEFAULT NULL;
  DECLARE v_msg    VARCHAR(128);

  IF TRIM(IFNULL(p_reason, '')) = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reason::Cancel reason is required';
  END IF;

  SELECT po_status INTO v_status FROM purchase_orders WHERE id = p_id AND is_deleted = 0;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase order not found';
  END IF;
  IF v_status NOT IN ('DRAFT', 'SENT') THEN
    SET v_msg = CONCAT('A ', LOWER(v_status), ' purchase order cannot be cancelled');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE purchase_orders
     SET po_status = 'CANCELLED', cancel_reason = TRIM(p_reason), updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'CANCEL', 'purchase_orders', p_id, JSON_OBJECT('status', v_status),
                     JSON_OBJECT('status', 'CANCELLED', 'reason', TRIM(p_reason)));

  SELECT p_id AS id, 'Purchase order cancelled' AS message;
END
