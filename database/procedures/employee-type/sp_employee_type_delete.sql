-- sp_employee_type_delete
-- Purpose : Soft-deletes an employee type; if employees have it, marks it inactive instead.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45404 not found
CREATE PROCEDURE sp_employee_type_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  DECLARE v_used INT DEFAULT 0;

  IF NOT EXISTS (SELECT 1 FROM employee_types WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee type not found';
  END IF;

  SELECT COUNT(*) INTO v_used FROM employees WHERE employee_type_id = p_id AND is_deleted = 0;

  IF v_used > 0 THEN
    UPDATE employee_types SET status = 0, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DEACTIVATE', 'employee_types', p_id, NULL, JSON_OBJECT('status', 0));
    SELECT p_id AS id, CONCAT('In use by ', v_used, ' employee(s) - marked inactive') AS message, 0 AS deleted;
  ELSE
    UPDATE employee_types SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DELETE', 'employee_types', p_id, NULL, NULL);
    SELECT p_id AS id, 'Employee type deleted successfully' AS message, 1 AS deleted;
  END IF;
END
