-- sp_salary_setup_get
-- Purpose : One salary setup.
-- Params  : p_id
-- Results : (1) row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_salary_setup_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM salary_setups WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary setup not found';
  END IF;

  SELECT s.id, s.employee_id, e.emp_code, e.full_name AS employee_name, s.salary_type, s.basic_salary,
         s.allowances, s.effective_from, s.created_at, IFNULL(s.updated_at, s.created_at) AS updated_at
    FROM salary_setups s
    JOIN employees e ON e.id = s.employee_id
   WHERE s.id = p_id;
END
