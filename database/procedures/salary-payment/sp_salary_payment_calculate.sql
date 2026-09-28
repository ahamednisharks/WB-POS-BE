-- sp_salary_payment_calculate
-- Purpose : Preview of a salary for the entry form: setup in force, gross and the pending advance.
-- Params  : p_employee_id, p_month 'YYYY-MM', p_working_days, p_days_present
-- Results : (1) employee_id, emp_code, employee_name, month, salary_type, basic_salary, allowances, effective_from,
--               working_days, days_present, gross, pending_advance, existing_id
-- Errors  : 45000 invalid input / no setup, 45404 employee not found
CREATE PROCEDURE sp_salary_payment_calculate(
  IN p_employee_id  INT,
  IN p_month        CHAR(7),
  IN p_working_days DECIMAL(5,1),
  IN p_days_present DECIMAL(5,1)
)
BEGIN
  DECLARE v_gross    DECIMAL(12,2);
  DECLARE v_setup_id INT;

  IF NOT EXISTS (SELECT 1 FROM employees WHERE id = p_employee_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee not found';
  END IF;

  CALL sp_salary_payment_compute(p_employee_id, p_month, p_working_days, p_days_present, v_gross, v_setup_id);

  SELECT e.id AS employee_id, e.emp_code, e.full_name AS employee_name, p_month AS month,
         s.salary_type, s.basic_salary, s.allowances, s.effective_from,
         p_working_days AS working_days, p_days_present AS days_present, v_gross AS gross,
         (SELECT IFNULL(SUM(a.amount - a.recovered_amount), 0) FROM employee_advances a
           WHERE a.employee_id = e.id AND a.is_deleted = 0) AS pending_advance,
         (SELECT sp.id FROM salary_payments sp
           WHERE sp.employee_id = e.id AND sp.pay_month = p_month AND sp.is_deleted = 0 LIMIT 1) AS existing_id
    FROM employees e
    JOIN salary_setups s ON s.id = v_setup_id
   WHERE e.id = p_employee_id;
END
