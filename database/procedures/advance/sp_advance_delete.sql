-- sp_advance_delete
-- Purpose : Soft-deletes an advance that has not been recovered at all.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45000 already (partly) recovered, 45404 not found
CREATE PROCEDURE sp_advance_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_recovered DECIMAL(12,2);

  SELECT recovered_amount INTO v_recovered FROM employee_advances WHERE id = p_id AND is_deleted = 0;
  IF v_recovered IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Advance not found';
  END IF;
  IF v_recovered > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This advance is already partly recovered and cannot be deleted';
  END IF;

  UPDATE employee_advances SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'DELETE', 'employee_advances', p_id, NULL, NULL);
  SELECT p_id AS id, 'Advance deleted successfully' AS message, 1 AS deleted;
END
