-- sp_login_get
-- Purpose : One login account.
-- Params  : p_id
-- Results : (1) row
-- Errors  : 45404 not found
CREATE PROCEDURE sp_login_get(IN p_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Login not found';
  END IF;

  SELECT u.id, u.employee_id, IFNULL(e.emp_code, '') AS emp_code,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS employee_name,
         u.username, u.role, IF(u.status = 1, 'ACTIVE', 'BLOCKED') AS status, u.last_login_at AS last_login,
         IF(u.locked_until > NOW(), 1, 0) AS is_locked,
         u.created_at, IFNULL(u.updated_at, u.created_at) AS updated_at
    FROM users u
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE u.id = p_id;
END
