-- sp_login_list
-- Purpose : Paged login accounts (never returns password hashes).
-- Params  : p_search (username, employee name / code), p_status (1 active / 0 blocked / NULL), p_role, p_employee_id,
--           p_sort_by (empCode|employeeName|username|role|status|lastLogin|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_login_list(
  IN p_search      VARCHAR(100),
  IN p_status      TINYINT,
  IN p_role        VARCHAR(10),
  IN p_employee_id INT,
  IN p_sort_by     VARCHAR(30),
  IN p_sort_dir    VARCHAR(4),
  IN p_page        INT,
  IN p_limit       INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT u.id, u.employee_id, IFNULL(e.emp_code, '') AS emp_code,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS employee_name,
         u.username, u.role, IF(u.status = 1, 'ACTIVE', 'BLOCKED') AS status, u.last_login_at AS last_login,
         IF(u.locked_until > NOW(), 1, 0) AS is_locked,
         u.created_at, IFNULL(u.updated_at, u.created_at) AS updated_at
    FROM users u
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE u.is_deleted = 0
     AND (p_status IS NULL OR u.status = p_status)
     AND (IFNULL(p_role, '') = '' OR u.role = p_role)
     AND (p_employee_id IS NULL OR u.employee_id = p_employee_id)
     AND (IFNULL(p_search, '') = ''
          OR u.username LIKE CONCAT('%', p_search, '%')
          OR e.full_name LIKE CONCAT('%', p_search, '%')
          OR e.emp_code LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'empCode'      AND p_sort_dir = 'asc'  THEN e.emp_code END ASC,
     CASE WHEN p_sort_by = 'empCode'      AND p_sort_dir = 'desc' THEN e.emp_code END DESC,
     CASE WHEN p_sort_by = 'employeeName' AND p_sort_dir = 'asc'  THEN e.full_name END ASC,
     CASE WHEN p_sort_by = 'employeeName' AND p_sort_dir = 'desc' THEN e.full_name END DESC,
     CASE WHEN p_sort_by = 'username'     AND p_sort_dir = 'asc'  THEN u.username END ASC,
     CASE WHEN p_sort_by = 'username'     AND p_sort_dir = 'desc' THEN u.username END DESC,
     CASE WHEN p_sort_by = 'role'         AND p_sort_dir = 'asc'  THEN u.role END ASC,
     CASE WHEN p_sort_by = 'role'         AND p_sort_dir = 'desc' THEN u.role END DESC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'asc'  THEN u.status END ASC,
     CASE WHEN p_sort_by = 'status'       AND p_sort_dir = 'desc' THEN u.status END DESC,
     CASE WHEN p_sort_by = 'lastLogin'    AND p_sort_dir = 'asc'  THEN u.last_login_at END ASC,
     CASE WHEN p_sort_by = 'lastLogin'    AND p_sort_dir = 'desc' THEN u.last_login_at END DESC,
     CASE WHEN p_sort_by = 'createdAt'    AND p_sort_dir = 'asc'  THEN u.id END ASC,
     u.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM users u
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE u.is_deleted = 0
     AND (p_status IS NULL OR u.status = p_status)
     AND (IFNULL(p_role, '') = '' OR u.role = p_role)
     AND (p_employee_id IS NULL OR u.employee_id = p_employee_id)
     AND (IFNULL(p_search, '') = ''
          OR u.username LIKE CONCAT('%', p_search, '%')
          OR e.full_name LIKE CONCAT('%', p_search, '%')
          OR e.emp_code LIKE CONCAT('%', p_search, '%'));
END
