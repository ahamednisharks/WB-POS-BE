-- sp_employee_profile
-- Purpose : Employee profile page: details, salary setups, last 12 salary payments, login and advance summary.
-- Params  : p_id
-- Results : (1) employee (as sp_employee_get), (2) salary setups, (3) last 12 payments, (4) login (0/1 row),
--           (5) advances summary (total, recovered, pending)
-- Errors  : 45404 not found
CREATE PROCEDURE sp_employee_profile(IN p_id INT)
BEGIN
  CALL sp_employee_get(p_id);

  SELECT s.id, s.salary_type, s.basic_salary, s.allowances, s.effective_from, s.created_at
    FROM salary_setups s
   WHERE s.employee_id = p_id AND s.is_deleted = 0
   ORDER BY s.effective_from DESC;

  SELECT p.id, p.pay_month AS month, p.working_days, p.days_present, p.gross_salary AS gross, p.bonus,
         p.advance_deduction, p.other_deduction AS other_deductions, p.net_salary AS net,
         p.payment_date, p.payment_mode, p.pay_status AS status
    FROM salary_payments p
   WHERE p.employee_id = p_id AND p.is_deleted = 0
   ORDER BY p.pay_month DESC
   LIMIT 12;

  SELECT u.id, u.username, u.role, IF(u.status = 1, 'ACTIVE', 'BLOCKED') AS status, u.last_login_at AS last_login
    FROM users u
   WHERE u.employee_id = p_id AND u.is_deleted = 0;

  SELECT IFNULL(SUM(a.amount), 0) AS total_advance,
         IFNULL(SUM(a.recovered_amount), 0) AS total_recovered,
         IFNULL(SUM(a.amount - a.recovered_amount), 0) AS pending
    FROM employee_advances a
   WHERE a.employee_id = p_id AND a.is_deleted = 0;
END
