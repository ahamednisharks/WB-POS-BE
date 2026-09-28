-- sp_login_reset_password
-- Purpose : Admin sets a new password (bcrypt hash from Node) and clears any lockout.
-- Params  : p_id, p_password_hash, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 missing hash, 45404 not found
CREATE PROCEDURE sp_login_reset_password(IN p_id INT, IN p_password_hash VARCHAR(100), IN p_user_id INT)
BEGIN
  DECLARE v_username VARCHAR(30) DEFAULT NULL;

  SELECT username INTO v_username FROM users WHERE id = p_id AND is_deleted = 0;
  IF v_username IS NULL THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Login not found';
  END IF;
  IF IFNULL(p_password_hash, '') = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'password::Password is required';
  END IF;

  UPDATE users
     SET password_hash = p_password_hash, failed_attempts = 0, locked_until = NULL,
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;
  CALL sp_util_audit(p_user_id, 'RESET_PASSWORD', 'users', p_id, NULL, NULL);

  SELECT p_id AS id, CONCAT('Password reset for ', v_username) AS message;
END
