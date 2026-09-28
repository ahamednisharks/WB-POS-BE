-- sp_advance_list
-- Purpose : Paged salary advances.
-- Params  : p_search (employee name / code), p_employee_id, p_from DATE, p_to DATE, p_pending_only (1 = balance > 0),
--           p_sort_by (advanceDate|employeeName|amount|balance|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_advance_list(
  IN p_search       VARCHAR(100),
  IN p_employee_id  INT,
  IN p_from         DATE,
  IN p_to           DATE,
  IN p_pending_only TINYINT,
  IN p_sort_by      VARCHAR(30),
  IN p_sort_dir     VARCHAR(4),
  IN p_page         INT,
  IN p_limit        INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT a.id, a.employee_id, e.emp_code, e.full_name AS employee_name, a.advance_date, a.amount,
         a.recovered_amount, a.amount - a.recovered_amount AS balance, IFNULL(a.remarks, '') AS remarks,
         a.created_at, IFNULL(a.updated_at, a.created_at) AS updated_at
    FROM employee_advances a
    JOIN employees e ON e.id = a.employee_id
   WHERE a.is_deleted = 0
     AND (p_employee_id IS NULL OR a.employee_id = p_employee_id)
     AND (p_from IS NULL OR a.advance_date >= p_from)
     AND (p_to IS NULL OR a.advance_date <= p_to)
     AND (IFNULL(p_pending_only, 0) = 0 OR a.amount > a.recovered_amount)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'advanceDate'  AND p_sort_dir = 'asc'  THEN a.advance_date END ASC,
     CASE WHEN p_sort_by = 'advanceDate'  AND p_sort_dir = 'desc' THEN a.advance_date END DESC,
     CASE WHEN p_sort_by = 'employeeName' AND p_sort_dir = 'asc'  THEN e.full_name END ASC,
     CASE WHEN p_sort_by = 'employeeName' AND p_sort_dir = 'desc' THEN e.full_name END DESC,
     CASE WHEN p_sort_by = 'amount'       AND p_sort_dir = 'asc'  THEN a.amount END ASC,
     CASE WHEN p_sort_by = 'amount'       AND p_sort_dir = 'desc' THEN a.amount END DESC,
     CASE WHEN p_sort_by = 'balance'      AND p_sort_dir = 'asc'  THEN a.amount - a.recovered_amount END ASC,
     CASE WHEN p_sort_by = 'balance'      AND p_sort_dir = 'desc' THEN a.amount - a.recovered_amount END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN a.id END ASC,
     a.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM employee_advances a
    JOIN employees e ON e.id = a.employee_id
   WHERE a.is_deleted = 0
     AND (p_employee_id IS NULL OR a.employee_id = p_employee_id)
     AND (p_from IS NULL OR a.advance_date >= p_from)
     AND (p_to IS NULL OR a.advance_date <= p_to)
     AND (IFNULL(p_pending_only, 0) = 0 OR a.amount > a.recovered_amount)
     AND (IFNULL(p_search, '') = '' OR e.full_name LIKE CONCAT('%', p_search, '%') OR e.emp_code LIKE CONCAT('%', p_search, '%'));
END
