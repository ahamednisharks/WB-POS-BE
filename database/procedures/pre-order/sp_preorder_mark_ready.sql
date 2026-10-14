-- sp_preorder_mark_ready
-- Purpose : Kitchen / counter marks a BOOKED pre-order as READY for pickup or delivery.
-- Params  : p_id, p_user_id
-- Results : the pre-order, as sp_preorder_get
-- Errors  : 45000 not booked, 45404 not found
CREATE PROCEDURE sp_preorder_mark_ready(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_status VARCHAR(10) DEFAULT NULL;

  SELECT order_status INTO v_status FROM pre_orders WHERE id = p_id AND is_deleted = 0;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Pre-order not found';
  END IF;
  IF v_status <> 'BOOKED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only a booked pre-order can be marked ready';
  END IF;

  UPDATE pre_orders
     SET order_status = 'READY', ready_at = NOW(), updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id AND order_status = 'BOOKED';

  CALL sp_preorder_get(p_id);
END
