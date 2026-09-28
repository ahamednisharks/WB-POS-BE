-- sp_employee_delete
-- Purpose : Soft-deletes an employee. With a login, salary or advance records the employee is marked RESIGNED
--           (and the login blocked) instead.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45404 not found
CREATE PROCEDURE sp_employee_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee not found';
  END IF;

  IF EXISTS (SELECT 1 FROM users WHERE employee_id = p_id AND is_deleted = 0)
     OR EXISTS (SELECT 1 FROM salary_payments WHERE employee_id = p_id AND is_deleted = 0)
     OR EXISTS (SELECT 1 FROM salary_setups WHERE employee_id = p_id AND is_deleted = 0)
     OR EXISTS (SELECT 1 FROM employee_advances WHERE employee_id = p_id AND is_deleted = 0) THEN
    UPDATE employees
       SET emp_status = 'RESIGNED', resign_date = IFNULL(resign_date, CURDATE()), updated_by = p_user_id, updated_at = NOW()
     WHERE id = p_id;
    UPDATE users SET status = 0, updated_by = p_user_id, updated_at = NOW() WHERE employee_id = p_id AND is_deleted = 0;
    CALL sp_util_audit(p_user_id, 'DEACTIVATE', 'employees', p_id, NULL, JSON_OBJECT('empStatus', 'RESIGNED'));
    SELECT p_id AS id, 'Employee has login or salary records - marked resigned' AS message, 0 AS deleted;
  ELSE
    UPDATE employees SET is_deleted = 1, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DELETE', 'employees', p_id, NULL, NULL);
    SELECT p_id AS id, 'Employee deleted successfully' AS message, 1 AS deleted;
  END IF;
END
