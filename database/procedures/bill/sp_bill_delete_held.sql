-- sp_bill_delete_held
-- Purpose : Discards a HELD bill (soft delete). Completed bills must be cancelled instead.
-- Params  : p_id, p_user_id, p_role
-- Results : (1) id, message, deleted
-- Errors  : 45000 not HELD, 45404 not found / not visible
CREATE PROCEDURE sp_bill_delete_held(IN p_id INT, IN p_user_id INT, IN p_role VARCHAR(10))
BEGIN
  DECLARE v_status  VARCHAR(10) DEFAULT NULL;
  DECLARE v_cashier INT;

  SELECT bill_status, cashier_id INTO v_status, v_cashier FROM bills WHERE id = p_id AND is_deleted = 0;
  IF v_status IS NULL OR (p_role = 'CASHIER' AND v_cashier <> p_user_id) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Bill not found';
  END IF;
  IF v_status <> 'HELD' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only held bills can be deleted. Cancel a completed bill instead.';
  END IF;

  UPDATE bills SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
  INSERT INTO bill_status_history (bill_id, from_status, to_status, remarks, changed_by)
  VALUES (p_id, 'HELD', 'HELD', 'Discarded', p_user_id);
  CALL sp_util_audit(p_user_id, 'DELETE', 'bills', p_id, NULL, NULL);

  SELECT p_id AS id, 'Held bill discarded' AS message, 1 AS deleted;
END
