-- sp_employee_type_get
-- Purpose : One employee type.
-- Params  : p_id
-- Results : (1) row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_employee_type_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM employee_types WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Employee type not found';
  END IF;

  SELECT t.id, t.type_name AS name, IFNULL(t.description, '') AS description, t.can_login,
         IF(t.status = 1, 'ACTIVE', 'INACTIVE') AS status,
         (SELECT COUNT(*) FROM employees e WHERE e.employee_type_id = t.id AND e.is_deleted = 0) AS employee_count,
         t.created_at, IFNULL(t.updated_at, t.created_at) AS updated_at
    FROM employee_types t
   WHERE t.id = p_id;
END
