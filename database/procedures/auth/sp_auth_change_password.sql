-- sp_auth_change_password
-- Purpose : Stores a new bcrypt hash for the logged-in user (hashing happens in Node).
-- Params  : p_user_id, p_new_hash
-- Results : (1) id, message
-- Errors  : 45000 missing hash, 45404 user not found
CREATE PROCEDURE sp_auth_change_password(IN p_user_id INT, IN p_new_hash VARCHAR(100))
BEGIN
  IF IFNULL(p_new_hash, '') = '' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Password is required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'User not found';
  END IF;

  UPDATE users
     SET password_hash = p_new_hash, failed_attempts = 0, locked_until = NULL,
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_user_id;

  SELECT p_user_id AS id, 'Password changed successfully' AS message;
END
