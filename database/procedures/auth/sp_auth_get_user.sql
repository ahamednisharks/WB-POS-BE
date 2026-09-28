-- sp_auth_get_user
-- Purpose : Login step 1 - returns the user's password hash so Node can bcrypt-compare it.
-- Params  : p_username
-- Results : (1) id, username, password_hash, role, status, employee_id
-- Errors  : 45401 unknown username
CREATE PROCEDURE sp_auth_get_user(IN p_username VARCHAR(30))
BEGIN
  DECLARE v_id INT DEFAULT NULL;

  SELECT MAX(id) INTO v_id FROM users WHERE username = TRIM(p_username) AND is_deleted = 0;

  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45401' SET MESSAGE_TEXT = 'Invalid username or password';
  END IF;

  SELECT u.id, u.username, u.password_hash, u.role, u.status, u.employee_id
    FROM users u
   WHERE u.id = v_id;
END
