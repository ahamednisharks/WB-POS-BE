-- sp_auth_me
-- Purpose : Profile of the logged-in user (also used by the JWT strategy on every request).
-- Params  : p_user_id
-- Results : (1) id, username, name, role, employee_id, emp_code, last_login_at, is_active
-- Errors  : 45401 user no longer exists
CREATE PROCEDURE sp_auth_me(IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45401' SET MESSAGE_TEXT = 'User not found';
  END IF;

  SELECT u.id,
         u.username,
         COALESCE(e.full_name, IF(u.employee_id IS NULL, 'Administrator', u.username)) AS name,
         u.role,
         u.employee_id,
         e.emp_code,
         u.last_login_at,
         IF(u.status = 1 AND IFNULL(e.emp_status, 'ACTIVE') = 'ACTIVE', 1, 0) AS is_active
    FROM users u
    LEFT JOIN employees e ON e.id = u.employee_id
   WHERE u.id = p_user_id;
END
