-- sp_advance_pending
-- Purpose : Outstanding advance of an employee (what salary can still recover), oldest first.
-- Params  : p_employee_id
-- Results : (1) summary (employee_id, total_advance, total_recovered, pending), (2) open advances
-- Errors  : 45404 employee not found
CREATE PROCEDURE sp_advance_pending(IN p_employee_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee not found';
  END IF;

  SELECT p_employee_id AS employee_id,
         IFNULL(SUM(amount), 0) AS total_advance,
         IFNULL(SUM(recovered_amount), 0) AS total_recovered,
         IFNULL(SUM(amount - recovered_amount), 0) AS pending
    FROM employee_advances
   WHERE employee_id = p_employee_id AND is_deleted = 0;

  SELECT id, advance_date, amount, recovered_amount, amount - recovered_amount AS balance, IFNULL(remarks, '') AS remarks
    FROM employee_advances
   WHERE employee_id = p_employee_id AND is_deleted = 0 AND amount > recovered_amount
   ORDER BY advance_date, id;
END
