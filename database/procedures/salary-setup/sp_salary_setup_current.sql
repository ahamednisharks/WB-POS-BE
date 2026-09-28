-- sp_salary_setup_current
-- Purpose : Setup in force for a month = latest effective_from on or before the last day of that month.
-- Params  : p_employee_id, p_month CHAR(7) 'YYYY-MM' (NULL = current month)
-- Results : (1) setup row (0 rows when the employee has no setup yet)
-- Errors  : 45000 invalid month, 45404 employee not found
CREATE PROCEDURE sp_salary_setup_current(IN p_employee_id INT, IN p_month CHAR(7))
BEGIN
  DECLARE v_month    CHAR(7) DEFAULT IFNULL(p_month, DATE_FORMAT(CURDATE(), '%Y-%m'));
  DECLARE v_month_end DATE;

  IF v_month NOT REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'month::Month must be YYYY-MM';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee not found';
  END IF;

  SET v_month_end = LAST_DAY(STR_TO_DATE(CONCAT(v_month, '-01'), '%Y-%m-%d'));

  SELECT s.id, s.employee_id, e.emp_code, e.full_name AS employee_name, s.salary_type, s.basic_salary,
         s.allowances, s.effective_from, v_month AS month
    FROM salary_setups s
    JOIN employees e ON e.id = s.employee_id
   WHERE s.employee_id = p_employee_id AND s.is_deleted = 0 AND s.effective_from <= v_month_end
   ORDER BY s.effective_from DESC, s.id DESC
   LIMIT 1;
END
