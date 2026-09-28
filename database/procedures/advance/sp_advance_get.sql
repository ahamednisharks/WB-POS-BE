-- sp_advance_get
-- Purpose : One salary advance.
-- Params  : p_id
-- Results : (1) row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_advance_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM employee_advances WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Advance not found';
  END IF;

  SELECT a.id, a.employee_id, e.emp_code, e.full_name AS employee_name, a.advance_date, a.amount,
         a.recovered_amount, a.amount - a.recovered_amount AS balance, IFNULL(a.remarks, '') AS remarks,
         a.created_at, IFNULL(a.updated_at, a.created_at) AS updated_at
    FROM employee_advances a
    JOIN employees e ON e.id = a.employee_id
   WHERE a.id = p_id;
END
