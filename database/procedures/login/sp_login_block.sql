-- sp_login_block
-- Purpose : Blocks (p_blocked = 1) or unblocks a login. Unblocking also clears a lockout.
-- Params  : p_id, p_blocked, p_user_id
-- Results : (1) id, message
-- Errors  : 45000 own login / resigned employee, 45404 not found
CREATE PROCEDURE sp_login_block(IN p_id INT, IN p_blocked TINYINT, IN p_user_id INT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_id AND is_deleted = 0) THEN
    SIGNAL SQLSTATE '45404' SET MESSAGE_TEXT = 'Login not found';
  END IF;
  IF IFNULL(p_blocked, 0) = 1 AND p_id = p_user_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You cannot block your own login';
  END IF;
  IF IFNULL(p_blocked, 0) = 0 AND EXISTS (SELECT 1 FROM users u JOIN employees e ON e.id = u.employee_id
                                          WHERE u.id = p_id AND e.emp_status = 'RESIGNED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The employee has resigned, so the login cannot be unblocked';
  END IF;

  UPDATE users
     SET status = IF(IFNULL(p_blocked, 0) = 1, 0, 1),
         failed_attempts = IF(IFNULL(p_blocked, 0) = 1, failed_attempts, 0),
         locked_until = IF(IFNULL(p_blocked, 0) = 1, locked_until, NULL),
         updated_by = p_user_id, updated_at = NOW()
   WHERE id = p_id;
  CALL sp_util_audit(p_user_id, IF(IFNULL(p_blocked, 0) = 1, 'BLOCK', 'UNBLOCK'), 'users', p_id, NULL, NULL);

  SELECT p_id AS id, IF(IFNULL(p_blocked, 0) = 1, 'Login blocked', 'Login unblocked') AS message;
END
