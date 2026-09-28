-- sp_salary_payment_list
-- Purpose : Paged salary records plus totals for the same filter (month summary cards).
-- Params  : p_search (employee name / code), p_month 'YYYY-MM', p_employee_id, p_pay_status (PENDING|PAID|NULL),
--           p_sort_by (month|empCode|employeeName|gross|net|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total, (3) totals (records, gross, bonus, advance_deduction, other_deductions, net, paid, pending)
-- Errors  : none
CREATE PROCEDURE sp_salary_payment_list(
  IN p_search      VARCHAR(100),
  IN p_month       CHAR(7),
  IN p_employee_id INT,
  IN p_pay_status  VARCHAR(10),
  IN p_sort_by     VARCHAR(30),
  IN p_sort_dir    VARCHAR(4),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT p.id, p.pay_month AS month, p.employee_id, e.emp_code, e.full_name AS employee_name,
         p.working_days, p.days_present, p.gross_salary AS gross, p.bonus, p.advance_deduction,
         p.other_deduction AS other_deductions, IFNULL(p.deduction_reason, '') AS deduction_reason,
         p.net_salary AS net, p.payment_date, p.payment_mode, p.pay_status AS status,
         p.created_at, IFNULL(p.updated_at, p.created_at) AS updated_at
    FROM salary_payments p
    JOIN employees e ON e.id = p.employee_id
   WHERE p.is_deleted = 0
     AND (IFNULL(p_month, '') = '' OR p.pay_month = p_month)
     AND (p_employee_id IS NULL OR p.employee_id = p_employee_id)
     AND (IFNULL(p_pay_status, '') = '' OR p.pay_status = p_pay_status)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'month'        AND p_sort_dir = 'asc'  THEN p.pay_month END ASC,
     CASE WHEN p_sort_by = 'month'        AND p_sort_dir = 'desc' THEN p.pay_month END DESC,
     CASE WHEN p_sort_by = 'empCode'      AND p_sort_dir = 'asc'  THEN e.emp_code END ASC,
     CASE WHEN p_sort_by = 'empCode'      AND p_sort_dir = 'desc' THEN e.emp_code END DESC,
     CASE WHEN p_sort_by = 'employeeName' AND p_sort_dir = 'asc'  THEN e.full_name END ASC,
     CASE WHEN p_sort_by = 'employeeName' AND p_sort_dir = 'desc' THEN e.full_name END DESC,
     CASE WHEN p_sort_by = 'gross'        AND p_sort_dir = 'asc'  THEN p.gross_salary END ASC,
     CASE WHEN p_sort_by = 'gross'        AND p_sort_dir = 'desc' THEN p.gross_salary END DESC,
     CASE WHEN p_sort_by = 'net'          AND p_sort_dir = 'asc'  THEN p.net_salary END ASC,
     CASE WHEN p_sort_by = 'net'          AND p_sort_dir = 'desc' THEN p.net_salary END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN p.pay_status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN p.pay_status END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN p.id END ASC,
     p.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM salary_payments p
    JOIN employees e ON e.id = p.employee_id
   WHERE p.is_deleted = 0
     AND (IFNULL(p_month, '') = '' OR p.pay_month = p_month)
     AND (p_employee_id IS NULL OR p.employee_id = p_employee_id)
     AND (IFNULL(p_pay_status, '') = '' OR p.pay_status = p_pay_status)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'));

  SELECT COUNT(*) AS records,
         IFNULL(SUM(p.gross_salary), 0) AS gross,
         IFNULL(SUM(p.bonus), 0) AS bonus,
         IFNULL(SUM(p.advance_deduction), 0) AS advance_deduction,
         IFNULL(SUM(p.other_deduction), 0) AS other_deductions,
         IFNULL(SUM(p.net_salary), 0) AS net,
         IFNULL(SUM(IF(p.pay_status = 'PAID', p.net_salary, 0)), 0) AS paid,
         IFNULL(SUM(IF(p.pay_status = 'PENDING', p.net_salary, 0)), 0) AS pending
    FROM salary_payments p
    JOIN employees e ON e.id = p.employee_id
   WHERE p.is_deleted = 0
     AND (IFNULL(p_month, '') = '' OR p.pay_month = p_month)
     AND (p_employee_id IS NULL OR p.employee_id = p_employee_id)
     AND (IFNULL(p_pay_status, '') = '' OR p.pay_status = p_pay_status)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'));
END
