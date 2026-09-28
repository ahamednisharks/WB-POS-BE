-- sp_salary_payment_slip
-- Purpose : Data for the printable salary slip.
-- Params  : p_id
-- Results : (1) shop settings, (2) salary record with employee details and the setup used
-- Errors  : 45404 not found
CREATE PROCEDURE sp_salary_payment_slip(IN p_id INT)
BEGIN
  DECLARE v_emp   INT DEFAULT NULL;
  DECLARE v_month CHAR(7);

  SELECT employee_id, pay_month INTO v_emp, v_month FROM salary_payments WHERE id = p_id AND is_deleted = 0;
  IF v_emp IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Salary payment not found';
  END IF;

  CALL sp_settings_get();

  SELECT p.id, p.pay_month AS month, DATE_FORMAT(STR_TO_DATE(CONCAT(p.pay_month, '-01'), '%Y-%m-%d'), '%M %Y') AS month_label,
         p.employee_id, e.emp_code, e.full_name AS employee_name, t.type_name AS employee_type_name,
         e.mobile, e.joining_date, e.bank_account_enc, IFNULL(e.ifsc, '') AS ifsc,
         s.salary_type, s.basic_salary, s.allowances,
         p.working_days, p.days_present, p.gross_salary AS gross, p.bonus, p.advance_deduction,
         p.other_deduction AS other_deductions, IFNULL(p.deduction_reason, '') AS deduction_reason,
         p.net_salary AS net, p.payment_date, p.payment_mode, p.pay_status AS status
    FROM salary_payments p
    JOIN employees e      ON e.id = p.employee_id
    JOIN employee_types t ON t.id = e.employee_type_id
    LEFT JOIN salary_setups s ON s.id = (
      SELECT s2.id FROM salary_setups s2
       WHERE s2.employee_id = p.employee_id AND s2.is_deleted = 0
         AND s2.effective_from <= LAST_DAY(STR_TO_DATE(CONCAT(p.pay_month, '-01'), '%Y-%m-%d'))
       ORDER BY s2.effective_from DESC, s2.id DESC LIMIT 1)
   WHERE p.id = p_id;
END
