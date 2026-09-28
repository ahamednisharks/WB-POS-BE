-- sp_po_delete
-- Purpose : Deletes a DRAFT purchase order (sent orders must be cancelled instead).
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45000 not a draft, 45404 not found
CREATE PROCEDURE sp_po_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_status VARCHAR(10) DEFAULT NULL;

  SELECT po_status INTO v_status FROM purchase_orders WHERE id = p_id AND is_deleted = 0;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Purchase order not found';
  END IF;
  IF v_status <> 'DRAFT' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only draft purchase orders can be deleted. Cancel it instead.';
  END IF;

  UPDATE purchase_orders SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'DELETE', 'purchase_orders', p_id, NULL, NULL);
  SELECT p_id AS id, 'Purchase order deleted' AS message, 1 AS deleted;
END
