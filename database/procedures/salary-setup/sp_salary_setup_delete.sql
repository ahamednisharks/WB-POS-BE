-- sp_salary_setup_delete
-- Purpose : Soft-deletes a salary setup (past salary payments keep their own computed amounts).
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45404 not found
CREATE PROCEDURE sp_salary_setup_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM salary_setups WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary setup not found';
  END IF;

  UPDATE salary_setups SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'DELETE', 'salary_setups', p_id, NULL, NULL);
  SELECT p_id AS id, 'Salary setup deleted successfully' AS message, 1 AS deleted;
END
