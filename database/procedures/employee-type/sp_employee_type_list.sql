-- sp_employee_type_list
-- Purpose : Paged employee types with employee counts.
-- Params  : p_search (name / description), p_status (1/0/NULL), p_can_login (1/0/NULL),
--           p_sort_by (name|canLogin|status|createdAt), p_sort_dir, p_page, p_limit
-- Results : (1) rows, (2) total
-- Errors  : none
CREATE PROCEDURE sp_employee_type_list(
  IN p_search    VARCHAR(100),
  IN p_status    TINYINT,
  IN p_can_login TINYINT,
  IN p_sort_by   VARCHAR(30),
  IN p_sort_dir  VARCHAR(4),
  IN p_page      INT,
  IN p_limit     INT
)
BEGIN
  DECLARE v_limit  INT DEFAULT LEAST(GREATEST(IFNULL(p_limit, 10), 1), 1000);
  DECLARE v_offset INT DEFAULT (GREATEST(IFNULL(p_page, 1), 1) - 1) * v_limit;

  SELECT t.id, t.type_name AS name, IFNULL(t.description, '') AS description, t.can_login,
         IF(t.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         (SELECT COUNT(*) FROM employees e WHERE e.employee_type_id = t.id AND e.is_deleted = 0) AS employee_count,
         t.created_at, IFNULL(t.updated_at, t.created_at) AS updated_at
    FROM employee_types t
   WHERE t.is_deleted = 0
     AND (p_status IS NULL OR t.status = p_status)
     AND (p_can_login IS NULL OR t.can_login = p_can_login)
     AND (IFNULL(p_search, '') = '' OR t.type_name LIKE CONCAT('%', p_search, '%') OR t.description LIKE CONCAT('%', p_search, '%'))
   ORDER BY
     CASE WHEN p_sort_by = 'name'      AND p_sort_dir = 'asc'  THEN t.type_name END ASC,
     CASE WHEN p_sort_by = 'name'      AND p_sort_dir = 'desc' THEN t.type_name END DESC,
     CASE WHEN p_sort_by = 'canLogin'  AND p_sort_dir = 'asc'  THEN t.can_login END ASC,
     CASE WHEN p_sort_by = 'canLogin'  AND p_sort_dir = 'desc' THEN t.can_login END DESC,
     CASE WHEN p_sort_by = 'status'    AND p_sort_dir = 'asc'  THEN t.status END ASC,
     CASE WHEN p_sort_by = 'status'    AND p_sort_dir = 'desc' THEN t.status END DESC,
     CASE WHEN p_sort_by = 'createdAt' AND p_sort_dir = 'asc'  THEN t.id END ASC,
     t.id DESC
   LIMIT v_limit OFFSET v_offset;

  SELECT COUNT(*) AS total
    FROM employee_types t
   WHERE t.is_deleted = 0
     AND (p_status IS NULL OR t.status = p_status)
     AND (p_can_login IS NULL OR t.can_login = p_can_login)
     AND (IFNULL(p_search, '') = '' OR t.type_name LIKE CONCAT('%', p_search, '%') OR t.description LIKE CONCAT('%', p_search, '%'));
END
