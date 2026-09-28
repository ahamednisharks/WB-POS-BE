-- sp_login_delete
-- Purpose : Soft-deletes a login; if it has billed or recorded transactions it is blocked instead.
-- Params  : p_id, p_user_id
-- Results : (1) id, message, deleted
-- Errors  : 45000 own login, 45404 not found
CREATE PROCEDURE sp_login_delete(IN p_id INT, IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Login not found';
  END IF;
  IF p_id = p_user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You cannot delete your own login';
  END IF;

  IF EXISTS (SELECT 1 FROM bills WHERE cashier_id = p_id) OR EXISTS (SELECT 1 FROM transactions WHERE user_id = p_id) THEN
    UPDATE users SET status = 0, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'BLOCK', 'users', p_id, NULL, JSON_OBJECT('status', 0));
    SELECT p_id AS id, 'This login has billing history - blocked instead of deleted' AS message, 0 AS deleted;
  ELSE
    UPDATE users SET is_deleted = 1, status = 0, updated_by = p_user_id, updated_at = NOW() WHERE id = p_id;
    CALL sp_util_audit(p_user_id, 'DELETE', 'users', p_id, NULL, NULL);
    SELECT p_id AS id, 'Login deleted successfully' AS message, 1 AS deleted;
  END IF;
END
