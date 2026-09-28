-- sp_auth_get_hash
-- Purpose : Current password hash of a user (change-password verifies the old password in Node).
-- Params  : p_user_id
-- Results : (1) id, password_hash
-- Errors  : 45404 user not found
CREATE PROCEDURE sp_auth_get_hash(IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'User not found';
  END IF;

  SELECT id, password_hash FROM users WHERE id = p_user_id;
END
