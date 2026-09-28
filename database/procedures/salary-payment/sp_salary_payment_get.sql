-- sp_salary_payment_get
-- Purpose : One salary record.
-- Params  : p_id
-- Results : (1) row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_salary_payment_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM salary_payments WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary payment not found';
  END IF;

  SELECT p.id, p.pay_month AS month, p.employee_id, e.emp_code, e.full_name AS employee_name,
         p.working_days, p.days_present, p.gross_salary AS gross, p.bonus, p.advance_deduction,
         p.other_deduction AS other_deductions, IFNULL(p.deduction_reason, '') AS deduction_reason,
         p.net_salary AS net, p.payment_date, p.payment_mode, p.pay_status AS status,
         p.created_at, IFNULL(p.updated_at, p.created_at) AS updated_at
    FROM salary_payments p
    JOIN employees e ON e.id = p.employee_id
   WHERE p.id = p_id;
END
