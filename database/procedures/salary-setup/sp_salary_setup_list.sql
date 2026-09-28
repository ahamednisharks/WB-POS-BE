-- sp_salary_setup_list
-- Purpose : Paged salary setups.
-- Params  : p_search (employee name / code), p_employee_id, p_salary_type (MONTHLY|DAILY|NULL),
--           p_sort_by (empCode|employeeName|salaryType|basicSalary|allowances|effectiveFrom|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_salary_setup_list(
  IN p_search      VARCHAR(100),
  IN p_employee_id INT,
  IN p_salary_type VARCHAR(10),
  IN p_sort_by     VARCHAR(30),
  IN p_sort_dir    VARCHAR(4),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT s.id, s.employee_id, e.emp_code, e.full_name AS employee_name, s.salary_type, s.basic_salary,
         s.allowances, s.effective_from, s.created_at, IFNULL(s.updated_at, s.created_at) AS updated_at
    FROM salary_setups s
    JOIN employees e ON e.id = s.employee_id
   WHERE s.is_deleted = 0
     AND (p_employee_id IS NULL OR s.employee_id = p_employee_id)
     AND (IFNULL(p_salary_type, '') = '' OR s.salary_type = p_salary_type)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'empCode'       AND p_sort_dir = 'asc'  THEN e.emp_code END ASC,
     CASE WHEN p_sort_by = 'empCode'       AND p_sort_dir = 'desc' THEN e.emp_code END DESC,
     CASE WHEN p_sort_by = 'employeeName'  AND p_sort_dir = 'asc'  THEN e.full_name END ASC,
     CASE WHEN p_sort_by = 'employeeName'  AND p_sort_dir = 'desc' THEN e.full_name END DESC,
     CASE WHEN p_sort_by = 'salaryType'    AND p_sort_dir = 'asc'  THEN s.salary_type END ASC,
     CASE WHEN p_sort_by = 'salaryType'    AND p_sort_dir = 'desc' THEN s.salary_type END DESC,
     CASE WHEN p_sort_by = 'basicSalary'   AND p_sort_dir = 'asc'  THEN s.basic_salary END ASC,
     CASE WHEN p_sort_by = 'basicSalary'   AND p_sort_dir = 'desc' THEN s.basic_salary END DESC,
     CASE WHEN p_sort_by = 'allowances'    AND p_sort_dir = 'asc'  THEN s.allowances END ASC,
     CASE WHEN p_sort_by = 'allowances'    AND p_sort_dir = 'desc' THEN s.allowances END DESC,
     CASE WHEN p_sort_by = 'effectiveFrom' AND p_sort_dir = 'asc'  THEN s.effective_from END ASC,
     CASE WHEN p_sort_by = 'effectiveFrom' AND p_sort_dir = 'desc' THEN s.effective_from END DESC,
     CASE WHEN p_sort_by = 'createdAt'     AND p_sort_dir = 'asc'  THEN s.id END ASC,
     s.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM salary_setups s
    JOIN employees e ON e.id = s.employee_id
   WHERE s.is_deleted = 0
     AND (p_employee_id IS NULL OR s.employee_id = p_employee_id)
     AND (IFNULL(p_salary_type, '') = '' OR s.salary_type = p_salary_type)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'));
END
